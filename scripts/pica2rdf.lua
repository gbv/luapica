-------------------------------------------------------------------------------
-- Experimental demo conversion from PICA+ to RDF/Turtle.
-- @author Jakob Voss <voss@gbv.de>
-------------------------------------------------------------------------------

require 'pica'

-------------------------------------------------------------------------------
--- Main conversion
-- @param record a single record in PICA+ format (UTF-8)
-- @return string RDF/Turtle serialization
function main(record, source)
    if type(record) == "string" then
        record = PicaRecord.new(record)  
    end

    local t = record:first('002@','0')
    if not t then
        return "# Type not found"
    end

    local err
    local ttl = Turtle.new()

    if t:find('^[ABCEGHKMOSVZ]') then -- Bibliographic record
        bibrecord(record,ttl)
    elseif t:find('^Tp') then -- Person
        authority_person(record,ttl)
    elseif t:find('^T') then -- other kind of authority 
        authority(record,ttl)
    else
        return "# Unknown record type: "..t
    end

    return tostring(ttl) .. "\n# "..#ttl.." triples"
end


function recordidentifiers(record)
    local ids = { }

    local eki = record:first('007G'):join('','c','0')
    if eki ~= "" then 
        table.insert(ids, "<urn:nbn:de:eki/eki:"..eki..">" )
    end

    -- VD16 Nummern

    -- VD17 Nummern (incl. alte Nummern bei Zusammenführungen!)
    local vd17 = record:all('006Q|006W','0',
        patternfilter("^[0-9]+:[0-9]+[A-Z]$"), 
        formatfilter("<urn:nbn:de:vd17/%s>")
    )
    tableconcat(ids, vd17)

    -- VD18 (TODO)
    --  local vd18 = record:first('006M$0'), 007S

    -- OCLC-Nummer
    local oclc = record:first('003O','0')
    if (oclc ~= '') then
    --    table.insert(ids,'info/') -- TODO
    end

    return ids
end

-------------------------------------------------------------------------------
--- Transforms a bibliographic PICA+ record
-------------------------------------------------------------------------------
function bibrecord(record, ttl)

    local i,id
    for i,id in ipairs(recordidentifiers(record)) do
        if i == 1 then
            ttl:subject( id )
        else
            ttl:addlink( 'owl:sameAs', id )
        end
        -- ttl:add( "dc:identifier", eki )
    end

    ttl:addlink('a','dct:BibliographicResource')

    dc = record:map({
       ['dc:title'] = {'021A','a'},
       ['dct:extent'] = {'034D','a'}, -- TODO: add 034M    $aIll., graph. Darst.
    })

    for key,value in pairs(dc) do
        ttl:add( key, value )
    end

    ttl:add( "dct:issued", record:first('011@','a'), 'xsd:gYear' ) -- TODO: check datatype


    local bklinks = record:all('045Q','8',patternfilter('(%d%d\.%d%d)'))
    for _,notation in pairs(bklinks) do
        ttl:addlink( 'dc:subject', '<http://uri.gbv.de/terminology/bk/'..notation..'>' )
    end

    local swd = record:all('041A','8',patternfilter('D\-ID:%s*(%d+)'))
    for _,swdid in ipairs(swd) do
        ttl:addlink( 'dc:subject', '<http://d-nb.info/gnd/'..swdid..'>' )
    end


    --- TODO: Digitalisat (z.B. http://nbn-resolving.org/urn:nbn:de:gbv:3:1-73723 )
end

--- Trim a string
function trim(s) return s:match'^%s*(.*%S)' or '' end

-------------------------------------------------------------------------------
--- Transforms a PICA+ authority record about a person
-------------------------------------------------------------------------------
function  authority_person(rec,ttl)
    ttl:addlink('a','foaf:Person')
    ttl:addlink('a','skos:Concept')

    local pnd = rec:first('007S','0')
    if pnd == "" then
        ttl:warn("Missing PND!")
    else 
        ttl:subject( "<http://d-nb.info/gnd/" .. pnd..">" )
        ttl:add( "dc:identifier", pnd )
    end

    ttl:add( "dc:identifier", rec:first('003@','0' ))

    local name = rec:first('028A'):join(' ', -- join with space
      'e','d','a','5',    -- selected subfields in this order
      { 'f', formatfilter('(%s)') } -- also with filters
    )

    if name ~= '' then
        ttl:add("skos:prefLabel",name) 
        ttl:add("foaf:name",name) 
    end
    -- 028A $dVannevar$aBush
end

-------------------------------------------------------------------------------
--- Transforms PICA+ authority record
-------------------------------------------------------------------------------
function  authority(rec,ttl)
    ttl:addlink('a','skos:Concept')
    -- ...
end

-------------------------------------------------------------------------------
--- Simple turtle serializer.
-- This class provides a handy serializer form a limited subset of RDF/Turtle
-- format. Each instances stores multiple RDF statements with the same subject.
-- 
-- @class table
-- @name Turtle
-------------------------------------------------------------------------------
Turtle = {

    -- static properties
    popular_namespaces = {
        bibo = 'http://purl.org/ontology/bibo/',
        dc   = 'http://purl.org/dc/elements/1.1/',
        dct  = 'http://purl.org/dc/terms/',
        foaf = 'http://xmlns.com/foaf/0.1/',
        frbr = 'http://purl.org/vocab/frbr/core#',
        skos = 'http://www.w3.org/2004/02/skos/core#',
        xsd  = 'http://www.w3.org/2001/XMLSchema#',
        owl  = 'http://www.w3.org/2002/07/owl#',
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

    -- # ttl returns the number of triples
}

--- Creates a new Turtle serializer.
-- @param subject the subject for all triples
function Turtle.new( subject )
    local tt = {
        warnings = { },
        namespaces = { }
    }
    setmetatable(tt,Turtle)
    tt:subject( subject or "[ ]" )
    return tt
end

--- Set the triple's subject.
function Turtle:subject( subject )
    self.subj = subject
end
 
--- Add a warning message.
-- @param message string to add as warning. Trailing whitespaces are removed.
function Turtle:warn( message )
    message = message:gsub("%s+$","")
    table.insert( self.warnings, message )
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

    local warnings,w = {}
    for _,w in ipairs(self.warnings) do
        w = "# "..w:gsub("\n","\n# ")
        table.insert( warnings, w )
    end

    return ns .. self.subj 
        .. table.concat( self, " ;\n    " ) .. " .\n" 
        .. table.concat( warnings, "\n" )
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

