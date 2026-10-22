-- Headless LÖVE minimap canvas/render cache; source shapes and terrain.
local Mini=require("src.survev.minimap")
local Demo=require("src.survev.offline_demo")
local state=Demo.new():getGameState()
local map=state.map
local m=Mini.new()
local commands=m:mapShapes(map)
assert(#commands>=7,"original Survev map metadata yielded no buildings")
local lastZ=-math.huge
local house,tree=false,false
for _,o in ipairs(commands) do
    assert(o.zIdx>=lastZ,"original minimap z order not sorted")
    lastZ=o.zIdx
    if o.objType=="shack_01" then house=true end
    if o.objType=="tree_01" then tree=true end
    assert(type(o.color)=="number" and
        (o.type==0 or o.type==1),"original shape metadata")
end
assert(house and tree)
local at=m:project({x=map.width/2,y=map.height/2},512,map)
assert(math.abs(at.x-256)<1e-10 and math.abs(at.y-256)<1e-10)
local top=m:project({x=map.width/2,y=map.height},512,map)
local bottom=m:project({x=map.width/2,y=0},512,map)
assert(top.y<bottom.y,"Survev world Y+ must be screen up")

local drawn,terrainDraws,canvases,freed=0,0,0,0
local stub={}
for _,fn in ipairs({"setColor","rectangle","circle","line","setLineWidth",
    "print","printf","push","pop","setCanvas","clear"}) do
    stub[fn]=function() end
end
stub.draw=function() drawn=drawn+1 end
stub.newCanvas=function(size,sizeY)
    assert(size==512 and sizeY==512)
    canvases=canvases+1
    local canvas={}
    function canvas:getDimensions() return size,sizeY end
    function canvas:setFilter(mode,mode2)
        assert(mode=="linear" and mode2=="linear")
    end
    function canvas:release() freed=freed+1 end
    return canvas
end
love={graphics=stub}
local terrain={draw=function(self,camera,w,h)
    terrainDraws=terrainDraws+1
    assert(w==512 and h==512)
    assert(camera.m_pos.x==map.width/2 and
        camera.m_pos.y==map.height/2)
end}
m:build(map,terrain)
assert(canvases==1 and terrainDraws==1 and m.builds==1)
assert(m:draw(state,1280,720,terrain))
assert(m:draw(state,1280,720,terrain))
assert(terrainDraws==1 and canvases==1,
    "minimap static background must not be regenerated per frame")
assert(drawn==2,"cached canvas should draw once per frame")
state.objects[state.activeId].pos={x=487,y=123}
local p=m:project(state.objects[state.activeId].pos,205,map)
assert(p.x>102 and p.y>102,"player marker should move dynamically")
m:toggleExpanded()
assert(m.expanded and m:draw(state,1280,720,terrain))
m:toggleExpanded()
m:toggleVisible()
assert(not m:draw(state,1280,720,terrain))
m:toggleVisible()
local another=Demo.new():getGameState()
m:build(another.map,terrain)
assert(canvases==2 and freed==1 and terrainDraws==2,
    "new MapMsg must invalidate the cached minimap")
m:reset()
assert(freed==2 and m.canvas==nil)
print("Survev minimap cached canvas, terrain, world projection, original objects and M/N toggle passed")
