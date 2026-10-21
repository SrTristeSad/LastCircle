-- Port of the little-endian bit order in shared/lib/bitBuffer.ts.
-- Written for LuaJIT/LÖVE 11.5 as well as Lua 5.1/5.4 (no 5.3 bit operators).
-- Only explicit capabilities are implemented; missing methods must error instead
-- of silently producing an incompatible packet.
local Stream = {}
Stream.__index = Stream

local function bytesFromString(data)
    local bytes = {}
    for i = 1, #data do bytes[i] = data:byte(i) end
    return bytes
end

function Stream.new(sizeOrData)
    local size, bytes
    if type(sizeOrData) == "string" then
        size, bytes = #sizeOrData, bytesFromString(sizeOrData)
    elseif type(sizeOrData) == "number" then
        assert(sizeOrData >= 0 and sizeOrData == math.floor(sizeOrData), "invalid buffer length")
        size, bytes = sizeOrData, {}
    else
        error("Stream.new expects capacity in bytes or a binary string")
    end
    return setmetatable({data=bytes, length=size*8, index=0}, Stream)
end

function Stream:bitsLeft() return self.length-self.index end
function Stream:byteIndex() return math.ceil(self.index/8) end
function Stream:check(bits)
    assert(type(bits)=="number" and bits == math.floor(bits) and bits >= 0
        and bits <= 32, "invalid bit count")
    if self.index + bits > self.length then error("bit stream out of bounds") end
end

function Stream:writeBits(value,bits)
    self:check(bits)
    assert(type(value)=="number" and value == value and value ~= math.huge
        and value ~= -math.huge, "invalid numeric bit value")
    assert(value == math.floor(value), "bit value must be integral")
    -- Two's complement/unsigned wrapping is the same as upstream setBits.
    value = value % (2^bits)
    for i=0,bits-1 do
        local byteIndex = math.floor(self.index/8)+1
        local shift = self.index % 8
        local mask = 2^shift
        local current = self.data[byteIndex] or 0
        local bitValue = value % 2
        local set = math.floor(current/mask)%2
        self.data[byteIndex] = current+(bitValue-set)*mask
        value = math.floor(value/2)
        self.index=self.index+1
    end
end

function Stream:readBits(bits,signed)
    self:check(bits)
    local value = 0
    local weight = 1
    for i=1,bits do
        local byteIndex = math.floor(self.index/8)+1
        local byte = self.data[byteIndex] or 0
        local mask = 2^(self.index%8)
        value = value+math.floor(byte/mask)%2*weight
        weight=weight*2
        self.index=self.index+1
    end
    if signed and bits > 0 and value >= 2^(bits-1) then
        value=value-2^bits
    end
    return value
end

function Stream:writeBoolean(b) self:writeBits(b and 1 or 0,1) end
function Stream:readBoolean() return self:readBits(1) ~= 0 end
for _,size in ipairs({8,16,32}) do
    Stream["writeUint"..size] = function(self,v) self:writeBits(v,size) end
    Stream["readUint"..size] = function(self) return self:readBits(size) end
    Stream["writeInt"..size] = function(self,v) self:writeBits(v,size) end
    Stream["readInt"..size] = function(self) return self:readBits(size,true) end
end

-- LÖVE provides love.data.pack, but plain LuaJIT test runners do not.
-- LuaJIT's built-in FFI is a portable fallback on little-endian hosts.
local haveFFI, ffi = pcall(require, "ffi")
if not haveFFI then ffi = nil end
local function requireLittleEndian()
    local check = ffi.new("uint16_t[1]", 0x0102)
    assert(ffi.cast("const uint8_t*", check)[0] == 0x02,
        "LuaJIT FFI float wire format requires little-endian host")
end
local function pack(fmt,v)
    if string.pack then return string.pack(fmt,v) end
    if love and love.data and love.data.pack then
        return love.data.pack("string",fmt,v)
    end
    if ffi then
        requireLittleEndian()
        local isFloat = fmt == "<f"
        assert(isFloat or fmt == "<d", "unsupported binary float")
        local ptr = ffi.new(isFloat and "float[1]" or "double[1]", v)
        return ffi.string(ffi.cast("const char*",ptr),isFloat and 4 or 8)
    end
    error("float packing requires Lua 5.3+, love.data or LuaJIT FFI")
