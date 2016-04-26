# std.normalize NEWS - User visible changes

## Noteworthy changes in release 1.0 (2016-02-09) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - New `argerror` to add unhandled argument type reporting to Lua
    functions; equivalent to `luaL_argerror` in the Lua C API.

  - `len` will return the length of whatever an object's `__tostring`
    metamethod returns (except that a `__len` metamethod is used first
    if available), before counting initial non-nil valued integer
    keys.

  - `load` will load a string of valid Lua code, even in Lua 5.1.

  - `str` is a fast specialization of `std.string.render`
    with all helper functions and abstractions inlined.

  - When `_DEBUG` specifies argchecking, these APIs all diagnose
    unsuitable types passed by the caller.

### Bug fixes

  - `getfenv (0)` now returns the global environment correctly in
    Lua 5.2+.

  - `getmetamethod` now handles functor metatable fields correctly,
    rather than `nil` as in previous releases.  It's also considerably
    faster now that it doesn't use `pcall` any more.

  - `pack` now sets `n` field to number of arguments packed, even in
    Lua 5.1.

### Incompatible changes

  - The output format of `str` skips initial sequence keys (compared to
    the output from `std.tostring`) in this new compact format, including
    stringification of tables using their `__tostring` metamethods.
