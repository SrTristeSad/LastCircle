-- RFC 6455 binary frame codec. Server frames must be unmasked;
-- every client frame is masked with 4 CSPRNG bytes.
local Codec=require("src.survev.ws_codec")
local Frame={MAX_PAYLOAD=8*1024*1024}
local function u16(n) return string.char(math.floor(n/256)%256,n%256) end
local function u64(n)
    local high=math.floor(n/4294967296)
    local low=n%4294967296
    return string.char(math.floor(high/16777216)%256,math.floor(high/65536)%256,
        math.floor(high/256)%256,high%256,math.floor(low/16777216)%256,
        math.floor(low/65536)%256,math.floor(low/256)%256,low%256)
end
local function readU16(b,i)
    local a,c=b:byte(i,i+1)
    return a*256+c
end
local function xorByte(a,b)
    local x=0;local power=1
    for _=1,8 do
        if a%2~=b%2 then x=x+power end
        a=math.floor(a/2);b=math.floor(b/2)
        power=power*2
    end
    return x
end
local function applyMask(body,mask)
    local parts={}
    for i=1,#body,4096 do
        local endIndex=math.min(#body,i+4095)
        local bytes={}
        for j=i,endIndex do
            bytes[#bytes+1]=string.char(xorByte(body:byte(j),mask:byte((j-1)%4+1)))
        end
        parts[#parts+1]=table.concat(bytes)
    end
    return table.concat(parts)
end
function Frame.encode(body,opcode,mask)
    assert(type(body)=="string","frame must contain string bytes")
    assert(#body<=Frame.MAX_PAYLOAD,"frame too large")
    opcode=opcode or 2
    assert(opcode==0 or opcode==1 or opcode==2 or opcode==8 or opcode==9 or opcode==10,
        "invalid WebSocket opcode")
    if opcode>=8 then assert(#body<=125,"control frame must be <=125 bytes") end
    mask=mask or Codec.randomBytes(4)
    assert(type(mask)=="string" and #mask==4,"mask must have 4 bytes")
    local n=#body
    local header=string.char(128+opcode)
    if n<=125 then header=header..string.char(128+n)
    elseif n<=65535 then header=header..string.char(128+126)..u16(n)
    else header=header..string.char(128+127)..u64(n) end
    return header..mask..applyMask(body,mask)
end

-- Try to parse exactly one SERVER frame. A nil frame means incomplete input.
-- On malformed traffic return (nil, buffer, descriptiveError).
function Frame.tryDecode(buffer)
    assert(type(buffer)=="string")
    if #buffer<2 then return nil,buffer end
    local a,b=buffer:byte(1,2)
    local fin=math.floor(a/128)%2==1
    local rsv=math.floor(a/16)%8
    local opcode=a%16
    if rsv~=0 then return nil,buffer,"unsupported WebSocket RSV bits" end
    if opcode~=0 and opcode~=1 and opcode~=2 and opcode~=8 and opcode~=9 and opcode~=10 then
        return nil,buffer,"unsupported WebSocket opcode"
    end
    if b>=128 then return nil,buffer,"masked server-to-client frame prohibited" end
    local length=b%128
    local offset=3
    if length==126 then
        if #buffer<4 then return nil,buffer end
        length=readU16(buffer,3)
        offset=5
        if length<126 then return nil,buffer,"non-minimal 16-bit length" end
    elseif length==127 then
        if #buffer<10 then return nil,buffer end
        local high=0
        for i=3,6 do high=high*256+buffer:byte(i) end
        local low=0
        for i=7,10 do low=low*256+buffer:byte(i) end
        if high>=2147483648 then return nil,buffer,"invalid 64-bit MSB" end
        length=high*4294967296+low
        offset=11
        if length<=65535 then return nil,buffer,"non-minimal 64-bit length" end
    end
    if length>Frame.MAX_PAYLOAD then return nil,buffer,"WebSocket payload too large" end
    if opcode>=8 then
        if not fin then return nil,buffer,"fragmented control frame" end
        if length>125 or (opcode==8 and length==1) then
            return nil,buffer,"invalid control payload size"
        end
    end
    local last=offset+length-1
    if #buffer<last then return nil,buffer end
    return {fin=fin,opcode=opcode,payload=buffer:sub(offset,last)},buffer:sub(last+1)
end
-- Helpers for deterministic unit testing of server frames (without masking).
function Frame.encodeServerForTest(body,opcode,fin)
    assert(type(body)=="string")
    opcode=opcode or 2
    local n=#body
    local header=string.char((fin==false and 0 or 128)+opcode)
    if n<=125 then header=header..string.char(n)
    elseif n<=65535 then header=header..string.char(126)..u16(n)
    else header=header..string.char(127)..u64(n) end
    return header..body
end
function Frame.decodeMaskedClientForTest(data)
    local a,b=data:byte(1,2)
    assert(a and b and b>=128,"client frame expected")
    local n=b%128
    local offset=3
    if n==126 then n=readU16(data,3);offset=5
    elseif n==127 then
        n=0
        for j=3,10 do n=n*256+data:byte(j) end
        offset=11
    end
    local mask=data:sub(offset,offset+3)
    local payload=data:sub(offset+4,offset+3+n)
    assert(#payload==n,"client frame truncated")
    return {opcode=a%16,fin=a>=128,payload=applyMask(payload,mask)}
end
return Frame
