--[[
 Purely to break internal dependency cycles without introducing
 multiple copies of base functions used in other normalize modules.

 @module std.normalize._base
]]

local strict	= require "std.normalize._strict"

local _ENV = strict {
  select	= select,
  setfenv	= setfenv or function () end,

  table_pack	= table.pack,
}



--[[ =============== ]]--
--[[ Implementation. ]]--
--[[ =============== ]]--


local pack = table_pack or function (...)
  return { n = select ("#", ...), ...}
end



--[[ ================= ]]--
--[[ Public Interface. ]]--
--[[ ================= ]]--


return {
  --- Return a list of given arguments, with field `n` set to the length.
  -- @see std.normalize.pack
  pack = pack,
}
