-----------------------------------------------------------------------------
-- Handle PICA+ data in Lua.
--
-- This module provides two classes (<a href="#PicaField">PicaField</a> and
-- <a href="#PicaRecord">PicaRecord</a>) for easy access and conversion of 
-- PICA+ records. Have a look at the file 'example.lua' for a synopsis.
-- 
-- @author Jakob Voss <voss@gbv.de>
-- @class module
-- @name pica
-----------------------------------------------------------------------------

-- define local variables for better performance
local string, table, rawset, rawget
    = string, table, rawset, rawget

-----------------------------------------------------------------------------
local function assertType(typ,value,name)
    assert(type(value)==typ, name.." must be "..typ.." but got "..type(value))
    return value
end

-----------------------------------------------------------------------------
--- Stores an ordered list of PICA+ subfields.
-- <tt>#f</tt> returns the number of subfields.
-- @field n (number) the <i>n</i>th subfield value or <tt>nil</tt>
-- @field c (string) the <i>first</i> subfield value of a subfield with code
--   <i>c</i> where <i>c</i> can be a letter (<tt>a-z</tt> or <tt>A-Z</tt>) 
--   or a digit (<tt>0-9</tt>). Nil is returned if no such subfields exists.
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
    -- field access via `field[ key ]` or `field.key`
    __index = function( field, key )
        if PicaField[key] then -- method or static property
            return PicaField[key]
        elseif ( type(key) == 'number' ) then -- n'th value 
            return rawget(field,key)
        elseif key == 'tag' or key == 'occ' then
            return rawget(field,'readonly')[key]
        elseif key == 'full' then
            local tag = rawget(field,'readonly').tag
            if tag == '' then return '' end
            local occ = rawget(field,'readonly').occ
            if occ == '' then
                return tag
            else
                return tag .. '/' .. occ
            end
        elseif key == 'ok' then
            return field.tag ~= "" and #field > 0
        elseif key == 'num' then
            return tonumber( rawget(field,'readonly').occ )
        elseif key == 'level' then
            return tonumber(rawget(field,'readonly').tag:sub(1,1))
        else
            return field:first(key)
        end
    end,

    -- Disallow changing the field. Note that we could allow
    -- setting values by this proxy method (e.g. `f.a = "xyz"`)
    __newindex = function( field, key, value )
        error("field."..key.." is read-only")
    end,

    -- to iterate over subfields
    __pairs = function( field )
        local i,n = 0,#field
        local codes = field:codes()
        local function iter(t)
          if i >= n then return nil end
          i = i + 1
          return codes[i], field[i]
        end

        return iter, field
    end
}

-- since lua 5.1 does not support __pairs
PicaField.pairs = PicaField.__pairs
PicaField.ipairs = ipairs

--- Creates a new PICA+ field.
-- The newly created field will have no subfields. The optional occurence 
-- indicator can only be set in addition to a valid tag. On failure this
-- returns an empty field with its tag set to the empty string.
-- On failure an empty PicaField instance is returned.
-- @param tag optional tag (e.g. <tt>021A</tt>) 
--        or tag and occurence (e.g. <tt>009P/09</tt>)
--        or a full line of PICA+ format to parse.
-- @param occ optional occurence indicator (<tt>01</tt> to <tt>99</tt>)
function PicaField.new( tag, occ, ... )
    tag = tag or ''
    occ = occ or ''

    local fields
    local d1, d2 = tag:find('%s*%$')

    if d1 then
        fields = tag:sub(d2)
        tag = d1 > 1 and tag:sub(1,d1-1) or ''
    elseif occ:match('^%$') or occ:match("^[a-zA-Z0-9]$") then
        fields, occ = occ, ''
    end

    if tag ~= '' then
        if occ ~= '' then -- both tag and occ supplied
            if not tag:find('^%d%d%d[A-Z@]$') or 
               not (occ:find('^%d%d$') ) then
               tag,occ = '',''
            end
        else -- only tag supplied (possibly with occurence indicator)
            _,_,tag,occ = tag:find('^(%d%d%d[A-Z@])(.*)$')
            if tag then
                if occ ~= '' then
                    _,_,occ = occ:find('^/(%d%d)$')
                end
            else
                tag,occ = '',''
            end
        end
    end

    local sf = setmetatable({ 
        readonly = {
            tag = tag, 
            occ = occ,
            codes = { },
        }, 
    },PicaField)

    if fields and fields ~= "" then
        sf:append( fields, ...)
    elseif ( ... ) then
        sf:append( ... )
    end

    return sf
