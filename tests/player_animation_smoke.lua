-- Original Survev client/src/objects/player.ts animSeq, Anim.Melee,
-- and client/src/animData.ts fists/pan HandR keyframes.
local Animated=require("src.survev.player_animation")
local Renderer=require("src.survev.player_renderer")
local Camera=require("src.survev.camera")
local Config=require("src.survev.game_config")
local Type=require("src.survev.object_serialize_fns").Type
local function near(a,b)
    assert(type(a)=="number" and math.abs(a-b)<1e-8,
        "expected "..tostring(b)..", got "..tostring(a))
end
local fist=assert(Animated.sample("fists",.1))
near(fist.HandR.pivot.x,29.75)
near(fist.HandR.pivot.y,1.75)
near(Animated.sample("fists",.05).HandR.pivot.x,21.875)
assert(Animated.sample("fists",.25)==nil)
local pan=assert(Animated.sample("pan",.15))
near(pan.HandR.pivot.x,22)
near(pan.HandR.pivot.y,-8.25)
near(pan.HandR.rot,-math.pi*.2)
near(Animated.sample("pan",.25).HandR.rot,math.pi*.5)
assert(Animated.sample("pan",.55)==nil)
assert(Animated.sample("ak47",.05)==nil)
assert(Animated.sample("pan",-1)==nil)

local player={
    __id=12,__type=Type.Player,
    pos={x=300,y=305},dir={x=1,y=0},scale=1,layer=0,
    outfit="outfitBase",activeWeapon="fists",
    helmet="",chest="",backpack="",
    dead=false,downed=false,
    animType=Config.Anim.Melee,animSeq=1,
}
local state={
    joined=true,offlinePreview=false,
    objects={[12]=player},updateCount=1,
}
local animation=Animated.new()
animation:update(state,0)
near(animation:poseFor(player).HandR.pivot.x,14)
animation:update(state,.1)
near(animation:poseFor(player).HandR.pivot.x,29.75)
-- Receiving the SAME animation sequence again must not replay the swing.
state.updateCount=2
animation:update(state,.05)
near(animation:poseFor(player).HandR.pivot.x,22.875)
local renderer=Renderer.new()
local camera=Camera.new()
camera.m_pos={x=300,y=305}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local function rightHand(commands)
    for _,cmd in ipairs(commands) do
        if cmd.name=="handR" then return cmd end
    end
    error("missing original right hand sprite")
end
local baseline=rightHand(assert(renderer:commands(player,camera,"main")))
local moving=rightHand(assert(renderer:commands(
    player,camera,"main",animation:poseFor(player))))
assert(moving.x>baseline.x,"server melee animation must move the source sprite")
-- Same player, next 3-bit network sequence: restart the keyframes.
player.animSeq=2
state.updateCount=3
animation:update(state,0)
near(animation:poseFor(player).HandR.pivot.x,14)
animation:update(state,.25)
assert(animation:poseFor(player)==nil,"swing ends at original last frame")
-- Source pan: full-state change and 0.15s swing, no fake damage.
player.activeWeapon="pan"
player.animSeq=3
state.updateCount=4
animation:update(state,0)
animation:update(state,.15)
local panPose=assert(animation:poseFor(player))
near(panPose.HandR.rot,-math.pi*.2)
local panWorld=rightHand(assert(renderer:commands(player,camera,"main",panPose)))
assert(math.abs(panWorld.rotation-baseline.rotation)>0.5)
-- Unknown melee animation remains idle rather than inventing keyframes.
player.activeWeapon="ak47"
player.animSeq=4
state.updateCount=5
animation:update(state,.05)
assert(animation:poseFor(player)==nil)
player.activeWeapon="fists"
player.animSeq=7
state.updateCount=6
animation:update(state,0)
assert(animation:poseFor(player)~=nil)
player.animSeq=0 -- wrapped 3-bit animation sequence
state.updateCount=7
animation:update(state,0)
near(animation:poseFor(player).HandR.pivot.x,14)
-- Downed/dead characters do not retain attacking poses.
player.downed=true
assert(animation:poseFor(player)==nil)
player.downed=false
player.dead=true
state.updateCount=8
animation:update(state,.01)
assert(animation:poseFor(player)==nil)
state.objects[12]=nil
state.updateCount=9
animation:update(state,.01)
assert(animation.entities[12]==nil)
animation:update(nil,.1)
assert(animation.world==nil)
-- Local offline practice keeps its independent preview gesture.
state.offlinePreview=true
state.objects[12]=player
state.updateCount=10
animation:update(state,.01)
assert(animation:poseFor(player)==nil)
print("Source-authoritative Survev fist/pan melee animation sequences passed")
