.PHONY: test doc update-doc clean


test:
	@export LUA_PATH='$(CURDIR)/lib/?.lua;$(CURDIR)/test/?.lua' && lua test/run_tests.lua

doc:
	@rm -rf doc
	luadoc -d doc lib/*.lua scripts/*.lua

update-doc: doc
	./gh-pages/update

clean:
	rm -rf doc

