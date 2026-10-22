-- Portable strict JSON for original Survev /api/find_game_v2.
-- No load(), eval(), external JSON package or string-pattern parsing of
-- untrusted server responses. Lua 5.1 (LÖVE/LuaJIT) + 5.4 compatible.
local J={}
local function utf8point(n)
    if n<0x80 then return string.char(n) end
    if n<0x800 then return string.char(0xc0+math.floor(n/64),0x80+n%64) end
    if n<0x10000 then
        return string.char(0xe0+math.floor(n/4096),0x80+math.floor(n/64)%64,0x80+n%64)
    end
    return string.char(0xf0+math.floor(n/262144),
        0x80+math.floor(n/4096)%64,0x80+math.floor(n/64)%64,0x80+n%64)
end
local null={}
J.null=null
function J.decode(text)
    assert(type(text)=="string" and #text<=262144,"invalid JSON response size")
    local pos,len=1,#text
    local function white()
        while pos<=len do
            local c=text:sub(pos,pos)
            if c==" " or c=="\n" or c=="\r" or c=="\t" then pos=pos+1
            else break end
        end
    end
    local function quoted()
        assert(text:sub(pos,pos)=='"',"JSON string expected")
        pos=pos+1
        local parts={}
        while pos<=len do
            local c=text:sub(pos,pos)
            if c=='"' then pos=pos+1;return table.concat(parts) end
            if c=="\\" then
                pos=pos+1
                c=text:sub(pos,pos)
                local esc={['"']='"',['\\']='\\',['/']='/',b="\b",
                    f="\f",n="\n",r="\r",t="\t"}
                if esc[c] then parts[#parts+1]=esc[c];pos=pos+1
                elseif c=="u" then
                    local hex=text:sub(pos+1,pos+4)
                    assert(#hex==4 and hex:match("^[0-9a-fA-F]+$"),"invalid unicode escape")
                    local point=tonumber(hex,16)
                    pos=pos+5
                    if point>=0xd800 and point<=0xdbff then
                        assert(text:sub(pos,pos+1)=="\\u","missing low surrogate")
                        local lowHex=text:sub(pos+2,pos+5)
                        assert(#lowHex==4 and lowHex:match("^[0-9a-fA-F]+$"),"invalid low surrogate")
                        local low=tonumber(lowHex,16)
                        assert(low>=0xdc00 and low<=0xdfff,"bad low surrogate")
                        point=0x10000+(point-0xd800)*1024+low-0xdc00
                        pos=pos+6
                    else
                        assert(point<0xdc00 or point>0xdfff,"unpaired low surrogate")
                    end
                    parts[#parts+1]=utf8point(point)
                else error("invalid JSON escape") end
            else
                assert(c:byte()>=32,"invalid JSON control byte")
                parts[#parts+1]=c;pos=pos+1
            end
        end
        error("unterminated JSON string")
    end
    local function parse(depth)
        assert(depth<=64,"JSON nesting too deep")
        white()
        local c=text:sub(pos,pos)
        if c=='"' then return quoted() end
        if c=="{" then
            pos=pos+1;white()
            local object={}
            if text:sub(pos,pos)=="}" then pos=pos+1;return object end
            while true do
                white()
                local key=quoted()
                assert(object[key]==nil,"duplicate JSON key")
                white();assert(text:sub(pos,pos)==":","expected JSON colon")
                pos=pos+1
                object[key]=parse(depth+1)
                white()
                c=text:sub(pos,pos);pos=pos+1
                if c=="}" then return object end
                assert(c==",","expected JSON object separator")
            end
        end
        if c=="[" then
            pos=pos+1;white()
            local list={}
            if text:sub(pos,pos)=="]" then pos=pos+1;return list end
            while true do
                list[#list+1]=parse(depth+1)
                white()
                c=text:sub(pos,pos);pos=pos+1
                if c=="]" then return list end
                assert(c==",","expected JSON array separator")
            end
        end
        local rest=text:sub(pos)
        for _,literal in ipairs({{"true",true},{"false",false},{"null",null}}) do
            if rest:sub(1,#literal[1])==literal[1] then
                pos=pos+#literal[1]
                return literal[2]
            end
        end
        local number=rest:match("^-?%d+%.?%d*[eE][+-]?%d+")
            or rest:match("^-?%d+%.?%d*")
        assert(number and number:match("^-?(0|[1-9])")~=false,"expected JSON value")
        -- Enforce number lexical grammar; no Lua number syntax extensions.
        assert(number:match("^-?%d+%.?%d*$") or
            number:match("^-?%d+%.?%d*[eE][+-]?%d+$"),"invalid JSON number")
        assert(not number:match("^%-?0%d"),"leading zero in JSON number")
        assert(not number:match("%.$"),"invalid JSON fraction")
        local n=tonumber(number)
        assert(n and n==n and math.abs(n)~=math.huge,"non-finite JSON number")
        pos=pos+#number;return n
    end
    local value=parse(0)
    white()
    assert(pos==len+1,"trailing JSON data")
    return value
end
local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        local escaped={['"']='\\"',['\\']='\\\\',['\b']='\\b',
            ['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
        return escaped[c] or string.format("\\u%04x",c:byte())
    end)..'"'
end
function J.encode(value)
    local function encode(v,depth)
        assert(depth<=64,"JSON nesting too deep")
        local t=type(v)
        if v==null then return "null" end
        if t=="string" then return quote(v) end
        if t=="boolean" then return tostring(v) end
        if t=="number" then
            assert(v==v and math.abs(v)~=math.huge,"invalid JSON number")
            return tostring(v)
        end
        assert(t=="table","unsupported JSON value")
        local count,max=0,0
        local array=true
        for k in pairs(v) do
            count=count+1
            if type(k)~="number" or k~=math.floor(k) or k<1 then
                array=false
            else max=math.max(max,k) end
        end
        if array and count==max and count>0 then
            local parts={}
            for i=1,max do parts[#parts+1]=encode(v[i],depth+1) end
            return "["..table.concat(parts,",").."]"
        end
        local parts={}
        for k,x in pairs(v) do
            assert(type(k)=="string","JSON object keys must be strings")
            parts[#parts+1]=quote(k)..":"..encode(x,depth+1)
        end
        table.sort(parts)
        return "{"..table.concat(parts,",").."}"
    end
    return encode(value,0)
end
return J
