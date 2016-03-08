--[[
 Depending on whether `std.debug_init` or `std.strict` modules are
 installed, and what the value of _DEBUG is in the global environment,
 return a function for efficiently setting up a lexical environment.

 @module std.normalize._base
]]

local _ENV = {
  _DEBUG	= _DEBUG,
  next		= next,
  pcall		= pcall,
  require	= require,
  setfenv	= setfenv or function () end,
  type		= type,
}
setfenv (1, _ENV)


-- Use the _DEBUG table from `std.debug_init`, if installed.
local ok, debug_init	= pcall (require, "std.debug_init")
if not ok then
  debug_init		= _DEBUG
end


local function is_strict ()
  if debug_init == false then
    -- _G._DEBUG == false
    return false
  elseif type (debug_init) ~= "table" then
    -- `std.debug_init` is not installed, or _G._DEBUG == true or nil 
    return true
  elseif debug_init.strict ~= nil then
    -- _G._DEBUG or std.debug_init have a specific `.strict` field set
    return debug_init.strict
  end
  -- otherwise, strict by default!
  return true
end


-- If strict is not required, pass the unchanged environment through.
local strict = function (env) return env end

-- If strict mode is required, use "std.strict" if we have it.
if is_strict () then
  -- `require "std.strict"` will get the old stdlib implementation of
  -- strict, which doesn't support individual environment tables :(
  ok, strict		= pcall (require, "std.strict.init")
  if not ok then
    strict		= false
  end
end


return {
  --- Set a strict environment.
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
