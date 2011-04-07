-----------------------------------------------------------------------------
-- Handle PICA+ data in Lua.
-- This module provides two classes (<a href="#PicaField">PicaField</a> and
-- <a href="#PicaRecord">PicaRecord</a>) for PICA+ data. The programming 
-- interface of these classes is optimized for easy access and conversion
-- of PICA+ records. Have a look at the file 'example.lua' for a synopsis.
-- 
-- @author Jakob Voss <voss@gbv.de>
-- @class module
-- @name pica
-- @see PicaField
-- @see PicaRecord
-----------------------------------------------------------------------------

-- this may increase performance
local string, table = string, table

--- Returns a filter function based on a Lua pattern.
-- The returned filter function removes all values that do not match the
-- pattern. If the pattern contains a capture expression, each value is
-- replaced by the first captured value.
-- @param pattern a
--   <a href="http://www.lua.org/manual/5.1/manual.html#5.4.1">pattern</a>
-- @usage check digit: <tt>record:find(tag,sf,patternfilter('%d'))</tt> 
-- @usage extract digit: <tt>record:find(tag,sf,patternfilter('(%d)'))</tt>
patternfilter = function( pattern )
    assert( type(pattern) == "string", "pattern must be string, got "..type(pattern) )
    return function( value )
        local start,_,capture = value:find(pattern)
        if not start then
            return false
        elseif capture then
            return capture
        else
            return value
        end
    end
end

--- Returns a filter function based on a Lua string format.
-- @param format as specified for
--   <a href="http://www.lua.org/manual/5.1/manual.html#5.4">string.format</a>
-- @usage <tt>field:first('a',formatfilter('a is: %s'))</tt>
formatfilter = function( format )
    assert( type(format) == "string", "format must be string, got "..type(format) )
    return function( value )
        return format:format( value )
    end
end

--- Insert all values with integer keys from one table to another.
-- @param t the table to modify
-- @param a the table to concat to table a
table.append = function( t, a )
    local v
    for _,v in ipairs(a) do
        table.insert( t, v )
    end
end

--- Returns a string or nil if the string is empty
string.notempty = function(self)
    return #self == 0 and nil or self
end

-----------------------------------------------------------------------------
--- Simply returns a value, optionally filtered by one or more functions.
-- If a filter function returns true, the original value is returned.
-- If a filter function returns no string or the empty string, nil is returned.
local function filtervalue( value, ... )
    local filter
    for _,filter in ipairs(arg) do
        local v = filter(value)
        if type(v) == "string" then
            if v == "" then 
                return
            end
            value = v
        elseif not v or type(v) ~= "boolean" then
            return
        end
    end
    return value
end

