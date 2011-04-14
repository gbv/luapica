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
    assertEquals( tostring(f), "" )

    f = PicaField.new("'021A")
    assert( not f.ok )

    f = PicaField.new('021A')
    assertEquals( f.tag, '021A' )
    assertEquals( f.full, '021A' )
    assertEquals( f.occ, "" )
    assertEquals( f.num, nil )
    assertEquals( f.level, 0 )
    assertEquals( tostring(f), '021A' )

    f = PicaField.new('028C','01')
    assertEquals( f.tag, '028C' )
    assertEquals( f.occ, '01' )
    assertEquals( f.num, 1 )
    assertEquals( f.level, 0 )
    assertEquals( f.full, '028C/01' )
    assertEquals( tostring(f), '028C/01' )

    f = PicaField.new('028C/02' )
    assertEquals( f.full, '028C/02' )

    f = PicaField.new("123X/02 $foo$bar$doz")
    local a,p = {
        {"123X/02$foo$bar$doz"},
        {"123X/02","$foo$bar$doz"},
        {"123X","02","$foo$bar$doz"},
        {"123X","02","f","oo","b","ar","d","oz"},
        {"123X/02","f","oo","b","ar","d","oz"},
    }
    for _,p in ipairs(a) do
        local g = PicaField.new( unpack(p) )
        assertEquals( tostring(g), tostring(f) )
    end

    f = PicaField.new('012Z','00')
    assertEquals( f.tag, '012Z' )
    assertEquals( f.occ, '00' )
    assertEquals( f.num, 0 )
    assertEquals( f.level, 0 )
    assertEquals( f.full, '012Z/00' )
end

function TestField:testAppend()
    local f,v = PicaField.new()

    for _,v in ipairs({'$.x','$','x','_$xa','x$xa','xy'}) do
        assertError( f.append, f, x )
    end
    assertEquals( tostring(f), "" )
    assertEquals(f[1],nil)

    f:append( "a", "foo" )
    assertEquals( tostring(f), '$afoo' )

    local v = f:values('a')
    assertEquals( v , 'foo' )

    v = f:first('b')
    assertEquals( v , nil )

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

    f = PicaField.new("021A"):append("$foo"):append("$bar")
    assertEquals( tostring(f), "021A $foo$bar" )
end

