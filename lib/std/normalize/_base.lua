--[[
 Purely to break internal dependency cycles without introducing
 multiple copies of base functions used in other normalize modules.

 @module std.normalize._base
]]

local strict	= require "std.normalize._strict"

local _ENV = strict {
  getmetatable	= getmetatable,
  select	= select,
  setfenv	= setfenv or function () end,
  tonumber	= tonumber,
  tostring	= tostring,
  type		= type,

  math_floor	= math.floor,
  math_tointeger = math.tointeger,
  table_pack	= table.pack,
}



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local function getmetamethod (x, n)
  local m = (getmetatable (x) or {})[tostring (n)]
  if type (m) == "function" then
    return m
  end
  if type ((getmetatable (m) or {}).__call) == "function" then
    return m
  end
end


local pack = table_pack or function (...)
  return { n = select ("#", ...), ...}
end


local tointeger = math_tointeger or function (x)
  local i = tonumber (x)
  if i and i - math_floor (i) == 0.0 then
    return i
  end
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  --- Return named metamethod, if callable, otherwise `nil`.
  -- @see std.normalize.getmetamethod
  getmetamethod = getmetamethod,

  --- Return a list of given arguments, with field `n` set to the length.
  -- @see std.normalize.pack
  pack = pack,

  --- Convert to an integer and return if possible, otherwise `nil`.
  -- @see std.normalize.math.tointeger
  tointeger = tointeger,
}
