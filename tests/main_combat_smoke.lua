-- Verify actual main.lua gameplay controls, not just a fabricated InputMsg.
-- The external network API is mocked here; a separate ws_combat_network.lua
-- verifies the same packets against the original TypeScript server.
local Match=require("src.survev.matchmaking")
local Network=require("src.survev.network_client")
local Actions=require("src.survev.input_bindings").Input
local state={
    joined=true,localId=7,activeId=7,spectating=false,
    gameOver=nil,objects={[7]={
        __id=7,pos={x=120,y=140},dir={x=1,y=0},
        __type=require("src.survev.object_serialize_fns").Type.Player,
        activeWeapon="m9",dead=false,downed=false,layer=0,
    }},map=nil,updateCount=1,
    localData={health=80,boost=10,zoom=50,scope="1xscope",
        inventory={bandage=2,["9mm"]=15},
        curWeapIdx=0,weapons={
            {type="m9",ammo=15},{type="",ammo=0},
            {type="fists",ammo=0},{type="",ammo=0},
        },
    },
}
Match.siteInfo=function()
    return {modes={{mapName="main",teamMode=1,enabled=true}},
        captchaEnabled=false,pops={}}
end
Match.request=function() return {
    joinToken="real-token",urls={"ws://127.0.0.1:19998/relay?test=1"},
} end
local sent={}
Network.new=function()
    local c={state="idle",connection={state="closed"}}
    function c:connectMatch(match)
        assert(match.joinToken=="real-token")
        self.connection.state="open"
        self.state="joined"
        return true,match.urls[1]
    end
    function c:getGameState() return state end
    function c:poll()end
    function c:sendInput(msg,dt)
        assert(dt==.016)
        sent[#sent+1]={
            moveLeft=msg.moveLeft,moveRight=msg.moveRight,
            shootStart=msg.shootStart,shootHold=msg.shootHold,
            inputs={(table.unpack or unpack)(msg.inputs)},useItem=msg.useItem,
            portrait=msg.portrait,
            toMouseLen=msg.toMouseLen,toMouseDir=msg.toMouseDir,
        }
        return "binary input sent"
    end
    function c:close()self.state="closed";self.connection.state="closed"end
    return c
end
local gfx={}
for _,name in ipairs({"setColor","rectangle","print","printf","clear",
    "setScissor","line","circle","draw","setLineWidth","push","pop",
    "translate","scale"}) do gfx[name]=function()end end
gfx.newFont=function()return {}end
gfx.newMesh=function()return {release=function()end}end
gfx.setFont=function()end
gfx.getDimensions=function()return 1280,720 end
gfx.getWidth=function()return 1280 end
gfx.getHeight=function()return 720 end
local down={}
local mouse={down=false}
love={
    graphics=gfx,
    filesystem={getInfo=function()return nil end},
    math={triangulate=function()return {}end},
    keyboard={isDown=function(...)
        for i=1,select("#",...) do
            if down[select(i,...)] then return true end
        end
        return false
    end},
    mouse={
        getPosition=function()return 700,350 end,
        isDown=function(button)return button==1 and mouse.down end,
    },
    window={setTitle=function()end},
    system={getClipboardText=function()return "" end},
    event={quit=function()end},
}
dofile("main.lua")
love.load()
love.textinput("http://127.0.0.1:8000")
love.keypressed("return")
local function frame()
    love.update(.016)
    return assert(sent[#sent],"main.lua did not send network InputMsg")
end
-- Mouse firing starts only from an actual world click; holding the
-- button thereafter does not resend shootStart every frame.
down.d=true
mouse.down=true
love.mousepressed(230,190,1)
local first=frame()
assert(first.moveRight and first.shootStart and first.shootHold)
assert(#first.inputs==0)
assert(first.toMouseLen>0 and first.toMouseLen<=64)
local hold=frame()
assert(hold.shootHold and not hold.shootStart)
mouse.down=false
down.d=false
local released=frame()
assert(not released.moveRight and not released.shootStart
    and not released.shootHold)
love.keypressed("f")
local interact=frame()
assert(#interact.inputs==1 and interact.inputs[1]==Actions.Interact)
local idle=frame()
assert(#idle.inputs==0,"F interaction was not one-shot")
love.keypressed("r")
local reload=frame()
assert(reload.inputs[1]==Actions.Reload)
love.keypressed("7")
local heal=frame()
assert(heal.useItem=="bandage" and #heal.inputs==0)
assert(frame().useItem=="","healing request must be one-shot")
love.keypressed("2")
local equip=frame()
assert(equip.inputs[1]==Actions.EquipSecondary)
-- HUD interaction is a weapon selection, never a shot.
love.mousepressed(945,425,1)
local weapon=frame()
assert(weapon.inputs[1]==Actions.EquipPrimary)
assert(not weapon.shootStart and not weapon.shootHold)
-- An inventory click never fires while the panel is visible.
love.keypressed("i")
mouse.down=true
love.mousepressed(200,180,1)
local inventory=frame()
assert(not inventory.shootStart and not inventory.shootHold)
mouse.down=false
love.keypressed("i")
-- Original desktop arrow keys can move if no other binding consumes them.
down.left=true
local arrow=frame()
assert(arrow.moveLeft)
down.left=false
assert(not frame().moveLeft)
-- Only the server can change hitpoints, inventory and weapon slots.
assert(state.localData.health==80)
assert(state.localData.inventory.bandage==2)
assert(state.localData.weapons[1].type=="m9")
print("Actual Lua main.lua fire/hold/release, F, R, heal, equip, HUD, inventory and arrows passed")