end
local function unpack(fmt,str)
    if string.unpack then return string.unpack(fmt,str) end
    if love and love.data and love.data.unpack then
        return love.data.unpack(fmt,str)
    end
    if ffi then
        requireLittleEndian()
        local isFloat = fmt == "<f"
        assert(isFloat or fmt == "<d", "unsupported binary float")
        local len = isFloat and 4 or 8
        assert(#str == len, "invalid floating point byte count")
        local ptr = ffi.new(isFloat and "float[1]" or "double[1]")
        ffi.copy(ptr,str,len)
        return tonumber(ptr[0])
    end
    error("float unpacking requires Lua 5.3+, love.data or LuaJIT FFI")
end
local function writePacked(self,fmt,v)
    local s = pack(fmt,v)
    for i=1,#s do self:writeUint8(s:byte(i)) end
end
local function readPacked(self,fmt,len)
    local t={}
    for i=1,len do t[i]=string.char(self:readUint8()) end
    return unpack(fmt,table.concat(t))
end
function Stream:writeFloat32(v) writePacked(self,"<f",v) end
function Stream:readFloat32() return readPacked(self,"<f",4) end
function Stream:writeFloat64(v) writePacked(self,"<d",v) end
function Stream:readFloat64() return readPacked(self,"<d",8) end

-- Survev's ASCIIString uses JavaScript charCodeAt (UTF-16 units),
-- keeping ONLY the low byte of each unit. Latin-1 names like "José"
-- MUST work. This is intentionally NOT normal UTF-8 serialization.
local function codeUnitsLowBytes(str)
    local codes={}
    local i=1
    while i<=#str do
        local a=str:byte(i)
        local cp,n
        if a<128 then cp,n=a,1
        elseif a>=194 and a<=223 then
            local b=str:byte(i+1)
            assert(b and b>=128 and b<=191,"invalid UTF-8")
            cp,n=(a-192)*64+(b-128),2
        elseif a>=224 and a<=239 then
            local b,d=str:byte(i+1,i+2)
            assert(b and d and b>=128 and b<=191 and d>=128 and d<=191,
                "invalid UTF-8")
            cp,n=(a-224)*4096+(b-128)*64+(d-128),3
            assert(cp>=2048 and not(cp>=55296 and cp<=57343),"invalid UTF-8 code point")
        elseif a>=240 and a<=244 then
            local b,d,e=str:byte(i+1,i+3)
            assert(b and d and e and b>=128 and b<=191 and d>=128 and d<=191
                and e>=128 and e<=191,"invalid UTF-8")
            cp,n=(a-240)*262144+(b-128)*4096+(d-128)*64+(e-128),4
            assert(cp>=65536 and cp<=1114111,"invalid Unicode code point")
        else error("invalid UTF-8 lead byte") end
        if cp>65535 then
            local v=cp-65536
            codes[#codes+1]=(55296+math.floor(v/1024))%256
            codes[#codes+1]=(56320+v%1024)%256
        else codes[#codes+1]=cp%256 end
        i=i+n
    end
    return codes
end
local function latin1ToUtf8(c)
    if c<128 then return string.char(c) end
    return string.char(192+math.floor(c/64),128+c%64)
end
function Stream:writeASCIIString(str,bytes)
    assert(type(str)=="string","expected ASCII/Latin-1 string")
    local codes=codeUnitsLowBytes(str)
    local len=bytes and bytes>0 and bytes or (#codes+1)
    for i=1,len do self:writeUint8(codes[i] or 0) end
end
function Stream:readASCIIString(bytes)
    if bytes==0 then return "" end
    local fixed=bytes~=nil
    local size=bytes or math.floor(self:bitsLeft()/8)
    local result,accepting={},true
    for _=1,size do
        local ch=self:readUint8()
        if ch==0 then
            accepting=false
            if not fixed then break end
        elseif accepting then result[#result+1]=latin1ToUtf8(ch) end
    end
    return table.concat(result)
end
function Stream:writeUTF8String(str,bytes)
    local len = bytes and bytes > 0 and bytes or (#str+1)
    for i=1,len do self:writeUint8(str:byte(i) or 0) end
end
function Stream:readUTF8String(bytes) return self:readASCIIString(bytes) end

function Stream:writeAlignToNextByte()
    local pad = (8-self.index%8)%8
    if pad > 0 then self:writeBits(0,pad) end
end
function Stream:readAlignToNextByte()
    local pad = (8-self.index%8)%8
    if pad > 0 then self:readBits(pad) end
end
function Stream:getBuffer()
    local chunks={}
    for i=1,self:byteIndex() do chunks[i]=string.char(self.data[i] or 0) end
    return table.concat(chunks)
end
function Stream:getHex()
    return (self:getBuffer():gsub(".",function(c) return string.format("%02x",c:byte()) end))
end

return Stream
