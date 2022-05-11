TESTS:=tests/tests.lua
LICENSE:=LICENSE

export LUA_PATH:=$(LUA_PATH);./src/?.lua;

all:
	@echo "Running tests ... "
	@./tests/tests.lua

tests: all

.PHONY: license

license:
	@cat $(LICENSE)
