LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= 2.0.1

luadir	= lib/std/normalize
SOURCES =				\
	$(luadir)/_base.lua		\
	$(luadir)/_strict.lua		\
	$(luadir)/_typecheck.lua	\
	$(luadir)/init.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all:


$(luadir)/version.lua: .FORCE
	@echo 'return "Normalized Lua Functions / $(VERSION)"' > '$@T';		\
	if cmp -s '$@' '$@T'; then						\
	    rm -f '$@T';							\
	else									\
	    echo 'echo "Normalized Lua Functions / $(VERSION)" > $@';		\
	    mv '$@T' '$@';							\
	fi

doc: build-aux/config.ld $(SOURCES)
	$(LDOC) -c build-aux/config.ld .

build-aux/config.ld: build-aux/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check: $(SOURCES)
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) spec/*_spec.yaml


.FORCE:
