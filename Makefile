LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= specl

VERSION	= 1.0

luadir	= lib/std/normalize
SOURCES =				\
	$(luadir)/_base.lua		\
	$(luadir)/_debug.lua		\
	$(luadir)/_strict.lua		\
	$(luadir)/_typecheck.lua	\
	$(luadir)/init.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)


all: doc $(luadir)/version.lua


$(luadir)/version.lua: .FORCE
	@echo 'return "Normalized Lua Functions / $(VERSION)"' > '$@T';		\
	if cmp -s '$@' '$@T'; then						\
	    rm -f '$@T';							\
	else									\
	    echo 'echo "Normalized Lua Functions / $(VERSION)" > $@';		\
	    mv '$@T' '$@';							\
	fi

doc: doc/config.ld $(SOURCES)
	$(LDOC) -c doc/config.ld .

doc/config.ld: doc/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check: $(SOURCES)
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) specs/*_spec.yaml


.FORCE:
