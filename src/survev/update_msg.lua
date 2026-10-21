-- Survev shared/net/updateMsg.ts @ c6185e31fe25a4a07def77a2bb25b1710bda90ac.
-- GPL-3.0-or-later. Byte layout and flag order follow the original.
-- Does not synthesize gameplay; receives and encodes the authoritative update.
local Net=require("src.survev.net")
local Objects=require("src.survev.object_serialize_fns")
local Config=require("src.survev.game_config")
local C=Net.Constants
local U={}
U.__index=U
U.Flags={
    DeletedObjects=1, FullObjects=2, ActivePlayerId=4, Gas=8,
    GasCircle=16, PlayerInfos=32, DeletePlayerIds=64,
    PlayerStatus=128, GroupStatus=256, Bullets=512, Explosions=1024,
    Emotes=2048, Planes=4096, AirstrikeZones=8192,
    MapIndicators=16384, KillLeader=32768,
}
local F=U.Flags
local function has(flags,value) return math.floor(flags/value)%2==1 end
local function bool(s,v) s:writeBoolean(v) end
local function readBool(s) return s:readBoolean() end
local function gameType(s,type) s:writeGameType(type or "") end
local function bit(s,val,bits) s:writeBits(val,bits) end
local function writeLocal(s,d)
    bool(s,d.healthDirty)
    if d.healthDirty then s:writeFloat(d.health,0,100,8) end
    bool(s,d.boostDirty)
    if d.boostDirty then s:writeFloat(d.boost,0,100,8) end
    bool(s,d.zoomDirty)
    if d.zoomDirty then s:writeUint8(d.zoom) end
    bool(s,d.actionDirty)
    if d.actionDirty then
        s:writeFloat(d.action.time,0,C.ActionMaxDuration,8)
        s:writeFloat(d.action.duration,0,C.ActionMaxDuration,8)
        s:writeUint16(d.action.targetId)
    end
    bool(s,d.inventoryDirty)
    if d.inventoryDirty then
        gameType(s,d.scope)
        for _,key in ipairs(Config.bagKeys) do
            local count=d.inventory[key] or 0
            bool(s,count>0)
            if count>0 then bit(s,count,9) end
        end
    end
    bool(s,d.weapsDirty)
    if d.weapsDirty then
        bit(s,d.curWeapIdx,2)
        for i=1,Config.WeaponSlot.Count do
            local weap=d.weapons[i]
            gameType(s,weap.type)
            s:writeUint8(weap.ammo)
        end
    end
    bool(s,d.spectatorCountDirty)
    if d.spectatorCountDirty then s:writeUint8(d.spectatorCount) end
    s:writeAlignToNextByte()
end
local function readLocal(s)
    local d={}
    d.healthDirty=readBool(s)
    if d.healthDirty then d.health=s:readFloat(0,100,8) end
    d.boostDirty=readBool(s)
    if d.boostDirty then d.boost=s:readFloat(0,100,8) end
    d.zoomDirty=readBool(s)
    if d.zoomDirty then d.zoom=s:readUint8() end
    d.actionDirty=readBool(s)
    if d.actionDirty then
        d.action={
            time=s:readFloat(0,C.ActionMaxDuration,8),
            duration=s:readFloat(0,C.ActionMaxDuration,8),
            targetId=s:readUint16(),
        }
    end
    d.inventoryDirty=readBool(s)
    if d.inventoryDirty then
        d.scope=s:readGameType()
        d.inventory={}
        for _,key in ipairs(Config.bagKeys) do
            local count=0
            if readBool(s) then count=s:readBits(9) end
            d.inventory[key]=count
        end
    end
    d.weapsDirty=readBool(s)
    if d.weapsDirty then
        d.curWeapIdx=s:readBits(2)
        d.weapons={}
        for i=1,Config.WeaponSlot.Count do
            d.weapons[i]={type=s:readGameType(),ammo=s:readUint8()}
        end
    end
    d.spectatorCountDirty=readBool(s)
    if d.spectatorCountDirty then d.spectatorCount=s:readUint8() end
    s:readAlignToNextByte()
    return d
end

local function writePlayerStatus(s,players)
    s:writeArray(players,8,function(p)
        bool(s,p.hasData)
        if p.hasData then
            s:writeMapPos(p.pos,11)
            bool(s,p.visible);bool(s,p.dead);bool(s,p.downed)
            local hasRole=(p.role or "")~=""
            bool(s,hasRole)
            if hasRole then gameType(s,p.role) end
        end
    end)
    s:writeAlignToNextByte()
end
local function readPlayerStatus(s)
    local result=s:readArray(8,function()
        local p={hasData=readBool(s)}
        if p.hasData then
            p.pos=s:readMapPos(11)
            p.visible=readBool(s)
            p.dead=readBool(s)
            p.downed=readBool(s)
            p.role=readBool(s) and s:readGameType() or ""
        end
        return p
    end)
    s:readAlignToNextByte()
    return result
