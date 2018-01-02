Normalized Lua Functions
========================

Copyright (C) 2002-2018 [std.normalize authors][authors]

[![License](https://img.shields.io/:license-mit-blue.svg)](https://mit-license.org)
[![travis-ci status](https://secure.travis-ci.org/lua-stdlib/normalize.png?branch=master)](https://travis-ci.org/lua-stdlib/normalize/builds)
[![codecov.io](https://codecov.io/gh/lua-stdlib/normalize/branch/master/graph/badge.svg)](https://codecov.io/gh/lua-stdlib/normalize)
[![Stories in Ready](https://badge.waffle.io/lua-stdlib/normalize.png?label=ready&title=Ready)](https://waffle.io/lua-stdlib/normalize)

This is a collection of normalized lua functions for Lua 5.1 (including
LuaJIT), 5.2 and 5.3.  The libraries are copyright by their authors
(see the [AUTHORS][] file for details), and released under the
[MIT license][mit] (the same license as Lua itself).  There is no
warranty.

_normalize_ has no run-time prerequisites beyond a standard Lua system,
and the [std._debug][] package - though it will also take advantage of
[std.strict][] if installed.

Writing Lua libraries that target several Lua implementations can be a
frustrating exercise in working around lots of small differences in APIs
and semantics they share (or rename, or omit).  _normalize_ provides the
means to simply access deterministic implementations of those APIs while
preserving the the same semantics across all supported host Lua
implementations.  Each function is as thin and fast an implementation as
possible within that host Lua environment, evaluating to the Lua C
implementation with no overhead where host semantics allow.

The core of this module is to transparently set the environment up with
a single API (as opposed to requiring caching functions from a module
table into module locals):

```lua
   local _ENV = require 'std.normalize' {
     'package',
     'std.prototype',
     strict = 'std.strict',
   }
   
   -- From here pairs, ipairs, setfenv et. al. work the same everywhere!
   -- While 'package' is imported, 'debug', 'table', et. al. are not
   -- preventing undeclared use.  External modules can be loaded into
   -- nested tables (std.prototype) or specific symbols (strict).
```

The normalized API is not yet complete, and in contrast to the
[lua-compat][] libraries, neither does it attempt to provide you with as 
nearly compatible an API as is possible relative to some specific Lua
implementation - rather it provides a variation of the "lowest common
denominator" that can be implemented relatively efficiently in the
supported Lua implementations. At the moment, only the functionality
required by [stdlib][] is provided.

Pull-requests for more normalized APIs are welcome!

[authors]: https://github.com/lua-stdlib/normalize/blob/master/AUTHORS.md
[github]: https://github.com/lua-stdlib/normalize/ "Github repository"
[lua]: https://www.lua.org "The Lua Project"
[lua-compat]: https://github.com/keplerproject/lua-compat-5.3 "Lua 5.3ish API"
[mit]: https://mit-license.org "MIT License"
[stdlib]: https://github.com/lua-stdlib/lua-stdlib "Standard Lua Libraries"
[std.strict]: https://github.com/lua-stdlib/strict "strict variables"
[typecheck]: https://github.com/gvvaughan/typecheck "function type checks"


Installation
------------

The simplest and best way to install normalize is with [LuaRocks][]. To
install the latest release (recommended):

```bash
    luarocks install std.normalize
```

To install current git master (for testing, before submitting a bug
report for example):

```bash
    luarocks install https://raw.githubusercontent.com/lua-stdlib/normalize/master/normalize-git-1.rockspec
```

The best way to install without [LuaRocks][] is to copy the `std/normalize`
folder and its contents into a directory on your package search path.

[luarocks]: https://www.luarocks.org "Lua package manager"


Documentation
-------------

The latest release of these libraries is [documented in LDoc][github.io].
Pre-built HTML files are included in the release.

[github.io]: https://lua-stdlib.github.io/normalize


Bug reports and code contributions
----------------------------------

These libraries are written and maintained by their users.

Please make bug reports and suggestions as [GitHub Issues][issues].
Pull requests are especially appreciated.

But first, please check that your issue has not already been reported by
someone else, and that it is not already fixed by [master][github] in
preparation for the next release (see Installation section above for how
to temporarily install master with [LuaRocks][]).

There is no strict coding style, but please bear in mind the following
points when proposing changes:

0. Follow existing code. There are a lot of useful patterns and avoided
   traps there.

1. 3-character indentation using SPACES in Lua sources: It makes rogue
   TABS easier to see, and lines up nicely with 'if' and 'end' keywords.

2. Simple strings are easiest to type using single-quote delimiters,
   saving double-quotes for where a string contains apostrophes.

3. Save horizontal space by only using SPACES where the parser requires
   them.

4. Use vertical space to separate out compound statements to help the
   coverage reports discover untested lines.

[issues]: https://github.com/lua-stdlib/normalize/issues
