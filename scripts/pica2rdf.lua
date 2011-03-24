require 'pica'

---
-- Experimental demo script for PICA+ to RDF conversion
---

-------------------------------------------------------------------------------
--- Simple turtle serialization object
-- Stores multiple RDF statements with the same subject.
Turtle = {
    known_namespaces = {
        dc   = 'http://purl.org/dc/elements/1.1/',
        dct  = 'http://purl.org/dc/terms/',
        bibo = 'http://purl.org/ontology/bibo/',
        frbr = 'http://purl.org/vocab/frbr/core#'
    },
    literal_escape = {
        ['"']   = "\\\"",
        ["\\"]  = "\\\\",
        ["\t"] = "\\t",
        ["\n"] = "\\n",
        ["\r"] = "\\r"
    }
}

Turtle.__index = function (tt,key)
    return Turtle[key]
end

function Turtle.new( subject )
    local tt = {
        subject = subject,
        namespaces = { }
    }
    setmetatable(tt,Turtle)
    return tt
end

--- Adds a statement (predicate and object)
-- empty strings as object values are ignored!
-- unknown predicate vocabularies are ignored!
function Turtle:add( predicate, object )
    if object == nil or object == "" then
        return false
    end

    if type(object) == "string" then
        object = self.literal(object)
    end

    if not self:use_uri( predicate ) then
        return false -- TODO. log error
    end

    table.insert( self, " " .. predicate .. ' ' .. object )
    return true
end

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
        if prefix and self.known_namespaces[prefix] then
            self.namespaces[prefix] = self.known_namespaces[prefix]
        else
            return false -- unknown prefix
        end
    end
    return true
end

function Turtle:__tostring()
    if #self == 0 then return "" end

    local ns = ""
    local prefix, uri

    for prefix, uri in pairs(self.namespaces) do
        ns = ns .. "@prefix "..prefix..": <"..uri.."> .\n"
    end
    if ns then ns = ns .. "\n" end

    return ns .. "<" .. self.subject .. ">"
        .. table.concat( self, " ;\n    " ) .. " .\n"
end

function Turtle.literal( value, type_or_lang )
    local str
    if type(value) == "string" then
        str = value:gsub('(["\\\t\n\r])',function(c)
            return Turtle.literal_escape[c]
        end)
        str = '"'..str..'"'
        -- TODO: add type_or_lang
    elseif type(value) == "number" then
        str = value
    end
    return str
end


-------------------------------------------------------------------------------
--- Main conversion
function main(s)
    record = PicaRecord.parse( s )

    eki = record:first('007G')
    if eki then
        eki = eki['c']..eki['0']
    end
    if (not eki) then
        return "# EKI not found"
    end

    local ttl = Turtle.new( "info/eki:"..eki )

    ttl:addlink('a','dct:BibliographicResource')
    ttl:add( "dc:identifier", eki )

    ttl:add( "dc:title", record:first('021A','a') )
    ttl:add( "dct:issued", record:first('011@','a') )

    ttl:add( "dct:extent", record:first('034D','a') ) -- TODO: add 034M    $aIll., graph. Darst.

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

    -- 041A $Ss$9491359985$8Ubuntu <Programm> ; SWD-ID: 48334261
    -- 041A/01 $Ss$9105105368$8Server ; SWD-ID: 42093247

    return tostring(ttl)
end