end
local function writeGroupStatus(s,players)
    s:writeArray(players,8,function(p)
        s:writeFloat(p.health,0,100,7)
        bool(s,p.disconnected)
    end)
end
local function readGroupStatus(s)
    return s:readArray(8,function()
        return {health=s:readFloat(0,100,7),disconnected=readBool(s)}
    end)
end
local function writeInfo(s,info)
    s:writeUint16(info.playerId)
    s:writeUint8(info.teamId)
    s:writeUint8(info.groupId)
    s:writeString(info.name)
    gameType(s,info.loadout.heal)
    gameType(s,info.loadout.boost)
    s:writeAlignToNextByte()
end
local function readInfo(s)
    local d={playerId=s:readUint16(),teamId=s:readUint8(),groupId=s:readUint8(),name=s:readString()}
    d.loadout={heal=s:readGameType(),boost=s:readGameType()}
    s:readAlignToNextByte()
    return d
end
local function writeGas(s,d)
    s:writeUint8(d.mode)
    s:writeFloat32(d.duration)
    s:writeMapPos(d.posOld)
    s:writeMapPos(d.posNew)
    s:writeFloat(d.radOld,0,2048,16)
    s:writeFloat(d.radNew,0,2048,16)
end
local function readGas(s)
    return {
        mode=s:readUint8(),
        duration=s:readFloat32(),
        posOld=s:readMapPos(),
        posNew=s:readMapPos(),
        radOld=s:readFloat(0,2048,16),
        radNew=s:readFloat(0,2048,16),
    }
end

local function writeBullet(s,b)
    s:writeUint16(b.playerId)
    s:writeMapPos(b.startPos or b.pos)
    s:writeUnitVec(b.dir,8)
    gameType(s,b.bulletType)
    bit(s,b.layer,2)
    s:writeFloat(b.varianceT,0,1,4)
    bit(s,b.distAdjIdx,4)
    bool(s,b.clipDistance)
    if b.clipDistance then s:writeFloat(b.distance,0,C.MaxPosition,16) end
    bool(s,b.shotFx)
    if b.shotFx then
        gameType(s,b.shotSourceType)
        bool(s,b.shotOffhand);bool(s,b.lastShot)
    end
    bool(s,b.reflectCount>0)
    if b.reflectCount>0 then
        bit(s,b.reflectCount,2)
        s:writeUint16(b.reflectObjId)
    end
    bool(s,b.hasModifier)
    if b.hasModifier then
        s:writeFloat(b.speedMult,.5,2,8)
        s:writeFloat(b.distanceMult,.5,2,8)
    end
    bool(s,b.hasSpecialFx)
    if b.hasSpecialFx then
        bool(s,b.shotAlt);bool(s,b.splinter);bool(s,b.trailSaturated)
        bool(s,b.apRounds);bool(s,b.highVelocity);bool(s,b.combatStims)
        bool(s,b.trailSmall);bool(s,b.trailThick)
    end
end
local function readBullet(s)
    local b={}
    b.playerId=s:readUint16()
    b.pos=s:readMapPos()
    b.startPos=b.pos
    b.dir=s:readUnitVec(8)
    b.bulletType=s:readGameType()
    b.layer=s:readBits(2)
    b.varianceT=s:readFloat(0,1,4)
    b.distAdjIdx=s:readBits(4)
    b.clipDistance=readBool(s)
    if b.clipDistance then b.distance=s:readFloat(0,C.MaxPosition,16) end
    b.shotFx=readBool(s)
    if b.shotFx then
        b.shotSourceType=s:readGameType()
        b.shotOffhand=readBool(s);b.lastShot=readBool(s)
    end
    b.reflectCount=0;b.reflectObjId=0
    if readBool(s) then
        b.reflectCount=s:readBits(2)
        b.reflectObjId=s:readUint16()
    end
    b.speedMult=1;b.distanceMult=1
    b.hasModifier=readBool(s)
    if b.hasModifier then
        b.speedMult=s:readFloat(.5,2,8)
        b.distanceMult=s:readFloat(.5,2,8)
    end
    b.hasSpecialFx=readBool(s)
    if b.hasSpecialFx then
        b.shotAlt=readBool(s);b.splinter=readBool(s);b.trailSaturated=readBool(s)
        b.apRounds=readBool(s);b.highVelocity=readBool(s);b.combatStims=readBool(s)
        b.trailSmall=readBool(s);b.trailThick=readBool(s)
    end
    return b
end
local function writeExplosion(s,e)
    s:writeMapPos(e.pos);gameType(s,e.type);bit(s,e.layer,2)
    s:writeAlignToNextByte()
