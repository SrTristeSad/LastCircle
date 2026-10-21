-- Headless test for original-color/polygon staging in the LÖVE terrain renderer.
-- Geometry is independently compared to TS in terrain_parity.lua.
local MapRenderer=require("src.survev.map_renderer")
local Palettes=require("src.survev.map_colors")
local Camera=require("src.survev.camera")
local draws,meshes,released,grid=0,0,0,0
local graphics={}
for _,name in ipairs({
    "clear","push","translate","scale","setColor","rectangle",
    "line","setLineWidth","pop"
}) do
    graphics[name]=function(...) if name=="line" then grid=grid+1 end end
end
graphics.newMesh=function(vertices,primitive,usage)
    assert(primitive=="triangles" and usage=="static" and #vertices>=3)
    meshes=meshes+1
    local obj={vertices=vertices}
    function obj:release() released=released+1 end
    return obj
end
graphics.draw=function(obj)
    assert(obj and obj.vertices)
    draws=draws+1
end
local function triangulate(points)
    assert(#points%2==0 and #points>=6)
    local list={}
    for j=3,#points/2 do
        local i=(j-1)*2+1
        list[#list+1]={points[1],points[2],points[i-2],points[i-1],
            points[i],points[i+1]}
    end
    return list
end
love={graphics=graphics,math={triangulate=triangulate}}
local main=Palettes.main
assert(main.colors.grass==0x80af49)
assert(main.colors.beach==0xcdb35b)
assert(main.colors.water==0x3282ab)
local red,green,blue=MapRenderer.hexToRgb(main.colors.grass)
assert(math.abs(red-128/255)<1e-10)
assert(math.abs(green-175/255)<1e-10)
assert(math.abs(blue-73/255)<1e-10)
local map={
    mapName="main",width=720,height=640,seed=98765,
    shoreInset=17,grassInset=8,
    groundPatches={
        {order=0,color=0x8c8b8a,roughness=.2,offsetDist=3,
            bound={type=0,pos={x=200,y=270},rad=22}},
        {order=1,color=0x667744,roughness=.25,offsetDist=2,
            bound={type=1,min={x=300,y=400},max={x=375,y=450}}},
    },
    rivers={
        {width=8,looped=false,points={
            {x=0,y=130},{x=100,y=160},{x=200,y=210},{x=310,y=250},{x=440,y=290}
        }},
        {width=5,looped=false,points={
            {x=200,y=210},{x=270,y=350},{x=300,y=440},{x=310,y=640}
        }},
    }
}
local renderer=MapRenderer.new(map)
assert(renderer.map==map)
assert(#renderer.terrain.shore==260 and #renderer.terrain.grass==260)
assert(#renderer.terrain.rivers==2)
assert(#renderer.rivers==2)
assert(#renderer.groundPatches[0]==1 and #renderer.groundPatches[1]==1)
assert(meshes==8,"2 coasts + 2 patches + 4 river meshes = 8")
local cam=Camera.new()
cam.m_pos={x=200,y=240}
cam.m_screenWidth,cam.m_screenHeight=1280,720
renderer:draw(cam,1280,720)
assert(draws==8)
assert(grid>20,"Survev original world grid should be drawn")
renderer:release()
assert(released==8)
print("LÖVE Survev biome/shore/river/patch mesh rendering smoke test passed")
