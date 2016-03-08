--[[--
 Normalize API differences between supported Lua implementations.

 Respecting the values set in the `std.debug_init` module and the
 `_G._DEBUG` variable, merge deterministic identically behaving
 cross-implementation low-level functions into the callers environment.

    local _ENV = require "std.normalize" {
      -- Copy global functions into module environment
      getmetatable = getmetatable,
      setmetatable = setmetatable,

      -- Prefer regular `tostring` over table value rendering
      str = tostring,
    }

 It can merge deterministic versions of core Lua functions that do not
 behave identically across all supported Lua implementations into your
 module's lexical environment.  Each function is as thin and fast a
 version as is possible in each Lua implementation, evaluating to the
 Lua C implementation with no overhead when semantics allow.

 It is not yet complete, and in contrast to the kepler project
 lua-compat libraries, neither does it attempt to provide you with as
 nearly compatible an API as is possible relative to some specific Lua
 implementation - rather it provides a variation of the "lowest common
 denominator" that can be implemented relatively efficiently in the
 supported Lua implementations, all in pure Lua.

 At the moment, only the functionality used by stdlib is implemented.

 @module std.normalize
]]


local strict		= require "std.normalize._base".strict

local _ENV = strict {
  _VERSION		= _VERSION,
  getmetatable		= getmetatable,
  ipairs		= ipairs,
  next			= next,
  pairs			= pairs,
  pcall			= pcall,
  rawset		= rawset,
  require		= require,
  select		= select,
  setmetatable		= setmetatable,
  tonumber		= tonumber,
  tostring		= tostring,
  type			= type,

  debug_getfenv		= getfenv or false,
  debug_getinfo		= debug.getinfo,
  debug_getupvalue	= debug.getupvalue,
  debug_setfenv		= debug.setfenv or false,
  debug_setupvalue	= debug.setupvalue,
  debug_upvaluejoin	= debug.upvaluejoin,
  table_concat		= table.concat,
  table_pack		= table.pack or pack or false,
  table_sort		= table.sort,
  table_unpack		= table.unpack or unpack,
}



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


-- At this point, only the locals imported above are visible (even in
-- Lua 5.1). If "std.strict" is available, we'll also get a runtime
-- error if any of the code below tries to use an undeclared variable.

local getfenv
if debug_getfenv then

  getfenv = function (fn)
    fn = fn or 1

    local type_fn = type (fn)
    if type_fn == "table" then
      -- Unwrap functors:
      -- No need to recurse because Lua doesn't support nested functors.
      -- __call can only (sensibly) be a function, so no need to adjust
      -- stack frame offset either.
      fn = (getmetatable (fn) or {}).__call or fn
    
    elseif type_fn == "number" and fn > 0 then
       -- Adjust for this function's stack frame, if fn is non-zero.
       fn = fn + 1
    end

    -- Return an additional nil result to defeat tail call elimination
    -- which would remove a stack frame and break numeric *fn* count.
    return debug_getfenv (fn), nil
  end

else

  -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
  getfenv = function (fn)
    fn = fn or 1
    
    local type_fn = type (fn)
    if type_fn == "table" then
      fn = (getmetatable (fn) or {}).__call or fn
    elseif type_fn == "number" then
      fn = debug_getinfo (fn == 0 and 0 or fn + 1, "f").func
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


local function getmetamethod (x, n)
  local m = (getmetatable (x) or {})[n]
  if type (m) == "function" then return m end
  if type ((getmetatable (m) or {}).__call) == "function" then return m end
end


if not ipairs(setmetatable({},{__ipairs=function() return false end})) then
  -- Ignore support for __ipairs when implemented by core.
  ipairs = function (l)
    return function (l, n)
      n = n + 1
      if l[n] ~= nil then
        return n, l[n]
      end
    end, l, 0
  end
end


local function len (x)
  local m = getmetamethod (x, "__len")
  if m then return m(x) end
  if type (x) ~= "table" then return #x end

  local n = #x
  for i = 1, n do
    if x[i] == nil then return i -1 end
  end
  return n
end


local pack = table_pack or function (...)
  return { n = select ("#", ...), ...}
end


if not not pairs(setmetatable({},{__pairs=function() return false end})) then
  -- Add support for __pairs when missing.
  local _pairs = pairs
  pairs = function (t)
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


local setfenv
if debug_setfenv then

  setfenv = function (fn, env)
    fn = fn or 1

    local type_fn = type (fn)
    if type_fn == "table" then
      fn = (getmetatable (fn) or {}).__call or fn
    elseif type_fn == "number" and fn > 0 then
       fn = fn + 1
    end
    return debug_setfenv (fn, env), nil
  end

