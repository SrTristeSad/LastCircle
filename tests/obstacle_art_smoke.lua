local Art=require("src.survev.obstacle_art_renderer")
local Registry=require("src.survev.map_obstacle_art")
local Camera=require("src.survev.camera")
assert(Registry.barrel_01.asset=="map/map-barrel-01.png")
assert(math.abs(Registry.barrel_01.imageScale-.4)<.000001)
assert(Registry.house_door_01.doorAnchor.y==1)
local calls,loaded,missing={},{},0
love={
    filesystem={getInfo=function(path)
        return path=="assets/survev/img/map/map-barrel-01.png"
            or path=="assets/survev/img/map/map-door-01.png"
    end},
    graphics={
        newImage=function(path)
            loaded[#loaded+1]=path
            return {getDimensions=function() return 144,144 end,
                setFilter=function() end}
        end,
        draw=function(_,x,y,angle,sx,sy,ax,ay)
            calls[#calls+1]={x=x,y=y,angle=angle,sx=sx,sy=sy,ax=ax,ay=ay}
        end,
        setColor=function() end,
        circle=function() missing=missing+1 end,
        print=function() end,
    }
}
local camera=Camera.new()
camera.m_pos={x=300,y=200}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local art=Art.new()
local objects={
    [14]={__type=2,__id=14,type="barrel_01",pos={x=300,y=200},
        ori=1,scale=1.2,dead=false},
    [15]={__type=2,__id=15,type="house_door_01",pos={x=305,y=201},
        ori=0,scale=1,dead=false},
    [16]={__type=2,__id=16,type="type_missing_from_upstream",
        pos={x=301,y=201},ori=0,scale=1,dead=false},
}
art:draw(objects,camera,1280,720)
assert(art.drawn==2 and art.unavailable==1)
assert(#calls==2 and #loaded==2)
local barrel=Registry.barrel_01
local expectedScale=1.5*1.2*barrel.imageScale
local foundBarrel=false
for _,call in ipairs(calls) do
    if math.abs(call.angle+math.pi/2)<1e-6 then
        assert(math.abs(call.x-640)<1e-6 and math.abs(call.y-360)<1e-6)
        assert(math.abs(call.sx-expectedScale)<1e-6)
        assert(call.ax==72 and call.ay==72)
        foundBarrel=true
    else
        assert(call.ax==72 and call.ay==144,"original door sprite anchor")
    end
end
assert(foundBarrel)
art:draw(objects,camera,1280,720)
assert(#loaded==2,"textures must be cached, not reloaded each frame")
assert(missing>=2,"missing upstream art must be explicitly diagnostic")
-- zOrd 18 (Player) and ~750 (roof): original bushes/trees are layered.
assert(Art.inStratum(Registry.barrel_01.zIdx,"belowPlayer"))
assert(Art.inStratum(Registry.bush_01.zIdx,"betweenPlayerAndRoof"))
assert(Art.inStratum(Registry.tree_01.zIdx,"aboveRoof"))
assert(not Art.inStratum(Registry.tree_01.zIdx,"belowPlayer"))
assert(Art.inStratum(Registry.barrel_01.zIdx,"all"))
print("Survev obstacle definitions, art paths, sprite rotation, scale, anchor and cache passed")
