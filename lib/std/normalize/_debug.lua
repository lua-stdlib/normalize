--[[
 Normalized Lua API for Lua 5.1, 5.2 & 5.3
 Coryright (C) 2014-2017 Gary V. Vaughan
]]
--[[--
 Depending on whether `std.debug_init` is installed, and on what the
 value of `_DEBUG` is in the global environment, return a table with
 a local `_DEBUG` that has at least `strict` and `argcheck` fields set
 appropriately.

 @module std.normalize._debug
]]

local _ENV = {
   _G = {
      _DEBUG = rawget(_G, '_DEBUG'),
   },
   next = next,
   pcall = pcall,
   require = require,
   setfenv = setfenv or function() end,
   type	 = type,
}
setfenv(1, _ENV)



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local _DEBUG
do
   local ok, debug_init	= pcall(require , 'std.debug_init')
   if ok then
      -- Use the _DEBUG table from `std.debug_init`, if installed.
      _DEBUG = debug_init._DEBUG
   else
      local function choose(t)
         for k, v in next, t do
	if _G._DEBUG == false then
	   t[k] = v.fast
	elseif _G._DEBUG == nil then
	   t[k] = v.default
	elseif type(_G._DEBUG) ~= 'table' then
	   t[k] = v.safe
	elseif _G._DEBUG[k] ~= nil then
	   t[k] = _G._DEBUG[k]
	else
	   t[k] = v.default
	end
         end
         return t
      end

      _DEBUG = choose {
         argcheck = {default = true, safe = true, fast = false},
         strict	= {default = true, safe = true, fast = false},
      }
   end
end


--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return _DEBUG
