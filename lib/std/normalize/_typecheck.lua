--[[
 Depending on the value of _DEBUG is in the global environment, return
 functions for efficient argument type checking.  This is effectively
 a minimal implementation of `typecheck`, limited to the functionality
 required by normalize proper, so that `typecheck` itself can depend
 on `normalize` without introducing a dependency cycle.

 @module std.normalize._typecheck
]]

local strict	= require "std.normalize._strict"

local _	= {
  base		= require "std.normalize._base",
}

local _ENV = strict {
  error		= error,
  next		= next,
  pcall		= pcall,
  require	= require,
  select	= select,
  setfenv	= setfenv or function () end,
  setmetatable	= setmetatable,
  type		= type,

  string_format	= string.format,
  table_concat	= table.concat,
  table_unpack	= table.unpack or unpack,

  _DEBUG	= require "std.normalize._debug",
  pack		= _.base.pack,
}
_ = nil


-- There an additional stack frame to count over from inside functions
-- with argchecks enabled.
local ARGCHECK_FRAME = 0



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function argerror (name, i, extramsg, level)
  local s = string_format ("bad argument #%d to '%s'", i, name)
  if extramsg ~= nil then
    s = s .. " (" .. extramsg .. ")"
  end

  -- So argerror(..., 1) needs 3 adding to it if the message from the
  -- underlying call to `error` is to blame the correct frame:
  --  1. calling error with level 1, would cause it to be the source
  --  2. another level would report argerror itself as the source
  --  3. we want to blame the function that called argerror, 2
  --     frames higher
  error (s, level and level > 0 and level + 2 + ARGCHECK_FRAME or 0)
end


local argscheck
do
  -- Set argscheck according to whether argcheck is required.
  if _DEBUG.argcheck then

    ARGCHECK_FRAME = 1

    local function icalls (name, checks, argu)
      return function (state, i)
        if i < state.checks.n then
          i = i + 1
          local ok, expected, got = state.checks[i] (state.argu, i)
          if not ok then
            return i, expected, got
          end
          return i, nil
        end
      end, {argu=argu, checks=checks}, 0
    end

    argscheck = function (name, ...)
      local checks = pack (...)
      return setmetatable ({}, {
        __concat = function (_, inner)
          return function (...)
            for i, expected, got in icalls (name, checks, pack (...)) do
              if expected or got then
                local buf, extramsg = {}
                if expected then
                  buf[#buf +1] = expected .. " expected"
                end
                if expected and got then
                  buf[#buf +1] = ", "
                end
                if got then
                  buf[#buf +1] = got
                end
                if #buf > 0 then
                  extramsg = table_concat (buf)
                end
                return argerror (name, i, extramsg, 3), nil
              end
            end
            -- Tail call pessimisation: inner might be counting frames,
            -- and have several return values that need preserving.
            -- Different Lua implementations tail call under differing
            -- conditions, so we need this hair to make sure we always
            -- get the same number of stack frames interposed.
            local results = pack (inner (...))
            return table_unpack (results, 1, results.n)
          end
        end,
      })
    end

  else

    -- Return `inner` untouched, for no runtime overhead!
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
  --- Add this to any stack frame offsets when argchecks are in force.
  -- @int ARGCHECK_FRAME
  ARGCHECK_FRAME = ARGCHECK_FRAME,

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
}
