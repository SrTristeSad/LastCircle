-- Survev original shot.ts / player.ts recoil source parity.
-- Recoil follows ONLY UpdateMsg.bullets with shotFx=true.
local Recoil=require("src.survev.shot_recoil")
local Render=require("src.survev.player_renderer")
local Camera=require("src.survev.camera")
local Config=require("src.survev.game_config")
local Gear=require("src.survev.equipment_art")
local State=require("src.survev.client_state")
local Types=require("src.survev.object_serialize_fns").Type
local Net=require("src.survev.net")
local function near(actual,expected,message)
    assert(type(actual)=="number" and math.abs(actual-expected)<1e-8,
        (message or "mismatch").." "..tostring(actual).." ~= "..tostring(expected))
end
local obj={
    __type=Types.Player,__id=17,pos={x=320,y=330},
    dir={x=1,y=0},outfit="outfitBase",scale=1,
    activeWeapon="ak47",backpack="",helmet="",chest="",
    dead=false,downed=false,
}
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=17,started=true})
state:applyUpdate({fullObjects={obj},bullets={}})
local actor=assert(state.objects[17])
local recoil=Recoil.new()
recoil:update(state,0)
assert(recoil:forPlayer(actor)==nil)
local function shot(source,fx,offhand,id)
    return {playerId=id or 17,shotSourceType=source,
        shotOffhand=not not offhand,shotFx=not not fx}
end
-- Ordinary automatic rifle fires both hands; no packet == no recoil.
local kick=assert(Gear.weapons.ak47.world.recoil)
assert(kick>0)
state:applyUpdate({bullets={shot("ak47",true,false)}})
recoil:update(state,0)
near(recoil.hands[17].left,kick)
near(recoil.hands[17].right,kick)
recoil:update(state,0)  -- same updateCount: no second recoil event
near(recoil.hands[17].right,kick)
local renderer=Render.new()
local camera=Camera.new()
camera.m_pos={x=320,y=330}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local function named(commands,name)
    for _,entry in ipairs(commands) do
        if entry.name==name then return entry end
    end
    error("sprite absent: "..name)
end
local baseline=renderer:commands(actor,camera,"main")
local moved=renderer:commands(actor,camera,"main",nil,
    recoil:forPlayer(actor))
local shift=-kick*1.125*camera:m_pixels(1)
near(named(moved,"handL").x-named(baseline,"handL").x,shift)
near(named(moved,"handR").x-named(baseline,"handR").x,shift)
near(named(moved,"gunR").x-named(baseline,"gunR").x,shift)
near(named(moved,"body").x,named(baseline,"body").x)
assert(#baseline==#moved)
-- Last authoritative packet had no new shots: decay is exact original
-- player.ts max(0, value-value*dt*5-dt), no extra shot is generated.
state:applyUpdate({bullets={shot("ak47",false,false)}})
recoil:update(state,.05)
local faded=math.max(0,kick-kick*.05*5-.05)
near(recoil.hands[17].left,faded)
near(recoil.hands[17].right,faded)
state:applyUpdate({bullets={shot("INVALID_GUN",true,false)}})
recoil:update(state,0)
near(recoil.hands[17].left,faded)
state:applyUpdate({bullets={shot("ak47",true,false,999)}})
recoil:update(state,0)
assert(recoil.hands[999]==nil,"never animate an unknown shooter")
-- A dual pistol must move only its corresponding side.
actor.activeWeapon="m9_dual"
local dual=assert(Gear.weapons.m9_dual)
assert(dual.isDual and dual.world.recoil>0)
state:applyUpdate({bullets={shot("m9_dual",true,true)}})
recoil:update(state,0)
local expectedL=faded+dual.world.recoil
near(recoil.hands[17].left,expectedL)
near(recoil.hands[17].right,faded)
local dualBase=renderer:commands(actor,camera,"main")
local dualMoved=renderer:commands(actor,camera,"main",nil,
    recoil:forPlayer(actor))
near(named(dualMoved,"gunL").x-named(dualBase,"gunL").x,
    -expectedL*1.125*camera:m_pixels(1))
near(named(dualMoved,"gunR").x-named(dualBase,"gunR").x,
    -faded*1.125*camera:m_pixels(1))
state:applyUpdate({bullets={shot("m9_dual",true,false)}})
recoil:update(state,0)
near(recoil.hands[17].left,expectedL)
near(recoil.hands[17].right,faded+dual.world.recoil)
-- Different session, death and offline preview cancel visual recoil.
actor.dead=true
state:applyUpdate({bullets={}})
recoil:update(state,0)
assert(recoil.hands[17]==nil)
assert(recoil:forPlayer(actor)==nil)
actor.dead=false
state.offlinePreview=true
recoil:update(state,0)
assert(next(recoil.hands)==nil)
state.offlinePreview=nil
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=17,started=true})
recoil:update(state,0)
assert(next(recoil.hands)==nil)
-- Two socket packets can arrive before the LÖVE renderer runs.
-- Their authoritative shotFx entries must BOTH survive the state merge.
local batch=State.new()
batch:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=17,started=true})
batch:applyUpdate({fullObjects={obj},bullets={shot("ak47",true,false)}})
batch:applyUpdate({bullets={shot("ak47",true,false)}})
assert(#batch.bullets==1,"per-frame visual bullets remain transient")
assert(batch.shotFxSeq==2 and #batch.shotFxEvents==2,
    "two packet events must survive in the numbered shot queue")
local batchedRecoil=Recoil.new()
batchedRecoil:update(batch,0)
near(batchedRecoil.hands[17].left,kick*2)
near(batchedRecoil.hands[17].right,kick*2)
batchedRecoil:update(batch,0)
near(batchedRecoil.hands[17].left,kick*2)
batch:applyUpdate({bullets={}})
batchedRecoil:update(batch,0)
near(batchedRecoil.hands[17].left,kick*2)
-- Bound retained shot events even if a consumer stalls for many packets.
for i=1,260 do
    batch:applyUpdate({bullets={shot("ak47",true,false)}})
end
assert(#batch.shotFxEvents==256)
assert(batch.shotFxSeq==262)
assert(batch.shotFxEvents[1].seq==7)
assert(batch.shotFxEvents[256].seq==262)
batchedRecoil:update(batch,0)
near(batchedRecoil.hands[17].left,kick*258)
batchedRecoil:update(batch,0)
near(batchedRecoil.hands[17].left,kick*258)
-- Reset must discard retained effects, rather than replaying previous match.
batch:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=17,started=true})
assert(batch.shotFxSeq==0 and #batch.shotFxEvents==0)
batchedRecoil:update(batch,0)
assert(next(batchedRecoil.hands)==nil)

print("Survev server-origin shotFx recoil, dual hands and exact decay passed")
