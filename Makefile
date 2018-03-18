# Normalized Lua API for Lua 5.1, 5.2 & 5.3
# Copyright (C) 2002-2018 std.normalize authors

LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= git

luadir	= lib/std/normalize
SOURCES =				\
	$(luadir)/_base.lua		\
	$(luadir)/_strict.lua		\
	$(luadir)/_typecheck.lua	\
	$(luadir)/init.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all: doc $(luadir)/version.lua


$(luadir)/version.lua: Makefile
	@echo 'return "Normalized Lua Functions / $(VERSION)"' > '$@'

doc: build-aux/config.ld $(SOURCES)
	$(LDOC) -c build-aux/config.ld .

build-aux/config.ld: build-aux/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check: $(SOURCES)
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) spec/*_spec.yaml


.FORCE:
