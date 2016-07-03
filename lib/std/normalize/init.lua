--[[--
 Normalize API differences between supported Lua implementations.

 Respecting the values set in the `std.debug_init` module and the
 `_G._DEBUG` variable, inject deterministic identically behaving
 cross-implementation low-level functions into the callers environment.

 Writing Lua libraries that target several Lua implementations can be a
 frustrating exercise in working around lots of small differences in APIs
 and semantics they share (or rename, or omit).  _normalize_ provides the
 means to simply access deterministic implementations of those APIs that
 have the the same semantics across all supported host Lua
 implementations.  Each function is as thin and fast an implementation as
 is possible within that host Lua environment, evaluating to the Lua C
 implmentation with no overhead where host semantics allow.

 The core of this module is to transparently set the environment up with
 a single API (as opposed to requiring caching functions from a module
 table into module locals):

    local _ENV = require "std.normalize" {
      "package",
      "std.prototype",
      strict = "std.strict",
    }

 It is not yet complete, and in contrast to the kepler project
 lua-compat libraries, neither does it attempt to provide you with as
 nearly compatible an API as is possible relative to some specific Lua
 implementation - rather it provides a variation of the "lowest common
 denominator" that can be implemented relatively efficiently in the
 supported Lua implementations, all in pure Lua.

 At the moment, only the functionality used by stdlib is implemented.

 @module std.normalize
]]


local strict		= require "std.normalize._strict"

local _ = {
  base			= require "std.normalize._base",
  typecheck		= require "std.normalize._typecheck",
}

local _ENV = strict {
  _G			= _G,
  _VERSION		= _VERSION,
  getfenv		= getfenv or false,
  getmetatable		= getmetatable,
  load			= load,
  loadstring		= loadstring or load,
  next			= next,
  pairs			= pairs,
  pcall			= pcall,
  rawset		= rawset,
  require		= require,
  select		= select,
  setfenv		= setfenv or false,
  setmetatable		= setmetatable,
  tostring		= tostring,
  type			= type,
  xpcall		= xpcall,

  debug_getfenv		= debug.getfenv or false,
  debug_getinfo		= debug.getinfo,
  debug_getupvalue	= debug.getupvalue,
  debug_setfenv		= debug.setfenv or false,
  debug_setupvalue	= debug.setupvalue,
  debug_upvaluejoin	= debug.upvaluejoin,
  io_open		= io.open,
  os_exit		= os.exit,
  package_config	= package.config,
  package_searchpath	= package.searchpath,
  string_concat		= string.concat,
  string_gmatch		= string.gmatch,
  string_gsub		= string.gsub,
  string_match		= string.match,
  table_concat		= table.concat,
  table_remove		= table.remove,
  table_sort		= table.sort,
  table_unpack		= table.unpack or unpack,

  getmetamethod		= _.base.getmetamethod,
  pack			= _.base.pack,
  tointeger		= _.base.tointeger,
  ARGCHECK_FRAME	= _.typecheck.ARGCHECK_FRAME,
  any			= _.typecheck.any,
  argerror		= _.typecheck.argerror,
  argscheck		= _.typecheck.argscheck,
  opt			= _.typecheck.opt,
  types			= _.typecheck.types,
}
_ = nil


local ARGCHECK_FRAME	= ARGCHECK_FRAME



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


-- At this point, only the locals imported above are visible (even in
-- Lua 5.1). If "std.strict" is available, we'll also get a runtime
-- error if any of the code below tries to use an undeclared variable.


local dirsep, pathsep, pathmark, execdir, igmark =
  string_match (package_config, "^([^\n]+)\n([^\n]+)\n([^\n]+)\n([^\n]+)\n([^\n]+)")


-- It's hard to test at require-time whether the host `os.exit` handles
-- boolean argument properly (ostensibly to defer to it in that case).
-- We're shutting down anyway, so sacrifice a bit of speed for timely
-- diagnosis of float and nil valued argument (with the argscheck
-- annotation, later in the file), since that probably indicates a bug
-- in your code!
local function exit (...)
  local n, status = select ("#", ...), ...
  if tointeger (n) == 0 or status == true then
    os_exit (0)
  elseif status == false then
    os_exit (1)
  end
  os_exit (status)
end


