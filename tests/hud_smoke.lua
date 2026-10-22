-- Survev ui2.ts HUD source semantics and no invented server data.
local HUD=require("src.survev.hud")
local Game=require("src.survev.game_config")
local Equipment=require("src.survev.equipment_art")
local Demo=require("src.survev.offline_demo")
local state=Demo.new():getGameState()
local view=assert(HUD.project(state))
assert(view.localPreview and #view.slots==Game.WeaponSlot.Count)
assert(view.health==100 and view.boost==62.5)
assert(view.scope=="1xscope")
assert(view.active.type=="fists" and view.slots[3].equipped)
assert(view.slots[1].type=="ak47" and view.slots[2].type=="m9")
assert(view.slots[1].ammo==Equipment.weapons.ak47.maxClip)
assert(view.slots[2].ammo==Equipment.weapons.m9.maxClip)
assert(view.clip==nil and view.reserve==nil,"melee slot has no gun ammo")
local demo=Demo.new()
local live=demo:getGameState()
assert(demo:equip(4))
view=assert(HUD.project(live))
assert(view.active.type=="ak47" and view.active.index==0)
assert(view.clip==Equipment.weapons.ak47.maxClip)
assert(view.reserve==90)
assert(demo:equip(3))
view=assert(HUD.project(live))
assert(view.active.type=="m9" and view.active.index==1)
assert(view.clip==Equipment.weapons.m9.maxClip and view.reserve==120)
assert(demo:equip(2))
view=assert(HUD.project(live))
assert(view.active.type=="pan" and view.active.index==2)
assert(view.clip==nil and view.reserve==nil)
assert(demo:equip(5))
view=assert(HUD.project(live))
assert(view.active.type=="m9_dual" and view.clip~=nil)
assert(demo:equip(1))
view=assert(HUD.project(live))
assert(view.active.type=="fists" and view.slots[3].equipped)
live.localData.weapons[1].ammo=0
live.localData.health=21.75
live.localData.boost=31.25
view=assert(HUD.project(live))
assert(view.health==21.75 and view.boost==31.25)
assert(view.healthColor[1]==255 and view.healthColor[2]==0)
local segments=HUD.boostSegments(100)
for _,v in ipairs(segments) do assert(v==1) end
local zero=HUD.boostSegments(0)
for _,v in ipairs(zero) do assert(v==0) end
local half=HUD.boostSegments(50)
assert(#half==4 and half[1]==1 and half[2]==1 and half[3]==0)
assert(HUD.healthColor(12,true)[1]==255)
assert(HUD.healthColor(12,true)[2]==0)
live.localData.health=nil;live.localData.boost=nil
live.localData.inventory=nil;live.localData.weapons=nil;live.localData.curWeapIdx=nil
view=assert(HUD.project(live))
assert(view.health==nil and view.boost==nil and view.clip==nil)
assert(view.active==nil and #view.slots==4)
assert(view.slots[1].ammo==nil,"no invented ammo for missing network packet")
live.objects[live.activeId].dead=true
live.localData.health=19
assert(HUD.project(live).health==0)
assert(HUD.project({joined=false})==nil)
local graphics,images,draws={},0,0
local names={"setColor","rectangle","setLineWidth","printf","print"}
for _,name in ipairs(names) do graphics[name]=function() end end
graphics.newImage=function()
    images=images+1
    local obj={}
    function obj:setFilter() end
    function obj:getDimensions() return 100,50 end
    return obj
end
graphics.draw=function() draws=draws+1 end
love={graphics=graphics,filesystem={getInfo=function() return true end}}
local renderer=HUD.new()
assert(renderer:draw(demo:getGameState(),1280,720))
assert(renderer:draw(demo:getGameState(),1280,720))
assert(images>=1 and images<=3)
assert(draws>=2)
assert(not renderer:draw({joined=false},1280,720))
print("Survev 4-slot HUD projection, health/boost, ammo authority and cached artwork passed")
