
.PHONY: all clean doc install test


test:
	@export LUA_PATH='$(CURDIR)/lib/?.lua;$(CURDIR)/test/?.lua' && lua test/run_tests.lua

doc:
	luadoc -d docs lib/*.lua scripts/*.lua

clean:
	rm -rf docs
	rm *~
