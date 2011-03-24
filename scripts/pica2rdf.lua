require 'pica'

function main(s)
    record = PicaRecord.parse( s )
    local rdf = ""

    rdf = "@prefix dc: <http://purl.org/dc/elements/1.1/> .\n"

    eki = record:first('007G')
    if eki then
        eki = eki['c']..eki['0']
    end
    if (not eki) then
        return "# EKI not found"
    end

    rdf = rdf .. "<info/eki:"..eki..">"

    local stm = { }
      

    table.insert( stm, "  dc:identifier \""..eki.."\"" )

    local bklinks = record:all('045Q')
    for k,f in pairs(bklinks) do
        local bk = f['8']
        _,_,notation = bk:find('(%d%d\.%d%d)')
        if (notation) then
            table.insert( stm, '  dc:subject <http://uri.gbv.de/terminology/bk/'..notation..'>' )
        end
    end

    year = record:first('011@','a')
    if year then
        table.insert( stm, "  dc:date ".."\""..year.."\"" )
    end

    rdf = rdf .. table.concat(stm,"; \n") .. " .\n"

    return rdf
end

