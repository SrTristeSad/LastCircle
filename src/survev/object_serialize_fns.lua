-- Survev shared/net/objectSerializeFns.ts @ c6185e31fe25a4a07def77a2bb25b1710bda90ac.
-- Full/partial object wire layouts, written in Lua without inventing entity data.
-- GPL-3.0-or-later. ObjectType numeric IDs are immutable protocol IDs.
local N=require("src.survev.net")
local C=N.Constants
local O={}
O.Type={
    Invalid=0,Player=1,Obstacle=2,Loot=3,LootSpawner=4,DeadBody=5,
    Building=6,Structure=7,Decal=8,Projectile=9,Smoke=10,Airdrop=11
}
-- GameConfig enum counts: Action=5, Anim=9, Haste=4, MaxPerks=8.
local ACTION_BITS,ANIM_BITS,HASTE_BITS,PERK_BITS=3,4,2,3
local STRUCTURE_LAYERS=2
local PROJECTILE_MAX_Z=5

local function noOp() end
local function bp(s,v) s:writeBoolean(v) end
local function br(s) return s:readBoolean() end
local function copyNumAndVecPos(s,data) s:writeMapPos(data.pos) end
local function readPos(s,data) data.pos=s:readMapPos() end
local function wType(s,name) s:writeGameType(name or "") end

