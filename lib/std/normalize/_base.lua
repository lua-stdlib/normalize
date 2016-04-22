--[[
 Depending on whether `std.debug_init` or `std.strict` modules are
 installed, and what the value of _DEBUG is in the global environment,
 return functions for efficient argument type checking and for setting
 up a lexical environment for the calling module.

 @module std.normalize._base
]]

local _ENV = {
  _G = {
    _DEBUG	= rawget (_G, "_DEBUG"),
  },
  error		= error,
  next		= next,
  pcall		= pcall,
  require	= require,
  select	= select,
  setfenv	= setfenv or function () end,
  setmetatable	= setmetatable,
  type		= type,

  string_format	= string.format,
}
setfenv (1, _ENV)



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function argerror (name, i, extramsg, level)
  local s = string_format ("bad argument #%d to '%s'", i, name)
  if extramsg ~= nil then
    s = s .. " (" .. extramsg .. ")"
  end
  error (s, level and level > 0 and level + 1 or 0)
end


local argscheck, strict
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
      argcheck = {default = true, safe = true, fast = false},
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
  end

  -- Set argscheck according to whether argcheck is required.
  if _DEBUG.argcheck then

    local function icalls (name, checks, argu)
      return function (state, i)
        if i < state.checks.n then
          i = i + 1
          local ok, errmsg = state.checks[i] (state.argu, i)
          return i, not ok and errmsg or nil
        end
      end, {argu=argu, checks=checks}, 0
    end

    argscheck = function (name, ...)
      local checks = { n = select ("#", ...), ... }
      return setmetatable ({}, {
        __concat = function (_, inner)
          return function (...)
	    for i, extramsg in icalls (name, checks, { n = select ("#", ...), ... }) do
              if extramsg then
                argerror (name, i, extramsg, 3)
              end
	    end
	    return inner (...)
          end
        end,
      })
    end

  else

    argscheck = function (...)
      return setmetatable ({}, {
	__concat = function (_, inner)
	  return inner
	end,
      })
    end

  end
end


return {
  --- Raise a bad argument error.
  -- @see std.normalize.argerror
  argerror = argerror,

  --- A rudimentary argument type validation decorator.
  --
  -- Return the checked function directly if `_DEBUG.argcheck` is reset,
  -- otherwise use check function arguments using predicate functions in
  -- the corresponding positions in the decorator call.
  -- @function argscheck
  -- @string name function name to use in error messages
  -- @tparam func predicate return true if checked function argument is
  --   valid, otherwise return nil and an error message suitable for
  --   *extramsg* argument of @{argerror}
  -- @tparam func ... additional predicates for subsequent checked
  --   function arguments
  -- @raises argerror when an argument validator returns failure
  -- @see argerror
  -- @usage
  --   local unpack = argscheck ("unpack", types.table) ..
  --   function (t, i, j)
  --     return table.unpack (t, i or 1, j or #t)
  --   end
  argscheck = argscheck,

  --- Set a module environment, using std.strict if available.
  --
  -- Either "std.strict" when available, otherwise a (Lua 5.1 compatible)
  -- function to set the specified module environment.
  -- @function strict
  -- @tparam table env module environment table
  -- @treturn table *env*, which must be assigned to `_ENV`
  -- @usage
  --   local _ENV = require "std.normalize._base".strict {}
  strict = strict or function (env) setfenv (2, env) return env end
}
