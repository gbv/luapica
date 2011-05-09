require "luaunit"
require "pica"

TestRecord = {}

function TestRecord:loadRecord( n )
    local filename = "test/data/"..n..".pica"
    local file = assert(io.open(filename,"r"))
    local record = PicaRecord.new( file:read('*all') )
    return record
end

function TestRecord:testNew()
    local f,r = nil,PicaRecord.new()
    
    r = PicaRecord.new("028A $dgiven1$dgiven2$asur$$name\n028C/01 $0foo")

    f = r:first("028A")
    assertEquals( f.tag, "028A" )
    assertEquals( r[1], f ) -- get by position

    f = r:first("029A")
    assertEquals( f.tag, '' )

    f = r["028A"] -- get first field
    assertEquals( f.tag, "028A" )
    assertEquals( f.num, nil )
    assertEquals( f.level, 0 )

    f = r:first("028C/01")
    assertEquals( f.tag, "028C" )
    assertEquals( f.occ, "01" )
    assertEquals( f.num, 1 )

    f = r["028C/01"]
    assertEquals( f.tag, "028C" )

    -- any occurence (required)
    f = r["028C/xx"]
    assertEquals( f.tag, "028C" )

    -- optional any occurence
    f = r["028C"]
    assertEquals( f.tag, "028C" )

    -- no occurrence
    f = r["028C/"]
    assertEquals( f.tag, "" )

    f = r["028A/"]
    assertEquals( f.tag, "028A" )

    f = r["028C/00"]
    assertEquals( f.tag, "" )
   
    r:append("028C/00 $foo$bar")
    f = r["028C/00"]
    assertEquals( f.full, "028C/00" )

end

function TestRecord:testAll()
    local r = PicaRecord.new("028A $dgiven1$dgiven2$asur$$name\n028C/01 $0foo")
    local f = r['028A']
    
    --print(dump( f:all('d') ))
    --print(dump( r:all('028A','d') ))
end

function TestRecord:testFirst()
    local record,f = self:loadRecord('book1')

    -- get first field

    f = record:first('041A')
    assertEquals( f['9'], '105543004' )

    f = record:first('041A/09')
    assert( not f['9'] )
    assertEquals( f.A, 'DE-101' )

    for _i,loc in ipairs({'041A/xx','041A/xx|123A','123A|041A/xx'}) do
        f = record:first(loc)
        assertEquals( f['9'], '106369393' )
    end

end

