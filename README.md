# luapica

> Lua library to handle PICA+ data

## Installation

Copy the contents of the 'lib' directory (at least 'pica.lua') into a location on your LUA_PATH.

## Synopsis

The following script ('example.lua') shows how to use the library:

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

    -- filter and transform subfield values with filters
    notations = record:all('045Q','8', {find = '(%d%d\.%d%d)'} )

    -- filter and transform subfield value
    f = record:first('028A')
    nametype = f[ { 'f', format="(%s)" } ]

    print( f:join(' ',     -- join selected subfields, separated by space
      {'e','d','a','5',     -- collect these subfields (if given) in this order
       { 'f', format='(%s)' } }) ) -- also with filters

For a more detailed tutorial have a look at the project wiki at
  https://github.com/gbv/luapica/wiki

## Examples

The file 'lib/picaconv.lua' contains a command line script to convert
PICA+ records. The first command line argument must be a concrete lua 
conversion script somewhere where lua can find it. The shell script 
'picaconv' sets the LUA_PATH variable for this purpose, so you can you
use all conversion scripts in the 'scripts' directory like this:

    $ picaconv <script> <picafile>

## API Documentation

For convenience the branch 'gh-pages' contains automatically generated
documentation, that is published at http://gbv.github.com/luapica

The API documentation is generated with LuaDoc. However, LuaDoc has
not been updated since years. I added some patches, so you get get a
fixed version of LuaDoc at https://github.com/gbv/luadoc.

    $ git clone git://github.com/gbv/luadoc.git
    $ cd luadoc
    $ make install

You can then generate documentation with:

    $ make doc 

## Feedback and updates

Please visit <https://github.com/gbv/luapica>.