end

--- Appends one or more subfields.
-- Subfields can either be specified in PICA+ format or as pairs of subfield
-- code (one character of <tt>[a-zA-Z0-9]</tt>) and subfield value. Empty
-- subfield values (the empty string <tt>""</tt>) are ignored.
-- @usage <tt>f:append("x","foo","y","bar")</tt>
-- @usage <tt>f:append("$xfoo$ybar")</tt>
-- @return the field
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
        assertType('string',code,'field data')

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
            assertType('string',value,'subfield value')
            appendsubfield( code, value )
            i = i + 2
        end
    until i > #arg

    return self
end

-- Inserts a default flag, unless a flag is given.
function PicaField:getFlagged( default, code, ... )
    if type(code) == "string" then
        local _,_,c,f,s = code:find("^([^!%+%?%*_]*)([!%+%?%*]?)(_?)$")
        if f == "" then
            f = default
            code = c..f..s
        end
    end
    return self:get( code, ... )
end

--- Returns the first value of a given subfield (or nil).
-- @param ... subfield code and/or optional filters
function PicaField:first( ... )
    local values = self:getFlagged( '?', ... )
    return values[1]
end

--- Returns a list of all matching values
-- @param ... locator and/or filters
-- @usage <tt>x,y,z = field:all()</tt> 
-- @usage <tt>n = field:all({'a',pattern='^%d+$'})</tt>
function PicaField:all( ... )
    local values = self:get( ... )
    return unpack( values )
end

-- Returns an ordered table of subfield values.
-- @return values - possibly empty table of values
-- @return msg - either nil or an error message
function PicaField:get( locator, filter )
    if type(locator) == "table" then
        locator, filter = locator[1], locator
    end
    if not locator then
        return { unpack( self ) } -- return a table copy
    end

    if type(locator) == "number" then -- TODO: also in :first, :all ??
        locator = tostring(locator)
    end
    assertType('string',locator,'locator')

    local _,_,sf,flag,str = locator:find("^_?([a-zA-Z0-9])([!%+%?%*]?)(_?)%s*$")
    assert( sf, "invalid subfield locator: "..locator )

    local list, err = {}
    local vpos = rawget(self,'readonly').codes[sf]

    if not vpos then -- no such subfield value
        if flag == "!" or flag == "+" then
            err = "subfield "..sf.." not found"
        end -- else: no error but empty list
    elseif flag == "!" and #vpos > 1 then
        err = "subfield "..sf.." is repeated"
    elseif flag == "?" then
        list = { PicaField.filtered( self[vpos[1]], filter) }
    else -- "*" or "+" or ""
        local p
        for _,p in ipairs(vpos) do
            local v = PicaField.filtered(self[p],filter)
            if v then
                table.insert(list,v)
            end
        end
        if m == "+" and #list == 0 then
            err = "subfield "..sf.." not found"
        end
    end

    if #list == 0 and str == "_" then
        list = {""} 
    end

    return list, err
end


-- TODO: cleanup
function PicaField.filtered( value, filter )
    if not (value and filter) then 
        return value 
    end

    local filters = {}
    local patternfilter = function( pattern )
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


    if type(filter) == "function" then
        filters = { filter }
    elseif type(filter) == "table" then
        
        if filter.match then
        local s = filter.match
            local s = assertType('string',filter.match,"match")

            local fun = patternfilter(s)

            table.insert(filters, fun) 
        end
        if (filter.format) then
            local s = assertType('string',filter.format,"format")
            local fun = function( value )
                return s:format( value )
            end
            table.insert(filters, fun) 
        end        
        if (filter.each) then
            local fun = assertType('function',filter.each,"format")
            table.insert(filters, fun) 
        end
    end

    -- Applies a filter chain. If a filter returns a non-empty string, the 
    -- string becomes the current value. If a filter returns true, the current
    -- value is kept. In other cases, the filter chain quits.
    for _,filter in ipairs(filters) do
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

