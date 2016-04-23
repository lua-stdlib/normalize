# std.normalize NEWS - User visible changes

## Noteworthy changes in release 1.0 (2016-02-09) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - `std.normalize.argerror` to add unhandled argument type reporting
    to Lua functions; equivalent to `luaL_argerror` in the Lua C API.

  - `std.normalize.load` will load a string of valid Lua code, even in
    Lua 5.1.

  - `std.normalize.str` is a fast specialization of `std.string.render`
    with all helper functions and abstractions inlined.

### Bug fixes

  - `std.normalize.getmetamethod` now handles functor metatable
    fields correctly, rather than `nil` as in previous releases.  It's
    also considerably faster now that it doesn't use `pcall` any more.

  - `std.normalize.ipairs` and `std.normalize.opairs` now diagnose
    missing argument, when `_DEBUG` specifies argchecking.

  - `std.normalize.pack` now sets `n` field to number of arguments
    packed, even in Lua 5.1.

  - `std.normalize.unpack` now diagnoses bad arguments, when `_DEBUG`
    specifies argchecking.

### Incompatible changes

  - The output format of `std.normalize.str` skips initial sequence keys
    in the new compact format, including stringification of tables using
    their `__tostring` metamethods.