-----------------------------------------------------------------------------
--- Stores an ordered list of PICA+ subfields.
-- This class overloads the following operators: 
-- <ul>
--   <li><tt>#f</tt> returns the number of subfields.</li>
--   <li><tt>f % l</tt> returns whether locator <tt>l</tt> applies to field 
--       <tt>f</tt> (see <a href="#PicaField:has">PicaField:has</a>).
-- </ul>
-- @field n (number) the <i>n</i>th subfield value or <tt>nil</tt>
-- @field c (string) the <i>first</i> subfield value of a subfield with code
--   <i>c</i> where <i>c</i> can be a letter (<tt>a-z</tt> or <tt>A-Z</tt>) 
--   or a digit (<tt>0-9</tt>). An empty string is returned if no such 
--   subfields exists (see <a href="#PicaField:has">PicaField:first</a>).
-- @field ok (boolean) whether the field has a tag and is not empty
-- @field tag (string) the tag without occurrence
-- @field full (string) tag and occurrence combined
-- @field occ (string) the occurrence as string
-- @field num (number) the occurrence as number between 0 and 99
-- @field lev (number) level 0, 1, or 2 (default is 0)
-- @class table
-- @name PicaField
-----------------------------------------------------------------------------
PicaField = {

    -- field % locator
    __mod = function( field, locator )
        return field:has( locator )
    end,

    -- field[ key ]  
    -- field.key
    __index = function( field, key )
        if ( type(key) == 'number' ) then -- n'th value 
            return field[key]
        elseif key == 'tag' or key=="occ" then
            return rawget(field,'readonly')[key]
        elseif key == 'ok' then
            return field.tag ~= "" and #field > 0
        elseif key:match('^[a-zA-Z0-9-][!%+%?%*]?$') then
            return field:first(key)
        elseif key == 'num' then
            local occ = rawget(field,'readonly').occ
            return occ == "" and 0 or tonumber(occ)
        elseif key == 'lev' then
            local tag = rawget(field,'readonly').tag
            return tag == '' and 0 or tonumber(tag:sub(1,1))
        elseif key == 'full' then
            if field.tag == "" or field.occ == "" then
                return field.tag
            else
                return field.tag .. '/' .. field.occ
            end
        else
            return PicaField[key] -- method name
        end
    end,

    -- field[ key ] = value    
    -- field.key = value    
    __newindex = function( field, key, value )
        if field.readonly[key] or PicaField[key] then
            error("field."..key.." is read-only")
        end
        rawset(field,key,value)
    end,

    -- read-only pseudo fields
    full = true, num = true, lev = true, ok = true
}

--- Creates a new PICA+ field.
-- The newly created field will have no subfields. The optional occurence 
-- indicator can only be set in addition to a valid tag. On failure this
-- returns an empty field with its tag set to the empty string.
-- On failure an empty PicaField instance is returned.
-- @param tag optional tag (e.g. <tt>021A</tt>) 
--        or tag and occurence (e.g. <tt>009P/09</tt>)
--        or a full line of PICA+ format to parse.
-- @param occ optional occurence indicator (<tt>01</tt> to <tt>99</tt>)
function PicaField.new( tag, occ, fields )
    tag = tag or ''
    occ = occ or ''

    local d1, d2 = tag:find('%s*%$')
    if d1 then
        fields = tag:sub(d2)
        tag = d1 > 1 and tag:sub(1,d1-1) or ''
    end

    if tag ~= '' then
        if occ ~= '' then -- both tag and occ supplied
            if not tag:find('^%d%d%d[A-Z@]$') or 
               not (occ:find('^%d%d$') and occ ~= '00') then
               tag,occ = '',''
            end
        else -- only tag supplied (possibly with occurence indicator)
            _,_,tag,occ = tag:find('^(%d%d%d[A-Z@])(.*)$')
            if tag then
                if occ ~= '' then
                    _,_,occ = occ:find('^/(%d%d)$')
                    if occ == '/00' then
                        tag,occ = '',''
                    end
                end
            else
                tag,occ = '',''
            end
        end
    end

    local sf = { 
        readonly = { 
            tag = tag, 
            occ = occ,
            codes = { },  -- table of subfield codes to lists of positions
        }, 
    }
    setmetatable(sf,PicaField)

    if fields and fields ~= "" then
        sf:append(fields)
    end

    return sf
end

