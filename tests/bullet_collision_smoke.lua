-- Original Survev bullet.ts visual collision subset: obstacles + players.
-- These are READ-ONLY visual results; they never damage a game object.
local C=require("src.survev.bullet_collision")
local Trails=require("src.survev.bullet_trails")
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Types=require("src.survev.object_serialize_fns").Type
local function near(a,b,label)
    assert(type(a)=="number" and math.abs(a-b)<2e-5,
        (label or "value").." expected "..tostring(b)..", got "..tostring(a))
end
local shooter={__type=Types.Player,__id=1,pos={x=0,y=1},
    dir={x=1,y=0},layer=0,scale=1,dead=false}
local target={__type=Types.Player,__id=2,pos={x=9,y=1},
    dir={x=1,y=0},layer=0,scale=1,dead=false}
local wall={__type=Types.Obstacle,__id=3,type="house_door_01",
    pos={x=6,y=0},ori=0,scale=1,layer=0,dead=false,
    isDoor=true,door={open=false}}
local objects={[1]=shooter,[2]=target,[3]=wall}
local start={x=0,y=1}
local finish={x=12,y=1}
local bullet={playerId=1,layer=0,reflectCount=0,damageSelf=false}
local geometry=C.snapshot(objects)
assert(#geometry.obstacles==1 and #geometry.players==2)
local hit=assert(C.firstHit(geometry,bullet,start,finish))
assert(hit.kind=="obstacle" and hit.id==3)
near(hit.point.x,5.7,"closed door visual collision")
near(hit.distance,5.7,"door travel distance")
-- The closest hit must win, not whichever object was inserted first.
objects[3]=nil
geometry=C.snapshot(objects)
hit=assert(C.firstHit(geometry,bullet,start,finish))
assert(hit.kind=="player" and hit.id==2)
near(hit.point.x,8,"player radius")
objects[2].scale=2
geometry=C.snapshot(objects)
near(assert(C.firstHit(geometry,bullet,start,finish)).point.x,7,
    "player scale")
objects[2].layer=1
geometry=C.snapshot(objects)
assert(not C.firstHit(geometry,bullet,start,finish),
    "different layer and own shooter must not stop bullets")
objects[2].layer=0;objects[2].dead=true
geometry=C.snapshot(objects)
assert(not C.firstHit(geometry,bullet,start,finish))
objects[2].dead=false
objects[2].pos={x=9,y=8}
geometry=C.snapshot(objects)
assert(not C.firstHit(geometry,bullet,start,finish),
    "missed player must not stop tracer")

-- Self-hit only for shrapnel and reflected bullets; even that is visual.
bullet.damageSelf=true
geometry=C.snapshot(objects)
assert(C.firstHit(geometry,bullet,start,finish).id==1)
bullet.damageSelf=false
objects[2].pos={x=9,y=1};objects[2].scale=1
objects[3]=wall
-- The reflected bullet ignores the obstacle that caused reflection.
bullet.reflectCount=1
bullet.reflectObjId=3
geometry=C.snapshot(objects)
hit=assert(C.firstHit(geometry,bullet,start,finish))
assert(hit.id==2 and hit.kind=="player")
bullet.reflectCount=0;bullet.reflectObjId=0
-- Non-collidable, low obstacles and dead obstacles do not stop the trail.
local ignored={wall_test={
    collision={type=0,pos={x=0,y=0},rad=1},
    height=10,collidable=false,
}}
local single={[8]={__type=Types.Obstacle,__id=8,type="wall_test",
    pos={x=5,y=1},scale=1,ori=0,layer=0}}
assert(not C.firstHit(C.snapshot(single,ignored),bullet,start,finish))
ignored.wall_test.collidable=true
ignored.wall_test.height=.1
assert(not C.firstHit(C.snapshot(single,ignored),bullet,start,finish))
ignored.wall_test.height=1
near(assert(C.firstHit(C.snapshot(single,ignored),bullet,start,finish)).point.x,
    4,"circle collider")
single[8].dead=true
assert(not C.firstHit(C.snapshot(single,ignored),bullet,start,finish))
single[8].dead=false
single[8].isSkin=true
assert(not C.firstHit(C.snapshot(single,ignored),bullet,start,finish))
single[8].isSkin=false
single[8].layer=1
assert(not C.firstHit(C.snapshot(single,ignored),bullet,start,finish))

-- Broad-phase culling must never change the near collision result.
-- Hundreds of distant obstacles are deliberately present.
local registry={near_wall={
    collision={type=1,min={x=-.3,y=0},max={x=.3,y=4}},
    height=10,collidable=true,
},far_wall={
    collision={type=0,pos={x=0,y=0},rad=1},
    height=10,collidable=true,
}}
local crowded={
    [3]={__type=Types.Obstacle,__id=3,type="near_wall",
        pos={x=6,y=0},ori=0,scale=1,layer=0}
}
for i=4,250 do
    crowded[i]={__type=Types.Obstacle,__id=i,type="far_wall",
        pos={x=50+i,y=1000+i},ori=0,scale=1,layer=0}
end
local crowdedHit=assert(C.firstHit(C.snapshot(crowded,registry),
    bullet,start,finish))
assert(crowdedHit.kind=="obstacle" and crowdedHit.id==3)
near(crowdedHit.point.x,5.7,"broad phase must not skip near wall")
-- The near-axis delta used by the original segment algorithm is tiny,
-- so the conservative sweep may not discard a grazing geometry.
-- Integrate with the exact UpdateMsg-driven BulletTrails port.
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
local worldTarget={
    __type=Types.Player,__id=2,pos={x=9,y=1},scale=1,
    layer=0,dead=false,
}
local function shot()
    return {bulletType="bullet_ak47",playerId=1,layer=0,
        pos={x=0,y=1},dir={x=1,y=0},
        varianceT=0,distAdjIdx=8,reflectCount=0,
        speedMult=1,distanceMult=1,shotFx=false}
end
state:applyUpdate({fullObjects={shooter,wall,worldTarget},
    bullets={shot()}})
local renderer=Trails.new()
renderer:update(state,0)
assert(#renderer.trails==1)
renderer:update(state,.1)
local rendered=renderer.trails[1]
assert(rendered.collided and rendered.impactKind=="obstacle"
    and rendered.impactId==3)
near(rendered.pos.x,5.7,"rendered door stops projectile")
assert(rendered.traveled<10)
assert(not worldTarget.damage and not wall.damage,
    "the renderer must never apply local damage")
renderer:update(state,.1)
near(rendered.scale,.4,"original fade after visual collision")
renderer:update(state,.1)
assert(#renderer.trails==0)
state:applyUpdate({delObjIds={3},bullets={shot()}})
renderer:update(state,0)
renderer:update(state,.1)
rendered=renderer.trails[1]
assert(rendered.collided and rendered.impactKind=="player"
    and rendered.impactId==2)
near(rendered.pos.x,8,"rendered player collision")
state:applyUpdate({delObjIds={2},bullets={shot()}})
renderer:update(state,0)
local withoutTarget=renderer.trails[2]
renderer:update(state,.1)
assert(not withoutTarget.collided)
near(withoutTarget.pos.x,10,"bullet continues unobstructed")
-- A deleted blocker remains deleted. No collision on an unrelated layer.
state:applyUpdate({fullObjects={wall},bullets={shot()}})
state.objects[3].layer=1
renderer:update(state,0)
local differentLayer=renderer.trails[#renderer.trails]
renderer:update(state,.1)
assert(not differentLayer.collided)
-- New match clears all collision snapshots and visual events.
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
renderer:update(state,0)
assert(#renderer.trails==0 and renderer.colliders)
-- Real binary UpdateMsg path (serializer -> byte frame -> decoder -> state
-- -> visual renderer). This does not replace a live multiplayer session.
local Update=require("src.survev.update_msg")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")
local wire=State.new()
wire:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
wire:applyUpdate({fullObjects={shooter,wall,worldTarget},bullets={}})
local update=Update.new()
update.ack=9
update.bullets={shot()}
local stream=Net.newMsgStream(1024,Registry)
stream:serializeMsg(Net.MsgType.Update,update)
local frames=Decoder.decode(stream:getBuffer(),Registry)
assert(#frames==1 and frames[1].id==Net.MsgType.Update)
assert(#frames[1].msg.bullets==1)
wire:receive(stream:getBuffer(),Registry)
assert(wire.updateCount==2 and #wire.bulletEvents==1)
local real=Trails.new()
real:update(wire,0)
assert(#real.trails==1)
real:update(wire,.1)
local clipped=real.trails[1]
assert(clipped.collided and clipped.impactKind=="obstacle" and
    clipped.impactId==3,"decoded Survev bullet should stop at actual door")
assert(math.abs(clipped.pos.x-5.7)<.1)
assert(wire.objects[3].dead==false and wire.objects[2].dead==false,
    "visual collision may not change authoritative packet-backed actors")

print("Survev obstacle/player visual bullet collision and lifecycle passed")
