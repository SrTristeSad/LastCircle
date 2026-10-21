-- Graphics integration test executed by a REAL LÖVE 11.x runtime under Xvfb.
-- A temporary CI game directory contains this file + src/, not mocks.
local Renderer=require("src.survev.map_renderer")
local Camera=require("src.survev.camera")
local Obstacles=require("src.survev.obstacle_art_renderer")
local renderer,cam,obstacles
local frames=0
function love.load()
    love.window.setTitle("LastCircle terrain smoke")
    love.window.setMode(960,640,{resizable=false,vsync=0})
    cam=Camera.new()
    cam.m_pos={x=360,y=320}
    cam.m_screenWidth,cam.m_screenHeight=960,640
    renderer=Renderer.new({
        mapName="main",seed=98765,width=720,height=640,
        shoreInset=17,grassInset=8,
        rivers={
            {width=8,looped=false,points={
                {x=0,y=130},{x=110,y=155},{x=200,y=210},{x=310,y=250},{x=440,y=290}
            }},
            {width=5,looped=false,points={
                {x=200,y=210},{x=270,y=350},{x=300,y=440},{x=310,y=640}
            }},
            {width=11,looped=true,points={
                {x=235,y=300},{x=285,y=365},{x=360,y=370},{x=390,y=300},
                {x=355,y=250},{x=280,y=245},{x=235,y=300}
            }},
        },
        groundPatches={
            {order=0,color=0x8c8b8a,roughness=.2,offsetDist=3,
                bound={type=0,pos={x=200,y=270},rad=22}},
            {order=1,color=0x667744,roughness=.25,offsetDist=2,
                bound={type=1,min={x=300,y=400},max={x=375,y=450}}},
        },
    })
    assert(#renderer.terrain.rivers==3)
    obstacles=Obstacles.new()
end
function love.draw()
    renderer:draw(cam,960,640)
    obstacles:draw({
        [1]={__type=2,__id=1,type="barrel_01",pos={x=360,y=320},
            ori=1,scale=1,dead=false},
        [2]={__type=2,__id=2,type="house_door_01",pos={x=370,y=320},
            ori=0,scale=1,dead=false}
    },cam,960,640)
    assert(obstacles.drawn==2 and obstacles.unavailable==0,
        "original Survev barrel/door SVG rasterized assets must render")
    frames=frames+1
    if frames>=3 then
        renderer:release()
        print("TRUE_LOVE_SURVEV_TERRAIN_RENDER_SUCCESS; frames="..frames)
        love.event.quit(0)
    end
end