function TestRecord:testAll()
    local record,f = self:loadRecord('book1')

    -- without subfield
    f = record:all('041A')
    assertEquals( #f, 6 )

    f = record:all('041A/xx')
    assertEquals( #f, 5 )

    -- TODO: get 041A with occ < 9

    -- with subfield

    f = record:all('041A','8')
    assertEquals( #f, 5 )

    f = record:all('041A/02','9')
    assertEquals( #f, 1 )
    assertEquals( f[1], '510428258' )

    f = record:all('041A/XX','9')
    assertEquals( #f, 4 )

    f = record:all('041A/','8')
    assertEquals( #f, 1 )

    f = record:all('003@|041A')
    assertEquals( #f, 7 )

    f = record:all('003@$0|006L$0')
    assertEquals( #f, 2 )

    f = record:all('003@|006L','0')
    assertEquals( #f, 2 )
end

function TestRecord:testFilter()
    local record = self:loadRecord('book1')

    -- print all matching subfields
    -- record:all('041A','8',{each=print})
    assertEquals( #record:all('041A','8',{find='41'}), 2 )

    assertEquals( #record:all('041A','8',{find='%d%d'}), 5 )
    assertEquals( #record:all('041A','8',function() return true end), 5 )
    assertEquals( #record:all('041A','8',function() return false end), 0 )
    assertEquals( #record:all('041A','8',function() return 1 end), 0 )

    local f = function() return "x" end

    local list = record:all( '041A', '8', f )
    assertEquals( list[1], "x" )

    list = record:all( '041A', '8',{find='(%d%d)'} )
    assertEquals( list[1], "41" )

    --- filter fields
    assertEquals( #record:all( function(f) return f.tag == "041A" end), 6 )
    assertEquals( #record:all( function(f) return f['8'] end ), 8 )

    r = record:all( '041A', function(f) return f.S == 's' end )

    assertEquals( #record:all( '041A', function(f) return f.S == 's' end ), 5 )
    assertEquals( #record:all( '041A', function(f) return f['8_']:find('41') end ), 2 )

    -- get field and filter it
    t = record:first('007G'):map({'c','0'})
    assertEquals( table.concat( t, '' ), 'DNB1009068466' )


    t = record:all('045Q','8',{find='(%d%d\.%d%d)'})
    assertEquals( #t, 2 )

    t = ""
    r = PicaRecord.new("006G $0850158583")
    r:all( '006G','0',{format="http://d-nb.info/%s",each=function(s) t = s end})
    assertEquals( t, "http://d-nb.info/850158583" )

    t = r:get( '006G','0',{format="http://d-nb.info/%s"})
    assertEquals( t,  "http://d-nb.info/850158583" )

    t = r:map{ DNB = {'006G','0',{format="http://d-nb.info/%s"}} }
    assertEquals( t.DNB, "http://d-nb.info/850158583" )

end

function TestRecord:testLocator()
    local r = PicaRecord.new()
    -- illformed locators
    local locators = {"|","123A$","|123A","123A/x","123A/1","123A/123","123A$x|003@"}
    for _,loc in ipairs(locators) do
        assertError( PicaRecord.all, r, loc )
        assertError( PicaRecord.first, r, loc )
    end
    assertError( PicaRecord.all, r, "123@$x", "x" )
    -- valid locators
    locators = {"123A/$x"," 001@","042Z| 045Y","124B$x|003@  $y"}
    for _,loc in ipairs(locators) do
        assert( r:all(loc) )
        assert( r:first(loc) )
    end

    -- locators with field and subfield
    r = self:loadRecord('book1')
    assertEquals( r["033A $p"], 'Aachen' )
    assertEquals( r:first("033A$p"), 'Aachen' )
end 

function TestRecord:testGet()
    local r,f,err = self:loadRecord('book1')

    assertError( PicaRecord.get, record, {} )

    -- FIXME: stack overflow:
    -- t = r:get('!008G') (!,? but not +,*)
--[[
    local eki = 'DNB1009068466';
    local t = table.concat( r:first('008G'):map{'c','0'}, '' )
-- FIXME: stack overflow:
    --t = r:get('!008G')

    t,err = r:map{
        -- create string from field
        eki = {"007G","$",function(f) return table.concat(f:map{'c','0'},'') end},
        foo = function(r) error("bad") end,
    }
print"---------------\n"
local f = function() end
local x,y,z = PicaRecord.parse_field_locator('007G',f)
print(dump( {x,y,z} ))

    assertEquals( t.eki, eki )
  --  assertEquals( t.eki2, '')
    assert(err.foo)
--]]
end

function TestRecord:testMap()
    local record = self:loadRecord('book1')

     -- easy conversion from PICA+ to key-value structures
    local dcrecord, errors = record:map { 
        title    = {'!021A','a'},     -- must be exactely one value
        subject  = {'*041A','8'},   -- optional any number of values
        language = {'010@$a'},      -- first matching value, if any    
        rtype    = '?002@$0'
    }

    assertEquals( errors, nil )
    assertEquals( dcrecord.title, 
      'Gleichspannungswandler hoher Leistungsdichte im Antriebsstrang von Kraftfahrzeugen' )
    assertEquals( dcrecord.language, 'ger' )
    assertEquals( #dcrecord.subject, 5 )
    assertEquals( dcrecord.rtype, 'Aaua' )

    dcrecord, errors = record:map {
        a = {'041A','9'},
        b = {'041A/xx','9'},
        c = {'+041A','9'},
        d = {'*041A','9'},
        e = {'*041A/','9'},
        d = {'*041A','9'},
        f = '?041A',
        x = {'123A','9'},
        y = {'!041A','8'},
        z = {'+123A','9'},
    }

    assertEquals( dcrecord.a, '105543004' )
    assertEquals( dcrecord.b, '106369393' )
    assertEquals( #dcrecord.c, 5 )
    assertEquals( #dcrecord.d, 5 )
    assertEquals( #dcrecord.e, 1 )

    assertEquals( dcrecord.x, nil )
    assertEquals( dcrecord.y, 'Elektrofahrzeug ; SWD-ID: 41517957' )
    assertEquals( dcrecord.z, nil )

    assertEquals( errors.f, 'got 6 values instead of at most one' )
    assertEquals( errors.x, nil )
    assertEquals( errors.y, 'got 5 values instead of one' )
    assertEquals( errors.z, 'not found' )
  
end
