-------------------------------------------------------------------------------
-- Experimental demo conversion from PICA+ to RDF/Turtle.
--
-- @author Jakob Voss <voss@gbv.de>
-------------------------------------------------------------------------------

require 'pica'

-------------------------------------------------------------------------------
--- Simple turtle serializer.
-- Stores multiple RDF statements with the same subject.
-- 
-- @class table
-- @name Turtle
-------------------------------------------------------------------------------
Turtle = {

    -- static properties
    popular_namespaces = {
        dc   = 'http://purl.org/dc/elements/1.1/',
        dct  = 'http://purl.org/dc/terms/',
        bibo = 'http://purl.org/ontology/bibo/',
        frbr = 'http://purl.org/vocab/frbr/core#',
        xsd  = 'http://www.w3.org/2001/XMLSchema#',
    },
    literal_escape = {
        ['"']   = "\\\"",
        ["\\"]  = "\\\\",
        ["\t"] = "\\t",
        ["\n"] = "\\n",
        ["\r"] = "\\r"
    },

    -- operators
    __index = function(ttl,key) -- ttl [ key ]
        return Turtle[key]
    end

    -- # ttl   returns the number of triples
}

--- Creates a new Turtle serializer.
-- @param subject the subject for all triples
function Turtle.new( subject )
    local tt = {
        subject = subject,
        warnings = { },
        namespaces = { }
    }
    setmetatable(tt,Turtle)
    return tt
end

function Turtle:warn( msg )
    table.insert( self.warnings, msg )
    return false
end

--- Adds a statement with literal as object.
-- empty strings as object values are ignored!
-- unknown predicate vocabularies are ignored!
function Turtle:add( predicate, object, lang_or_type )
    if object == nil or object == "" then
        return false
    end

    if type(object) == "string" or type(object) == "number" then
        object = self:literal(object, lang_or_type)
    end -- else???

    if not self:use_uri( predicate ) then
        return false -- TODO. log error
    end

    table.insert( self, " " .. predicate .. ' ' .. object )
    return true
end

--- Adds a statement with URI as object.
function Turtle:addlink( predicate, uri )
    if uri == nil or uri == "" then
        return false
    end

    if not self:use_uri( predicate ) or not self:use_uri( uri ) then
        return false -- TODO. log error
    end

    table.insert( self, " " .. predicate .. ' ' .. uri )
    return true
end


function Turtle:use_uri( uri )
    if uri == 'a' or uri:find('^<[^>]*>$') then
        return true
    else
        local _,_,prefix = uri:find('^([a-z]+):')
        if prefix and self.popular_namespaces[prefix] then
            self.namespaces[prefix] = self.popular_namespaces[prefix]
        else
            prefix = prefix and prefix..':' or uri
            self:warn( "unknown uri prefix " .. prefix )
            return false
        end
    end
    return true
end

--- Returns a RDF/Turtle document
function Turtle:__tostring()
    if #self == 0 then return "" end

    local ns = ""
    local prefix, uri

    for prefix, uri in pairs(self.namespaces) do
        ns = ns .. "@prefix "..prefix..": <"..uri.."> .\n"
    end
    if ns then ns = ns .. "\n" end

    return ns .. self.subject 
        .. table.concat( self, " ;\n    " ) .. " .\n"
end

function Turtle:literal( value, lang_or_type )
    local str
    if type(value) == "string" then
        str = value:gsub('(["\\\t\n\r])',function(c)
            return Turtle.literal_escape[c]
        end)
        str = '"'..str..'"'
        if lang_or_type and lang_or_type ~= '' then
            if lang_or_type:find('^[a-z][a-z]$') then -- TODO: less restrictive
                str = str .. '@' .. lang_or_type
            elseif self:use_uri( lang_or_type ) then
                str = str .. '^^' .. lang_or_type
            else
                return
            end
        end
        -- TODO: add type_or_lang
    elseif type(value) == "number" then
        str = value
    end
    return str
end


-------------------------------------------------------------------------------
--- Transforms a bibliographic PICA+ record
-------------------------------------------------------------------------------
function bibrecord(record, ttl)
    ttl:addlink('a','dct:BibliographicResource')

    dc = record:map({
       ['dc:title'] = {'021A','a'},
       ['dct:extent'] = {'034D','a'}, -- TODO: add 034M    $aIll., graph. Darst.
    })

    for key,value in pairs(dc) do
        ttl:add( key, value )
    end

    ttl:add( "dct:issued", record:first('011@','a'), 'xsd:gYear' ) -- TODO: check datatype

    -- The following code will further be simplified to something like:
    -- record:all('045Q','8', function(v) 
    --      local _,_,n = v:find('(%d%d\.%d%d)')
    --      if n then return n end
    --)
    -- or with http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html 
    --  record:all('045Q','8', re.compile('(%d%d\.%d%d)') )
    local bklinks = record:all('045Q','8')
    for k,bk in pairs(bklinks) do
        _,_,notation = bk:find('(%d%d\.%d%d)')
        if (notation) then
            ttl:addlink( 'dc:subject', '<http://uri.gbv.de/terminology/bk/'..notation..'>' )
        end
    end

    -- TODO: use filter function instead of loop
    local swd = record:all('041A','8')
    for _,s in ipairs(swd) do
        _,_,swdid = s:find('ID:%s*(%d+)')
        if swdid then
            ttl:addlink( 'dc:subject', '<http://d-nb.info/gnd/'..swdid..'>' )
        end
    end
end

-------------------------------------------------------------------------------
--- Transforms an authority record
-------------------------------------------------------------------------------
function  authorityrecord(record,ttl)
    -- TODO
    -- local type = record:first('022@','0'):sub(2,1)
    -- ...
end

-------------------------------------------------------------------------------
--- Main conversion
function main(s)
    record = PicaRecord.new( s )

    local ttl

    local type = record:first('002@','0')
    if not type then
        return "# Type not found"
    end

    local err

    if type:find('^[ABCEGHKMOSVZ]') then

        local eki = record:first('007G')
        eki = eki['c']..eki['0']
        if eki == "" then
            ttl = Turtle.new( "[ ]" )
            ttl:warn("EKI not found")
        else
            ttl = Turtle.new( "<info/eki:"..eki..">" )
            ttl:add( "dc:identifier", eki )
        end

        bibrecord(record,ttl)
    elseif type:find('^Tp') then -- Person

        local pnd = record:first('007S','0')
        if pnd == "" then
            ttl = Turtle.new( "[ ]" )
            ttl:warn("# Missing PND")
        else 
            ttl = Turtle.new( "<http://d-nb.info/gnd/" .. pnd..">" )
            ttl:add( "dc:identifier", pnd )
            authorityrecord(record, ttl)
        end

    else
        return "# Unknown record type: "..type
    end

    return tostring(ttl)
end

