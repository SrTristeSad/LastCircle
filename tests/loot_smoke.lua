-- Source Survev LootBarn/UI loot selection and offline collection tests.
local Demo=require("src.survev.offline_demo")
local Loot=require("src.survev.loot_renderer")
local Inventory=require("src.survev.inventory_panel")
local Hints=require("src.survev.interaction_hint")
local Defs=require("src.survev.loot_art")
local Obj=require("src.survev.object_serialize_fns").Type
local d=Demo.new()
local s=d:getGameState()
local p=s.objects[s.activeId]
assert(#Defs.bagKeys==25 and #Defs.loot["9mm"].asset>0)
assert(Defs.loot["m9"].type=="gun" and Defs.loot["bandage"].radius==1)
assert(s.objects[30].__type==Obj.Loot)
assert(Loot.nearest(s)==nil,"loot must not be auto-collected at spawn")
local display=assert(Inventory.project(s))
assert(#display.rows==25 and display.level==2 and display.available)
local i9
for _,row in ipairs(display.rows) do
    if row.type=="9mm" then i9=row end
end
assert(i9 and i9.count==120 and i9.max==330,
    "original backpack 02 (level 2) supports 330 9mm")
p.pos={x=353,y=325}
local closest=assert(Loot.nearest(s))
assert(closest.id==30 and closest.def.radius==1.2)
assert(Hints.scan(s).kind=="loot" and Hints.scan(s).usable)
local success,quantity=d:pickup()
assert(success and quantity==50)
assert(s.localData.inventory["9mm"]==170)
assert(s.objects[30]==nil,"all loot picked up must disappear")
assert(Loot.nearest(s)==nil)
assert(d.pickups==1 and s.localData.health==100,
    "local pickup must not simulate damage")
-- Original LootBarn restrictions: owner, layer, dead/downed & range.
p.pos={x=349,y=324}
assert(Loot.nearest(s).id==31)
s.objects[31].ownerId=98
assert(Loot.nearest(s)==nil)
s.objects[31].ownerId=p.__id
assert(Loot.nearest(s).id==31)
s.objects[31].layer=1
assert(Loot.nearest(s)==nil)
s.objects[31].layer=0
p.downed=true
assert(Loot.nearest(s)==nil)
p.downed=false;p.dead=true
assert(Loot.nearest(s)==nil)
p.dead=false
local ok,n=d:pickup()
assert(ok and n==3 and s.localData.inventory.bandage==3)
assert(s.objects[31]==nil)
-- Unimplemented gun pickups are VISUAL ONLY, never fabricated gun slots.
p.pos={x=348,y=316}
assert(Loot.nearest(s).id==32)
assert(not d:pickup(),"gun pickup requires real inventory/server logic")
assert(s.objects[32].type=="m9" and s.localData.weapons[2].type=="m9")
-- Partial stack respects source capacity exactly; full stack is retained.
local limited=Demo.new()
local w=limited:getGameState()
w.localData.inventory["9mm"]=325
w.objects[1].pos={x=353,y=325}
local yes,amount=limited:pickup()
assert(yes and amount==5 and w.localData.inventory["9mm"]==330)
assert(w.objects[30].count==45)
assert(not limited:pickup(),"full bag cannot silently swallow ground loot")
assert(w.objects[30].count==45)
-- No invented current values or capacity for incomplete real server data.
local live=Demo.new():getGameState()
live.offlinePreview=nil
live.localData.inventory=nil
live.objects[1].backpack=nil
local projected=assert(Inventory.project(live))
assert(not projected.available and projected.level==nil)
assert(projected.rows[1].count==nil and projected.rows[1].max==nil)
local invalid=Demo.new():getGameState()
invalid.objects[33].type="NOT_FROM_SURVEV"
invalid.objects[1].pos={x=357,y=317}
assert(Loot.nearest(invalid)==nil)
-- Real LÖVE graphics contract: only metadata-referenced sprites, cached.
local loads,draws=0,0
love={
  filesystem={getInfo=function(path)
      assert(path:find("assets/survev/img/",1,true)==1)
      return true
  end},
  graphics={
    setColor=function() end,
    newImage=function(path)
      loads=loads+1
      local tex={}
      function tex:getDimensions()return 48,48 end
      function tex:setFilter()end
      return tex
    end,
    draw=function() draws=draws+1 end,
    rectangle=function() end,
    circle=function() end,
    line=function() end,
    setLineWidth=function() end,
    print=function() end,
    printf=function() end,
  }
}
local camera=require("src.survev.camera").new()
camera.m_pos={x=355,y=321}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local renderer=Loot.new()
local a=renderer:draw(s.objects,camera,1280,720)
assert(a>=3 and loads>=2 and draws>=a)
local first=loads
renderer:draw(s.objects,camera,1280,720)
assert(loads==first,"loot PNG cache must not load textures twice")
local inv=Inventory.new()
assert(inv:toggle() and inv:draw(s,1280,720))
assert(inv:draw(s,1280,720))
assert(not inv:toggle() and not inv:draw(s,1280,720))
print("Survev loot: source radii, layer/owner checks, stack caps, HUD inventory, images and preview pickup passed")