-- Query multiple subfield values.
-- Note that the returned array may be sparse!
-- @see PicaField:get
-- @see PicaField:join
function PicaField:map( map )
    local values, errors, key, query = {}, {}
    for key,query in pairs(map) do
        local v, err, x, flag
        if type(query) == "table" then
            flag = query[1]
            v, err = self:getFlagged( '?', unpack(query) )
        else
            flag = query
            v, err = self:getFlagged( '?', query )
        end
        if err then errors[key] = err end
        if #v > 0 then
            if type(flag) == "string" and #v == 1 and not flag:find("[*+]") then
                v = v[1]
            end
            values[key] = v
        end
    end

    return values, ( next(errors) and errors or nil )
end

--- Concatenate table of subfield values.
function PicaField:join( sep, map )
    local values, errors = self:map( map )
    local condense = {}
    for key,_ in pairs(map) do
        if values[key] then
            table.insert( condense, values[key]  )
        end
    end
    return table.concat( condense, sep )
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
    local f,t,c,v = self.full,{''};
    if #self == 0 then
        return f
    elseif f ~= '' then
        t[1] = ' '
    end
    for c,v in self:pairs() do
        table.insert(t,'$'..c..v:gsub('%$','$$'))
    end
    return f..table.concat(t,'')
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

    -- record[ key ]    or    record.key
    __index = function (record,key)
        if type(key) == "number" then
            return rawget(record,'fields')[key]
        elseif key:match('^%d%d%d[A-Z@]') then
            -- TODO: record:get( key ) ?
            return record:first(key) 
        else
            return PicaRecord[key]
        end
    end,

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
    end
    str = tostring(str)
    str:gsub("[^\r\n]+", function(line)
        local field = PicaField.new(line)
        record:append( field )
    end)
    return record
end

--- Appends a field to the record.
-- @param field PicaField object to append
function PicaRecord:append( field )
    if type(field) == "string" then
        field = PicaField.new(field)
    end
    table.insert( self, field )
    if not self.fields[ field.tag ] then
        self.fields[ field.tag ] = { }
    end
    table.insert( self.fields[ field.tag ], field )
end

--- Parses a field locator.
-- @see PicaRecord:all
-- @see PicaRecord:first
function PicaRecord.parse_field_locator( locator, filter )

    if type(locator) == "table" then
        locator, filter = locator[1], locator
    elseif type(filter) ~= "table" then
        filter = { }
    end

    if not locator then
        return nil,false,filter
    end

    local list = {}

--    if
    local wantfield = true
