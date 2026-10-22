-- LastCircle LOCAL VISUAL TEST (no server).
-- This deliberately constructs a SMALL MapMsg/UpdateMsg-shaped source-data
-- scene from the pinned Survev MapObjectDefs. It is NOT a fabricated Survev
-- game server, nor a replay of a real matchmaking session.
--
-- The terrain generator, sprite definitions, building/door renderers, player
-- size and speed all come from the Survev Lua port. Only movement in this
-- isolated inspection sandbox is locally simulated.
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Config=require("src.survev.game_config")
local Obj=require("src.survev.object_serialize_fns").Type
local Obstacles=require("src.survev.map_obstacle_art")
local Buildings=require("src.survev.map_building_art")
local Collisions=require("src.survev.los_geometry")
local V=require("src.survev.v2")
local Palettes=require("src.survev.map_colors")
local Equipment=require("src.survev.equipment_art")
local Outfits=require("src.survev.player_art").outfits
local Hint=require("src.survev.interaction_hint")
local Loot=require("src.survev.loot_renderer")
local LootDefs=require("src.survev.loot_art")
local Demo={}
Demo.__index=Demo

local function clamp(value,low,high)
    return math.max(low,math.min(high,value))
end

local function dummyMap()
    local palette=assert(Palettes.main,"original Survev main palette missing")
    return {
        mapName="main",width=720,height=640,seed=98765,
        shoreInset=17,grassInset=8,
        rivers={
            {width=6,looped=false,points={
                {x=0,y=280},{x=180,y=287},{x=300,y=307},
                {x=420,y=291},{x=550,y=285},{x=720,y=285},
            }},
        },
        places={{name="Area de teste local",pos={x=.5,y=.5}}},
        groundPatches={
            {bound={type=0,pos={x=364,y=324},rad=18},
                roughness=.23,offsetDist=3,order=0,
                color=palette.colors.grass,useAsMapShape=false},
        },
        objects={},
    }
end