function TestField:testGet()
    local f,v,l

    -- get list of all values
    f = PicaField.new()
    v = f:get()
    assertEquals( #v, 0 )
    f:append('a','foo','0','bar')
    v = f:get()
    assertEquals( #v, 2 )
    assertEquals( v[1], "foo" )
    assertEquals( v[2], "bar" )
    assertEquals( v.a, nil )

    assertEquals( f[1], "foo" )
    assertEquals( f[2], "bar" )        
    assertEquals( f.a, "foo" )
    assertEquals( f._0, "bar" ) -- numeric subfield code

    -- get first of existing
    assertEquals( f["a"], "foo" )
    assertEquals( f["a_"], "foo" )
    assertEquals( f["a*"], "foo" )
    assertEquals( f["a?"], "foo" )
    assertEquals( f["a!"], "foo" )
    assertEquals( f["a+"], "foo" )

    -- get first of non-existing
    assertEquals( f["y"], nil )
    assertEquals( f["y?"], nil )
    assertEquals( f["y*"], nil )
    assertEquals( f["y!"], nil )
    assertEquals( f["y+"], nil )
    assertEquals( f["y_"], "" )
    assertEquals( f["y?_"], "" )
    assertEquals( f["y*_"], "" )
    assertEquals( f["y!_"], "" )
    assertEquals( f["y+_"], "" )

    assertEquals( f.y, nil )
    assertEquals( f.y_, "" )

    -- get repeated field
    f:append("0","doz")
    local t = {
        ["0"] = {"bar",nil},
        ["0_"] = {"bar",nil},
        ["0?"] = {"bar",nil},
        ["0?_"] = {"bar",nil},
        ["0*"] = {"bar","doz"},
        ["0*_"] = {"bar","doz"},
        ["0+"] = {"bar","doz"},
        ["0+_"] = {"bar","doz"},
        ["0!"] = {nil,nil},
        ["0!_"] = {"",nil},
    }
    local q,r
    for q,r in pairs(t) do
        local a,b = f:first(q) -- f[q] would only return one value!
        assertEquals( a, r[1] ); 
        assertEquals( b, r[2] );
    end
end

function TestField:testPairs()
    local f,c,v = PicaField.new("123Q $afoo$xbar$adoz$0baz")
    local i,t = 1,{"a","foo","x","bar","a","doz","0","baz"}
    for c,v in f:pairs() do
        assert( c == t[i] and v == t[i+1] )
        i = i+2
    end
    for i,v in f:ipairs() do
        assert( v == t[2*i] )
    end
end

function TestField:testHas()
    local f = PicaField.new()
    assert( not f.x )
    f:append('1','foo')
    f:append('x','bar')
    assert( f.x )

    -- TODO: required?
    assert( f:get(1) )
    --assertEquals( f:has(1), true )
end

function TestField:testLen()
    local f = PicaField.new()
    assertEquals( #f, 0 )

    f:append( 'x','abc')
    assertEquals( #f, 1 )
   
    f:append( '1','x')
    assertEquals( #f, 2 )
end

function TestField:testCopy()
    local e,f
    
    -- full copy
    for _,f in ipairs({"018A","123@/03","212I $xy$zw"}) do
        f = PicaField.new(f)
        local s = tostring(f)
        e = f:copy()
        f:append("$foo") -- modify original
        assertEquals( tostring(e), s )
    end

    f = PicaField.new("123A $foo$bar$doz")
    assertEquals( tostring(f:copy("234@")), "234@ $foo$bar$doz" )
    assertEquals( tostring(f:copy("234@","fxz")), "234@ $foo" )
    assertEquals( tostring(f:copy("234@","d-f")), "234@ $foo$doz" )
    assertEquals( tostring(f:copy("")), "$foo$bar$doz" )
    assertEquals( tostring(f:copy("b")), "123A $bar" )
    assertEquals( tostring(f:copy("^b")), "123A $foo$doz" )

    assertError( PicaField.copy, f, "." )
end



function TestField:testFilter()
    local f = PicaField.new('028A $dg1$dg2$ffoo')
    assertEquals( f:first('f'), "foo" )

    assertEquals( f:first('f',formatfilter("")), nil )
    --assertEquals( f:first('f',formatfilter("foo")), "foo" )

    assertEquals( f:first('f',formatfilter("(%s)")), "(foo)" )
    assertEquals( f:first('f',formatfilter("x")), "x" )
    assertEquals( f:first('g',formatfilter("x")), nil )
    assertEquals( f:first('g_',formatfilter("x")), "" )
end

function TestField:testMap()
    local f = PicaField.new('028A $dg1$dg2$ffoo')

    local m = f:get("f")
    assertEquals( m[1], "foo" )

--[[TODO
    local m,e = f:collect("d","f","x")
    assertEquals( e, nil )
    assertEquals( #m, 2 )

    m,e = f:collect("d*","f","x!")
    assertEquals( #m, 3 )
    assertEquals( type(e), "table" )
--]]
end

function TestField:testCodes()
    local f = PicaField.new('123A $xfoo$ybar$xdoz')
    local a,b,c,d = unpack(f:codes())
    assert( a == 'x' and b == 'y' and c == 'x' and d == nil )
    a = PicaField.new():codes()
    assert( type(a) == "table" and #a == 0 )
end

function TestField:testOkAndEmpty()
    local f = PicaField.new()
    assertEquals( f.ok, false )
    assertEquals( f.level, nil )
    assertEquals( f.num, nil )

    f:append( 'x','abc')
    assertEquals( f.ok, false )
    assertEquals( #f, 1 )

    f = PicaField.new('123A')
    assertEquals( f.ok, false )
    assertEquals( #f, 0 )
    assertEquals( f.level, 1 )
    assertEquals( f.num, nil )

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
    assertError( function() f.level = 2 end )    
    assertError( function() f.ok = true end )    
end
