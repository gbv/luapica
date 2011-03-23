require "luaunit"
require "pica"

-- useful dumper method
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end


TestField = {}

function TestField:testNew()
    local f = PicaField.new()
    assertEquals( tostring(f), '' )

    f = PicaField.new('021A')
    assertEquals( f.tag, '021A' )
    assertEquals( f:fulltag(), '021A' )
    assertEquals( tostring(f), '021A' )

    f = PicaField.new('028C','01')
    assertEquals( f.tag, '028C' )
    assertEquals( f.occ, '01' )
    assertEquals( f:fulltag(), '028C/01' )
    assertEquals( tostring(f), '028C/01' )
end

function TestField:testAppend()
    local f = PicaField.new()

    f:append( "a", "foo" )
    assertEquals( tostring(f), '$afoo' )

    -- print(dump(f:values('a')))
    local v = f:values('a')
    assertEquals( #v , 1 )
    assertEquals( v[1] , 'foo' )

    v = f:first('b')
    assertEquals( v , '' )

    f:append( "b", "$" )
    assertEquals( tostring(f), '$afoo$b$$' )

    f:append( "a", "bar" )
    assertEquals( tostring(f), '$afoo$b$$$abar' )
    
    v = f:values('a')
    assertEquals( #v , 2 )
    assertEquals( v[1] , 'foo' )
    assertEquals( v[2] , 'bar' )

    v = f:first('b')
    assertEquals( v , '$' )

    -- short syntax
    assertEquals( f['b'] , '$' )
    assertEquals( f['a'] , 'foo' )
end


function TestField:testParsing()

    local fields = { 
        ['028A $dgiven1$dgiven2$asur$$name'] = {'028A',''}
    }
    --fields['028A $dgiven1$dgiven2$asurname'] = {'028A',''}
    
    for line,fulltag in pairs(fields) do
        local field = PicaField.parse(line)

        assertEquals( field.tag, fulltag[1] )
        assertEquals( field.occ, fulltag[2] )
        assertEquals( tostring(field), line )
    end

end


TestRecord = {}

function TestRecord:testNew()
    local r = PicaRecord.new()
    
    r = PicaRecord.parse("028A $dgiven1$dgiven2$asur$$name\n028C/01 $0foo")

    local f = r:first("028A")
    assertEquals( f.tag, "028A" )

    local f = r:first("029A")
    assertEquals( f, nil )

end
