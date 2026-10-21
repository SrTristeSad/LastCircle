-- RFC 6455: SHA-1 + Base64 handshake utilities independent of LOVE/LuaSec.
-- No network or game rules here. Lua 5.4 / LuaJIT compatible.
local Codec = {}
local MOD = 4294967296
local function band(a,b)
    local result,bit=0,1
    a=a%MOD;b=b%MOD
    while a>0 and b>0 do
        if a%2==1 and b%2==1 then result=result+bit end
        a=math.floor(a/2);b=math.floor(b/2);bit=bit*2
    end
    return result
end
local function bxor(a,b)
    local result,bit=0,1
    a=a%MOD;b=b%MOD
    while a>0 or b>0 do
        if a%2~=b%2 then result=result+bit end
        a=math.floor(a/2);b=math.floor(b/2);bit=bit*2
    end
    return result
end
local function bor(a,b)
    return (a + b - band(a,b))%MOD
end
local function bnot(a) return 4294967295 - a%MOD end
local function rol(a,n) return (a*2^n + math.floor(a/2^(32-n)))%MOD end
local function fourBytes(n)
    return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,
        math.floor(n/256)%256,n%256)
end
function Codec.sha1(data)
    assert(type(data)=="string")
    local bitLen=#data*8
    data=data..string.char(128)
    local padding=(56 - #data%64)%64
    data=data..string.rep("\0",padding)
    local high=math.floor(bitLen/MOD)
    local low=bitLen%MOD
    data=data..fourBytes(high)..fourBytes(low)
    local h0,h1,h2,h3,h4=0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
    for chunk=1,#data,64 do
        local w={}
        for i=0,15 do
            local at=chunk+i*4
            local a,b,c,d=data:byte(at,at+3)
            w[i]=(a*16777216+b*65536+c*256+d)%MOD
        end
        for i=16,79 do
            w[i]=rol(bxor(bxor(w[i-3],w[i-8]),bxor(w[i-14],w[i-16])),1)
        end
        local a,b,c,d,e=h0,h1,h2,h3,h4
        for i=0,79 do
            local f,k
            if i<20 then f=bor(band(b,c),band(bnot(b),d));k=0x5A827999
            elseif i<40 then f=bxor(bxor(b,c),d);k=0x6ED9EBA1
            elseif i<60 then
                f=bor(bor(band(b,c),band(b,d)),band(c,d));k=0x8F1BBCDC
            else f=bxor(bxor(b,c),d);k=0xCA62C1D6 end
            local temp=(rol(a,5)+f+e+k+w[i])%MOD
            e,d,c,b,a=d,c,rol(b,30),a,temp
        end
        h0=(h0+a)%MOD;h1=(h1+b)%MOD;h2=(h2+c)%MOD
        h3=(h3+d)%MOD;h4=(h4+e)%MOD
    end
    return fourBytes(h0)..fourBytes(h1)..fourBytes(h2)..fourBytes(h3)..fourBytes(h4)
end
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function Codec.base64(data)
    local out={}
    for i=1,#data,3 do
        local a,b,c=data:byte(i,i+2)
        local n=a*65536+(b or 0)*256+(c or 0)
        local s={}
        for j=3,0,-1 do
            local idx=math.floor(n/(64^j))%64+1
            s[#s+1]=alphabet:sub(idx,idx)
        end
        if not c then s[4]="=" end
        if not b then s[3]="=" end
        out[#out+1]=table.concat(s)
    end
    return table.concat(out)
end
function Codec.accept(key)
    return Codec.base64(Codec.sha1(key.."258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
end

-- Fail closed when no OS CSPRNG is available (never Math.random for WS masks).
-- Injectable random function is used in tests only.
function Codec.randomBytes(n)
    assert(n>=1 and n<=1024)
    local ok,ffi=pcall(require,"ffi")
    if ok and ffi and ffi.os=="Windows" then
        ffi.cdef[[
            typedef unsigned long DWORD;
            long BCryptGenRandom(void *,unsigned char *,unsigned long,unsigned long);
        ]]
        local bcrypt=ffi.load("bcrypt")
        local out=ffi.new("unsigned char[?]",n)
        local code=bcrypt.BCryptGenRandom(nil,out,n,2)
        assert(code==0,"Windows CSPRNG BCryptGenRandom failure")
        return ffi.string(out,n)
    end
    local file=io.open("/dev/urandom","rb")
    assert(file,"OS secure random source unavailable")
    local data=file:read(n)
    file:close()
    assert(data and #data==n,"OS random read incomplete")
    return data
end

return Codec
