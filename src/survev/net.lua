-- Port of the BitStream wire helpers / MsgStream framing from
-- survev/survev shared/net/net.ts @ c6185e31. GPL-3.0.
-- Does NOT provide a websocket client; does NOT imply server compatibility.
local Base = require("src.survev.bit_stream")
local Net = {}
Net.Constants = {
    MaxPosition = 1024,
    MapNameMaxLen = 24,
    PlayerNameMaxLen = 16,
    MouseMaxDist = 64,
    SmokeMaxRad = 10,
    ActionMaxDuration = 8.5,
    AirstrikeZoneMaxRad = 256,
    AirstrikeZoneMaxDuration = 60,
    PlayerMinScale = .75,
    PlayerMaxScale = 2,
    MapObjectMinScale = .125,
    MapObjectMaxScale = 2.5,
    MaxPerks = 8,
    MaxMapIndicators = 16,
}
Net.MsgType = {
    None=0, Join=1, _Disconnect=2, Input=3, Edit=4,
    Joined=5, Update=6, Kill=7, GameOver=8, Pickup=9,
    Map=10, Spectate=11, DropItem=12, Emote=13,
    PlayerStats=14, AdStatus=15, Loadout=16,
    RoleAnnouncement=17, Stats=18, UpdatePass=19,
    AliveCounts=20, PerkModeRoleSelect=21,
}
Net.PickupMsgType = {
    Full=0, AlreadyOwned=1, AlreadyEquipped=2,
    BetterItemEquipped=3, Success=4, GunCannotFire=5, MaxPerks=6,
}
local S={}
S.__index=S
setmetatable(S,{__index=Base})

-- registries={game={typeToId={},idToType={}},map={...}}
-- Empty string has ID zero in the original DefinitionRegister.
function Net.newStream(capacityOrBytes,registries)
    local instance=Base.new(capacityOrBytes)
    instance.registries=registries or {}
    return setmetatable(instance,S)
end
function S:writeString(str,len) self:writeASCIIString(str,len) end
function S:readString(len) return self:readASCIIString(len) end

function S:writeFloat(f,min,max,bits)
    assert(bits>0 and bits<31 and bits==math.floor(bits), "invalid float bit width")
    assert(max>min and f>=min and f<=max, "quantized float outside original range")
    local range=2^bits-1
    local x=math.max(min,math.min(max,f))
    local v=((x-min)/(max-min))*range+.5
    self:writeBits(math.floor(v),bits)
end
function S:readFloat(min,max,bits)
    assert(bits>0 and bits<31 and bits==math.floor(bits), "invalid float bit width")
    local q=self:readBits(bits)
    return min+(q/(2^bits-1))*(max-min)
end
function S:writeVec(v,minX,minY,maxX,maxY,bits)
    self:writeFloat(v.x,minX,maxX,bits)
    self:writeFloat(v.y,minY,maxY,bits)
end
function S:readVec(minX,minY,maxX,maxY,bits)
    return {x=self:readFloat(minX,maxX,bits),y=self:readFloat(minY,maxY,bits)}
end
function S:writeMapPos(v,bits)
    self:writeVec(v,0,0,1024,1024,bits or 16)
end
function S:readMapPos(bits)
    return self:readVec(0,0,1024,1024,bits or 16)
end
function S:writeUnitVec(v,bits)
    self:writeVec(v,-1.0001,-1.0001,1.0001,1.0001,bits)
end
function S:readUnitVec(bits)
    return self:readVec(-1.0001,-1.0001,1.0001,1.0001,bits)
end
function S:writeVec32(v) self:writeFloat32(v.x) self:writeFloat32(v.y) end
function S:readVec32() return {x=self:readFloat32(),y=self:readFloat32()} end

local function registryId(self,kind,name)
    if name=="" then return 0 end
    local reg=self.registries[kind]
    assert(reg and reg.typeToId and reg.typeToId[name]~=nil,
        "undefined "..kind.." game type: "..tostring(name))
    return reg.typeToId[name]
end
local function registryName(self,kind,id)
    if id==0 then return "" end
    local reg=self.registries[kind]
    assert(reg and reg.idToType and reg.idToType[id]~=nil,
        "undefined "..kind.." type id: "..tostring(id))
    return reg.idToType[id]
end
function S:writeGameType(name) self:writeBits(registryId(self,"game",name),10) end
function S:readGameType() return registryName(self,"game",self:readBits(10)) end
function S:writeMapType(name) self:writeBits(registryId(self,"map",name),12) end
function S:readMapType() return registryName(self,"map",self:readBits(12)) end

function S:writeArray(items,bits,writeFn)
    assert(type(items)=="table" and type(writeFn)=="function")
    assert(bits>0 and bits<31 and bits==math.floor(bits))
    local count=math.min(#items,2^bits-1)
    self:writeBits(count,bits)
    for i=1,count do writeFn(items[i],i-1) end
end
function S:readArray(bits,readFn)
    assert(bits>0 and bits<31 and bits==math.floor(bits))
    local n=self:readBits(bits)
    local t={}
    for i=1,n do t[i]=readFn(i-1) end
    return t
end
function S:writeBytes(other,offset,length)
    assert(self.index%8==0 and offset>=0 and length>=0
        and offset+length<=other:byteIndex(), "invalid aligned byte copy")
    local buffer=other:getBuffer()
    for i=offset+1,offset+length do self:writeUint8(buffer:byte(i)) end
end
-- Collider.Type: Circle=0, Aabb=1 (shared/utils/collider.ts).
function S:writeCollider(col)
    self:writeUint8(col.type)
    if col.type == 0 then
        self:writeMapPos(col.pos)
        self:writeFloat(col.rad,0,Net.Constants.MaxPosition,16)
    else
        self:writeMapPos(col.min)
        self:writeMapPos(col.max)
    end
end
function S:readCollider()
    local colliderType=self:readUint8()
    if colliderType == 0 then
        return {type=0,pos=self:readMapPos(),
            rad=self:readFloat(0,Net.Constants.MaxPosition,16)}
    end
    return {type=1,min=self:readMapPos(),max=self:readMapPos()}
end

Net.BitStream=S

local MsgStream={}
MsgStream.__index=MsgStream
function Net.newMsgStream(sizeOrBytes,registries)
    return setmetatable({stream=Net.newStream(sizeOrBytes,registries)},MsgStream)
end
function MsgStream:getStream() return self.stream end
function MsgStream:getBuffer() return self.stream:getBuffer() end
function MsgStream:serializeMsg(msgType,msg)
    assert(self.stream.index%8==0,"messages must start at byte boundary")
    assert(msg and type(msg.serialize)=="function","missing message serializer")
    self.stream:writeUint8(msgType)
    msg:serialize(self.stream)
    self.stream:writeAlignToNextByte()
end
function MsgStream:serializeMsgStream(msgType,source)
    assert(self.stream.index%8==0 and source.index%8==0,"unaligned message copy")
    self.stream:writeUint8(msgType)
    self.stream:writeBytes(source,0,source.index/8)
end
function MsgStream:deserializeMsgType()
    if self.stream:bitsLeft()>=8 then return self.stream:readUint8() end
    return Net.MsgType.None
end
Net.MsgStream=MsgStream

return Net
