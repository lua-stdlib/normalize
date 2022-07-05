--[[
 Normalized Lua API for Lua 5.1, 5.2, 5.3 & 5.4
 Coryright (C) 2014-2023 std.normalize authors
]]
--[[--
 Purely to break internal dependency cycles without introducing
 multiple copies of base functions used in other normalize modules.

 @module std.normalize._base
]]


local _ENV = require 'std.normalize._strict' (_G)

local getmetatable = getmetatable
local pack = table.pack or false
local tointeger = math.tointeger or false



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function getmetamethod(x, n)
   local m = (getmetatable(x) or {})[tostring(n)]
   if type(m) == 'function' then
      return m
   end
   if type((getmetatable(m) or {}).__call) == 'function' then
      return m
   end
end


local pack_mt = {
   __len = function(self)
      return self.n
   end,
}


local pack = pack or function(...)
   return {n=select('#', ...), ...}
end


local tointeger = (function(f)
   if not f then
      -- No host tointeger implementation, use our own.
      local floor = math.floor
      return function(x)
        if type(x) == 'number' and x - floor(x) == 0.0 then
           return x
        end
      end

   elseif f '1' ~= nil then
      -- Don't perform implicit string-to-number conversion!
      return function(x)
         if type(x) == 'number' then
            return tointeger(x)
         end
      end
   end

   -- Host tointeger is good!
   return f
end)(tointeger)



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
   --- Return named metamethod, if callable, otherwise `nil`.
   -- @see std.normalize.getmetamethod
   getmetamethod = getmetamethod,

   --- Return a list of given arguments, with field `n` set to the length.
   -- @see std.normalize.pack
   pack = function(...)
      return setmetatable(pack(...), pack_mt)
   end,

   --- Convert to an integer and return if possible, otherwise `nil`.
   -- @see std.normalize.math.tointeger
   tointeger = tointeger,
}
