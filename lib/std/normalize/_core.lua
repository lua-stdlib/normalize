--[[
 Core functions for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2011-2026 std.normalize authors
]]
--[[--
 The functions that std.normalize shares with the modules that sit
 beneath it, and so cannot depend on it.

 This file requires nothing, and is the same wherever it is: std.normalize
 requires it as `std.normalize._core`, and typecheck, std.strict and
 optparse vendor a byte for byte copy as their own `_normalize` module,
 so that there is only one copy to maintain.  Change it here, and let
 `luke release` copy it to them, rather than change a copy.

 @module std.normalize._core
]]


-- Whether *x* can be called, and so what it is if it can: *x* itself,
-- rather than its `__call` metamethod, which needs `self` too.
local function callable(x)
   -- Careful here!
   -- Most versions of Lua don't recurse functables, so make sure you
   -- always put a real function in __call metamethods.  Consequently,
   -- no reason to recurse here.
   -- func=function() print 'called' end
   -- func() --> 'called'
   -- functable=setmetatable({}, {__call=func})
   -- functable() --> 'called'
   -- nested=setmetatable({}, {__call=function(self, ...) return functable(...)end})
   -- nested() -> 'called'
   -- notnested=setmetatable({}, {__call=functable})
   -- notnested()
   -- --> stdin:1: attempt to call global 'nested' (a table value)
   -- --> stack traceback:
   -- -->	stdin:1: in main chunk
   -- -->		[C]: in ?
   if type(x) == 'function' then
      return x
   end
   -- A protected metatable, from `__metatable`, need not be a table.
   local mt = getmetatable(x)
   if type(mt) == 'table' and mt.__call then
      return x
   end
end


-- Whether *x* is callable, as true or false.
local function iscallable(x)
   return callable(x) ~= nil
end


local function getmetamethod(x, n)
   local mt = getmetatable(x)
   if type(mt) == 'table' then
      return callable(mt[n])
   end
end


local function rawlen(x)
   -- Lua 5.1 does not implement rawlen, and while # operator ignores
   -- __len metamethod, `nil` in sequence is handled inconsistently.
   if type(x) ~= 'table' then
      return #x
   end

   local n = #x
   for i = 1, n do
      if x[i] == nil then
         return i -1
      end
   end
   return n
end


local function len(x)
   return (getmetamethod(x, '__len') or rawlen)(x)
end


local tointeger = (function(f)
   if f == nil then
      -- No host tointeger implementationm use our own.
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
            return f(x)
         end
      end
   end

   -- Host tointeger is good!
   return f
end)(math.tointeger)


local pack = (function(f)
   local pack_mt = {
      __len = function(self)
         return self.n
      end,
   }

   local pack_fn = f or function(...)
      return {n=select('#', ...), ...}
   end

   return function(...)
      return setmetatable(pack_fn(...), pack_mt)
   end
end)(rawget(_G, "pack"))


local pairs = (function(b)
   if b then
      -- Add support for __pairs when missing.
      return function (t)
         return (getmetamethod(t, '__pairs') or pairs)(t)
      end
   end

   return _G.pairs
end)(not not pairs(setmetatable({},{__pairs=function() return false end})))


return {
   callable = callable,
   getmetamethod = getmetamethod,
   iscallable = iscallable,
   len = len,
   pack = pack,
   pairs = pairs,
   rawlen = rawlen,
   tointeger = tointeger,
}
