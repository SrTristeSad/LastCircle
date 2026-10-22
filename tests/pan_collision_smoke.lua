-- Survev source pan reflectSurface + m_hasActivePan + coldet math parity.
-- A reported pan interception only stops a visual tracer; never emits damage.
local C=require("src.survev.bullet_collision")
local Game=require("src.survev.game_config")
local Types=require("src.survev.object_serialize_fns").Type
local Trails=require("src.survev.bullet_trails")
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local function near(a,b)
    assert(type(a)=="number" and math.abs(a-b)<1e-7,
        tostring(a).." ~= "..tostring(b))
end
local player={
    __type=Types.Player,__id=2,pos={x=0,y=0},
    dir={x=1,y=0},layer=0,scale=1,dead=false,
    wearingPan=false,activeWeapon="pan",animType=Game.Anim.None,
}
local shooter={
    __type=Types.Player,__id=1,pos={x=5,y=-.45},
    dir={x=-1,y=0},layer=0,scale=1,dead=false,
    activeWeapon="ak47",
}
local lineStart,lineEnd={x=5,y=-.45},{x=-3,y=-.45}
local shot={layer=0,playerId=1,damageSelf=false,reflectCount=0}
local objects={[1]=shooter,[2]=player}
local snap=C.snapshot(objects)
local hit=assert(C.firstHit(snap,shot,lineStart,lineEnd))
assert(hit.kind=="pan" and hit.id==2)
assert(hit.point.x>1.3 and hit.point.x<2.7,
    "equipped pan must intercept BEFORE the actual body")

player.animType=Game.Anim.Melee
snap=C.snapshot(objects)
local body=assert(C.firstHit(snap,shot,lineStart,lineEnd))
assert(body.kind=="player" and body.id==2)
near(body.point.x,math.sqrt(1-.45*.45))

-- Pan holstered on the hip uses different upstream segment and blocks
-- bullets arriving from the LEFT, before they enter the player circle.
player.wearingPan=true
player.activeWeapon="fists"
player.animType=Game.Anim.Melee
snap=C.snapshot(objects)
hit=assert(C.firstHit(snap,shot,{x=-5,y=-.45},{x=3,y=-.45}))
assert(hit.kind=="pan" and hit.id==2)
assert(hit.point.x< -1)
-- Zero-scale change should preserve the original source endpoints.
player.scale=2
snap=C.snapshot(objects)
hit=assert(C.firstHit(snap,shot,{x=-5,y=-1},{x=5,y=-1}))
assert(hit.kind=="pan" and hit.point.x<-2)
player.scale=1

-- Same source pan surface with facing rotated 90 degrees must transform.
player.wearingPan=false
player.activeWeapon="pan"
player.animType=Game.Anim.None
player.dir={x=0,y=1}
snap=C.snapshot(objects)
hit=assert(C.firstHit(snap,shot,
    {x=.45,y=5},{x=.45,y=-3}))
assert(hit.kind=="pan" and hit.id==2)
-- Don't synthesize pan protection on absent server state.
player.activeWeapon="fists"
snap=C.snapshot(objects)
hit=assert(C.firstHit(snap,shot,
    {x=.45,y=5},{x=.45,y=-3}))
assert(hit.kind=="player")

-- Check the FULL render path, from UpdateMsg state to tracer collision.
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
player.dir={x=1,y=0}
player.activeWeapon="pan"
player.wearingPan=false
local function packet()
    return {bulletType="bullet_ak47",pos={x=5,y=-.45},
        dir={x=-1,y=0},playerId=1,layer=0,
        reflectCount=0,varianceT=0,distAdjIdx=8,
        speedMult=1,distanceMult=1}
end
state:applyUpdate({fullObjects={shooter,player},bullets={packet()}})
local tracks=Trails.new()
tracks:update(state,0)
tracks:update(state,.1)
assert(tracks.trails[1].collided)
assert(tracks.trails[1].impactKind=="pan" and
    tracks.trails[1].impactId==2)
assert(not player.damage and not shooter.damage)
assert(not state.objects[2].damage)

-- When moving/turning, preserve the preceding network pose.
state:applyUpdate({partObjects={{__type=Types.Player,__id=2,
    pos={x=1,y=0},dir={x=1,y=0}}},bullets={}})
tracks:update(state,0)
local after=tracks.colliders.players
local previous=nil
for _,p in ipairs(after) do if p.__id==2 then previous=p end end
assert(previous and previous.oldPos.x==0 and previous.pos.x==1)

state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
tracks:update(state,0)
assert(#tracks.trails==0)
print("Survev source pan reflection segment + prior network pose tests passed")
