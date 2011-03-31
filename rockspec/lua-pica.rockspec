package = "LuaPica"
version = "0.1-1"
description = { 
  summary = "Lua library to handle PICA+ data",
  license = "GPL3",
  homepage = "https://github.com/nichtich/lua-pica"
}
source = { 
  url = "git://github.com/nichtich/lua-pica.git"
}
dependencies = {
  "lua >= 5.1"
}
build = {
   type = "make",
   variables = {
      LUA_DIR = "$(LUADIR)",
      SYS_BINDIR = "$(BINDIR)"
   }
}
