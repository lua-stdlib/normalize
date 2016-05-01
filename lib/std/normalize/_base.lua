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
  tostring	= tostring,
  type		= type,

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
}