--    local sf_or_nil = type(subfield) == "string" and subfield or nil

    (locator.."|"):gsub("([^|]*)|", function(l) 
        local _,_,tag,occ,sf = l:find('^%s*(%d%d%d[A-Z@])([^$%s]*)%s*(.*)')
        assert( tag, "malformed field locator:" .. l)

        if occ == '' then
            occ = '*'
        elseif occ == '/' then
            occ = ''
        elseif occ == '/xx' or occ == '/XX' then
            occ = 'xx'
        elseif occ ~= '' then
            _,_,occ = occ:find('^/(%d%d)$')
            assert( occ , "occurrence must be / or /00 to /99 in locator "..l )
        end
        if sf == '' then
            sf = nil --sf_or_nil
        else
            _,_,sf = sf:find('^$(.+)$')
            assert( sf, "subfield must not be empty in locator "..l )
            wantfield = false
        end

        table.insert(list, {tag,occ,sf})
    end)

  --  if wantfield then
  --      wantfield = (sf_or_nil == nil)
  --  else
    if not wantfield then
        for _,t in ipairs(list) do
            assert( #t == 3, "field and subfield locators are mixed in "..locator )
        end
        --if sf_or_nil then
        --    error("subfield in locator "..locator.." and as parameter "..subfield )
        --end
    end


    if wantfield then
        return list, wantfield, filter --{subfield,...}
    else
        return list, wantfield, filter --{...}
    end
end

--- Apply one or more function to each field of the record.

-- TODO: == record:all({each=...})

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

    locators, wantrecord, filters 
        = self.parse_field_locator( field, subfield, ... )

    if wantrecord then
        result = PicaRecord.new()
    else
        result = { }
    end

    local function field_handler(field)
        if (filters and filters.each) then
           if not filters.each(field) then return end
        end
        for _,f in ipairs(filters) do
            if not f(field) then
                return
            end
        end
        result:append(field)
    end

    -- filter all fields
    if not locators then
        for _,field in ipairs(self) do
            field_handler(field)
        end
        return result
    end

    -- iterate over all locators
    for _,loc in ipairs(locators) do
        local tag, occ, sf = unpack(loc)
        local fields = self.fields[ tag ]

        if fields then

        local check_occ = function(f)
            return occ == '*' or occ == f.occ or (occ == 'xx' and f.occ ~= '')
        end
        if wantrecord then
            local f
            for _,f in ipairs( fields ) do
                if check_occ(f) then
                    field_handler(f)
                end
            end
        else 
            for n,f in pairs( fields ) do
                if check_occ(f) then
                    -- proceed with field
                    filters[1] = sf 
                    local values = f:get(filters)
                    for _,v in pairs( values ) do
                        if (v) then table.insert( result, v ) end
                    end
                end
            end
        end
        end
    end

    return result
end


--- Returns the first matching field or subfield value
-- @param field locator of a field (<tt>AAAA</tt> or <tt>AAAA/</tt>
--        or <tt>AAAA/BB</tt> or <tt>AAAA/00</tt>)
-- @usage <tt>rec["028A/"]</tt> returns field 028A but not 028A/xx,
--        <tt>rec["028A"]</tt> returns field 028A or 028A/xx,
--        <tt>rec["028A/xx"]</tt> returns field 028A/xx but not or 028A,
--        <tt>rec["028A/01"]</tt> returns field 028A/01
function PicaRecord:first( ... )
    local result = self:all( ... )
-- TODO: better performance with filter value 'max=1'

    if result[1] then
        return result[1]
    else
        local locators, wantfield, filters 
            = self.parse_field_locator( ... )
        return wantfield and PicaField.new() or ''
    end
--[[
    for _,loc in ipairs(locators) do
        local tag, occ, sf = unpack(loc)
        local field = self.fields[ tag ]
        if field then
            for n,f in pairs(field) do
                if occ == '*' or occ == f.occ or (occ == 'xx' and f.occ ~= '') then
                    if wantfield then
                        return f -- TODO: apply filters? filterfield(f, unpack(filter))
                    else
                        return f:first(sf, unpack(filters))
                    end

                end
            end
        end
    end

    return wantfield and PicaField.new() or ''
]]
end

--- Returns whether a given locator matches.
-- @param ...
function PicaRecord:has(...)
    local f = self:first(...)
    return (f ~= '' or not f.empty)
end

---Get matching values from the record.
-- with error checking
function PicaRecord:get( query, filter )
    if type(query) == "table" then
        query, filter = query[1], query
    elseif type(query) == "function" then
        query, filter = nil, {each=query}
    end

    if not query then
        query = ""
    end
    assertType("string",query,"query")

    local result, err
    local m = query:sub(1,1) 

    if m == "!" then
        result = self:all( query:sub(2), filter )
        if #result ~= 1 then
            err = 'got '..#result..' values instead of one'
        end
        result = result[1]
    elseif m == "?" then
        result = self:all( query:sub(2), filter )
        if #result > 1 then
            err = 'got '..#result..' values instead of at most one'
        end
        result = result[1]
    elseif m == "+" then
        result = self:all( query:sub(2), filter )
        if #result == 0 then
            err = 'not found'
        end
    elseif m == "*" then
        result = self:all( query:sub(2), filter )
    else
        result = self:first( query, filter )
    end
    
    return result, err
end

--- Transforms a PICA+ record to a key-value structure using a mapping table.
-- @param map mapping table
-- @see PicaRecord:get
-- @return table of transformed values
-- @return nil (if there are no error) or non-empty table of errors
function PicaRecord:map( map )
    assertType('table',map,'mapping table required')
    local result, errors, key, pattern = {}, {}
    for key, pattern in pairs(map) do
        local value, err = self:get(pattern)
        if err then
            errors[key] = err
        end 
        if ( type(value) == 'string' and value ~= "" ) 
        or ( type(value) == 'table'  and #value > 0    ) then
            result[key] = value
        end
    end
    if next(errors) == nil then
        errors = nil 
    end
    return result, errors
end
