.PHONY: test doc update-doc clean rockspec

test:
	@export LUA_PATH='$(CURDIR)/lib/?.lua;$(CURDIR)/test/?.lua' && lua test/run_tests.lua

doc:
	@rm -rf doc
	luadoc -d doc lib/*.lua scripts/*.lua

update-doc: doc
	./gh-pages/update

clean:
	rm -rf doc

rockspec:
	@cd rockspec && rm -f luapica-*.rockspec && \
	awk 'BEGIN {FS="\""}; $$0 ~ "version" {print "luapica-"$$2".rockspec"}' \
	lua-pica.rockspec | xargs ln -s lua-pica.rockspec

# TODO: after pushing to master at github:
# create rocks file
#   luarocks pack rockspec/$latest.rockspec
# and copy it together with the .rockspec to gh-pages/rock
