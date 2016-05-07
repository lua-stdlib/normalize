# std.normalize NEWS - User visible changes

## Noteworthy changes in release 1.0 (2016-05-08) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - Passing a table of module names to the result of requiring this
    module injects top-level normalized APIs into the module
    environment, and additionally loads the named modules.  For
    compatibility across supported Lua hosts, this must be assigned
    back to `_ENV`:

    ```lua
      local _ENV = require "std.normalize" {
        "package",
        "std.prototype",
        strict = "std.strict",
      }
    ```

  - New `argerror` to add unhandled argument type reporting to Lua
    functions; equivalent to `luaL_argerror` in the Lua C API.

  - `len` will return the length of whatever an object's `__tostring`
    metamethod returns (except that a `__len` metamethod is used first
    if available), before counting initial non-nil valued integer
    keys.

  - `rawlen` ignores metamethods, and always counts up to the last
    sequential non-`nil` valued element in a sequence.

  - `load` will load a string of valid Lua code or call the given
    function or functor argument to fetch strings, even in Lua 5.1.
    Note that, for consistency across host implementations, the optional
    `mode` and `env` arguments are currently **not** supported.

  - `math.tointeger` and `math.type` are available everywhere (within
    the limitations of representing all number as 53-bit floats on Lua
    5.2 and earlier).

  - New `os.exit` wrapper accepts a boolean argument, even in Lua 5.1;
    but is slightly slower than the host Lua implementation in order to
    diagnose explicit `nil` or floating-point arguments (`os.exit ()` is
    still equivalent to `os.exit (true)`).

  - `package.searchpath` is available everywhere.

  - `str` is a fast specialization of `std.string.render`
    with all helper functions and abstractions inlined.

  - When `_DEBUG` specifies argchecking, normalized APIs all diagnose
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