--- Appends one or more subfields.
-- Subfields can either be specified in PICA+ format or as pairs of subfield
-- code (one character of <tt>[a-zA-Z0-9]</tt>) and subfield value. Empty
-- subfield values (the empty string <tt>""</tt>) are ignored.
-- @usage <tt>f:append("x","foo","y","bar")</tt>
-- @usage <tt>f:append("$xfoo$ybar")</tt>
function PicaField:append( ... )
    local i = 1

    local function appendsubfield( code, value )
        assert( code:find("^[a-zA-Z0-9]$"), "invalid subfield code: "..code )

        if value == "" then return end -- ignore empty subfields

        table.insert( self, value )

        local codes = rawget(self,'readonly').codes
        if codes[code] then
            table.insert( codes[code], #self )
        else
            codes[code] = { #self }
        end
    end

    repeat 
        local code = arg[i]
        assert( type(code) == "string", "field data must be string, got "..type(code) )

        if code:sub(1,1) == "$" then
            local value = ""
            local sf = ""
            local pos = 1

            for t, v in code:gfind('$(.)([^$]+)') do
                if t == '$' then
                    value = value..'$'..v
                else
                    if sf ~= "" then
                        appendsubfield(sf,value) 
                    end
                    sf, value = t, v
                end
            end

            appendsubfield(sf,value)
            i = i + 1
        else
            local value = arg[i+1]
            assert( type(value) == "string", "subfield value must be a string" )
            appendsubfield( code, value )
            i = i + 2
        end
    until i > #arg
end


--- Checks whether a field contains a given subfield.
-- @param ... subfield code (one character of <tt>a-z</tt>, 
--   <tt>A-Z</tt> or <tt>0-9</tt>)
-- @usage <tt>f:has("x")</tt> or <tt>f % "x"</tt>
-- @return boolean result of <tt>(self:first( subfield ) ~= "")</tt>
function PicaField:has( ... )
    return self:first( ... ) ~= ""
end

--- Returns the first value of a given subfield or an empty string.
-- @param ... subfield code and/or optional filters
function PicaField:first( code, ... )
    -- this is the default for subfields locators
    if type(code) == "string" and not code:find("[!%+%?%*]$") then
        code = code .. "?"
    end
    local list, errors = self:get( code, ... )
    if errors then
        return
    end
    if code:sub(-1) == "+" then
        return unpack(list) -- may be nil
    else
        local v = list[1]
        if code:sub(-1) == "*" then
            if v then 
                return unpack(list) 
            else
                return ""
            end
        else
            return v or ""
        end
    end
end

--- Returns an ordered table of all matching values
-- @param ... locator and/or filters
function PicaField:all( code, ... )
    if type(code) == "string" and not code:find("[!%+%?%*]$") then
        code = code .. "*"
    end
    local list = self:get( code, ... )
    return list
end

--- Returns a list of subfield values.
-- Calling this method as <tt>field:values(...)</tt> is equivalent to calling
-- <tt>unpack(field:all(...))</tt>. In contrast to <tt>all</tt> and 
-- <tt>get</tt> this method returns not a table but a list of non-empty strings.
-- @param ... locator and/or filters
-- @usage <tt>x,y,z = field:values()</tt> 
-- @usage <tt>n = field:values('a',patternfilter('^%d+$'))</tt>
-- @see PicaField:all
-- @see PicaField:get
function PicaField:values( ... )
    return unpack( self:all( ... ) )
end

-- Returns an ordered table of subfield values.
-- @return values possibly empty table of values
-- @return errors either nil or a list of error messages
function PicaField:get( locator, ... )
    if type(locator) == "nil" then
        return { unpack( self ) } -- return a table copy
    end
    assert( type(locator) == "string", "locator must be string, got "..type(locator) )

    local _,_,sf,m = locator:find("^([a-zA-Z0-9])([!%+%?%*]?)$")
    assert( sf, "invalid subfield locator: "..locator )

    local codes = rawget(self,'readonly').codes
    codes = codes[sf]

    -- no such subfield value
    if not codes then
        if m == "!" or m == "+" then
            return { }, { "subfield "..sf.." not found" }
        else
            return { }
        end
    end

    -- ok, there is at least one value
    if m == "!" and #codes > 1 then 
        return { }, { "subfield "..sf.." is repeated" }
    end

    if m == "" or m == "?" then
        return { filtervalue( self[codes[1]], ...) }
    else -- "*" or "+"
        local list, errors, p = { }
	for _,p in ipairs(codes) do
            local v = filtervalue( self[p], ...)
            if v then
                table.insert(list,v)
            end
        end
        if m == "+" and #list == 0 then
            errors = { "subfield "..sf.." not found" }
        end
        return list, errors
    end
end

--- Concatenate table of subfield values.
-- @see PicaField:get
-- @see PicaField:join
function PicaField:collect( ... )
    local values, errors = {}, {}

    local a
    for _,a in ipairs(arg) do
        local v, e, x
        if type(a) == "table" then
            v, e = self:get( unpack(a) )
        else
            v, e = self:get( a )
        end
        if e then table.append(errors,e) end
        table.append(values,v)
    end

    return values, ( next(errors) and errors or nil )
end

--- Collect and join subfield values.
-- @see PicaField:collect
function PicaField:join( sep, ... )
    return table.concat( self:collect( ... ), sep )
end

--- Returns an ordered table of subfield codes.
-- For instance for a field <tt>$xfoo$ybar$xdoz</tt> this method returns the
-- table <tt>{'x','y','x'}</tt>. 
-- @use <tt>cs = field:codes()             -- get as table</tt>
-- @use <tt>a,b,c = unpack(field:codes())  -- get as list</tt>
function PicaField:codes()
    local codes,c,list,pos = {}
    for c,list in pairs( rawget(self,'readonly').codes ) do
        for _,pos in ipairs(list) do
            codes[pos] = c
        end
    end
    return codes
end

-- returns the whole field as string in readable PICA+ format.
function PicaField:__tostring()
    local t,s = self.full,"";

    local codes = self:codes()
    local i,v

    for i,v in ipairs(self) do
        s = s..'$'..codes[i]..v:gsub('%$','$$')
    end

    if t ~= "" and s ~= "" then
        return t..' '..s
    else
        return t..s
    end
end

-----------------------------------------------------------------------------
--- Copies a field.
-- @usage <tt>field:copy()</tt> full copy with tag, occ and all subfields
-- @usage <tt>field:copy("123@")</tt> copy subfields but modify tag
-- @usage <tt>field:copy("123@/01")</tt> copy subfields but modify tag and occ
-- @usage <tt>field:copy("a-d")</tt> copy tag, occ, and selected subfields
-- @usage <tt>field:copy("")</tt> copy only all subfields
function PicaField:copy( full, subfields )

    if type(full) == "string" then
        if type(subfields) == "string" then
        elseif full == "" or full:match("^%d%d%d[A-Z@]$") or 
            full:match("^%d%d%d[A-Z@]/%d%d$") then
            subfields = nil 
        else
            subfields = full  
            full = self.full
        end
    else
        full = self.full
        subfields = nil
    end

    if subfields then
        assert( subfields:match("^%^?[a-zA-Z0-9-]+$"), 
            "illformed subfield locator: "..subfields )
        subfields = "["..subfields.."]"
    end

    local codes = self:codes()
    local f = PicaField.new( full )

    for i,v in ipairs(self) do
        if not subfields or codes[i]:match(subfields) then
            f:append( codes[i], v )
        end
    end

    return f
end

-----------------------------------------------------------------------------
--- Stores a PICA+ record.
-- Basically a PicaRecord is a list of PICA+ fields
-- This class overloads the following operators: 
-- <ul>
--   <li><tt>#r</tt> returns the number of fields.</li>
--   <li><tt>r % l</tt> returns whether locator <tt>p</tt> matches
--       <tt>r</tt> (see <a href="#PicaRecord:has">PicaRecord:has</a>).
-- </ul>
-- @field n (number) the <i>n</i>th field value
-- @field locator (string) the first matching field or value
--   (see <a href="#PicaRecord:first">PicaRecord:first</a>)
-- @class table
-- @name PicaRecord
-----------------------------------------------------------------------------
PicaRecord = {

    -- record % locator
    __mod = function (record,locator)
        return record:has( locator )
    end,

    -- record[ key ]  
    -- record.key
    __index = function (record,key)
    	if type(key) == "number" then
            return record[key]
        elseif key:match('^%d%d%d[A-Z@]') then
            -- TODO: record:get( key ) ?
            return record:first(key) 
        else
            return PicaRecord[key]
        end
    end,

    -- tostring( record )
    __tostring = function (record)
        local s,f,i = {},nil,nil
        for i,f in ipairs(record) do
            s[i] = tostring(f) 
        end
        return table.concat(s,"\n")
    end,
}

--- Creates a new PICA+ record.
-- If you provide a string, it will be parsed as PICA+ format.
-- @param str (optional string) string to parse
function PicaRecord.new( str )
    local record = { fields = { } }
    setmetatable(record,PicaRecord)
    if str == nil then
        return record
    elseif type(str) == "string" then
        str:gsub("[^\r\n]+", function(line)
        -- print(line,"\n")
            local field = PicaField.new(line)
            record:append( field )
        end)
    else
        error('can only parse string, got '..type(str))
    end
    return record
end

--- Appends a field to the record.
-- @param field PicaField object to append
function PicaRecord:append( field )
    table.insert( self, field )
    if not self.fields[ field.tag ] then
        self.fields[ field.tag ] = { }
    end
    table.insert( self.fields[ field.tag ], field )
end

--- Parses a field locator.
-- @see PicaRecord:all
-- @see PicaRecord:first
function PicaRecord.parse_field_locator( locator, subfield, ... )
    local list = {}
    local wantfield = true
    local sfornil = type(subfield) == "string" and subfield or nil

    (locator.."|"):gsub("([^|]*)|", function(l) 
        local _,_,tag,occ,sf = l:find('^(%d%d%d[A-Z@])([^$]*)(.*)')
        assert( tag, "malformed field locator:" .. l)

        if occ == '' then
            occ = '*'
        elseif occ == '/' then
            occ = ''
        elseif occ ~= '' then
            _,_,occ = occ:find('^/(%d%d)$')
            assert( occ , "occurrence must be / or /00 to /99 in locator "..l )
        end
        if sf == '' then
            sf = sfornil
        else
            _,_,sf = sf:find('^$(.+)$')
            assert( sf, "subfield must not be empty in locator "..l )
            wantfield = false
        end

        table.insert(list, {tag,occ,sf})
    end)

    if wantfield then
        wantfield = (sfornil == nil)
    else
        for _,t in ipairs(list) do
            assert( #t == 3, "field and subfield locators are mixed in "..locator )
        end
        if sfornil then
            error("subfield in locator "..locator.." and as parameter "..subfield )
        end
    end

    if wantfield then
        return list, wantfield, {subfield,...}
    else
        return list, wantfield, {...}
    end
end

--- Apply one or more function to each field of the record.
-- In contrast to PicaRecord:filter, the return values of functions are ignored
-- and nothing is returned.
-- @param ... functions that are called for each field
-- @see PicaRecord:filter
function PicaRecord:apply( ... )
     local methods = {...}
     for _,field in ipairs(self) do
        for _,method in ipairs(methods) do
            method( field )
        end
    end
end


--- Returns all matching subfield values (as table) or all matching fields
--  (as record).
-- You can filter fields by tag (and occurence indicator) and/or by using
-- a filter method that is called for each field as <tt>filter(field)</tt>.
-- A field is only included in the returned record, if the filter method
-- returns true. Note that the returned record contains references to the
-- original fields instead of copies!
-- @param field (optional) field locator
-- @param subfield
-- @param ... function that is applied to each value as filter
-- @return table or PicaRecord
-- @usage r:all('021A')
-- @see PicaRecord:apply
function PicaRecord:all( field, subfield, ... )
    local locators, wantrecord, filters, result

    local function append_field(field)
        for _,f in ipairs(filters) do
            if not f(field) then
                return
            end
        end
        result:append(field)
    end

    -- filter all fields
    if type(field) ~= "string" then
        filters = {field, subfield, ...}
        result = PicaRecord.new()
        for _,field in ipairs(self) do
            append_field(field)
        end
        return result
    end

    locators, wantrecord, filters 
        = self.parse_field_locator( field, subfield, ... )

    if wantrecord then
        result = PicaRecord.new()
    else
        result = { }
    end

    local function checkfield(fields,occ,sf)

        local check_occ = function(f)
            return occ == '*' or occ == f.occ or (occ == '00' and f.occ ~= '')
        end

        if wantrecord then
            local f
            for _,f in ipairs( fields ) do
                if check_occ(f) then
                    append_field(f)
                end
            end
        else 
            for n,f in pairs( fields ) do
                if check_occ(f) then
                    local values = f:all(sf)
                    for _,v in pairs( values ) do
                        v = filtervalue( v, unpack(filters) )
                        if (v) then table.insert( result, v ) end
                    end
                end
            end
        end

    end

    -- iterate over all locators
    for _,loc in ipairs(locators) do
        local tag, occ, sf = unpack(loc)
        local fields = self.fields[ tag ]
        if fields then
            checkfield(fields,occ,sf)
        end
    end

    return result
end


--- Returns the first matching field or subfield value
-- @param field locator of a field (<tt>AAAA</tt> or <tt>AAAA/</tt>
--        or <tt>AAAA/BB</tt> or <tt>AAAA/00</tt>)
-- @usage <tt>rec["028A/"]</tt> returns field 028A but not 028A/xx,
--        <tt>rec["028A"]</tt> returns field 028A or 028A/xx,
--        <tt>rec["028A/00"]</tt> returns field 028A/xx but not or 028A,
--        <tt>rec["028A/01"]</tt> returns field 028A/01
function PicaRecord:first( field, subfield, ... )
    local locators, wantfield, filters 
        = self.parse_field_locator( field, subfield, ... )

    for _,loc in ipairs(locators) do
        local tag, occ, sf = unpack(loc)
        local field = self.fields[ tag ]
        if field then
            for n,f in pairs(field) do
                if occ == '*' or occ == f.occ or (occ == '00' and f.occ ~= '') then
                    if type(subfield) ~= "string" then
                        return f -- TODO: apply filters? filterfield(f, unpack(filter))
                    else
                        return f:first(subfield, unpack(filters))
                    end
                end
            end
        end
    end

    return wantfield and PicaField.new() or ''
end

--- Returns whether a given locator matches.
-- @param ...
function PicaRecord:has(...)
    local f = self:first(...)
    return (f ~= '' or not f.empty)
end

---Get matching values from the record.
-- with error checking
function PicaRecord:get( query, ... )
    local result, err
    assert( type(query) == "string" and query ~= "", "query must be a non-empty string" )
    local m = query:sub(1,1)
    if m == "!" then
        result = self:all( query:sub(2), ... )
        if #result ~= 1 then
            err = 'got '..#result..' values instead of one'
        end
        result = result[1]
    elseif m == "+" then
        result = self:all( query:sub(2), ... )
        if #result == 0 then
            err = 'not found'
        end
    elseif m == "*" then
        result = self:all( query:sub(2), ... )
    else
        result = self:first( query, ... )
    end
    -- TODO: check type of result - do we want to allow PicaField?
    return result, err
end

--- Transforms the record to a table using a mapping table.
-- @param map mapping table
-- @see PicaRecord:get
-- @return table of transformed values
-- @return table of errors or nil of no errors occurred
function PicaRecord:map( map )
    assert( type(map) == "table", "mapping table required" )
    local result, errors = {}, {}
    local key,pattern,value,err
    for key,pattern in pairs(map) do
        if type(pattern) == "string" then
           value,err = self:get( pattern )
        elseif type(pattern) == "table" then
           value,err = self:get( unpack(pattern) )
        else
           error( "pattern must be string or table" )
        end
        if err then
            errors[key] = err
        end 
        if (type(value) == "string" and value ~= "") 
           or (type(value) == "table" and #value > 0 ) then
            result[key] = value
        end
    end
    if next(errors) == nil then
        errors = nil 
    end
    return result, errors
end
