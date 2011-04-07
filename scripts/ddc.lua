require 'pica'

-------------------------------------------------------------------------------
-- This example extracts DDC notations from GBV PICA+ format
-------------------------------------------------------------------------------
function main(record)
    if type(record) == "string" then
        record = PicaRecord.new(record)
    end

    local uris = { }
    local function add_ddc( notation, edition )
        -- here we could further validate ddc notation and edition
        if not notation then return end
        local uri = "http://dewey.info/class/"..notation.."/"
        if edition then
            uri = uri .. "e"..edition.."/"
        end
        table.insert( uris, uri )
    end

    -- 54xx = 045H : DDC-Notation analytisch
    -- Example: 045H $a629.2293
    -- Example: 045H $eDDC22ger$a791.430943$c791.4309$g43$ADNB
    record:all('045H',function(f)
        local edition = f:first('e!',patternfilter("^DDC(%d+)"))
        local notation = f["a!"]
        -- TODO: collect subfield values dfghijklm and create syntetic notations if required
        add_ddc( notation, edition )
    end)

    -- 5010 = 045F : DDC
    -- Example: 045F $a791.430722
    -- Example: 045F $eDDC22$a941.081$a943$ALOC
    record:all('045F',function(f)
        local edition = f:first('e!',patternfilter("^DDC(%d+)"))
        f:all("a",function(notation)
            add_ddc( notation, edition )
        end)
    end)

    -- Note that HEBIS-PICA has other PICA+ tags for DDC (not tested yet). 
    -- SWB uses a subset of GBV format (045F without $e).

    return table.concat( uris, "\n" )
end
