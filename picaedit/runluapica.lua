
local T,E = io.read("*all")
io.flush()

local write = io.write
local dummy = function(...) return nil end

require "pica"
record = os.getenv("record")

-- TODO: catch parsing error and exit with specific error message
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

if T:match('function%s+main%s*%(') then
   T = T .. "\nreturn main(record,source)"
end

T,E = loadstring(T,"=i")
if not T then
    error(E:sub(3)) -- compilation failed
else
    T=(function (...) return {select('#',...),...} end)(pcall(T))
    if not T[2] then
	error(T[3]) -- runtime error 
    else
	for i=3,T[1]+1 do write(tostring(T[i]),"\t") end
    end
end
