
.PHONY: all clean doc install test

export LUA_PATH := $(CURDIR)/scr/?.lua;$(CURDIR)/test/?.lua

test:
	lua test/run_tests.lua

clean:
	rm -rf docs

