-----------------------------------------------------------------------------
-- Handle PICA+ data in Lua
--
-- @class module
-- @name pica
-----------------------------------------------------------------------------
-- module "pica" -- deprecated. TODO: Tell LuaDoc to treat this as a module.

-----------------------------------------------------------------------------
--- Stores an ordered list of PICA+ subfields
-- @class table
-- @name PicaField
-- @field ok boolean value, indicating whether the field is non-empty
-- @field x  subfield value for subfield code <tt>x</tt> or the empty string
-- @field n  nth subfield
-----------------------------------------------------------------------------
PicaField = { }
PicaField.__index = PicaField

--- Access properties of a PICA+ field
-- You can access the first subfield values via its code
-- if it does not exists, the empty string is returned.
-- @usage <tt>field.ok</tt> returns whether the field is empty<br>
-- <tt>field.a</tt> returns the first subfield value <tt>a</tt>
PicaField.__index = function (field,key)
    if ( type(key) == 'number' ) then
        -- return the nth subfield value
        local f = field[key]
        return f
    elseif ( key:match('^[a-z0-9]$')  ) then
        -- return the first subfield value of the given code
        return field:first(key)
    elseif key == 'ok' then
        -- return whether the field is not empty
        return field.tag ~= "" and field.size > 0
    else
        return PicaField[key]
    end
end

--- Returns the length of the field, that is the number of subfields.
-- @usage <tt>#field</tt>
PicaField.__len = function (field)
    return field.size
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

    _, _, fulltag, data
        = string.find(line,"^([^%s$]+)%s*($[^$].+)$")

    local field = PicaField.new(fulltag)
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
    -- TODO: validate
    if not self.subfields[code] then
        self.subfields[code] = { }
    end
    self.size = self.size + 1
    self.subfields[code][ self.size ] = value
    self[ self.size ] = value
end

--[[
--- Returns whether the field is not empty.
function PicaField:ok()
    return self.tag ~= "" and self.size > 0
end

--- Returns whether the field is empty.
function PicaField:empty()
    return self.tag == "" or self.size == 0
end
--]]


--- Returns the first value of a given subfield or an empty string.
-- @param code a subfield code
function PicaField:first( code )
    -- TODO: speed up and support multiple codes and an additional filter
    local values = self:values(code)
    return values[1] or ""
end

function PicaField:all( code )
    local values = self:values(code)
    return values
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

-- Returns tag and occurence indicator as string.
function PicaField:fulltag()
    if self.tag == "" then
        return ""
    end
    if self.occ == "" then
        return self.tag
    else
        return self.tag .. '/' .. self.occ
    end
end

-- returns the whole field as string in readable PICA+ format.
function PicaField:__tostring()
    local t,s = self:fulltag(),"";

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

--- A PICA+ record.
-- @class table
-- @
----
PicaRecord = {}
PicaRecord.__index = PicaRecord

--- Access a field or field value.
-- <tt>rec[n]</tt> returns th nth field if n is a number
-- or the first field/value if n is a locator
PicaRecord.__index = function (record,key)
    if type(key) == "number" then
       return record[key]
    elseif key:match('^%d%d%d[A-Z@]') then
       return record:first(key) 
    else
        return PicaRecord[key]
    end
end

function PicaRecord.new()
    local record = { fields = { } }
    setmetatable(record,PicaRecord)
    return record
end

function PicaRecord.parse( string )
    local record = PicaRecord.new()
    string:gsub("[^\r\n]+", function(line)
    -- print(line,"\n")
        local field = PicaField.parse(line)
        record:append( field )
    end)
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

    _,_,tag,occ = field:find('^(%d%d%d[A-Z@])(.*)')
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

-- TODO: support field locators as in :first
function PicaRecord:all( field, subfield )
    local list = { }

    local tag, occ = self.parse_field_locator( field )

    if tag == nil or self.fields[ tag ] == nil then
        return list
    end

    if subfield then
        for n,f in pairs( self.fields[field] ) do
            local values = f:all(subfield)
            for m,v in pairs( values ) do
                table.insert( list, v )
            end
        end
    else -- return all fields. TODO: check occ!
        list = self.fields[field]
    end

    return list
end

--- Returns the first matching field or subfield value
-- @param field locator of a field (<tt>AAAA</tt> or <tt>AAAA/</tt>
--        or <tt>AAAA/BB</tt> or <tt>AAAA/00</tt>)
-- @usage <tt>rec["028A/"]</tt> returns field 028A,
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
        if occ == '*' or occ == f.occ or (occ == '00' and f.occ) then
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


