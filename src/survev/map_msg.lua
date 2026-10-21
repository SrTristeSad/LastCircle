-- Complete field layout port from shared/net/mapMsg.ts, Survev commit c6185e31.
-- Source controls procedural map seed, terrain, rivers and object definitions.
-- This parses map packets; the graphical/world renderer is NOT ported yet.
local Net=require("src.survev.net")
local Map={}
Map.__index=Map

local function writeRiver(s,data)
    s:writeUint8(data.width)
    s:writeUint8(data.looped and 1 or 0)
    s:writeArray(data.points,8,function(pos) s:writeMapPos(pos) end)
end
local function readRiver(s)
    return {width=s:readUint8(),looped=s:readUint8()~=0,
        points=s:readArray(8,function() return s:readMapPos() end)}
end
local function writePlace(s,place)
    s:writeString(place.name)
    s:writeVec(place.pos,0,0,1,1,16)
end
local function readPlace(s)
    return {name=s:readString(),pos=s:readVec(0,0,1,1,16)}
end
local function writeObject(s,obj)
    s:writeMapPos(obj.pos)
    s:writeFloat(obj.scale,Net.Constants.MapObjectMinScale,
        Net.Constants.MapObjectMaxScale,8)
    s:writeMapType(obj.type)
    s:writeBits(obj.ori,2)
    s:writeAlignToNextByte()
end
local function readObject(s)
    local obj={
        pos=s:readMapPos(),
        scale=s:readFloat(Net.Constants.MapObjectMinScale,
            Net.Constants.MapObjectMaxScale,8),
        type=s:readMapType(),
        ori=s:readBits(2),
    }
    s:readAlignToNextByte()
    return obj
end
local function writeGroundPatch(s,patch)
    s:writeCollider(patch.bound)
    s:writeUint32(patch.color)
    s:writeFloat32(patch.roughness)
    s:writeFloat32(patch.offsetDist)
    s:writeBits(patch.order or 0,7)
    s:writeBoolean(patch.useAsMapShape)
end
local function readGroundPatch(s)
    return {
        bound=s:readCollider(),
        color=s:readUint32(),
        roughness=s:readFloat32(),
        offsetDist=s:readFloat32(),
        order=s:readBits(7),
        useAsMapShape=s:readBoolean(),
    }
end
function Map.new()
    return setmetatable({
        mapName="",seed=0,width=0,height=0,shoreInset=0,grassInset=0,
        rivers={},places={},objects={},groundPatches={},
    },Map)
end
function Map:serialize(s)
    s:writeString(self.mapName,Net.Constants.MapNameMaxLen)
    s:writeUint32(self.seed)
    s:writeUint16(self.width)
    s:writeUint16(self.height)
    s:writeUint16(self.shoreInset)
    s:writeUint16(self.grassInset)
    s:writeArray(self.rivers,8,function(river) writeRiver(s,river) end)
    s:writeArray(self.places,8,function(place) writePlace(s,place) end)
    s:writeArray(self.objects,16,function(obj) writeObject(s,obj) end)
    s:writeArray(self.groundPatches,8,function(patch) writeGroundPatch(s,patch) end)
end
function Map:deserialize(s)
    self.mapName=s:readString(Net.Constants.MapNameMaxLen)
    self.seed=s:readUint32()
    self.width=s:readUint16()
    self.height=s:readUint16()
    self.shoreInset=s:readUint16()
    self.grassInset=s:readUint16()
    self.rivers=s:readArray(8,function() return readRiver(s) end)
    self.places=s:readArray(8,function() return readPlace(s) end)
    self.objects=s:readArray(16,function() return readObject(s) end)
    self.groundPatches=s:readArray(8,function() return readGroundPatch(s) end)
end
return Map
