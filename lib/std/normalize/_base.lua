--[[
 Depending on whether `std.debug_init` or `std.strict` modules are
 installed, and what the value of _DEBUG is in the global environment,
 return a function for efficiently setting up a lexical environment.

 @module std.normalize._base
]]

local _ENV = {
  _G = {
    _DEBUG	= rawget (_G, "_DEBUG"),
  },
  next		= next,
  pcall		= pcall,
  require	= require,
  setfenv	= setfenv or function () end,
  type		= type,
}
setfenv (1, _ENV)



--[[ ================== ]]--
--[[ Initialize _DEBUG. ]]--
--[[ ================== ]]--


local strict


do
  local _DEBUG

  local ok, debug_init	= pcall (require, "std.debug_init")
  if ok then
    -- Use the _DEBUG table from `std.debug_init`, if installed.
    _DEBUG		= debug_init._DEBUG
  else
    local function choose (t)
      for k, v in next, t do
	if _G._DEBUG == false then
	  t[k] = v.fast
	elseif _G._DEBUG == nil then
	  t[k] = v.default
	elseif type (_G._DEBUG) ~= "table" then
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
      strict   = {default = true, safe = true, fast = false},
    }
  end

  -- If strict mode is required, use "std.strict" if we have it.
  if _DEBUG.strict then
    -- `require "std.strict"` will get the old stdlib implementation of
    -- strict, which doesn't support individual environment tables :(
    ok, strict		= pcall (require, "std.strict.init")
    if not ok then
      strict		= false
    end
  else
  end
end


return {
  --- Set a module environment, using std.strict if available.
  --
  -- Either "std.strict" when available, otherwise a (Lua 5.1 compatible)
  -- function to set the specified module environment.
  -- @function strict
  -- @tparam table env module environment table
  -- @treturn table *env*, which must be assigned to `_ENV`
  -- @usage
  -- local _ENV = require "std.normalize._base".strict {}
  strict = strict or function (env) setfenv (2, env) return env end
}
