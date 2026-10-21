-- LÖVE API smoke with originals-only sprite metadata.
local Camera=require("src.survev.camera")
local Building=require("src.survev.building_renderer")
local Type=require("src.survev.object_serialize_fns").Type
local meta=require("src.survev.map_building_art")
local loaded,draws={},{}
love={
  filesystem={getInfo=function(path)
      return path:match("^assets/survev/img/map/map%-building%-.+%.png$")~=nil
  end},
  graphics={
    newImage=function(path)
      loaded[#loaded+1]=path
      local image={}
      function image:getDimensions() return 256,256 end
      function image:setFilter(a,b) assert(a=="linear" and b=="linear") end
      return image
    end,
    setColor=function() end,
    draw=function(image,x,y,angle,sx,sy,ox,oy)
        assert(image and type(x)=="number")
        draws[#draws+1]={x=x,y=y,angle=angle,sx=sx,sy=sy,ox=ox,oy=oy}
    end,
  }
}
local camera=Camera.new()
camera.m_pos={x=300,y=360}
camera.m_screenWidth,camera.m_screenHeight=1024,768
local renderer=Building.new()
local objs={
   [21]={__type=Type.Building,__id=21,type="bank_01",
       pos={x=310,y=355},ori=1,layer=0,ceilingDead=false,ceilingDamaged=false},
   [22]={__type=Type.Building,__id=22,type="shack_01",
       pos={x=300,y=360},ori=0,layer=0,ceilingDead=true,ceilingDamaged=false},
}
local floors=renderer:drawPhase(objs,camera,"floor",1024,768)
assert(floors==3,"bank 2 floors + shack 1 interior floor")
local ceilings=renderer:drawPhase(objs,camera,"ceiling",1024,768)
assert(ceilings==3,"bank roofs visible, shack roof destroyed")
local countLoaded=#loaded
assert(countLoaded==6)
assert(#draws==6)
local cx=camera:m_pointToScreen({x=310,y=355})
local foundBank=false
for _,d in ipairs(draws) do
    if math.abs(d.angle+math.pi/2)<1e-5 and d.ox==128 then
        foundBank=true
        break
    end
end
assert(foundBank,"building orientation must use original quadrant")
assert(math.abs(cx.x-752)<1e-5)
renderer:drawPhase(objs,camera,"floor",1024,768)
renderer:drawPhase(objs,camera,"ceiling",1024,768)
assert(#loaded==countLoaded,"building sprites must not reload each frame")
objs[21].ceilingDead=true
assert(renderer:drawPhase(objs,camera,"ceiling",1024,768)==0,
    "destroyed roof must reveal original interior floor")
assert(#renderer:getDefinition("bank_01").zoomRegions==3)
assert(meta.bank_01.floor[1].asset=="map/map-building-bank-floor-01.png")
print("Original floors/ceilings: image and lifecycle tests passed")