local normalize_getfenv
if debug_getfenv then

  normalize_getfenv = function (fn)
    local n = tointeger (fn or 1)
    if n then
      if n > 0 then
        -- Adjust for this function's stack frame, if fn is non-zero.
        n = n + 1 + ARGCHECK_FRAME
      end

      -- Return an additional nil result to defeat tail call elimination
      -- which would remove a stack frame and break numeric *fn* count.
      return getfenv (n), nil
    end

    if type (fn) ~= "function" then
      -- Unwrap functors:
      -- No need to recurse because Lua doesn't support nested functors.
      -- __call can only (sensibly) be a function, so no need to adjust
      -- stack frame offset either.
      fn = (getmetatable (fn) or {}).__call or fn
    end

    -- In Lua 5.1, only debug.getfenv works on C functions; but it
    -- does not work on stack counts.
    return debug_getfenv (fn)
  end

else

  -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
  normalize_getfenv = function (fn)
    if fn == 0 then
      return _G
    end
    local n = tointeger (fn or 1)
    if n then
      fn = debug_getinfo (n + 1 + ARGCHECK_FRAME, "f").func
    elseif type (fn) ~= "function" then
      fn = (getmetatable (fn) or {}).__call or fn
    end

    local name, env
    local up = 0
    repeat
      up = up + 1
      name, env = debug_getupvalue (fn, up)
    until name == '_ENV' or name == nil
    return env
  end

end


local function rawlen (x)
  -- Lua 5.1 does not implement rawlen, and while # operator ignores
  -- __len metamethod, `nil` in sequence is handled inconsistently.
  if type (x) ~= "table" then
    return #x
  end

  local n = #x
  for i = 1, n do
    if x[i] == nil then
      return i -1
    end
  end
  return n
end


local function len (x)
  local m = getmetamethod (x, "__len")
  if m then
    return m (x)
  elseif getmetamethod (x, "__tostring") then
    x = tostring (x)
  end
  return rawlen (x)
end


local function ipairs (l)
  if getmetamethod (l, "__len") then
    -- Use a closure to capture len metamethod result if necessary.
    local n = len (l)
    return function (l, i)
      i = i + 1
      if i <= n then
        return i, l[i]
      end
    end, l, 0
  end

  -- ...otherwise, find the last item as we go without calling `len()`.
  return function (l, i)
    i = i + 1
    if l[i] ~= nil then
      return i, l[i]
    end
  end, l, 0
end


if not pcall (load, "_=1") then
  local loadfunction = load
  load = function (...)
    if type (...) == "string" then
      return loadstring (...)
    end
    return loadfunction (...)
  end
end


local function normalize_load (chunk, chunkname)
  local m = getmetamethod (chunk, "__call")
  if m then
    chunk = m
  elseif getmetamethod (chunk, "__tostring") then
    chunk = tostring (chunk)
  end
  if getmetamethod (chunkname, "__tostring") then
    chunkname = tostring (chunkname)
  end
  return load (chunk, chunkname)
end


if not not pairs(setmetatable({},{__pairs=function() return false end})) then
  -- Add support for __pairs when missing.
  local _pairs = pairs
  function pairs (t)
    return (getmetamethod (t, "__pairs") or _pairs) (t)
  end
end


local function keysort (a, b)
  if type (a) == "number" then
    return type (b) ~= "number" or a < b
  else
    return type (b) ~= "number" and tostring (a) < tostring (b)
  end
end