local player={
    serializedPartialSize=6, serializedFullSize=32,
    serializePart=function(s,d)
        s:writeMapPos(d.pos)
        s:writeUnitVec(d.dir,8)
    end,
    deserializePart=function(s,d)
        d.pos=s:readMapPos()
        d.dir=s:readUnitVec(8)
    end,
    serializeFull=function(s,d)
        wType(s,d.outfit);wType(s,d.backpack);wType(s,d.helmet)
        wType(s,d.chest);wType(s,d.activeWeapon)
        s:writeBits(d.layer,2)
        bp(s,d.dead);bp(s,d.downed)
        s:writeBits(d.animType,ANIM_BITS);s:writeBits(d.animSeq,3)
        s:writeBits(d.actionType,ACTION_BITS);s:writeBits(d.actionSeq,3)
        bp(s,d.wearingPan);bp(s,d.healEffect);bp(s,d.lastStandEffect)
        bp(s,d.frozen)
        if d.frozen then
            s:writeBits(d.frozenOri,2)
            wType(s,d.frozenType)
        end
        local haste=d.hasteType~=0
        bp(s,haste)
        if haste then
            s:writeBits(d.hasteType,HASTE_BITS)
            s:writeBits(d.hasteSeq,3)
        end
        local actionItem=(d.actionItem or "")~=""
        bp(s,actionItem)
        if actionItem then wType(s,d.actionItem) end
        local hasScale=d.scale~=1
        bp(s,hasScale)
        if hasScale then s:writeFloat(d.scale,C.PlayerMinScale,C.PlayerMaxScale,8) end
        local hasRole=(d.role or "")~=""
        bp(s,hasRole)
        if hasRole then wType(s,d.role) end
        local perks=d.perks or {}
        local hasPerks=#perks>0
        bp(s,hasPerks)
        if hasPerks then
            s:writeArray(perks,PERK_BITS,function(p)
                wType(s,p.type);bp(s,p.droppable)
            end)
        end
    end,
    deserializeFull=function(s,d)
        d.outfit=s:readGameType()
        d.backpack=s:readGameType()
        d.helmet=s:readGameType()
        d.chest=s:readGameType()
        d.activeWeapon=s:readGameType()
        d.layer=s:readBits(2)
        d.dead=br(s);d.downed=br(s)
        d.animType=s:readBits(ANIM_BITS);d.animSeq=s:readBits(3)
        d.actionType=s:readBits(ACTION_BITS);d.actionSeq=s:readBits(3)
        d.wearingPan=br(s);d.healEffect=br(s);d.lastStandEffect=br(s)
        d.frozen=br(s);d.frozenOri=0;d.frozenType=""
        if d.frozen then d.frozenOri=s:readBits(2);d.frozenType=s:readGameType() end
        d.hasteType=0;d.hasteSeq=-1
        if br(s) then d.hasteType=s:readBits(HASTE_BITS);d.hasteSeq=s:readBits(3) end
        d.actionItem=br(s) and s:readGameType() or ""
        d.scale=br(s) and s:readFloat(C.PlayerMinScale,C.PlayerMaxScale,8) or 1
        d.role=br(s) and s:readGameType() or ""
        d.perks={}
        if br(s) then
            d.perks=s:readArray(PERK_BITS,function()
                return {type=s:readGameType(),droppable=br(s)}
            end)
        end
    end,
}
local obstacle={
    serializedPartialSize=6,serializedFullSize=16,
    serializePart=function(s,d)
        s:writeMapPos(d.pos)
        s:writeBits(d.ori,2)
        s:writeFloat(d.scale,C.MapObjectMinScale,C.MapObjectMaxScale,8)
    end,
    deserializePart=function(s,d)
        d.pos=s:readMapPos()
        d.ori=s:readBits(2)
        d.scale=s:readFloat(C.MapObjectMinScale,C.MapObjectMaxScale,8)
    end,
    serializeFull=function(s,d)
        s:writeFloat(d.healthT,0,1,8)
        s:writeMapType(d.type)
        s:writeBits(d.layer,2)
        bp(s,d.dead);bp(s,d.isDoor)
        if d.isDoor then
            bp(s,d.door.open);bp(s,d.door.canUse);bp(s,d.door.locked)
            s:writeBits(d.door.seq,5)
        end
        bp(s,d.isButton)
        if d.isButton then
            bp(s,d.button.onOff);bp(s,d.button.canUse)
            s:writeBits(d.button.seq,6)
        end
        bp(s,d.isPuzzlePiece)
        if d.isPuzzlePiece then s:writeUint16(d.parentBuildingId) end
        bp(s,d.isSkin)
        if d.isSkin then s:writeUint16(d.skinPlayerId) end
    end,
    deserializeFull=function(s,d)
        d.healthT=s:readFloat(0,1,8)
        d.type=s:readMapType()
        d.layer=s:readBits(2)
        d.dead=br(s);d.isDoor=br(s)
        if d.isDoor then
            d.door={
                open=br(s),canUse=br(s),locked=br(s),seq=s:readBits(5)
            }
        end
        d.isButton=br(s)
        if d.isButton then
            d.button={onOff=br(s),canUse=br(s),seq=s:readBits(6)}
        end
        d.isPuzzlePiece=br(s)
        if d.isPuzzlePiece then d.parentBuildingId=s:readUint16() end
        d.isSkin=br(s)
        if d.isSkin then d.skinPlayerId=s:readUint16() end
    end,
}
local building={
    serializedPartialSize=2,serializedFullSize=9,
    serializePart=function(s,d)
        bp(s,d.ceilingDead);bp(s,d.occupied);bp(s,d.ceilingDamaged)
        bp(s,d.hasPuzzle)
        if d.hasPuzzle then
            bp(s,d.puzzle.solved);s:writeBits(d.puzzle.errSeq,7)
        end
    end,
    deserializePart=function(s,d)
        d.ceilingDead=br(s);d.occupied=br(s);d.ceilingDamaged=br(s)
        d.hasPuzzle=br(s)
        if d.hasPuzzle then
            d.puzzle={solved=br(s),errSeq=s:readBits(7)}
        end
    end,
    serializeFull=function(s,d)
        s:writeMapPos(d.pos)
        s:writeMapType(d.type)
        s:writeBits(d.ori,2);s:writeBits(d.layer,2)
    end,
    deserializeFull=function(s,d)
        d.pos=s:readMapPos();d.type=s:readMapType()
        d.ori=s:readBits(2);d.layer=s:readBits(2)
    end,
}
local structure={
    serializedPartialSize=0,serializedFullSize=10,
    serializePart=noOp,deserializePart=noOp,
    serializeFull=function(s,d)
        s:writeMapPos(d.pos);s:writeMapType(d.type)
        s:writeBits(d.ori,2)
        bp(s,d.interiorSoundEnabled);bp(s,d.interiorSoundAlt)
        for i=1,STRUCTURE_LAYERS do s:writeUint16(d.layerObjIds[i]) end
    end,
    deserializeFull=function(s,d)
        d.pos=s:readMapPos();d.type=s:readMapType()
        d.ori=s:readBits(2)
        d.interiorSoundEnabled=br(s);d.interiorSoundAlt=br(s)
        d.layerObjIds={}
        for i=1,STRUCTURE_LAYERS do d.layerObjIds[i]=s:readUint16() end
    end,
}
local lootSpawner={
    serializedPartialSize=8,serializedFullSize=0,
    serializePart=function(s,d)
        s:writeMapPos(d.pos);s:writeMapType(d.type);s:writeBits(d.layer,2)
    end,
    deserializePart=function(s,d)
        d.pos=s:readMapPos();d.type=s:readMapType();d.layer=s:readBits(2)
    end,
    serializeFull=noOp,deserializeFull=noOp,
}
local loot={
    serializedPartialSize=4,serializedFullSize=5,
    serializePart=copyNumAndVecPos,deserializePart=readPos,
    serializeFull=function(s,d)
        wType(s,d.type);s:writeUint8(d.count)
        s:writeBits(d.layer,2);bp(s,d.isOld);bp(s,d.isPreloadedGun)
        local hasOwner=(d.ownerId or 0)~=0
        bp(s,hasOwner)
        if hasOwner then s:writeUint16(d.ownerId) end
    end,
    deserializeFull=function(s,d)
        d.type=s:readGameType();d.count=s:readUint8()
        d.layer=s:readBits(2);d.isOld=br(s);d.isPreloadedGun=br(s)
        d.hasOwner=br(s)
        if d.hasOwner then d.ownerId=s:readUint16() end
    end,
}
local deadBody={
    serializedPartialSize=4,serializedFullSize=3,
    serializePart=copyNumAndVecPos,deserializePart=readPos,
    serializeFull=function(s,d) s:writeUint8(d.layer);s:writeUint16(d.playerId) end,
    deserializeFull=function(s,d)
        d.layer=s:readUint8();d.playerId=s:readUint16()
    end,
}
local decal={
    serializedPartialSize=0,serializedFullSize=8,
    serializePart=noOp,deserializePart=noOp,
    serializeFull=function(s,d)
        s:writeMapPos(d.pos)
        s:writeFloat(d.scale,C.MapObjectMinScale,C.MapObjectMaxScale,8)
        s:writeMapType(d.type)
        s:writeBits(d.ori,2);s:writeBits(d.layer,2)
        s:writeUint8(d.goreKills)
    end,
    deserializeFull=function(s,d)
        d.pos=s:readMapPos()
        d.scale=s:readFloat(C.MapObjectMinScale,C.MapObjectMaxScale,8)
        d.type=s:readMapType()
        d.ori=s:readBits(2);d.layer=s:readBits(2)
        d.goreKills=s:readUint8()
    end,
}
local projectile={
    serializedPartialSize=8,serializedFullSize=2,
    serializePart=function(s,d)
        s:writeMapPos(d.pos)
        s:writeFloat(d.posZ,0,PROJECTILE_MAX_Z,10)
        s:writeUnitVec(d.dir,7)
    end,
    deserializePart=function(s,d)
        d.pos=s:readMapPos()
        d.posZ=s:readFloat(0,PROJECTILE_MAX_Z,10)
        d.dir=s:readUnitVec(7)
    end,
    serializeFull=function(s,d) wType(s,d.type);s:writeBits(d.layer,2) end,
    deserializeFull=function(s,d)
        d.type=s:readGameType();d.layer=s:readBits(2)
    end,
}
local smoke={
    serializedPartialSize=5,serializedFullSize=1,
    serializePart=function(s,d)
        s:writeMapPos(d.pos);s:writeFloat(d.rad,0,C.SmokeMaxRad,8)
    end,
    deserializePart=function(s,d)
        d.pos=s:readMapPos();d.rad=s:readFloat(0,C.SmokeMaxRad,8)
    end,
    serializeFull=function(s,d)
        s:writeBits(d.layer,2);s:writeBits(d.interior,6)
    end,
    deserializeFull=function(s,d)
        d.layer=s:readBits(2);d.interior=s:readBits(6)
    end,
}
local airdrop={
    serializedPartialSize=1,serializedFullSize=4,
    serializePart=function(s,d)
        s:writeFloat(d.fallT,0,1,7);bp(s,d.landed)
    end,
    deserializePart=function(s,d)
        d.fallT=s:readFloat(0,1,7);d.landed=br(s)
    end,
    serializeFull=copyNumAndVecPos,deserializeFull=readPos,
}
O[O.Type.Invalid]={
    serializedPartialSize=0,serializedFullSize=0,
    serializePart=noOp,deserializePart=noOp,serializeFull=noOp,deserializeFull=noOp
}
O[O.Type.Player]=player
O[O.Type.Obstacle]=obstacle
O[O.Type.Loot]=loot
O[O.Type.LootSpawner]=lootSpawner
O[O.Type.DeadBody]=deadBody
O[O.Type.Building]=building
O[O.Type.Structure]=structure
O[O.Type.Decal]=decal
O[O.Type.Projectile]=projectile
O[O.Type.Smoke]=smoke
O[O.Type.Airdrop]=airdrop
return O
