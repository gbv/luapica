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

    f = PicaField.new("'021A")
    assert( not f.ok )

    f = PicaField.new('021A')
    assertEquals( f.tag, '021A' )
    assertEquals( f.full, '021A' )
    assertEquals( tostring(f), '021A' )

    f = PicaField.new('028C','01')
    assertEquals( f.tag, '028C' )
    assertEquals( f.occ, '01' )
    assertEquals( f.num, 1 )
    assertEquals( f.lev, 0 )
    assertEquals( f.full, '028C/01' )
    assertEquals( tostring(f), '028C/01' )

    f = PicaField.new('028C/02' )
    assertEquals( f.full, '028C/02' )
end

function TestField:testAppend()
    local f,v = PicaField.new()

    for _,v in ipairs({'$.x','$','x','_$xa','x$xa','xy'}) do
        assertError( f.append, f, x )
    end
    assertEquals( tostring(f), '' )

    f:append( "a", "foo" )
    assertEquals( tostring(f), '$afoo' )

    local v = f:values('a')
    assertEquals( v , 'foo' )

    v = f:first('b')
    assertEquals( v , '' )

    f:append( "b", "$" )
    assertEquals( tostring(f), '$afoo$b$$' )

    f:append( "a", "bar" )
    assertEquals( tostring(f), '$afoo$b$$$abar' )
    
    local a,b,c = f:values('a')
    assertEquals( a , 'foo' )
    assertEquals( b , 'bar' )
    assertEquals( c , nil )

    v = f:first('b')
    assertEquals( v , '$' )

    -- short syntax
    assertEquals( f['b'] , '$' )
    assertEquals( f['a'] , 'foo' )

    assertEquals( f.b , '$' )
    f:append( "1", "zz" )

    assertEquals( f['1'] , 'zz' )
    assertEquals( f[1] , 'foo' )
    assertEquals( f[2] , '$' )

end

function TestField:testGet()
    local f,v,l

    -- get list of all values
    f = PicaField.new()
    v = f:get()
    assertEquals( #v, 0 )
    f:append('a','foo','x','bar')
    v = f:get()
    assertEquals( #v, 2 )
    assertEquals( v.a, nil )
    assertEquals( v[1], "foo" )

    -- get first
    assertEquals( f["a"], "foo" )
    assertEquals( f["a*"], "foo" )
    assertEquals( f["a?"], "foo" )
    assertEquals( f["a!"], "foo" )
    assertEquals( f["a+"], "foo" )

    assertEquals( f["y"], "" )
    assertEquals( f["y*"], "" )
    assertEquals( f["y?"], "" )
    assertEquals( f["y!"], nil )
    assertEquals( f["y+"], nil )

    f:append('a','bar')
    local a,b = f["a"]
    assertEquals( a, "foo" ); assertEquals( b, nil )
    a,b = f["a?"]
    assertEquals( a, "foo" ); assertEquals( b, nil )
    a,b = f["a!"]
    assertEquals( a, nil ); assertEquals( b, nil )
    a,b = f["a*"]
    --assertEquals( a, "foo" ); assertEquals( b, "bar" )
    --a,b = f["a+"]
    --assertEquals( a, "foo" ); assertEquals( b, "bar" )
end

function TestField:testHas()
    local f = PicaField.new()
    assertEquals( f:has("x"), false )
    assertEquals( f % "x", false )
    f:append('a','foo')
    f:append('x','bar')
    assertEquals( f:has("x"), true )
    assertEquals( f % "x", true )
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

function TestField:testFilter()
    local f = PicaField.new('028A $dg1$dg2$ffoo')
    assertEquals( f:first('f',formatfilter("(%s)")), "(foo)" )
    assertEquals( f:first('f',formatfilter("")), "" )
    assertEquals( f:first('f',formatfilter("x")), "x" )
    assertEquals( f:first('g',formatfilter("x")), "" )
end

function TestField:testMap()
    local f = PicaField.new('028A $dg1$dg2$ffoo')

    local m = f:get("f")
    assertEquals( m[1], "foo" )

    local m,e = f:collect("d","f","x")
    assertEquals( e, nil )
    assertEquals( #m, 2 )

    m,e = f:collect("d*","f","x!")
    assertEquals( #m, 3 )
    assertEquals( type(e), "table" )
end

function TestField:codes()
    local f = PicaField.new('123A $xfoo$ybar$xdoz')
    local a,b,c,d = f:codes()
    assert( a == 'x' and b == 'y' and c == 'x' and d == nil )
end

function TestField:testOkAndEmpty()
    local f = PicaField.new()
    assertEquals( f.ok, false )
    assertEquals( f.lev, 0 ) -- default level
    assertEquals( f.num, 0 ) -- default occurrence number

    f:append( 'x','abc')
    assertEquals( f.ok, false )
    assertEquals( #f, 1 )

    f = PicaField.new('123A')
    assertEquals( f.ok, false )
    assertEquals( #f, 0 )
    assertEquals( f.lev, 1 )
    assertEquals( f.num, 0 )

    f:append( 'x','abc')
    assertEquals( f.ok, true )
    assertEquals( #f, 1 )
end

function TestField:testParsing()

    local fields = { 
        ['028A $dgiven1$dgiven2$asur$$name'] = {'028A',''}
    }
    --fields['028A $dgiven1$dgiven2$asurname'] = {'028A',''}
    
    for line,full in pairs(fields) do
        local field = PicaField.new(line)

        assertEquals( field.tag, full[1] )
        assertEquals( field.occ, full[2] )
        assertEquals( tostring(field), line )
    end

end

function TestField:testReadonly()
    local f = PicaField.new("123A")
    assertError( function() f.tag = "x" end )    
    assertError( function() f.tag = "123A" end )    
    assertError( function() f.occ = "02" end )    
    assertError( function() f.num = 2 end )    
    assertError( function() f.full = "123X/02" end )    
end
