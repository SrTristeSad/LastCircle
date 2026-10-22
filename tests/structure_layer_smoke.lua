-- Survev BulletBarn structure stairs + masks from pinned StructureDefs.
local Defs=require("src.survev.map_structure_collision")
local S=require("src.survev.structure_layer")
local Types=require("src.survev.object_serialize_fns").Type
local Trails=require("src.survev.bullet_trails")
local Net=require("src.survev.net")
local State=require("src.survev.client_state")
local function near(a,b)
    assert(type(a)=="number" and math.abs(a-b)<1e-7,
        tostring(a).." ~= "..tostring(b))
end
local n,s,m=0,0,0
for _,def in pairs(Defs) do
    n=n+1;s=s+#def.stairs;m=m+#def.mask
end
assert(n>5 and s>5 and m>0,
    "generation must include ORIGINAL structures, stairs and masks")
assert(Defs.bunker_structure_01)
local atOrigin={
    [8]={__id=8,__type=Types.Structure,
        type="bunker_structure_01",
        pos={x=0,y=0},ori=0}
}
local stairs=S.snapshot(atOrigin)
assert(#stairs==1 and #stairs[1].stairs==1)
local bullet={layer=0}
assert(S.updateLayer(stairs,bullet,
    {x=0,y=12},{x=0,y=6})==2,
    "stair outside mask promotes to upper/mixed visual layer")
assert(bullet.layer==2)
assert(S.updateLayer(stairs,bullet,
    {x=0,y=12},{x=0,y=6})==2,
    "once promoted it must not promote twice")
bullet.layer=0
assert(S.updateLayer(stairs,bullet,
    {x=0,y=12},{x=0,y=4})==0,
    "crossing masked area stops stair layer change")
bullet.layer=0
assert(S.updateLayer(stairs,bullet,
    {x=9,y=12},{x=9,y=6})==0,
    "distant trajectory doesn't cross the original stairs")

-- Bridge stairs are loot-only in original def and MUST NOT promote bullets.
local bridge={
    [16]={__id=16,__type=Types.Structure,
        type="bridge_lg_structure_01",
        pos={x=0,y=0},ori=0}
}
local bridgeShapes=S.snapshot(bridge)
assert(#bridgeShapes[1].stairs==2)
assert(bridgeShapes[1].stairs[1].lootOnly)
bullet.layer=0
assert(S.updateLayer(bridgeShapes,bullet,
    {x=0,y=13},{x=0,y=9})==0)

-- Structure origin/orientation transforms use same source helper as buildings.
atOrigin[8].ori=1
local turned=S.snapshot(atOrigin)
bullet.layer=0
assert(S.updateLayer(turned,bullet,
    {x=-12,y=0},{x=-6,y=0})==2,
    "source ori=1 stair rotated to -X world axis")
atOrigin[8].ori=0
atOrigin[8].pos={x=100,y=200}
local shifted=S.snapshot(atOrigin)
bullet.layer=0
assert(S.updateLayer(shifted,bullet,
    {x=100,y=212},{x=100,y=206})==2)
bullet.layer=0
assert(S.updateLayer(shifted,bullet,
    {x=0,y=12},{x=0,y=6})==0)

-- Integrate real UpdateMsg world state -> bullet trail layer.
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
local obj={
    __type=Types.Structure,__id=8,type="bunker_structure_01",
    pos={x=0,y=0},ori=0
}
local function shot(x,y,dx,dy)
    return {bulletType="bullet_ak47",pos={x=x,y=y},
        dir={x=dx,y=dy},playerId=1,layer=0,
        reflectCount=0,varianceT=0,distAdjIdx=8,
        speedMult=1,distanceMult=1}
end
state:applyUpdate({fullObjects={obj},bullets={shot(0,12,0,-1)}})
local trails=Trails.new()
trails:update(state,0)
trails:update(state,.06) -- 6 world units: 12 -> 6
assert(#trails.trails==1)
near(trails.trails[1].pos.y,6)
assert(trails.trails[1].layer==2)
assert(not trails.trails[1].collided)
-- Masks should not promote when the bullet crosses them.
state:applyUpdate({bullets={shot(0,12,0,-1)}})
trails:update(state,0)
trails:update(state,.08) -- 8 world units -> enters mask y<5.8
assert(#trails.trails==2)
assert(trails.trails[2].layer==0)
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=1,started=true})
trails:update(state,0)
assert(#trails.trails==0 and #trails.colliders.structures==0)
print("Survev source structure stairs, loot-only masks, orientation and bullet visual layer passed")