end
local function readExplosion(s)
    local e={pos=s:readMapPos(),type=s:readGameType(),layer=s:readBits(2)}
    s:readAlignToNextByte()
    return e
end
local function writeEmote(s,e)
    s:writeUint16(e.playerId)
    gameType(s,e.type);gameType(s,e.itemType)
    bool(s,e.isPing)
    if e.isPing then s:writeMapPos(e.pos) end
    s:writeAlignToNextByte()
end
local function readEmote(s)
    local e={playerId=s:readUint16(),type=s:readGameType(),itemType=s:readGameType(),isPing=readBool(s)}
    if e.isPing then e.pos=s:readMapPos() end
    s:readAlignToNextByte()
    return e
end
local function writePlane(s,p)
    s:writeUint8(p.id)
    s:writeVec(p.pos,-256,-256,C.MaxPosition+256,C.MaxPosition+256,10)
    s:writeUnitVec(p.planeDir,8)
    bool(s,p.actionComplete)
    bit(s,p.action,3)
end
local function readPlane(s)
    local p={id=s:readUint8()}
    p.pos=s:readVec(-256,-256,C.MaxPosition+256,C.MaxPosition+256,10)
    p.planeDir=s:readUnitVec(8)
    p.actionComplete=readBool(s)
    p.action=s:readBits(3)
    return p
end
local function writeAirstrike(s,z)
    s:writeMapPos(z.pos,12)
    s:writeFloat(z.rad,0,C.AirstrikeZoneMaxRad,8)
    s:writeFloat(z.duration,0,C.AirstrikeZoneMaxDuration,8)
end
local function readAirstrike(s)
    return {pos=s:readMapPos(12),rad=s:readFloat(0,C.AirstrikeZoneMaxRad,8),
        duration=s:readFloat(0,C.AirstrikeZoneMaxDuration,8)}
end
local function writeIndicator(s,i)
    bit(s,i.id,4);bool(s,i.dead);bool(s,i.equipped)
    gameType(s,i.type);s:writeMapPos(i.pos)
end
local function readIndicator(s)
    return {id=s:readBits(4),dead=readBool(s),equipped=readBool(s),
        type=s:readGameType(),pos=s:readMapPos()}
end

function U.new()
    return setmetatable({
        delObjIds={}, fullObjects={}, partObjects={},
        activePlayerId=0,activePlayerIdDirty=false,
        activePlayerData={},gasDirty=false,gasT=0,gasTDirty=false,
        playerInfos={},deletedPlayerIds={},playerStatus={},
        playerStatusDirty=false,groupStatus={},groupStatusDirty=false,
        bullets={},explosions={},emotes={},planes={},airstrikeZones={},
        mapIndicators={},killLeaderId=0,killLeaderKills=0,
        killLeaderDirty=false,ack=0,
    },U)
end

function U:serialize(s)
    local flags=0
    local flagsIndex=s.index
    s:writeUint16(0)
    if #self.delObjIds>0 then
        s:writeArray(self.delObjIds,16,function(id) s:writeUint16(id) end)
        flags=flags+F.DeletedObjects
    end
    if #self.fullObjects>0 then
        s:writeArray(self.fullObjects,16,function(obj)
            local o=Objects[obj.__type]
            assert(o and obj.__type~=0,"invalid Survev object type")
            s:writeUint8(obj.__type)
            s:writeUint16(obj.__id)
            o.serializePart(s,obj)
            s:writeAlignToNextByte()
            o.serializeFull(s,obj)
            s:writeAlignToNextByte()
        end)
        flags=flags+F.FullObjects
    end
    -- PartObjects has no conditional flag; its length field is unconditional.
    s:writeArray(self.partObjects,16,function(obj)
        local o=Objects[obj.__type]
        assert(o and obj.__type~=0,"invalid Survev object type")
        s:writeUint8(obj.__type)
        s:writeUint16(obj.__id)
        o.serializePart(s,obj)
        s:writeAlignToNextByte()
    end)
    if self.activePlayerIdDirty then
        s:writeUint16(self.activePlayerId)
        flags=flags+F.ActivePlayerId
    end
    writeLocal(s,self.activePlayerData)
    if self.gasDirty then writeGas(s,self.gasData);flags=flags+F.Gas end
    if self.gasTDirty then
        s:writeFloat(self.gasT,0,1,16)
        flags=flags+F.GasCircle
    end
    if #self.playerInfos>0 then
        s:writeArray(self.playerInfos,8,function(info) writeInfo(s,info) end)
        flags=flags+F.PlayerInfos
    end
    if #self.deletedPlayerIds>0 then
        s:writeArray(self.deletedPlayerIds,8,function(id) s:writeUint16(id) end)
        flags=flags+F.DeletePlayerIds
    end
    if self.playerStatusDirty then
        writePlayerStatus(s,self.playerStatus)
        flags=flags+F.PlayerStatus
    end
    if self.groupStatusDirty then
        writeGroupStatus(s,self.groupStatus)
        flags=flags+F.GroupStatus
    end
    if #self.bullets>0 then
        s:writeArray(self.bullets,8,function(b) writeBullet(s,b) end)
        s:writeAlignToNextByte()
        flags=flags+F.Bullets
    end
    if #self.explosions>0 then
        s:writeArray(self.explosions,8,function(e) writeExplosion(s,e) end)
        flags=flags+F.Explosions
    end
    if #self.emotes>0 then
        s:writeArray(self.emotes,8,function(e) writeEmote(s,e) end)
        flags=flags+F.Emotes
    end
    if #self.planes>0 then
        s:writeArray(self.planes,8,function(p) writePlane(s,p) end)
        flags=flags+F.Planes
    end
    if #self.airstrikeZones>0 then
        s:writeArray(self.airstrikeZones,8,function(z) writeAirstrike(s,z) end)
        s:writeAlignToNextByte()
        flags=flags+F.AirstrikeZones
    end
    if #self.mapIndicators>0 then
        s:writeArray(self.mapIndicators,4,function(i) writeIndicator(s,i) end)
        s:writeAlignToNextByte()
        flags=flags+F.MapIndicators
    end
    if self.killLeaderDirty then
        s:writeUint16(self.killLeaderId)
        s:writeUint8(self.killLeaderKills)
        flags=flags+F.KillLeader
    end
    s:writeUint8(self.ack)
    local tail=s.index
    s.index=flagsIndex
    s:writeUint16(flags)
    s.index=tail
