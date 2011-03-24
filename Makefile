
.PHONY: all clean doc install test


test:
	@export LUA_PATH='$(CURDIR)/src/?.lua;$(CURDIR)/test/?.lua' && lua test/run_tests.lua

doc:
	luadoc -d docs --nofiles src/*.lua

clean:
	rm -rf docs

