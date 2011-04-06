require "luaunit"
require "pica"

TestRecords = {}

function TestRecords:loadRecord( n )
    local filename = "test/data/test"..n..".pica"
    local file = assert(io.open(filename,"r"))
    local record = PicaRecord.new( file:read('*all') )
    return record
end

function TestRecords:testFirst()
    local record,f = self:loadRecord('01')

    -- get first field

    f = record:first('041A')
    assertEquals( f['9'], '105543004' )

    f = record:first('041A/09')
    assertEquals( f['9'], '' )
    assertEquals( f.A, 'DE-101' )

    for _i,loc in ipairs({'041A/00','041A/00|123A','123A|041A/00'}) do
        f = record:first(loc)
        assertEquals( f['9'], '106369393' )
    end

end

function TestRecords:testAll()
    local record,f = self:loadRecord('01')

    -- without subfield
    f = record:all('041A')
    assertEquals( #f, 6 )

    f = record:all('041A/00')
    assertEquals( #f, 5 )

    -- TODO: get 041A with occ < 9

    -- with subfield

    f = record:all('041A','8')
    assertEquals( #f, 5 )

    f = record:all('041A/02','9')
    assertEquals( #f, 1 )
    assertEquals( f[1], '510428258' )

    f = record:all('041A/00','9')
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

function TestRecords:testFilter()
    local record = self:loadRecord('01')

    assertEquals( #record:all('041A','8',patternfilter('41')), 2 )
    assertEquals( #record:all('041A','8',patternfilter('%d%d')), 5 )
    assertEquals( #record:all('041A','8',function() return true end), 5 )
    assertEquals( #record:all('041A','8',function() return false end), 0 )
    assertEquals( #record:all('041A','8',function() return 1 end), 0 )

    local list = record:all( '041A', '8', function() return "x" end )
    assertEquals( list[1], "x" )

    list = record:all( '041A', '8', patternfilter('(%d%d)') )
    assertEquals( list[1], "41" )

    --- filter fields
    assertEquals( #record:filter( function(f) return f.tag == "041A" end), 6 )
    assertEquals( #record:filter( function(f) return f['8'] ~= '' end ), 8 )
    assertEquals( #record:filter( '041A', function(f) return f.S == 's' end ), 5 )
    assertEquals( #record:filter( '041A', function(f) return f['8']:find('41') end ), 2 )

    -- get field and filter it
    assertEquals( record:first('007G'):join('','c','0'), 'DNB1009068466' )
end

function TestRecords:testLocator()
    local r = PicaRecord.new()
    local locators = {"|","123A$","|123A","123A/x","123A/1","123A/123","123A$x|003@"}
    for _,loc in ipairs(locators) do
        assertError( PicaRecord.all, r, loc )
        assertError( PicaRecord.first, r, loc )
    end
    assertError( PicaRecord.all, r, "123@$x", "x" )
    locators = {"123A/$x","001@","042Z|045Y","124B$x|003@$y"}
    for _,loc in ipairs(locators) do
        assert( r:all(loc) )
        assert( r:first(loc) )
    end
end 

function TestRecords:testGet()
    local record,f = self:loadRecord('01')

    assertError( PicaRecord.get, record, {} )
end

function TestRecords:testMap()
    local record = self:loadRecord('01')

     -- easy conversion from PICA+ to key-value structures
    local dcrecord, errors = record:map { 
        title = {'!021A','a'},     -- must be exactely one value
        subject = {'*041A','8'},   -- optional any number of values
        language = {'010@','a'}    -- first matching value, if any    
    }

    assertEquals( errors, nil )
    assertEquals( dcrecord.title, 
      'Gleichspannungswandler hoher Leistungsdichte im Antriebsstrang von Kraftfahrzeugen' )
    assertEquals( dcrecord.language, 'ger' )
    assertEquals( #dcrecord.subject, 5 )
   
    dcrecord, errors = record:map {
        a = {'041A','9'},
        b = {'041A/00','9'},
        c = {'+041A','9'},
        d = {'*041A','9'},
        e = {'*041A/','9'},
        d = {'*041A','9'},
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

    assertEquals( errors.x, nil )
    assertEquals( errors.y, 'got 5 values instead of one' )
    assertEquals( errors.z, 'not found' )
  
end