end

function U:deserialize(s)
    local flags=s:readUint16()
    self.flags=flags
    if has(flags,F.DeletedObjects) then
        self.delObjIds=s:readArray(16,function() return s:readUint16() end)
    end
    if has(flags,F.FullObjects) then
        self.fullObjects=s:readArray(16,function()
            local d={__type=s:readUint8(),__id=s:readUint16()}
            local o=Objects[d.__type]
            assert(o and d.__type~=0,"unknown Survev full object type "..tostring(d.__type))
            o.deserializePart(s,d)
            s:readAlignToNextByte()
            o.deserializeFull(s,d)
            s:readAlignToNextByte()
            return d
        end)
    end
    self.partObjects=s:readArray(16,function()
        local d={__type=s:readUint8(),__id=s:readUint16()}
        local o=Objects[d.__type]
        assert(o and d.__type~=0,"unknown Survev partial object type "..tostring(d.__type))
        o.deserializePart(s,d)
        s:readAlignToNextByte()
        return d
    end)
    self.activePlayerIdDirty=has(flags,F.ActivePlayerId)
    if self.activePlayerIdDirty then self.activePlayerId=s:readUint16() end
    self.activePlayerData=readLocal(s)
    self.gasDirty=has(flags,F.Gas)
    if self.gasDirty then self.gasData=readGas(s) end
    self.gasTDirty=has(flags,F.GasCircle)
    if self.gasTDirty then self.gasT=s:readFloat(0,1,16) end
    if has(flags,F.PlayerInfos) then
        self.playerInfos=s:readArray(8,function() return readInfo(s) end)
    end
    if has(flags,F.DeletePlayerIds) then
        self.deletedPlayerIds=s:readArray(8,function() return s:readUint16() end)
    end
    self.playerStatusDirty=has(flags,F.PlayerStatus)
    if self.playerStatusDirty then self.playerStatus=readPlayerStatus(s) end
    self.groupStatusDirty=has(flags,F.GroupStatus)
    if self.groupStatusDirty then self.groupStatus=readGroupStatus(s) end
    if has(flags,F.Bullets) then
        self.bullets=s:readArray(8,function() return readBullet(s) end)
        s:readAlignToNextByte()
    end
    if has(flags,F.Explosions) then
        self.explosions=s:readArray(8,function() return readExplosion(s) end)
    end
    if has(flags,F.Emotes) then
        self.emotes=s:readArray(8,function() return readEmote(s) end)
    end
    if has(flags,F.Planes) then
        self.planes=s:readArray(8,function() return readPlane(s) end)
    end
    if has(flags,F.AirstrikeZones) then
        self.airstrikeZones=s:readArray(8,function() return readAirstrike(s) end)
        s:readAlignToNextByte()
    end
    if has(flags,F.MapIndicators) then
        self.mapIndicators=s:readArray(4,function() return readIndicator(s) end)
        s:readAlignToNextByte()
    end
    self.killLeaderDirty=has(flags,F.KillLeader)
    if self.killLeaderDirty then
        self.killLeaderId=s:readUint16()
        self.killLeaderKills=s:readUint8()
    end
    self.ack=s:readUint8()
end
function U.getPlayerStatusUpdateRate(factionMode)
    return factionMode and .5 or .25
end
return U
