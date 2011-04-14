.PHONY: test doc update-doc clean rockspec

SCRIPTS=scripts/pica2rdf.lua scripts/ddc.lua

test:
	@export LUA_PATH='$(CURDIR)/lib/?.lua;$(CURDIR)/test/?.lua' && lua test/run_tests.lua

doc:
	@rm -rf doc
	luadoc -d doc lib/*.lua $(SCRIPTS)

update-doc: doc
	./gh-pages/update

clean:
	rm -rf doc

rockspec:
	@cd rockspec && rm -f luapica-*.rockspec && \
	awk 'BEGIN {FS="\""}; $$0 ~ "version" {print "luapica-"$$2".rockspec"}' \
	luapica.rockspec | xargs ln -s luapica.rockspec

# TODO: after pushing to master at github:
# create rocks file
#   luarocks pack rockspec/$latest.rockspec
# and copy it together with the .rockspec to gh-pages/rock
