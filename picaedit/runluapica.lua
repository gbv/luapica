
local T = io.read("*all")
io.flush()

local write = io.write
local dummy = function(...) return nil end


require "pica"
record = os.getenv("record")

-- TODO: catch this kind of error and exit with specific error message
record = PicaRecord.new(record)

source = os.getenv("source")

arg=nil
debug.debug=nil
debug.getfenv=getfenv
debug.getregistry=nil
dofile=nil
io={write=io.write}
loadfile=nil
os.execute=nil
os.getenv=nil
os.remove=nil
os.rename=nil
os.tmpname=nil
package.loaded.io=io
package.loaded.package=nil
package=nil
require=dummy

T = loadstring(T,"=input")
if not T then
    error("failed to compile")
else
    T=(function (...) return {select('#',...),...} end)(pcall(T))
    if not T[2] then
        -- TODO: possibly clean up error message
	error(T[3]) --#write(T[3]) E="failed to run" 
    else
	for i=3,T[1]+1 do write(tostring(T[i]),"\t") end
    end
end
