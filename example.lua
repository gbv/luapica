
    require 'pica'

    r = io.read("*all")           -- read from standard input
    record = PicaRecord.new( r )  -- parses a PICA+ record

    -- get the first matching field
    f = record:first('007G')      -- alternatively: record["007G"]
    if f.ok then                  -- check whether not empty and valid tag
        print( f.tag )            -- get field's tag ('007G')
        print( f.occ )            -- get field's occurrence
        print( f.full )           -- get field's tag and occurrence combined
        print( f['c']..f['0'] )   -- get subfield values (or '')
        print( f.c )              -- short for f['c']
    end

    -- directly get a subfield value (or the empty string)
    year = record:first('001@','a')

    -- easy conversion from PICA+ to key-value structures
    dcrecord, errors = record:map { 
        title = {'!021A','a'},     -- must be exactely one value
        subject = {'*041A','8'},   -- optional any number of values
        language = {'010@','a'}    -- first matching value, if any    
    }

    -- use fields locators and custom filters to select fields
    gndfields = record:all('041A', function(f) return f.S == 's' end )

    -- filter and transform subfield values with filters, e.g. 'patternfilter'
    notations = record:all('045Q','8', patternfilter('(%d%d\.%d%d)') )

    -- filter and transform subfield value with 'formatfilter'
    f = record:first('028A')
    nametype = f:first('f',formatfilter("(%s)"))

    print( f:join(' ',     -- join selected subfields, separated by space
      {'e','d','a','5',     -- collect these subfields (if given) in this order
       { 'f', formatfilter('(%s)') } }) ) -- also with filters