function Demo.new()
    local state=State.new()
    state:applyMessage(Net.MsgType.Joined,{
        teamMode=Config.TeamMode.Solo,playerId=1,started=true,emotes={}
    })
    local map=dummyMap()
    local spawn={x=355,y=321}
    local units={
        -- The sprite names, original image scales and rotations are looked
        -- up in generated registries; none of the art is invented.
        {id=10,type="shack_01",x=365,y=329,ori=0,building=true},
        {id=11,type="barn_01",x=323,y=356,ori=0,building=true},
        {id=12,type="warehouse_01",x=439,y=364,ori=1,building=true},
        {id=13,type="house_door_01",x=362,y=321,ori=0,door=true},
        {id=14,type="house_door_01",x=324,y=350,ori=1,door=true},
        {id=15,type="tree_01",x=344,y=340,ori=0},
        {id=16,type="tree_01",x=380,y=345,ori=0},
        {id=17,type="tree_02",x=336,y=327,ori=0},
        {id=18,type="tree_02",x=388,y=316,ori=0},
        {id=19,type="stone_01",x=338,y=319,ori=0},
        {id=20,type="barrel_01",x=375,y=315,ori=0},
        {id=21,type="crate_01",x=376,y=332,ori=0},
        {id=22,type="bush_01",x=344,y=316,ori=0},
        {id=23,type="bush_01",x=384,y=333,ori=0},
        {id=24,type="tree_01",x=406,y=350,ori=0},
    }
    local all={
        {
            __type=Obj.Player,__id=1,pos=V.copy(spawn),dir={x=1,y=0},
            outfit="outfitBase",backpack="backpack02",
            helmet="helmet02",chest="chest02",
            activeWeapon="fists",scale=1,layer=0,dead=false,downed=false,
            offlinePreview=true,
        }
    }
    local doorOrigins={}
    for _,spec in ipairs(units) do
        local meta=spec.building and Buildings[spec.type]
            or Obstacles[spec.type]
        assert(meta,"missing pinned Survev definition: "..spec.type)
        if spec.building then
            assert(meta.floor and #meta.floor>0,"building has no real floor")
        else
            assert(meta.asset,"original obstacle sprite missing: "..spec.type)
        end
        local entity={
            __id=spec.id,__type=spec.building and Obj.Building or Obj.Obstacle,
            type=spec.type,pos={x=spec.x,y=spec.y},
            ori=spec.ori,layer=0,scale=1,dead=false,
            ceilingDead=false,ceilingDamaged=false,
        }
        if spec.door then
            assert(meta.door,"source object does not define a door")
            entity.isDoor=true
            entity.door={open=false,canUse=true,locked=false,seq=1}
            doorOrigins[spec.id]={pos=V.copy(entity.pos),ori=spec.ori}
        end
        all[#all+1]=entity
        -- MapMsg.objects is used for the minimap in the original client.
        map.objects[#map.objects+1]={
            pos=V.copy(entity.pos),ori=entity.ori,scale=1,type=entity.type
        }
    end
    -- Sample ground loot uses actual ObjectType.Loot, original sprites,
    -- source pickup ranges and counts, not permanent MapMsg decorations.
    for _,item in ipairs({
        {id=30,type="9mm",count=50,x=353,y=325},
        {id=31,type="bandage",count=3,x=349,y=324},
        {id=32,type="m9",count=1,x=348,y=316},
        {id=33,type="762mm",count=45,x=357,y=317},
        {id=34,type="soda",count=2,x=353,y=316},
    }) do
        assert(LootDefs.loot[item.type] and
            LootDefs.loot[item.type].asset,"missing original Survev loot")
        all[#all+1]={
            __id=item.id,__type=Obj.Loot,type=item.type,
            pos={x=item.x,y=item.y},count=item.count,
            layer=0,isOld=true,isPreloadedGun=false,ownerId=0,
        }
    end
    -- Local ONLY: every item category starts at a known zero, just like
    -- GameConfig.player.defaultItems.inventory in original server code.
    -- In REAL sessions no values are inferred when UpdateMsg is absent.
    local demoInventory={}
    for _,key in ipairs(LootDefs.bagKeys) do demoInventory[key]=0 end
    demoInventory["9mm"]=120
    demoInventory["762mm"]=90
    demoInventory["1xscope"]=1
    state:applyMessage(Net.MsgType.Map,map)
    state:applyMessage(Net.MsgType.Update,{
        ack=0,activePlayerIdDirty=true,activePlayerId=1,
        fullObjects=all,
        activePlayerData={
            healthDirty=true,health=100,
            boostDirty=true,boost=62.5,
            inventoryDirty=true,scope="1xscope",
            -- Fixed LOCAL PREVIEW reserves use source GameConfig.bagSizes
            -- (base capacity 9mm=120, 762mm=90), NOT fake game pickups.
            inventory=demoInventory,
            weapsDirty=true,curWeapIdx=2,
            weapons={
                {type="ak47",ammo=assert(Equipment.weapons.ak47.maxClip)},
                {type="m9",ammo=assert(Equipment.weapons.m9.maxClip)},
                {type="fists",ammo=0},
                {type="",ammo=0}
            },
        },
    })
    state.offlinePreview=true
    return setmetatable({
        state=state,spawn=spawn,
        doorOrigins=doorOrigins,steps=0,interactions=0,
        message="Cenario de teste feito com artes e definicoes originais.",
    },Demo)
end

local function collides(self,newPos)
    local map=self.state.map
    -- This is a local collision PREVIEW, not server-authoritative physics.
    if newPos.x<map.shoreInset+1 or newPos.x>map.width-map.shoreInset-1
        or newPos.y<map.shoreInset+1
        or newPos.y>map.height-map.shoreInset-1 then return true end
    local radius=Config.player.radius
    for _,obstacle in ipairs(Collisions.obstacles(self.state.objects)) do
        if obstacle.collidable and not obstacle.dead and
            Collisions.sameLayer(obstacle.layer,0) and
            Collisions.intersectCircle(obstacle.collider,newPos,radius) then
            return true
        end
    end
    return false
end

-- Equipment buttons display ORIGINAL inventory visuals; no real pickup,
-- ammo, attack, damage or server-authoritative inventory takes place.
local equipSlots={"fists","pan","m9","ak47","m9_dual"}
local outfitList={"outfitBase","outfitDemo","outfitMedic","outfitScout"}
function Demo:equip(slot)
    assert(type(slot)=="number")
    local key=equipSlots[slot]
    if not key or not Equipment.weapons[key]
        or (Equipment.weapons[key].world and
            not Equipment.weapons[key].world.asset) then return false end
    local obj=self.state.objects[self.state.activeId]
    obj.previewFistTicker=nil
    local current={}
    for i,item in ipairs(self.state.localData.weapons) do
        current[i]={type=item.type,ammo=item.ammo}
    end
    -- Original four slots: primary=0, secondary=1, melee=2, throwable=3.
    local index=2
    if key=="m9" or key=="m9_dual" then index=1 end
    if key=="ak47" then index=0 end
    current[index+1]={
        type=key,ammo=Equipment.weapons[key].maxClip or 0,
    }
    self.state:applyMessage(Net.MsgType.Update,{
        ack=0,partObjects={{__id=obj.__id,__type=Obj.Player,
            activeWeapon=key}},
        activePlayerData={
            weapsDirty=true,curWeapIdx=index,weapons=current
        },
    })
    self.message="Equipado visualmente: "..Equipment.weapons[key].name..
        " (nenhuma municao/dano no teste local)."
    return true
end
function Demo:toggleGear()
    local obj=self.state.objects[self.state.activeId]
    local active=obj.chest~=""
    local backpack=active and "" or "backpack02"
    local helmet=active and "" or "helmet02"
    local chest=active and "" or "chest02"
    assert(Equipment.gear.chest02.skin.asset and
        Equipment.gear.helmet02.skin.asset)
    self.state:applyMessage(Net.MsgType.Update,{
        ack=0,partObjects={{__id=obj.__id,__type=Obj.Player,
            backpack=backpack,helmet=helmet,chest=chest}}
    })
    self.message=active and "Armadura e mochila ocultadas no teste." or
        "Vestindo armadura, capacete e mochila originais."
    return true
end
function Demo:cycleOutfit()
    local obj=self.state.objects[self.state.activeId]
    local idx=1
    for i,key in ipairs(outfitList) do
        if key==obj.outfit then idx=i;break end
    end
    local nextType=outfitList[idx%#outfitList+1]
    assert(Outfits[nextType].baseAsset,"source outfit image missing")
    self.state:applyMessage(Net.MsgType.Update,{
        ack=0,partObjects={{__id=obj.__id,__type=Obj.Player,
            outfit=nextType}}
    })
    self.message="Roupa oficial: "..nextType
    return nextType
end

-- Preview-only pickup: the real Survev server remains authoritative.
-- We model only stackable bag items here; weapons/armour never magically
-- enter player inventory. Partial stacks respect the original bag capacity.
function Demo:pickup()
    local target=Loot.nearest(self.state)
    if not target then
        self.message="Nenhum item do Survev no raio de coleta."
        return false
    end
    local obj=target.object
    local item=target.def
    local capacities=LootDefs.bagSizes[obj.type]
    if not capacities then
        self.message=item.name.." - apenas visualizacao; coleta de equipamentos pendente."
        return false
    end
    local actor=self.state.objects[self.state.activeId]
    local bag=Equipment.gear[actor.backpack or ""]
    local level=bag and bag.level or 0
    local limit=capacities[level+1]
    assert(limit,"capacity must be defined by original Survev GameConfig")
    local existing=self.state.localData.inventory[obj.type] or 0
    local quantity=math.min(obj.count,math.max(0,limit-existing))
    if quantity<=0 then
        self.message="Mochila cheia para "..item.name.." ("..existing.."/"..limit..")."
        return false
    end
    local inventory={}
    for name,n in pairs(self.state.localData.inventory) do inventory[name]=n end
    inventory[obj.type]=existing+quantity
    local message={
        ack=0,
        activePlayerData={inventoryDirty=true,
            scope=self.state.localData.scope,inventory=inventory},
    }
    local remaining=obj.count-quantity
    if remaining==0 then
        message.delObjIds={obj.__id}
    else
        -- Count is serialized ONLY with the full Loot object. Avoid
        -- forging a partial update with fields absent from the wire.
        local snapshot={}
        for k,v in pairs(obj) do snapshot[k]=v end
        snapshot.count=remaining
        message.fullObjects={snapshot}
    end
    self.state:applyMessage(Net.MsgType.Update,message)
    self.message="TESTE LOCAL: +"..quantity.." "..item.name..
        " (servidor nao conectado)."
    self.pickups=(self.pickups or 0)+1
    return true,quantity
end

-- One local visual animation, using the exact source Animations.fists
-- frames. Clicking does NOT inflict damage or simulate combat authority.
function Demo:punch()
    local p=self.state.objects[self.state.activeId]
    if not p or p.previewFistTicker~=nil then return false end
    if p.activeWeapon~="fists" then
        self.message="Soco visual apenas com punhos (tecla 1). Combate pendente."
        return false
    end
    p.previewFistTicker=0
    self.message="Soco visual original do Survev (sem dano; somente teste)."
    return true
end

function Demo:update(dt,moveX,moveY,aim)
    dt=clamp(dt or 0,0,.08)
    local player=self.state.objects[1]
    if not player then return end
    if player.previewFistTicker~=nil then
        local frames=require("src.survev.player_art").animations.fists
        player.previewFistTicker=player.previewFistTicker+dt
        if player.previewFistTicker>=frames[#frames].time then
            player.previewFistTicker=nil
        end
    end
    local dir=V.copy(player.dir)
    if aim and type(aim.x)=="number" and type(aim.y)=="number" then
        local toward=V.sub(aim,player.pos)
        local len=V.length(toward)
        if len>.00001 then dir=V.div(toward,len) end
    end
    moveX=clamp(moveX or 0,-1,1)
    moveY=clamp(moveY or 0,-1,1)
    local length=math.sqrt(moveX*moveX+moveY*moveY)
    if length>1 then moveX,moveY=moveX/length,moveY/length end
    local amount=dt*Config.player.moveSpeed
    local x=player.pos.x+moveX*amount
    local y=player.pos.y+moveY*amount
    local nextPos=V.copy(player.pos)
    -- Axis-separated test collision permits sliding around source obstacles.
    if not collides(self,{x=x,y=nextPos.y}) then nextPos.x=x end
    if not collides(self,{x=nextPos.x,y=y}) then nextPos.y=y end
    local moved=V.lengthSqr(V.sub(player.pos,nextPos))>.00000001
    if moved or (dir.x~=player.dir.x or dir.y~=player.dir.y) then
        self.state:applyMessage(Net.MsgType.Update,{
            ack=0,partObjects={{__type=Obj.Player,__id=1,
                pos=nextPos,dir=dir}},
        })
    end
    if moved then self.steps=self.steps+1 end
end

-- Door transition based on original
-- server/src/game/objects/obstacle.ts:toggleDoor().
function Demo:interact()
    -- Original UI gives nearby loot priority over door interaction.
    if Loot.nearest(self.state) then return self:pickup() end
    local player=self.state.objects[1]
    local choice=Hint.scan(self.state)
    local best=choice and choice.usable and self.doorOrigins[choice.id]
        and self.state.objects[choice.id] or nil
    if not best then
        self.message="Nenhuma porta do Survev esta ao alcance (F)."
        return false
    end
    local def=Obstacles[best.type].door
    local origin=self.doorOrigins[best.__id]
    local opening=not best.door.open
    local newPos=V.copy(best.pos)
    local newOri=best.ori
    if def.slideToOpen then
        local offset=V.rotate({x=0,y=def.slideOffset*(opening and -1 or 1)},
            best.ori*math.pi*.5)
        newPos=V.add(newPos,offset)
    elseif not opening then
        newOri=origin.ori
    else
        local side=def.openOneWay
        if not side or side==0 then
            local toDoor=V.sub(best.pos,player.pos)
            local doorDir=V.rotate({x=1,y=0},best.ori*math.pi*.5)
            side=V.dot(toDoor,doorDir)<0 and -1 or 1
        end
        newOri=(best.ori-side)%4
    end
    local copyDoor={}
    for k,v in pairs(best.door) do copyDoor[k]=v end
    copyDoor.open=opening
    copyDoor.seq=copyDoor.seq+1
    self.state:applyMessage(Net.MsgType.Update,{
        ack=0,
        partObjects={{__type=Obj.Obstacle,__id=best.__id,
            pos=newPos,ori=newOri,door=copyDoor}},
    })
    -- The local-only state update reproduces the source toggleDoor
    -- behavior but is never represented as a server packet.
    self.interactions=self.interactions+1
    self.message=opening and "Porta de teste aberta." or "Porta de teste fechada."
    return true
end

function Demo:getGameState() return self.state end
return Demo
