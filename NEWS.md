# std.normalize NEWS - User visible changes

## Noteworthy changes in release ?.? (????-??-??) [?]

### New features

  - Support importing into another project directly with:

    ```sh
    $ cp ../normalize/lib/std/normalize/init.lua lib/std/normalize.lua
    ```


## Noteworthy changes in release 2.0.3 (2020-04-15) [stable]

### New features

  - Initial support for Lua-5.4.


## Noteworthy changes in release 2.0.2 (2018-03-17) [stable]

### Bug fixes

  - Passing a table to the return value of `require 'std.normalize'`
    really does diagnose attempts to access undeclared variables when
    std.strict is found in the package.path now.

  - Don't trigger undeclared variable accesses during loading, when
    used in conjunction with other strict modules.


## Noteworthy changes in release 2.0.1 (2017-11-26) [stable]

### Bug fixes

  - Environment table population now correctly looks up ALLCAPS symbols
    when inferring destination symbol names, and only treats explicit
    assignment to an ALLCAPS destination symbol name as a string
    constant:

    ```lua
    local _ENV = require 'std.normalize' {
       'lyaml.functional.NULL',
       CONST = 'lyaml.functional.NULL',
    }
    assert(NULL == require 'lyaml.functional'.NULL)
    assert(type(CONST) == 'string')
    ```

    Previously, `NULL` would not have been loaded, instead remaining as
    the constant string 'lyaml.functional.NULL'.


## Noteworthy changes in release 2.0 (2017-10-16) [stable]

### New features

  - New `string.render` exposes the low-level implementation of `str`.

  - New `table.keys` fetches a list of keys in a given table.

  - New `table.merge` performs destructive merging of table content.

### Bug fixes

  - Include `_G` table, pointing to the complete normalized table
    of loaded modules, in the default user environment.  So this
    will work now:

    ```lua
    local _ENV = require 'std.normalize' {}
    for i = 1, len(_G.arg) do
       print(i .. ': ' .. _G.arg[i])
    end
    ```

### Incompatible changes

  - Strict mode and argument checking are no longer controlled by the
    global _DEBUG setting, but rather by the new `std._debug` module.
    For example, to turn off all runtime debug facilities, insteod of
    setting `_DEBUG = false` before loading this module, you should use:

    ```lua
    local _debug = require 'std._debug'(false)
    ```

  - Removed ugly `opairs` implementation, with it's own fixed ordering.
    If you still need it, you can use something like this:

    ```lua
    keylist = table.keys(t)
    sort(keylist, function(a, b)
       if type(a) == 'number' then
          return type(b) ~= 'number' or a < b
       else
          return type(b) ~= 'number' and tostring(a) < tostring(b)
       end
    end)
    for _, k in ipairs(keylist) do
       process(k, t[k])
    end
    ```


## Noteworthy changes in release 1.0.4 (2017-09-11) [stable]

### New features

  - `std.normalize` has been rewritten, in addition to maintaining
    backwards compatibility, also allowing easier loading of symbols
    into the module environment:

    ```lua
    local _ENV = require 'std.normalize' {
       -- local string = require 'std.normalize.string'
       'string',
       -- local math = require 'math'
       math = math,
       -- local ceil = require 'math'.ceil
       ceil = math.ceil,
       -- local floor = require 'std.normalize.math'.floor
       'math.floor',
       -- local int = require 'std.normalize.math'.tointeger
       int = 'math.tointeger',
       -- local MODNAME = 'math.tointeger'
       MODNAME = 'math.tointeger',
    }
    ```

    Note that dot-delimited strings are searched in the 'std.normalize'
    table, and can be followed by optional nested table references to
    drill into that table.  Otherwise the references are filled from
    the host Lua _G as the table is populated before it is even passed
    to the 'std.normalize' loader.


## Noteworthy changes in release 1.0.3 (2017-09-02) [stable]

### New features

  - `std.normalize` allows assignment of non-string values in its table
    argument to propagate up to the assigned environment:

    ```lua
    local _ENV = require 'std.normalize' {
       ceil = math.ceil,
       argcheck = require 'typecheck'.argcheck,
    }
    ```

### Incompatible changes

  - `math.tointeger` returns `nil` for string type arguments now, for
    deterministic behaviour whether or not LUA_NOCVTS2N is defined at
    compile time.

  - `getfenv`, consequently, now diagnoses a bad argument when passed an
    integer-like string instead of an actual integer.


## Noteworthy changes in release 1.0.2 (2017-07-07) [stable]

### New features

  - `pack` sets a `__len` metamethod on its result so that `len` returns
    the actual number of arguments packed (including `nil`s).

  - `unpack`ing a `pack`ed sequence returns the original sequence without
    requiring an explicit `to_index` argument, even if the original
    sequence contains `nil`s:

    ```lua
    a, b, c = unpack(pack(1, nil, 3))
    assert(a == 1 and b == nil and c == 3, "require 'std.normalize' first!")
    ```

  - `str` uses C-like escape sequences \a, \b, \t, \n, \v, \f, \r and \\
    to render the associated bytes.

### Bug fixes

  - `getmetamethod` no longer raises an argerror for nil-valued
    initial argument.

  - `ipairs` and `opairs` now diagnose all non-table valued arguments
     correctly.

  - `str` now only skips consecutive integer keys in proper sequences.

### Incompatible changes

  - `ipairs` now respects the `__len` metamethod, such as the one set by
    `pack`.


## Noteworthy changes in release 1.0.1 (2016-05-28) [stable]

### Bug fixes

  - `argerror` correctly treats missing or `nil`-valued argument
    as equivalent to level 1 (i.e. blame the caller of the function
    that calls `argerror`).


## Noteworthy changes in release 1.0 (2016-05-08) [stable]

### New features (since lua-stdlib-41.2)

  - Initial release, now separated out from lua-stdlib.

  - Passing a table of module names to the result of requiring this
    module injects top-level normalized APIs into the module
    environment, and additionally loads the named modules.  For
    compatibility across supported Lua hosts, this must be assigned
    back to `_ENV`:

    ```lua
      local _ENV = require 'std.normalize' {
        'package',
        'std.prototype',
        strict = 'std.strict',
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
    diagnose explicit `nil` or floating-point arguments (`os.exit()` is
    still equivalent to `os.exit(true)`).

  - `package.searchpath` is available everywhere.

  - `str` is a fast specialization of `std.string.render`
    with all helper functions and abstractions inlined.

  - When `_DEBUG` specifies argchecking, normalized APIs all diagnose
    unsuitable types passed by the caller.

### Bug fixes

  - `getfenv(0)` now returns the global environment correctly in
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
