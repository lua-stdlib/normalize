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


local debug_getinfo = debug.getinfo
local debug_getupvalue = debug.getupvalue
local debug_setupvalue = debug.setupvalue
local debug_upvaluejoin = debug.upvaluejoin
-- In Lua 5.1, only debug.getfenv works on C functions; but compatibility
-- layers (like specl) may supply only the best version as `getfenv`.
local host_getfenv = rawget(_G, 'getfenv') or false
local host_setfenv = rawget(_G, 'setfenv') or false
local debug_getfenv = debug.getfenv or host_getfenv
local debug_setfenv = debug.setfenv or host_setfenv


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


-- The function that a functor *fn* runs: its own `call` field, like the
-- functables that share one `__call` dispatcher, or else its `__call`
-- metamethod.  No need to recurse, because Lua doesn't support nested
-- functors.
local function unwrap(fn)
   local call = type(fn) == 'table' and rawget(fn, 'call')
   if type(call) == 'function' then
      return call
   end
   local mt = getmetatable(fn)
   return type(mt) == 'table' and mt.__call or fn
end


-- A getfenv that works on every Lua, for a caller that is *extra* stack
-- frames beneath the function, such as one that checks its arguments.
-- Choose by version: an environment that smooths over Lua differences
-- may not provide the 5.1 debug.[gs]etfenv.
local function make_getfenv(extra)
   if _VERSION == 'Lua 5.1' then
      return function(fn)
         local n = tointeger(fn or 1)
         if n then
            if n > 0 then
               -- Adjust for this function's stack frame, if fn is non-zero.
               n = n + 1 + extra
            end

            -- The parentheses return only the environment, and keep this
            -- from being a tail call, which would remove a stack frame and
            -- break the numeric *fn* count.
            return (host_getfenv(n))
         end

         if type(fn) ~= 'function' then
            -- Unwrapping a functor doesn't change the stack frame offset.
            fn = unwrap(fn)
         end

         -- In Lua 5.1, only debug.getfenv works on C functions; but it
         -- does not work on stack counts.
         return debug_getfenv(fn)
      end
   end

   -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
   return function(fn)
      if fn == 0 then
         return _G
      end
      local n = tointeger(fn or 1)
      if n then
         fn = debug_getinfo(n + 1 + extra, 'f').func
      elseif type(fn) ~= 'function' then
         fn = unwrap(fn)
      end

      local name, env
      local up = 0
      repeat
         up = up + 1
         name, env = debug_getupvalue(fn, up)
      until name == '_ENV' or name == nil
      return env
   end
end


-- A setfenv that works on every Lua, with *extra* stack frames, as for
-- make_getfenv.
local function make_setfenv(extra)
   if _VERSION == 'Lua 5.1' then
      return function(fn, env)
         local n = tointeger(fn or 1)
         if n then
            if n > 0 then
               n = n + 1 + extra
            end
            -- One value, and not a tail call, as in getfenv.
            return (host_setfenv(n, env))
         end
         if type(fn) ~= 'function' then
            fn = unwrap(fn)
         end
         return debug_setfenv(fn, env)
      end
   end

   -- Thanks to http://lua-users.org/lists/lua-l/2010-06/msg00313.html
   return function(fn, env)
      local n = tointeger(fn or 1)
      if n then
         if n > 0 then
            n = n + 1 + extra
         end
         fn = debug_getinfo(n, 'f').func
      elseif type(fn) ~= 'function' then
         fn = unwrap(fn)
      end

      local up, name = 0
      repeat
         up = up + 1
         name = debug_getupvalue(fn, up)
      until name == '_ENV' or name == nil
      if name then
         debug_upvaluejoin(fn, up, function() return name end, 1)
         debug_setupvalue(fn, up, env)
      end
      return n ~= 0 and fn or nil
   end
end


return {
   callable = callable,
   getfenv = make_getfenv(0),
   getmetamethod = getmetamethod,
   iscallable = iscallable,
   len = len,
   pack = pack,
   pairs = pairs,
   rawlen = rawlen,
   setfenv = make_setfenv(0),
   tointeger = tointeger,

   -- The getfenv and setfenv for a function that is *extra* stack frames
   -- beneath its caller, as std.normalize's are when typecheck checks
   -- their arguments.
   with_frames = function(extra)
      return {getfenv = make_getfenv(extra), setfenv = make_setfenv(extra)}
   end,
}