local function opairs (t)
  local keys, i = {}, 0
  for k in pairs (t) do keys[#keys + 1] = k end
  table_sort (keys, keysort)

  local _, _t = pairs (t)
  return function (t)
    i = i + 1
    local k = keys[i]
    if k ~= nil then
      return k, t[k]
    end
  end, _t, nil
end


local pathmatch_patt = "[^" .. pathsep .. "]+"

local searchpath = package_searchpath or function (name, path, sep, rep)
  name = string_gsub (name, sep or '%.', rep or dirsep)

  local errbuf = {}
  for template in string_gmatch (path, pathmatch_patt) do
    local filename = string_gsub (template, pathmark, name)
    local fh = io_open (filename, "r")
    if fh then
      fh:close ()
      return filename
    end
    errbuf[#errbuf + 1] = "\tno file '" .. filename .. "'"
  end
  return nil, table_concat (errbuf, "\n")
end


local normalize_setfenv
if debug_setfenv then

  normalize_setfenv = function (fn, env)
    local n = tointeger (fn or 1)
    if n then
      if n > 0 then
	n = n + 1 + ARGCHECK_FRAME
      end
      return setfenv (n, env), nil
    end
    if type (fn) ~= "function" then
      fn = (getmetatable (fn) or {}).__call or fn
    end
    return debug_setfenv (fn, env)
  end

else

  -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
  normalize_setfenv = function (fn, env)
    local n = tointeger (fn or 1)
    if n then
      if n > 0 then
	n = n + 1 + ARGCHECK_FRAME
      end
      fn = debug_getinfo (n, "f").func
    elseif type (fn) ~= "function" then
      fn = (getmetatable (fn) or {}).__call or fn
    end

    local up, name = 0
    repeat
      up = up + 1
      name = debug_getupvalue (fn, up)
    until name == '_ENV' or name == nil
    if name then
      debug_upvaluejoin (fn, up, function () return name end, 1)
      debug_setupvalue (fn, up, env)
    end
    return n ~= 0 and fn or nil
  end

end


local function copy (t)
  local r = {}
  for k, v in pairs (t) do
    r[k] = v
  end
  return r
end


local function str (x, roots)
  roots = roots or {}

  local function stop_roots (x)
    return roots[x] or str (x, copy (roots))
  end

  if type (x) ~= "table" or getmetamethod (x, "__tostring") then
    return tostring (x)

  else
    local buf = {"{"}				-- pre-buffer table open
    roots[x] = tostring (x)			-- recursion protection

    local kp, vp				-- previous key and value
    for k, v in opairs (x) do
      if kp ~= nil and k ~= nil then
        -- semi-colon separator after sequence values, or else comma separator
        buf[#buf + 1] = type (kp) == "number" and k ~= kp + 1 and "; " or ", "
      end
      if k == 1 or type (k) == "number" and k -1 == kp then
        -- no key for sequence values
        buf[#buf + 1] = stop_roots (v)
      else
        buf[#buf + 1] = stop_roots (k) .. "=" .. stop_roots (v)
      end
      kp, vp = k, v
    end
    buf[#buf + 1] = "}"				-- buffer << table close

    return table_concat (buf)			-- stringify buffer
  end
end


local function math_type (x)
  if type (x) ~= "number" then
    return nil
  end
  return tointeger (x) and "integer" or "float"
end


local function unpack (t, i, j)
  return table_unpack (t, tointeger (i) or 1, tointeger (j) or len (t))
end


do
  local have_xpcall_args = false
  local function catch (arg) have_xpcall_args = arg end
  xpcall (catch, function () end, true)

  if not have_xpcall_args then
    local _xpcall = xpcall
    xpcall = function (fn, errh, ...)
      local argu = pack (...)
      return _xpcall (function ()
        return fn (unpack (argu, 1, argu.n))
      end, errh)
    end
  end
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


local T = types


local M = {
  --- Raise a bad argument error.
  -- Equivalent to luaL_argerror in the Lua C API. This function does not
  -- return.  The `level` argument behaves just like the core `error`
  -- function.
  -- @function argerror
  -- @string name function to callout in error message
  -- @int i argument number
  -- @string[opt] extramsg additional text to append to message inside
  --   parentheses
  -- @int[opt=1] level call stack level to blame for the error
  -- @usage
  --   local function slurp (file)
  --     local h, err = input_handle (file)
  --     if h == nil then argerror ("std.io.slurp", 1, err, 2) end
  --     ...
  argerror = argscheck (
    "argerror", T.stringy, T.integer, T.accept, opt (T.integer)
  ) .. argerror,

  --- Get a function or functor environment.
  --
  -- This version of getfenv works on all supported Lua versions, and
  -- knows how to unwrap functors (table's with a function valued
  -- `__call` metamethod).
  -- @function getfenv
  -- @tparam function|int fn stack level, C or Lua function or functor
  --   to act on
  -- @treturn table the execution environment of *fn*
  -- @usage
  --   callers_environment = getfenv (1)
  getfenv = argscheck (
    "getfenv", opt (T.integer, T.callable)
  ) .. normalize_getfenv,

  --- Return named metamethod, if callable, otherwise `nil`.
  -- @function getmetamethod
  -- @param x item to act on
  -- @string n name of metamethod to look up
  -- @treturn function|nil metamethod function, or `nil` if no
  --   metamethod
  -- @usage
  --   normalize = getmetamethod (require "std.normalize", "__call")
  getmetamethod = argscheck (
    "getmetamethod", T.arg, T.stringy
  ) .. getmetamethod,

  --- Iterate over elements of a sequence, until the first `nil` value.
  --
  -- Returns successive key-value pairs with integer keys starting at 1,
  -- up to the index returned by the `__len` metamethod if any, or else
  -- up to last non-`nil` value.
  --
  -- Unlike Lua 5.1, any `__index` metamethod is respected.
  --
  -- Unlike Lua 5.2+, any `__ipairs` metamethod is **ignored**!
  -- @function ipairs
  -- @tparam table t table to iterate on
  -- @treturn function iterator function
  -- @treturn table *t* the table being iterated over
  -- @treturn int the previous iteration index
  -- @usage
  --   t, u = {}, {}
  --   for i, v in ipairs {1, 2, nil, 4} do t[i] = v end
  --   assert (len (t) == 2)
  --
  --   for i, v in ipairs (pack (1, 2, nil, 4)) do u[i] = v end
  --   assert (len (u) == 4)
  ipairs = argscheck ("ipairs", T.table) .. ipairs,

  --- Deterministic, functional version of core Lua `#` operator.
  --
  -- Respects `__len` metamethod (like Lua 5.2+), or else if there is
  --  a `__tostring` metamethod return the length of the string it
  -- returns.  Otherwise, always return one less than the lowest
  -- integer index with a `nil` value in *x*, where the `#` operator
  -- implementation might return the size of the array part of a table.
  -- @function len
  -- @param x item to act on
  -- @treturn int the length of *x*
  -- @usage
  --   x = {1, 2, 3, nil, 5}
  --   --> 5	3
  --   print (#x, len (x))
  len = argscheck ("len", any (T.table, T.stringy)) .. len,

  --- Load a string or a function, just like Lua 5.2+.
  -- @function load
  -- @tparam string|function ld chunk to load
  -- @string source name of the source of *ld*
  -- @treturn function a Lua function to execute *ld* in global scope.
  -- @usage
  --   assert (load 'print "woo"') ()
  load = argscheck (
    "load", any (T.callable, T.stringy), opt (T.stringy)
  ) .. normalize_load,

  math = {
    --- Convert to an integer and return if possible, otherwise `nil`.
    -- @function math.tointeger
    -- @param x object to act on
    -- @treturn[1] integer *x* converted to an integer if possible
    -- @return[2] `nil` otherwise
    tointeger = argscheck ("tointeger", T.arg) .. tointeger,

    --- Return "integer", "float" or `nil` according to argument type.
    --
    -- To ensure the same behaviour on all host Lua implementations,
    -- this function returns "float" for integer-equivalent floating
    -- values, even on Lua 5.3.
    -- @function math.type
    -- @param x object to act on
    -- @treturn[1] string "integer", if *x* is a whole number
    -- @treturn[2] string "float", for other numbers
    -- @return[3] `nil` otherwise
    type = argscheck ("type", T.arg) .. math_type,
  },

  --- Ordered `pairs` iterator, respecting `__pairs` metamethod.
  --
  -- Although `__pairs` will be used to collect results, `opairs`
  -- always returns them in the same order as `str`.
  -- @function opairs
  -- @tparam table t table to act on
  -- @treturn function iterator function
  -- @treturn table *t*, the table being iterated over
  -- @return the previous iteration key
  -- @usage
  --   --> 1        b
  --   --> 2        a
  --   --> foo      c
  --   for k, v in opairs {"b", foo = "c", "a"} do print (k, v) end
  opairs = argscheck ("opairs", T.table) .. opairs,

  os = {
    --- Exit the program.
    -- @function os.exit
    -- @tparam bool|number[opt=true] status report back to parent process
    -- @usage
    --   exit (len (records.processed) > 0)
    exit = argscheck ("exit", any (T.boolean, T.integer, T.missing)) .. exit,
  },

  --- Return a list of given arguments, with field `n` set to the length.
  --
  -- The returned table also has a `__len` metamethod that returns `n`, so
  -- `ipairs` and `unpack` behave sanely when there are `nil` valued elements.
  -- @function pack
  -- @param ... tuple to act on
  -- @treturn table packed list of *...* values, with field `n` set to
  --   number of tuple elements (including any explicit `nil` elements)
  -- @see unpack
  -- @usage
  --   --> 5
  --   len (pack (nil, 2, 5, nil, nil))
  pack = pack,

  package = {
    --- Package module constants for `package.config` substrings.
    -- @table package
    -- @string dirsep directory separator in path elements
    -- @string execdir replaced by the executable's directory in a path
    -- @string igmark ignore everything before this when building
    --   `luaopen_` function name
    -- @string pathmark mark substitution points in a path template
    -- @string pathsep element separator in a path template
    dirsep	= dirsep,
    execdir	= execdir,
    igmark	= igmark,
    pathmark	= pathmark,
    pathsep	= pathsep,

    --- Searches for a named file in a given path.
    --
    -- For each `package.pathsep` delimited template in the given path,
    -- search for an readable file made by first substituting for *sep*
    -- with `package.dirsep`, and then replacing any
    -- `package.pathmark` with the result.  The first such file, if any
    -- is returned.
    -- @function package.searchpath
    -- @string name name of search file
    -- @string path `package.pathsep` delimited list of full path templates
    -- @string[opt="."] sep *name* component separator
    -- @string[opt=`package.dirsep`] rep *sep* replacement in template
    -- @treturn[1] string first template substitution that names a file
    --   that can be opened in read mode
    -- @return[2] `nil`
    -- @treturn[2] string error message listing all failed paths
    searchpath	= argscheck (
      "searchpath", T.string, T.string, opt (T.string), opt (T.string)
    ) .. searchpath,
  },

  --- Like Lua `pairs` iterator, but respect `__pairs` even in Lua 5.1.
  -- @function pairs
  -- @tparam table t table to act on
  -- @treturn function iterator function
  -- @treturn table *t*, the table being iterated over
  -- @return the previous iteration key
  -- @usage
  --   for k, v in pairs {"a", b = "c", foo = 42} do process (k, v) end
  pairs = argscheck ("pairs", T.table) .. pairs,

  --- Length of a string or table object without using any metamethod.
  -- @function rawlen
  -- @tparam string|table x object to act on
  -- @treturn int raw length of *x*
  -- @usage
  --   --> 0
  --   rawlen (setmetatable ({}, {__len = function () return 42}))
  rawlen = argscheck ("rawlen", any (T.string, T.table)) .. rawlen,

  --- Set a function or functor environment.
  --
  -- This version of setfenv works on all supported Lua versions, and
  -- knows how to unwrap functors.
  -- @function setfenv
  -- @tparam function|int fn stack level, C or Lua function or functor
  --   to act on
  -- @tparam table env new execution environment for *fn*
  -- @treturn function function acted upon
  -- @usage
  --   function clearenv (fn) return setfenv (fn, {}) end
  setfenv = argscheck (
    "setfenv", any (T.integer, T.callable), T.table
  ) .. normalize_setfenv,

  --- Return a compact stringified representation of argument.
  -- @function str
  -- @param x item to act on
  -- @treturn string compact string representing *x*
  -- @usage
  --   -- {baz,5,foo=bar}
  --   print (str {foo="bar","baz", 5})
  str = str,

  --- Either `table.unpack` in newer-, or `unpack` in older Lua implementations.
  -- @function unpack
  -- @tparam table t table to act on
  -- @int[opt=1] i first index to unpack
  -- @int[opt=len(t)] j last index to unpack
  -- @return ... values of numeric indices of *t*
  -- @see pack
  -- @usage
  --   local a, b, c = unpack (pack (nil, 2, nil))
  --   assert (a == nil and b == 2 and c == nil)
  unpack = argscheck (
    "unpack", T.table, opt (T.integer), opt (T.integer)
  ) .. unpack,

  --- Support arguments to a protected function call, even on Lua 5.1.
  -- @function xpcall
  -- @tparam function f protect this function call
  -- @tparam function errh error object handler callback if *f* raises
  --   an error
  -- @param ... arguments to pass to *f*
  -- @treturn[1] boolean `false` when `f (...)` raised an error
  -- @treturn[1] string error message
  -- @treturn[2] boolean `true` when `f (...)` succeeded
  -- @return ... all return values from *f* follow
  -- @usage
  --   -- Use errh to get a backtrack after curses exits abnormally
  --   xpcall (main, errh, arg, opt)
  xpcall = argscheck ("xpcall", T.callable, T.callable) .. xpcall,
}


local G = {
  _VERSION	= _G._VERSION,
  arg		= _G.arg,
  argerror	= M.argerror,
  assert	= _G.assert,
  collectgarbage = _G.collectgarbage,
  coroutine = {
    create	= _G.coroutine.create,
    resume	= _G.coroutine.resume,
    running	= _G.coroutine.running,
    status	= _G.coroutine.status,
    wrap	= _G.coroutine.wrap,
    yield	= _G.coroutine.yield,
  },
  debug = {
    debug	 = _G.debug.debug,
    gethook	 = _G.debug.gethook,
    getinfo	 = _G.debug.getinfo,
    getlocal	 = _G.debug.getlocal,
    getmetatable = _G.debug.getmetatable,
    getregistry	 = _G.debug.getregistry,
    getupvalue	 = _G.debug.getupvalue,
    getuservalue = _G.debug.getuservalue,
    sethook	 = _G.debug.sethook,
    setmetatable = _G.debug.setmetatable,
    setupvalue	 = _G.debug.setupvalue,
    setuservalue = _G.debug.setuservalue,
    traceback	 = _G.debug.traceback,
    upvalueid	 = _G.debug.upvalueid,
    upvaluejoin	 = _G.debug.upvaluejoin,
  },
  dofile	= _G.dofile,
  error		= _G.error,
  getfenv	= M.getfenv,
  getmetamethod	= M.getmetamethod,
  getmetatable	= _G.getmetatable,
  io = {
    close	= _G.io.close,
    flush	= _G.io.flush,
    input	= _G.io.input,
    lines	= _G.io.lines,
    open	= _G.io.open,
    output	= _G.io.output,
    popen	= _G.io.popen,
    read	= _G.io.read,
    stderr	= _G.io.stderr,
    stdin	= _G.io.stdin,
    stdout	= _G.io.stdout,
    tmpfile	= _G.io.tmpfile,
    type	= _G.io.type,
    write	= _G.io.write,
  },
  ipairs	= M.ipairs,
  len		= M.len,
  load		= M.load,
  loadfile	= _G.loadfile,
  math = {
    abs		= _G.math.abs,
    acos	= _G.math.acos,
    asin	= _G.math.asin,
    atan	= _G.math.atan,
    ceil	= _G.math.ceil,
    cos		= _G.math.cos,
    deg		= _G.math.deg,
    exp		= _G.math.exp,
    floor	= _G.math.floor,
    fmod	= _G.math.fmod,
    huge	= _G.math.huge,
    log		= _G.math.log,
    max		= _G.math.max,
    min		= _G.math.min,
    modf	= _G.math.modf,
    pi		= _G.math.pi,
    rad		= _G.math.rad,
    random	= _G.math.random,
    randomseed	= _G.math.randomseed,
    sin		= _G.math.sin,
    sqrt	= _G.math.sqrt,
    tan		= _G.math.tan,
    tointeger	= M.math.tointeger,
    type	= M.math.type,
  },
  next		= _G.next,
  opairs	= M.opairs,
  os = {
    clock	= _G.os.clock,
    date	= _G.os.date,
    difftime	= _G.os.difftime,
    execute	= _G.os.execute,
    exit	= M.os.exit,
    getenv	= _G.os.getenv,
    remove	= _G.os.remove,
    rename	= _G.os.rename,
    setlocale	= _G.os.setlocale,
    time	= _G.os.time,
    tmpname	= _G.os.tmpname,
  },
  pack		= M.pack,
  package = {
    config	= _G.package.config,
    cpath	= _G.package.cpath,
    dirsep	= M.package.dirsep,
    execdir	= M.package.execdir,
    igmark	= M.package.igmark,
    loadlib	= _G.package.loadlib,
    path	= _G.package.path,
    pathmark	= M.package.pathmark,
    pathsep	= M.package.pathsep,
    preload	= _G.package.preload,
    searchers	= _G.package.searchers or _G.package.loaders,
    searchpath	= M.package.searchpath,
  },
  pairs		= M.pairs,
  pcall		= _G.pcall,
  print		= _G.print,
  rawequal	= _G.rawequal,
  rawget	= _G.rawget,
  rawlen	= M.rawlen,
  rawset	= _G.rawset,
  require	= _G.require,
  select	= _G.select,
  setfenv	= M.setfenv,
  setmetatable	= _G.setmetatable,
  str		= M.str,
  string = {
    byte	= _G.string.byte,
    char	= _G.string.char,
    dump	= _G.string.dump,
    find	= _G.string.find,
    format	= _G.string.format,
    gmatch	= _G.string.gmatch,
    gsub	= _G.string.gsub,
    lower	= _G.string.lower,
    match	= _G.string.match,
    rep		= _G.string.rep,
    reverse	= _G.string.reverse,
    sub		= _G.string.sub,
    upper	= _G.string.upper,
  },
  table = {
    concat	= _G.table.concat,
    insert	= _G.table.insert,
    remove	= _G.table.remove,
    sort	= _G.table.sort,
  },
  tonumber	= _G.tonumber,
  tostring	= _G.tostring,
  type		= _G.type,
  unpack	= M.unpack,
  xpcall	= M.xpcall,
}
G._G		= G
G.package.loaded = {
  _G		= G,
  coroutine	= G.coroutine,
  debug		= G.debug,
  io		= G.io,
  math		= G.math,
  os		= G.os,
  package	= G.package,
  string	= G.string,
  table		= G.table,
}


-- Replace host Lua functions with normalized equivalents.
-- @tparam table userenv user's lexical environment table
-- @treturn table *userenv* with normalized functions
local function normalize (userenv)
  local env = {}

  -- Top level functions are always available.
  for k, v in next, G do
    if G.package.loaded[k] == nil then
      env[k] = v
    end
  end

  -- Top level tables must be required by name.
  for symbol, module in pairs (userenv) do
    local k, dst = tostring (module), env

    -- e.g. { "string", "std.seq" }
    local i = tointeger (symbol)
    if i then
      k = {}
      string_gsub (module, "[^%.]+", function (s) k[#k + 1] = s end)
      while #k > 1 do
        local subkey = table_remove (k, 1)
        dst[subkey] = dst[subkey] or {}
        dst = dst[subkey]
      end
      k = table_remove (k, 1)
    else
      k = symbol
    end

    dst[k] = G.package.loaded[module] or require (module)
  end

  return env
end


return setmetatable (G, {
  --- Metamethods
  -- @section metamethods

  --- Normalize caller's lexical environment.
  --
  -- Using "std.strict" when available and selected, otherwise a (Lua 5.1
  -- compatible) function to set the given environment.
  --
  -- With an empty table argument, the core (not-table) normalize
  -- functions are loaded into the callers environment.  For consistent
  -- behaviour between supported host Lua implementations, the result
  -- must always be assigned back to `_ENV`.  Additional core modules
  -- must be named to be loaded at all (i.e. no "debug" table unless it
  -- is explicitly listed in the argument table).
  --
  -- Additionally, external modules are loaded using `require`, with `.`
  -- separators in the module name translated to nested tables in the
  -- module environment. For example "std.prototype" in the usage below
  -- is equivalent to:
  --
  --     local std = { prototype = require "std.prototype" }
  --
  -- And finally, you can assign a loaded module to a specific symbol
  -- with `key=value` syntax.  For example "std.strict" in the usage
  -- below is equivalent to:
  --
  --     local strict = require "std.strict"
  -- @function __call
  -- @tparam table env environment table
  -- @tparam[opt=1] int level stack level for `setfenv`, 1 means set
  --   caller's environment
  -- @treturn table *env* with this module's functions merge id.  Assign
  --   back to `_ENV`
  -- @usage
  --   local _ENV = require "std.normalize" {
  --     "string",
  --     "std.prototype",
  --     strict = "std.strict",
  --   }
  __call = function (_, env, level)
    return strict (normalize (env), 1 + (level or 1)), nil
  end,

  --- Lazy loading of normalize modules.
  -- Don't load everything on initial startup, wait until first attempt
  -- to access a submodule, and then load it on demand.
  -- @function __index
  -- @string name submodule name
  -- @treturn table|nil the submodule that was loaded to satisfy the missing
  --   `name`, otherwise `nil` if nothing was found
  -- @usage
  -- local version = require "std.normalize".version
  __index = function (self, name)
    local ok, t = pcall (require, "std.normalize." .. name)
    if ok then
      rawset (self, name, t)
      return t
    end
  end,
})
