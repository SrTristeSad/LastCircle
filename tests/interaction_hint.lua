-- The door prompt is built from REAL Survev obstacle colliders and
-- def.door.interactionRad, not object center or invented pickup metadata.
local Demo=require("src.survev.offline_demo")
local Hint=require("src.survev.interaction_hint")
local Geometry=require("src.survev.los_geometry")
local MapObjs=require("src.survev.map_obstacle_art")
local Config=require("src.survev.game_config")
local world=Demo.new():getGameState()
local player=world.objects[world.activeId]
local door=world.objects[13]
assert(MapObjs.house_door_01.door.interactionRad==.75)
assert(not MapObjs.house_door_01.door.autoOpen)
assert(Hint.scan(world)==nil,"cannot interact with distant door")
player.pos={x=361,y=322}
local current=assert(Hint.scan(world))
assert(current.id==13 and current.type=="house_door_01")
assert(current.key=="F" and current.action=="Abrir porta")
assert(current.usable and current.penetration>0)
door.door.open=true
assert(Hint.scan(world).action=="Fechar porta")
door.door.open=false
door.door.locked=true
assert(not Hint.scan(world).usable,"locked but visible door")
door.door.locked=false
door.door.canUse=false
assert(Hint.scan(world)==nil,"locked out by authoritative canUse")
door.door.canUse=true
door.dead=true
assert(Hint.scan(world)==nil,"destroyed obstacles cannot interact")
door.dead=false
door.layer=1
assert(Hint.scan(world)==nil,"different layer must not interact")
door.layer=0
assert(Hint.scan(world).id==13)
player.dead=true
assert(Hint.scan(world)==nil,"dead players cannot interact")
player.dead=false
-- Collider priority differs from old nearest-center shortcut: at the
-- far end of a long door, collider is near while origin may be distant.
player.pos={x=362,y=324.75}
assert(Hint.scan(world).id==13)
assert(math.abs(player.pos.y-door.pos.y)>
    Config.player.radius+MapObjs.house_door_01.door.interactionRad)
-- Test that original collider radius and player radius are both applied.
local c=Geometry.transform(MapObjs.house_door_01.collision,door.pos,door.ori)
local hit=Geometry.intersectCircle(c,player.pos,
    MapObjs.house_door_01.door.interactionRad+Config.player.radius)
assert(hit and hit.pen>0)

local seen={}
love={graphics={
    setColor=function() end,
    rectangle=function() end,
    printf=function(text) seen[#seen+1]=text end,
}}
assert(Hint.draw(world,1280,720))
assert(seen[1]:find("Abrir porta"))
assert(not Hint.draw({objects={},activeId=0},1280,720))
print("Original Survev collider/radius-based door prompt, locks, layers, angle and source F action passed")
