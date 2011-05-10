#!/usr/bin/env lua
-------------------------------------------------------------------------------
-- Convert PICA+ records using a lua script
-------------------------------------------------------------------------------

local function print_help ()
    print ("Usage: "..arg[0]..[[ script [options|files]

Convert PICA+ records with a lua script. The lua script must define a 'main'
function that gets a chunk of PICA+ data for each record and returns a string.
Use '-' as script to just print back the read records.
]])
end

function convert_file(file,main)
    local line = ""
    repeat
        local record = ""
        while true do
            line = file:read()
            if line == nil or line == "" then 
                break 
            else
                record = record.."\n"..line
            end
        end
        if record ~= "" then
            local result = main(record)
            print(result.."\n")
        end
    until line == nil
end

if #arg < 1 then
    print_help()
else
    local script = arg[1]
    if script == '-' then
        function main(s) return s end
    else
        require(script)
    end
    if #arg > 1 then
        for i = 2, #arg do
            local filename = arg[i]
            local file = assert(io.open(filename,"r"))
            convert_file(file,main)
        end
    else
        convert_file(io.stdin,main)
    end
end
