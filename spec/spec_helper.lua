--[[
 Normalized Lua API for Lua 5.1, 5.2 & 5.3
 Copyright (C) 2014-2017 Gary V. Vaughan
]]
local typecheck
have_typecheck, typecheck = pcall(require, 'typecheck')

local inprocess = require 'specl.inprocess'
local hell = require 'specl.shell'

badargs = require 'specl.badargs'

local cwd = os.getenv 'PWD'

package.path = cwd .. '/lib/?.lua;' .. cwd .. '/lib/?/init.lua;' .. package.path


-- Allow user override of LUA binary used by hell.spawn, falling
-- back to environment PATH search for 'lua' if nothing else works.
local LUA = os.getenv 'LUA' or 'lua'


-- Allow use of bare 'pack' and 'unpack' even in Lua 5.3.
pack = table.pack or function(...) return {n = select('#', ...), ...} end
unpack = table.unpack or unpack


local function getmetamethod(x, n)
   local m =(getmetatable(x) or {})[tostring(n)]
   if type(m) == 'function' then
      return m
   end
   if type((getmetatable(m) or {}).__call) == 'function' then
      return m
   end
end


function callable(x)
   return type(x) == 'function' or getmetamethod(x, '__call')
end


function copy(t)
   local r = {}
   for k, v in next, t do r[k] = v end
   return r
end


-- In case we're not using a bleeding edge release of Specl...
_diagnose = badargs.diagnose
badargs.diagnose = function(...)
   if have_typecheck then
      return _diagnose(...)
   end
end


-- A copy of base.lua:type, so that an unloadable base.lua doesn't
-- prevent everything else from working.
function objtype(o)
   return(getmetatable(o) or {})._type or io.type(o) or type(o)
end


local function mkscript(code)
   local f = os.tmpname()
   local h = io.open(f, 'w')
   -- TODO: Move this into specl, or expose arguments so that we can
   --          turn this on and off based on specl `--coverage` arg.
   h:write "pcall(require, 'luacov')"
   h:write(code)
   h:close()
   return f
end


--- Run some Lua code with the given arguments and input.
-- @string code valid Lua code
-- @tparam[opt={}] string|table arg single argument, or table of
--    arguments for the script invocation.
-- @string[opt] stdin standard input contents for the script process
-- @treturn specl.shell.Process|nil status of resulting process if
--    execution was successful, otherwise nil
function luaproc(code, arg, stdin)
   local f = mkscript(code)
   if type(arg) ~= 'table' then arg = {arg} end
   local cmd = {LUA, f, unpack(arg)}
   -- inject env and stdin keys separately to avoid truncating `...` in
   -- cmd constructor
   cmd.env = { LUA_PATH=package.path, LUA_INIT='', LUA_INIT_5_2='' }
   cmd.stdin = stdin
   local proc = hell.spawn(cmd)
   os.remove(f)
   return proc
end


local function tabulate_output(code)
   local proc = luaproc(code)
   if proc.status ~= 0 then return error(proc.errout) end
   local r = {}
   proc.output:gsub('(%S*)[%s]*',
      function(x)
         if x ~= '' then r[x] = true end
      end)
   return r
end


--- Show changes to tables wrought by a require statement.
-- There are a few modes to this function, controlled by what named
-- arguments are given.   Lists new keys in T1 after `require "import"`:
--
--       show_apis {added_to=T1, by=import}
--
-- @tparam table argt one of the combinations above
-- @treturn table a list of keys according to criteria above
function show_apis(argt)
   return tabulate_output([[
      local before, after = {}, {}
      for k in pairs(]] .. argt.added_to .. [[) do
         before[k] = true
      end

      local M = require ']] .. argt.by .. [['
      for k in pairs(]] .. argt.added_to .. [[) do
         after[k] = true
      end

      for k in pairs(after) do
         if not before[k] then print(k) end
      end
   ]])
end


--[[ ================ ]]--
--[[ Tmpfile manager. ]]--
--[[ ================ ]]--


local tmpdir = string.gsub(
   os.getenv 'TMPDIR' or os.getenv 'TMP' or '/tmp',
   '([^/])/*$', '%1'
) .. '/normalize-' .. math.random(65536)


local function append(path, ...)
   local n = select('#', ...)
   if n > 0 then
      local fh = io.open(path, 'a')
      fh:write(table.concat({...}, '\n') .. '\n')
      fh:close()
   end
   return n
end


-- Create a temporary file.
-- @usage
--    h = Tmpfile()            -- empty generated filename
--    h = Tmpfile(content) -- save *content* to generated filename
--    h = Tmpfile(name, line, line, line) -- write *line*s to *name*
Tmpfile = setmetatable({}, {
   _type = 'Tmpfile',

   __call = function(self, path_or_content, ...)
      local new = {}
      if select('#', ...) == 0 then
         new.path = os.tmpname()
         append(new.path, path_or_content)
      else
         new.path = path_or_content
         append(new.path, ...)
      end
      return setmetatable(new, getmetatable(self))
   end,

   __index = {
      dirname = function(self)
         return self.path:gsub('/[^/]*$', '', 1)
      end,

      basename = function(self)
         return self.path:gsub('.*/', '')
      end,

      append = function(self, ...)
         return append(self.path, ...)
      end,

      remove = function(self)
         return os.remove(self.path)
      end,
   },
})


Tmpdir = setmetatable({}, {
   _type = 'Tmpdir',

   __call = function(self, dirname)
      local new = {
         path = dirname or tmpdir,
         children = {},
      }
      os.execute("mkdir '" .. new.path .. "'")
      return setmetatable(new, getmetatable(self))
   end,

   __index = {
      file = function(self, name, ...)
         local child = Tmpfile(self.path .. '/' .. name, ...)
         self.children[#self.children + 1] = child
         return child
      end,

      subdir = function(self, name)
         local child = Tmpdir(self.path .. '/' .. name)
         self.children[#self.children + 1] = child
         return child
      end,

      remove = function(self)
         for _, child in ipairs(self.children) do
	child:remove()
         end
         return os.remove(self.path)
      end,
   }
})

