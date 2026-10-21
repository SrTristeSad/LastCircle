-- Headless smoke test of the LÖVE entry point's two UI modes.
-- Confirms the real client bootstraps even without prepared image assets.
local functions={setColor=true,rectangle=true,print=true,printf=true,clear=true,
    setScissor=true,line=true,circle=true,draw=true,setLineWidth=true}
local graphics={}
for name in pairs(functions) do graphics[name]=function() end end
graphics.newFont=function() return {} end
graphics.setFont=function() end
graphics.getDimensions=function() return 1280,720 end
graphics.getWidth=function() return 1280 end
graphics.getHeight=function() return 720 end
local quitCalled=false
love={
    filesystem={getInfo=function() return nil end},
    graphics=graphics,
    window={setTitle=function() end},
    keyboard={isDown=function() return false end},
    mouse={getPosition=function() return 640,360 end,isDown=function() return false end},
    system={getClipboardText=function() return "sample" end},
    event={quit=function() quitCalled=true end},
}
dofile("main.lua")
assert(type(love.load)=="function" and type(love.draw)=="function")
love.load()
love.resize(1280,720)
love.draw()
love.keypressed("right")
love.keypressed("left")
love.draw()
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
assert(quitCalled,"asset inspector escape must quit")
print("LÖVE headless entry-point assets/network UI smoke tests passed")
