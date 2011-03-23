-----------------------------------------------------------------------------
-- lua-pica
-----------------------------------------------------------------------------
-- module "pica" -- TODO

--- Stores an ordered list of PICA+ subfields
PicaField = { }
PicaField.__index = PicaField

-- you can access the first subfield values via its code
-- if it does not exists, the empty string is returned.
PicaField.__index = function (sf,key)
    if ( key:match('^[a-z0-9]$')  ) then
        -- return the first value
        return sf:first(key)
    else
        return PicaField[key]
    end
end

--- Creates a new PICA+ field.
-- The newly created field will be empty.
-- @param tag tag (optional)
-- @param occ occurence indicator (optional)
function PicaField.new( tag, occ )
    local sf = { 
        tag = tag or '', 
        occ = occ or '',
        subfields = { }, size = 0 
    }
    setmetatable(sf,PicaField)
    return sf
end

--- Creates a new PICA+ field by parsing a line of PICA+ format.
-- On failure an empty PicaField object is returned.
-- @usage <tt>field = PicaField:parse(str)</tt>
-- @param line
function PicaField.parse( line )

    _, _, tag, occ, data
        = string.find(line,"^([0-9][0-9][0-9][A-Z@])(%S*)%s($[^$].+)$")

    if tag == nil then 
        return PicaField.new()
    end    

    if string.find(occ,'^/([0-9][0-9])$') then
        occ = string.sub(occ,2)
    elseif not occ == "" then
        return nil
    end

    local field = PicaField.new(tag,occ)
    local value = ""
    local sf = ""
    local pos = 1

    for t, v in string.gfind(data,'$(.)([^$]+)') do
        -- io.write(t,'/',v,"\n");
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

    --return 
    return field
end

-- get the first value of a given subfield code
function PicaField:first( code )
    -- TODO: speed up
    local values = self:values(code)
    return values[1] or ""
end

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

function PicaField:append( code, value )
    if not self.subfields[code] then
        self.subfields[code] = { }
    end
    self.size = self.size + 1
    self.subfields[code][ self.size ] = value
end

--- Returns the subfields as array
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

-- returns tag and occurence indicator as string
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

-- returns the whole field as string in readable PICA+ format
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


PicaRecord = {}
PicaRecord.__index = PicaRecord

PicaRecord.__index = function (field,key)
    --if ( key:match('^[0-9][0-9][0-9][A-Z@]$') or
    --     key:match('^[0-9][0-9][0-9][A-Z@]/[0-9][0-9]$') ) then
        -- return the first value
   --     return field:first(key)
    --else
        return PicaRecord[key]
    --end
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


function PicaRecord:append( field )
    --print(dump(field))
    table.insert( self, field )

    -- TODO: support repeatable fields
    if not self[ field.tag ] then
        self[ field.tag ] = { }
    end

    table.insert( self[ field.tag ], field )
--     local fields = { } 
    --if ( self[field:fulltag()] ) then
        -- ...
    --end
end

function PicaRecord:all( field )
    local list = { }
    if self[field] then
        list = self[field]
    end
    return list
end

function PicaRecord:first( field, subfield )
    field = self[ field ]
    if field == nil or field[1] == nil then
        if subfield == nil then return nil else return "" end
    else
        field = field[1]
        if subfield == nil then
            return field
        else
            return field:first(subfield)
        end
    end
end