else

  -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
  setfenv = function (fn, env)
    fn = fn or 1
    
    local type_fn = type (fn)
    if type_fn == "table" then
      fn = (getmetatable (fn) or {}).__call or fn
    elseif type_fn == "number" then
      fn = debug_getinfo (fn == 0 and 0 or fn + 1, "f").func
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
    return fn
  end

end


local function copy (t)
  local r = {}
  for k, v in pairs (t) do r[k] = v end
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


local function unpack (t, i, j)
  return table_unpack (t, tonumber (i) or 1, tonumber (j) or len (t))
end


local function normal (env)
  local r = {
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
    -- callers_environment = getfenv (1)
    getfenv = getfenv,

    --- Return named metamethod, if callable, otherwise `nil`.
    -- @function getmetamethod
    -- @param x item to act on
    -- @string n name of metamethod to look up
    -- @treturn function|nil metamethod function, or `nil` if no
    --   metamethod
    -- @usage
    -- normalize = getmetamethod (require "std.normalize", "__call")
    getmetamethod = getmetamethod,

    --- Iterate over elements of a sequence, until the first `nil` value.
    --
    -- Returns successive key-value pairs with integer keys starting at 1,
    -- up to the last non-`nil` value.  Unlike Lua 5.2, any `__ipairs`
    -- metamethod is **ignored**!
    -- @function ipairs
    -- @tparam table t table to iterate on
    -- @treturn function iterator function
    -- @treturn table *t* the table being iterated over
    -- @treturn int the previous iteration index
    -- @usage
    -- -- length of sequence
    -- args = {"first", "second", nil, "last"}
    -- --> 1=first
    -- --> 2=second
    -- for i, v in ipairs (args) do
    --   print (string.format ("%d=%s", i, v))
    -- end
    ipairs = ipairs,

    --- Functional version of core Lua `#` operator.
    --
    -- Respects `__len` metamethod (like Lua 5.2+), otherwise always
    -- return one less than the lowest integer index with a `nil` value
    -- in *x*, where the `#` operator implementation might return the
    -- size of the array part of a table.
    -- @function len
    -- @param x item to act on
    -- @treturn int the length of *x*
    -- @usage
    -- x = {1, 2, 3, nil, 5}
    -- --> 5	3
    -- print (#x, len (x))
    len = len,

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
    -- --> 1        b
    -- --> 2        a
    -- --> foo      c
    -- for k, v in opairs {"b", foo = "c", "a"} do print (k, v) end
    opairs = opairs,

    --- Like Lua `pairs` iterator, but respect `__pairs` even in Lua 5.1.
    -- @function pairs
    -- @tparam table t table to act on
    -- @treturn function iterator function
    -- @treturn table *t*, the table being iterated over
    -- @return the previous iteration key
    -- @usage
    -- for k, v in pairs {"a", b = "c", foo = 42} do process (k, v) end
    pairs = pairs,

    --- The fastest pack implementation available.
    -- @function pack
    -- @param ... tuple to act on
    -- @treturn table packed list of *...* values, with field `n` set to
    --   number of tuple elements (including any explicit `nil` elements)
    -- @usage
    -- --> {1, 2, "ax", n = 3}
    -- pack (("ax1"):find "(%D+)")
    pack = pack,

    --- set a function or functor environment.
    --
    -- This version of setfenv works on all supported Lua versions, and
    -- knows how to unwrap functors.
    -- @function setfenv
    -- @tparam function|int fn stack level, C or Lua function or functor
    --   to act on
    -- @tparam table env new execution environment for *fn*
    -- @treturn function function acted upon
    -- @usage
    -- function clearenv (fn) return setfenv (fn, {}) end
    setfenv = setfenv,

    --- Return a compact stringified representation of argument.
    -- @function str
    -- @param x item to act on
    -- @treturn string compact string representing *x*
    -- @usage
    -- -- {baz,5,foo=bar}
    -- print (str {foo="bar","baz", 5})
    str = str,

    --- Either `table.unpack` in newer-, or `pack` in older Lua implementations.
    -- @function unpack
    -- @tparam table t table to act on
    -- @int[opt=1] i first index to unpack
    -- @int[opt=len(t)] j last index to unpack
    -- @return ... values of numeric indices of *t*
    -- @usage
    -- return unpack (results_table)
    unpack = unpack,
  }
  for k, v in next, env do
    r[k] = v
  end
  return r
end


return setmetatable (normal {}, {
  --- Metamethods
  -- @section metamethods

  --- Normalize caller's lexical environment.
  --
  -- Using "std.strict" when available and selected, otherwise a (Lua 5.1
  -- compatible) function to set the given environment with normalized
  -- functions from this module merged in.
  -- @function __call
  -- @tparam table env environment table
  -- @treturn table *env* with this module's functions merge id.  Assign
  --   back to `_ENV`
  -- @usage
  -- local _ENV = require "std.normalize" {}
  __call = function (_, env) return strict (normal (env)) end,

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
