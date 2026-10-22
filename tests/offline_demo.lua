-- Offline visual sandbox: source definitions, movement/collision and doors.
-- Does not claim it reproduces a complete authoritative Survev match.
local Demo=require("src.survev.offline_demo")
local Config=require("src.survev.game_config")
local Net=require("src.survev.net")
local Obj=require("src.survev.object_serialize_fns").Type
local Registry=require("src.survev.map_obstacle_art")
local Buildings=require("src.survev.map_building_art")
local V=require("src.survev.v2")
local d=Demo.new()
local state=d:getGameState()
assert(state.joined and state.started and state.offlinePreview)
assert(state.localId==1 and state.activeId==1)
assert(state.map.mapName=="main" and state.map.seed==98765)
assert(state.map.width==720 and state.map.height==640)
assert(#state.map.rivers==1 and #state.map.groundPatches==1)
assert(#state.map.objects>=13)
assert(state.objects[1].__type==Obj.Player)
assert(state.objects[1].outfit=="outfitBase")
assert(state.localData.health==100)
assert(d:punch(),"mouse click must start source fist animation")
assert(not d:punch(),"animation must not restart every frame")
assert(state.objects[1].previewFistTicker==0)
d:update(.05,0,0)
d:update(.05,0,0)
assert(math.abs(state.objects[1].previewFistTicker-.1)<1e-9)
assert(state.localData.health==100,"animation must not invent damage")
for i=1,4 do d:update(.05,0,0) end
assert(state.objects[1].previewFistTicker==nil,
    "animation must finish at upstream fists cooldown 0.25 seconds")
assert(d:punch(),"punch may restart once original cooldown ends")
for i=1,6 do d:update(.05,0,0) end
assert(state.objects[1].previewFistTicker==nil)

assert(state.objects[10].__type==Obj.Building and Buildings.shack_01)
assert(state.objects[13].__type==Obj.Obstacle and Registry.house_door_01)
for _,obj in pairs(state.objects) do
    if obj.type and obj.__type==Obj.Obstacle then
        assert(Registry[obj.type] and Registry[obj.type].asset,
            "demo has placeholder or nonexistent source art")
    end
end
local p=state.objects[1]
local sx=p.pos.x
local sequence=state.updateCount
d:update(.05,1,0,{x=400,y=321})
assert(math.abs(p.pos.x-sx-Config.player.moveSpeed*.05)<1e-7,
    "local preview must use the original speed, not guessed speed")
assert(state.updateCount>sequence)
assert(math.abs(V.length(p.dir)-1)<1e-7)
local x1=p.pos.x
d:update(.05,1,1,{x=400,y=340})
assert(p.pos.x-x1<=Config.player.moveSpeed*.05/math.sqrt(2)+.00001,
    "diagonal movement may not exceed source cardinal speed")
assert(not d:interact(),"door out of source interaction range")
-- Travel toward the test door without penetrating its original collider.
for i=1,30 do d:update(.05,1,0,{x=362,y=321}) end
local door=state.objects[13]
assert(not door.door.open)
assert(d:interact(),"door should be interactive within Survev source range")
assert(state.objects[13].door.open)
assert(state.objects[13].door.seq==2)
assert(state.objects[13].ori~=0,"swing door must rotate like original server")
assert(d.interactions==1)
assert(d:interact(),"closing same door should work")
assert(not state.objects[13].door.open)
assert(state.objects[13].ori==0)
assert(state.objects[13].door.seq==3)
-- Local physics is not authoritative. Test boundary clamp and source obstacles.
p.pos={x=Config.player.radius+17,y=40}
d:update(.08,-1,0)
assert(p.pos.x>=17+1-1e-7,"local preview must not move through shore bounds")
local e=Demo.new()
assert(e.state~=state and e.state.map~=state.map)
assert(e.state.objects[13].door.open==false)
assert(e.state.map.seed==state.map.seed)
assert(Demo.new().state.objects[1].pos.x==sx)
print("LastCircle OFFLINE playtest passed: original map, sprite registry, camera state, WASD speed, collision, F doors and reset")
