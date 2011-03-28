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
-- @field ok returns whether the field has a tag and is not empty
-- @field empty returns whether the field has no subfields (<tt>#f == 0</tt>)
-- @class table
-- @name PicaField
-----------------------------------------------------------------------------
PicaField = {

    -- # field
    __len = function (field)
        return field.size
    end,

    -- field % subfield
    __mod = function(field,subfield)
        return field:has( subfield )
    end,

    -- field[ key ]  
    -- field.key
    __index = function (field,key)
        if ( type(key) == 'number' ) then -- n'th value 
            return field[key]
        elseif ( key:match('^[a-zA-Z0-9]$')  ) then -- first matching value
            return field:first(key)
        elseif key == 'empty' then
            return field.size == 0
        elseif key == 'full' then
            return field:get_full()
        elseif key == 'str' then
            return tostring(field)
        elseif key == 'ok' then
            return field.tag ~= "" and field.size > 0
        else
            return PicaField[key]
        end
        -- rawget?
    end,

    -- field[ key ] = value    
    -- field.key = value    
    __newindex = function(field, key, value)
        -- TODO:
        --- field.x = "foo"
        --- field.tag / . fulltag / .occ
        rawset(field,key,value)
    end,

}

-- implements 'field.full'
function PicaField:get_full()
    if self.tag == "" then
        return ""
    end
    if self.occ == "" then
        return self.tag
    else
        return self.tag .. '/' .. self.occ
    end
end


--- Creates a new PICA+ field.
-- The newly created field will have no subfields. The optional occurence 
-- indicator can only be set in addition to a valid tag. On failure this
-- returns an empty field with its tag set to the empty string.
-- @param tag optional tag (e.g. <tt>021A</tt>) 
--        or tag and occurence (e.g. <tt>009P/09</tt>)
-- @param occ optional occurence indicator (<tt>01</tt> to <tt>99</tt>)
function PicaField.new( tag, occ )
    tag = tag or ''
    occ = occ or ''

    if tag ~= '' then
        if occ ~= '' then -- both tag and occ supplied
            if not string.find(tag,'^%d%d%d[A-Z@]$') or 
               not (string.find(occ,'^%d%d$') and occ ~= '00') then
               tag,occ = '',''
            end
        else -- only tag supplied (possibly with occurence indicator)
            _,_,tag,occ = string.find(tag,'^(%d%d%d[A-Z@])(.*)$')
            if occ ~= '' then
                _,_,occ = string.find(occ,'^/(%d%d)$')
                if occ == '/00' then
                    tag,occ = '',''
                end
            end
        end
    end

    local sf = { 
        tag = tag, 
        occ = occ,
        subfields = { }, size = 0 
    }
    setmetatable(sf,PicaField)
    return sf
end

--- Creates a new PICA+ field by parsing a line of PICA+ format.
-- On failure an empty PicaField instance is returned.
-- @usage <tt>field = PicaField:parse(str)<br>
-- if field.tag then <br>-- successfully parsed field<br>end</tt>
-- @param line
function PicaField.parse( line )

    _, _, full, data
        = string.find(line,"^([^%s$]+)%s*($[^$].+)$")

    local field = PicaField.new(full)
    if not field.tag then return field end

    -- parse subfields
    local value = ""
    local sf = ""
    local pos = 1

    for t, v in string.gfind(data,'$(.)([^$]+)') do
        if t == '$' then
            value = value..'$'..v
        else
            if not (sf == "") then
                field:append(sf,value) 
            end
            sf, value = t, v
        end
    end
    field:append(sf,value)

    return field
end

--- Appends a subfield.
-- On failure adds nothing.
-- @param code subfield code 
--        (<tt>a</tt> to <tt>z</tt> or <tt>0</tt> to <tt>9</tt>)
-- @param value subfield value. Must be a non-empty string.
function PicaField:append( code, value )
    -- TODO: validate code (A-Z, a-z, 0-9)
    if not self.subfields[code] then
        self.subfields[code] = { }
    end
    self.size = self.size + 1
    self.subfields[code][ self.size ] = value
    self[ self.size ] = value
end

--- Returns the first value of a given subfield or an empty string.
-- @param code a subfield code
function PicaField:first( code )
    -- TODO: speed up and support multiple codes and an additional filter
    local values = self:values(code)
    return values[1] or ""
end

--- Returns a list of all matching values
function PicaField:all( code )
    local values = self:values(code)
    return values
end

--- Checks whether a field contains a given subfield.
-- @param ... subfield code (one character of <tt>a-z</tt>, 
--   <tt>A-Z</tt> or <tt>0-9</tt>)
-- @usage <tt>f:has("x")</tt> or <tt>f % "x"</tt>
-- @return boolean result of <tt>(self:first( subfield ) ~= "")</tt>
function PicaField:has(...)
    return (self:first(...) ~= "")
end


--- Returns a list of subfield values.
function PicaField:values( code )
    local values = { }
    if self.subfields[code] then
        for pos,val in pairs(self.subfields[code]) do
            table.insert( values, { pos, val } )
        end
    end
    -- sort by position
    table.sort( values, function(a,b)
        return a[1] < b[1] 
    end )
    -- get the values only
    for k,v in pairs(values) do
        values[k] = v[2]
    end
    return values
end

--- Returns the subfields as array.
-- { [1] = { 'a' = 'foo' }, [2] = { 'b' : 'bar' }, [3] => { 'a' = 'doz' } ...
function PicaField:list()
    local list = { }
    for code, values in pairs(self.subfields) do
        for pos, val in pairs(values) do         
            list[pos] = { }
            list[pos][code] = val
        end    
    end
    return list
end

-- returns the whole field as string in readable PICA+ format.
function PicaField:__tostring()
    local t,s = self.full,"";

    for pos,sf in pairs(self:list()) do
        for code, value in pairs(sf) do
            value = string.gsub(value,'%$','$$')
            s = s..'$'..code..value
        end
    end

    if t ~= "" and s ~= "" then
        return t..' '..s
    else
        return t..s
    end
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
-- @field n (number) the <i>n</i>th field
-- @field locator (string) the first matching field or value
--   (see <a href="#PicaRecord:first">PicaRecord:first</a>)
-- @class table
-- @name PicaRecord
-----------------------------------------------------------------------------
PicaRecord = {

    -- #record
    __len = function (record)
        return record.size
    end,

    -- field % locator
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
            local field = PicaField.parse(line)
            record:append( field )
        end)
    else
        error('can only parse string, got '..type(str))
    end
    return record
end

--- Appends a field to the record.
function PicaRecord:append( field )
    table.insert( self, field )

    if not self.fields[ field.tag ] then
        self.fields[ field.tag ] = { }
    end
    table.insert( self.fields[ field.tag ], field )
end

--- Parses a field locator into tag and occurrence.
-- see PicaRecord:first and PicaRecord:all for examples
function PicaRecord.parse_field_locator( field )

    _,_,tag,occ = string.find(field,'^(%d%d%d[A-Z@])(.*)')
    if not tag or (occ ~= "" and not occ:find('^/%d*$')) then
        return
    end 

    if occ == "" then
        occ = "*"
    elseif occ == "/" then
        occ = ""
    elseif occ ~= "" then
       _,_,occ = occ:find('^/(%d*)$')
    end

    return tag, occ
end

--- Returns all matching values
-- @return table
-- TODO: support field locators as in :first
function PicaRecord:all( field, subfield )
    local list = { }

    local tag, occ = self.parse_field_locator( field )

    if tag == nil or self.fields[ tag ] == nil then
        return list
    end

    local check_occ = function(f)
        return occ == '*' or occ == f.occ or (occ == '00' and f.occ ~= '')
    end

    local fl = self.fields[ tag ]
    if not fl then
        return { }
    elseif subfield then
        for n,f in pairs( fl ) do
            if check_occ(f) then
                local values = f:all(subfield)
                for m,v in pairs( values ) do
                    table.insert( list, v )
                end
            end
        end
    else 
        -- TODO: test this and maybe it should better return a Picarecord?
        local f
        for _,f in ipairs( fl ) do
            if check_occ(f) then
                table.insert( list, f )
            end
        end
    end

    return list
end

--- Returns the first matching field or subfield value
-- @param field locator of a field (<tt>AAAA</tt> or <tt>AAAA/</tt>
--        or <tt>AAAA/BB</tt> or <tt>AAAA/00</tt>)
-- @usage <tt>rec["028A/"]</tt> returns field 028A but not 028A/xx,
--        <tt>rec["028A"]</tt> returns field 028A or 028A/xx,
--        <tt>rec["028A/00"]</tt> returns field 028A/xx but not or 028A,
--        <tt>rec["028A/01"]</tt> returns field 028A/01
function PicaRecord:first( field, subfield )
    -- local tag
    -- TODO: /00

    local dummy = function()
        if subfield == nil then
            return PicaField.new()
        else
            return ''
        end
    end
    
    local tag, occ = self.parse_field_locator( field )
    if not tag then
        return dummy()
    end

    field = self.fields[ tag ]
    if field == nil then
        return dummy()
    end


    for n,f in pairs(field) do
        if occ == '*' or occ == f.occ or (occ == '00' and f.occ ~= '') then
            if subfield == nil then
                return f
            else
                return f:first(subfield)
            end
        end
    end

    -- not found
    return dummy()
end

--- Returns whether a given locator matches.
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
           or (type(value) == "table" and not (next(value) == nil)) then
            result[key] = value
        end
    end
    if next(errors) == nil then
        errors = nil 
    end
    return result, errors
end


