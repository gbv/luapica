package = "luapica"
version = "0.1-1"
description = { 
    summary = "Lua library to handle PICA+ data",
    license = "GPL3",
    homepage = "https://github.com/gbv/luapica"
}
source = { 
    url = "git://github.com/gbv/luapica.git"
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
