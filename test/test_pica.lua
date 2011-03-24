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

    f = PicaField.new('028C/02' )
    assertEquals( f:fulltag(), '028C/02' )
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

    assertEquals( f.b , '$' )
    f:append( "1", "zz" )

    assertEquals( f['1'] , 'zz' )
    assertEquals( f[1] , 'foo' )

end

function TestField:testLen()
    local f = PicaField.new()
    assertEquals( #f, 0 )

    f:append( 'x','abc')
    assertEquals( #f, 1 )
   
    f:append( '1','x')
    assertEquals( #f, 2 )
end

function TestField:testIter()
    local f = PicaField.new()
    local list = {
        {"x","abc"},
        {"z","xx"},
        {"0","1"},
        {"z","yy"}
    }
    local k,v
    for k,v in ipairs(list) do
        f:append( v[1], v[2] )
    end
    for k,v in ipairs(f) do
        assertEquals( v, list[k][2] )
    end

    --[[
  --iterate with pairs over subfield (key/value)
    --for k,v in pairs(f.subfields) do
-- .sf shoul returns an iterator over code/value pairs
-- .val(...)
-- .first(...)
-- .iter / .all / .sf ( function(code,value) end ) 
    for k,v in f.iter() do
        print(k,".",v,"\n")
    end
    --]]
end

function TestField:testOk()
    local f = PicaField.new()
    f:append( 'x','abc')
    assertEquals( f.ok, false )

    f = PicaField.new('123A')
    assertEquals( f.ok, false )

    f:append( 'x','abc')
    assertEquals( f.ok, true )
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
    local f,r = nil,PicaRecord.new()
    
    r = PicaRecord.parse("028A $dgiven1$dgiven2$asur$$name\n028C/01 $0foo")

    f = r:first("028A")
    assertEquals( f.tag, "028A" )
    assertEquals( r[1], f ) -- get by position

    f = r:first("029A")
    assertEquals( f.tag, '' )

    f = r["028A"] -- get first field
    assertEquals( f.tag, "028A" )

    f = r:first("028C/01")
    assertEquals( f.tag, "028C" )
    assertEquals( f.occ, "01" )

    f = r["028C/01"]
    assertEquals( f.tag, "028C" )

    -- any occurence (required)
    f = r["028C/00"]
    assertEquals( f.tag, "028C" )

    -- optional any occurence
    f = r["028C"]
    assertEquals( f.tag, "028C" )

    -- no occurrence
    f = r["028C/"]
    assertEquals( f.tag, "" )

    f = r["028A/"]
    assertEquals( f.tag, "028A" )
end

function TestRecord:testAll()
    local r = PicaRecord.parse("028A $dgiven1$dgiven2$asur$$name\n028C/01 $0foo")
    local f = r['028A']
    
    --print(dump( f:all('d') ))
    --print(dump( r:all('028A','d') ))
end