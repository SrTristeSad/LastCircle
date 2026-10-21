-- Source-aligned Survev roof fade states for inside zoomRegions.
-- Ray/LOS visibility while outside a building is intentionally not asserted.
local Visibility=require("src.survev.building_visibility")
local Meta=require("src.survev.map_building_art")
local Types=require("src.survev.object_serialize_fns").Type
local def=assert(Meta.shack_01)
assert(#def.zoomRegions>0 and def.zoomRegions[1].zoomIn.type==1)
local vis=Visibility.new()
local objs={
    [50]={__type=Types.Building,__id=50,type="shack_01",
        pos={x=100,y=100},ori=0,layer=0,
        ceilingDead=false,ceilingDamaged=false},
}
local player={pos={x=100,y=100},layer=0}
local z=def.zoomRegions[1].zoomIn
assert(Visibility.isInRegion(z,objs[50].pos,0,player.pos))
assert(not Visibility.isInRegion(z,objs[50].pos,0,{x=140,y=140}))
vis:update(.05,objs,player)
assert(math.abs(vis:alpha(50)-.4)<1e-9,"12 Hz source reveal step")
vis:update(.05,objs,player)
assert(math.abs(vis:alpha(50)-.16)<1e-9)
-- When outside original may scan walls; use a distant point where no rays
-- can reach so the remaining fade rate is source-equivalent.
player.pos={x=400,y=400}
vis:update(.05,objs,player)
assert(vis:alpha(50)>.16,"roof must fade back in outside visibility")
-- Source special case: destroyed roof always reveals regardless of player.
objs[50].ceilingDead=true
vis:update(.2,objs,nil)
assert(vis:alpha(50)==0)
-- Rotation of the source zoomIn collider is world-based, not screen-based.
objs[50].ceilingDead=false
objs[50].ori=1
vis:reset()
player.pos={x=100,y=102}
assert(Visibility.isInRegion(z,objs[50].pos,1,player.pos))
vis:update(.05,objs,player)
assert(vis:alpha(50)<1)
-- Forced no-reveal matches the original zeroing of visionTicker.
player.noCeilingRevealTicker=2
vis:update(.05,objs,player)
assert(vis:alpha(50)>.4)
objs[50]=nil
vis:update(.05,objs,player)
assert(vis:alpha(50)==1)
print("Source-equivalent Survev inside zoom region, linger and fade tested")
