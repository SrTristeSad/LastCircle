-- Headless entry-point smoke for local demo, source assets and network UI.
-- A mocked graphics API exercises control flow; real rendering is checked
-- separately by the LÖVE/OpenGL CI workflow.
local functions={
    setColor=true,rectangle=true,print=true,printf=true,clear=true,
    setScissor=true,line=true,circle=true,draw=true,setLineWidth=true,
    push=true,pop=true,translate=true,scale=true,
}
local graphics={}
for name in pairs(functions) do graphics[name]=function() end end
graphics.newFont=function() return {} end
graphics.newMesh=function()
    return {release=function() end}
end
graphics.setFont=function() end
graphics.getDimensions=function() return 1280,720 end
graphics.getWidth=function() return 1280 end
graphics.getHeight=function() return 720 end
local quitCalled=false
love={
    filesystem={getInfo=function() return nil end},
    graphics=graphics,
    math={triangulate=function(p)
        if #p<6 then return {} end
        return {{p[1],p[2],p[3],p[4],p[5],p[6]}}
    end},
    window={setTitle=function() end},
    keyboard={isDown=function() return false end},
    mouse={getPosition=function() return 640,360 end,isDown=function() return false end},
    system={getClipboardText=function() return "example" end},
    event={quit=function() quitCalled=true end},
}
dofile("main.lua")
assert(type(love.load)=="function" and type(love.draw)=="function")
love.load()
love.resize(1280,720)
-- Starts DIRECTLY in local Survev map, without a server.
love.update(.016)
love.draw()
love.keypressed("f")
love.keypressed("r")
love.keypressed("f5")
love.update(.016)
love.draw()
-- Original art viewer still available on F7.
love.keypressed("f7")
love.draw()
love.keypressed("right")
love.keypressed("left")
love.draw()
-- F6 remains the real protocol entry point.
love.keypressed("f6")
love.draw()
love.mousepressed(640,164,1)
love.textinput("w")
love.keypressed("tab")
love.textinput("a")
love.keypressed("backspace")
love.keypressed("tab")
love.keypressed("tab")
love.textinput("a")
love.update(.016)
love.draw()
love.keypressed("f6")
love.draw()
love.keypressed("escape")
assert(quitCalled,"Escape in local playtest should quit")
print("LÖVE headless local map / asset / WebSocket entry point passed")
