-- No client-side equip or pickup is permitted: only UpdateMsg changes state.
local Net=require("src.survev.net")
local State=require("src.survev.client_state")
local Obj=require("src.survev.object_serialize_fns").Type
local Tracker=require("src.survev.equipment_tracker")

local function weapons(primary,ammo)
    return {
        {type=primary,ammo=ammo or 0},
        {type="m9",ammo=12},
        {type="fists",ammo=0},
        {type="",ammo=0},
    }
end
local state=State.new()
local tracker=Tracker.new()
tracker:update(state,0)
assert(#tracker.events==0)
state:applyMessage(Net.MsgType.Joined,{
    teamMode=1,playerId=1,started=true,
})
state:applyMessage(Net.MsgType.Update,{
    activePlayerIdDirty=true,activePlayerId=1,
    fullObjects={{
        __type=Obj.Player,__id=1,
        pos={x=10,y=10},dir={x=1,y=0},
        helmet="helmet01",backpack="backpack01",chest="chest01",
    }},
    activePlayerData={
        weapsDirty=true,curWeapIdx=0,weapons=weapons("ak47",30),
    },
})
tracker:update(state,0)
assert(#tracker.events==0,"initial snapshot is NOT an equipment event")

-- A PickupMsg by itself must not cause any equipment change notice.
state:applyMessage(Net.MsgType.Pickup,{
    type=Net.PickupMsgType.Success,item="mp5",count=1,
})
tracker:update(state,0.1)
assert(#tracker.events==0)

-- Magazine count changed: still the same gun, so no equipment event.
state:applyMessage(Net.MsgType.Update,{
    activePlayerData={
        weapsDirty=true,curWeapIdx=0,weapons=weapons("ak47",13),
    },
})
tracker:update(state,0)
assert(#tracker.events==0,"ammo changes must not be treated as new gear")

state:applyMessage(Net.MsgType.Update,{
    partObjects={{__id=1,__type=Obj.Player,
        helmet="helmet02",backpack="backpack02"}},
    activePlayerData={
        weapsDirty=true,curWeapIdx=0,weapons=weapons("mp5",18),
    },
})
tracker:update(state,0)
assert(#tracker.events==3)
local combined=""
for _,ev in ipairs(tracker.events) do combined=combined..ev.message.."|" end
assert(combined:find("MP5",1,true))
assert(combined:find("Mochila",1,true))
assert(combined:find("Capacete",1,true))
assert(state.localData.weapons[1].type=="mp5")
assert(state.objects[1].helmet=="helmet02")
tracker:update(state,3.1)
assert(#tracker.events==0,"notice expiration should not mutate weapons")

-- Spectator target changes must be baselined, never fabricated pickups.
state:applyMessage(Net.MsgType.Update,{
    fullObjects={{
        __type=Obj.Player,__id=2,
        pos={x=15,y=15},dir={x=1,y=0},helmet="helmet03",
    }},
    activePlayerIdDirty=true,activePlayerId=2,
})
tracker:update(state,0)
assert(#tracker.events==0)
state:applyMessage(Net.MsgType.Update,{
    partObjects={{__id=2,__type=Obj.Player,helmet="helmet02"}},
})
tracker:update(state,0)
assert(#tracker.events==1)

state.offlinePreview=true
tracker:update(state,0)
assert(#tracker.events==0)
state.offlinePreview=nil
tracker:update(state,0)
assert(#tracker.events==0)

state:applyMessage(Net.MsgType.Joined,{
    teamMode=1,playerId=3,started=true,
})
tracker:update(state,0)
assert(#tracker.events==0)
print("LastCircle server-authoritative equipment changes passed")
