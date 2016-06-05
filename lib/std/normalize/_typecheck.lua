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
  ipairs	= ipairs,
  next		= next,
  pcall		= pcall,
  require	= require,
  select	= select,
  setfenv	= setfenv or function () end,
  setmetatable	= setmetatable,
  tonumber	= tonumber,
  type		= type,

  string_format	= string.format,
  table_concat	= table.concat,
  table_sort	= table.sort,
  table_unpack	= table.unpack or unpack,

  _DEBUG	= require "std.normalize._debug",
  getmetamethod	= _.base.getmetamethod,
  pack		= _.base.pack,
  tointeger	= _.base.tointeger,
}
_ = nil


-- There an additional stack frame to count over from inside functions
-- with argchecks enabled.
local ARGCHECK_FRAME = 0



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function argerror (name, i, extramsg, level)
  level = tointeger (level) or 1
  local s = string_format ("bad argument #%d to '%s'", tointeger (i), name)
  if extramsg ~= nil then
    s = s .. " (" .. extramsg .. ")"
  end
  error (s, level > 0 and level + 2 + ARGCHECK_FRAME or 0)
end


local function iscallable (x)
  return type (x) == "function" or getmetamethod (x, "__call")
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
          if not iscallable (inner) then
            error ("attempt to annotate non-callable value with 'argscheck'", 2)
          end
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



--[[ ================= ]]--
--[[ Type annotations. ]]--
--[[ ================= ]]--


local function fail (expected, argu, i)
  local got = type (argu[i])
  if i > argu.n then
    got = "no value"
  end
  return nil, expected, "got " .. got
end


local function check (expected, argu, i, predicate)
  local arg = argu[i]
  if predicate (arg) then
    return true
  end
  return fail (expected, argu, i)
end


local types = setmetatable ({
  -- Accept argu[i].
  accept = function ()
    return true
  end,

  -- Reject missing argument *i*.
  arg = function (argu, i)
    if i > argu.n then
      return nil, nil, "value expected"
    end
    return true
  end,

  -- Accept function valued or `__call` metamethod carrying argu[i].
  callable = function (argu, i)
    return check ("callable", argu, i, iscallable)
  end,

  -- Accept argu[i] if it is an integer valued number, or can be
  -- converted to one by `tonumber`.
  integer = function (argu, i)
    local value = tonumber (argu[i])
    if type (value) ~= "number" then
      return fail ("integer", argu, i)
    end
    if tointeger (value) == nil then
      return nil, nil, "number has no integer representation"
    end
    return true
  end,

  -- Accept missing argument *i* (but not explicit `nil`).
  missing = function (argu, i)
    if i > argu.n then
      return true
    end
    return nil, ""
  end,

  -- Accept string valued or `__string` metamethod carrying argu[i].
  stringy = function (argu, i)
    return check ("string", argu, i, function (x)
      return type (x) == "string" or getmetamethod (x, "__tostring")
    end)
  end,

  -- Accept non-nil valued argu[i].
  value = function (argu, i)
    if argu[i] ~= nil then
      return true
    end
    return nil, "value", nil
  end,
}, {
  __index = function (_, k)
    -- Accept named primitive valued argu[i].
    return function (argu, i)
      return check (k, argu, i, function (x)
        return type (x) == k
      end)
    end
  end,
})


local function any (...)
  local fns = {...}
  return function (argu, i)
    local buf, ok, expected, got = {}
    for _, predicate in ipairs (fns) do
      ok, expected, got = predicate (argu, i)
      if ok then
        return true
      end
      if expected == nil then
	return nil, nil, got
      elseif expected ~= "nil" then
        buf[#buf + 1] = expected
      end
    end
    if #buf == 0 then
      return nil, nil, got
    elseif #buf > 1 then
      table_sort (buf)
      buf[#buf -1], buf[#buf] = buf[#buf -1] .. " or " .. buf[#buf], nil
    end
    return nil, table_concat (buf, ", "), got
  end
end


local function opt (...)
  return any (types["nil"], ...)
end



return {
  --- Add this to any stack frame offsets when argchecks are in force.
  -- @int ARGCHECK_FRAME
  ARGCHECK_FRAME = ARGCHECK_FRAME,

  --- Call each argument in turn until one returns non-nil.
  --
  -- This function satisfies the @{ArgCheck} interface in order to be
  -- useful as an argument to @{argscheck} when one of several other
  -- @{ArgCheck} functions can satisfy the requirement for a given
  -- argument.
  -- @function any
  -- @tparam ArgCheck ... type predicate callables
  -- @treturn ArgCheck a new function that calls all passed
  --   predicates, and combines error messages if all fail
  -- @usage
  --   len = argscheck ("len", any (types.table, types.string)) .. len
  any = any,

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

  --- Create an @{ArgCheck} predicate for an optional argument.
  --
  -- This function satisfies the @{ArgCheck} interface in order to be
  -- useful as an argument to @{argscheck} when a particular argument
  -- is optional.
  -- @function opt
  -- @tparam ArgCheck ... type predicate callables
  -- @treturn ArgCheck a new function that calls all passed
  --   predicates, and combines error messages if all fail
  -- @usage
  --   getfenv = argscheck (
  --     "getfenv", opt (types.integer, types.callable)
  --   ) .. getfenv
  opt = opt,

  --- A collection of @{ArgCheck} functions used by `normalize` APIs.
  -- @table types
  -- @tfield ArgCheck accept always succeeds
  -- @tfield ArgCheck callable accept a function or functor
  -- @tfield ArgCheck integer accept integer valued number
  -- @tfield ArgCheck none accept only `nil`
  -- @tfield ArgCheck stringy accept a string or `__tostring` metamethod
  --   bearing object
  -- @tfield ArgCheck table accept any table
  -- @tfield ArgCheck value accept any non-`nil` value
  types = types,
}



--- Types
-- @section types

--- Signature of an @{argscheck} predicate callable.
-- @function ArgCheck
-- @tparam table argu a packed table (including `n` field) of all arguments
-- @int index into *argu* for argument to action
-- @return[1] non-nil if one of the callable arguments succeeded
-- @return[2] nil if all of the callable arguments failed
-- @treturn[2] string the expected types returned by failed calls
-- @treturn[2] string a description of the failed predicate argument
-- @return[3] nil otherwise
-- @treturn[3] nil if expected type list is not relevant to failure
--   description
-- @treturn[3] string error message
-- @usage
--   len = argscheck ("len", any (types.table, types.string)) .. len
