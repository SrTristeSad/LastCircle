-- Actual LastCircle LÖVE input callbacks: after death the spectator may
-- request ORIGINAL SpectateMsg and MUST release previous input controls.
-- Matchmaking and server state are injected to avoid any fake gameplay.
local Match=require("src.survev.matchmaking")
local Network=require("src.survev.network_client")
local Spectate=require("src.survev.spectate_msg")
local modes={{mapName="main",teamMode=1,enabled=true}}
local living={__id=7,pos={x=120,y=140},dead=false,downed=false}
local target={__id=8,pos={x=130,y=150},dead=false,downed=false}
local state={
    joined=true,localId=7,activeId=7,spectating=false,
    objects={[7]=living,[8]=target},map=nil,gameOver=nil,
    teamMode=1,updateCount=0,localData={},
}
local actorInputs={}
local spectateActions={}
local client
Match.siteInfo=function()return {modes=modes,captchaEnabled=false,pops={}}end
Match.request=function()
    return {joinToken="real-from-server",urls={"ws://127.0.0.1:19998/relay"}}
end
Network.new=function()
    client={state="idle",connection={state="closed"}}
    function client:connectMatch(_,opts)
        assert(opts.name=="Jogador Lua")
        self.state="joined"
        self.connection.state="open"
        return true,"ws://127.0.0.1:19998/relay"
    end
    function client:getGameState()return state end
    function client:poll()end
    function client:sendInput(msg,dt)
        actorInputs[#actorInputs+1]={
            left=msg.moveLeft,right=msg.moveRight,shoot=msg.shootHold,
            begin=msg.shootStart,count=#msg.inputs,useItem=msg.useItem,
            portrait=msg.portrait,dt=dt,
        }
        return "sent"
    end
    function client:sendSpectate(action)
        spectateActions[#spectateActions+1]=action
        return "sent"
    end
    function client:close()self.connection.state="closed"end
    return client
end
local g={}
for _,name in ipairs({
    "setColor","rectangle","print","printf","clear","setScissor",
    "line","circle","draw","setLineWidth","push","pop","translate",
    "scale",
}) do g[name]=function()end end
g.newFont=function()return {}end
g.newMesh=function()return {release=function()end}end
g.setFont=function()end
g.getWidth=function()return 1280 end
g.getHeight=function()return 720 end
g.getDimensions=function()return 1280,720 end
local keys={}
love={
    graphics=g,
    filesystem={getInfo=function()return nil end},
    math={triangulate=function(p)
        return #p>=6 and {{p[1],p[2],p[3],p[4],p[5],p[6]}} or {}
    end},
    keyboard={isDown=function(...)
        for i=1,select("#",...) do if keys[select(i,...) ] then return true end end
        return false
    end},
    mouse={isDown=function()return false end,
        getPosition=function()return 700,360 end},
    window={setTitle=function()end},
    system={getClipboardText=function()return "" end},
    event={quit=function()end},
}
dofile("main.lua")
love.load()
love.textinput("http://127.0.0.1:8000")
love.keypressed("return")
assert(client and client.state=="joined")
keys["left"]=true
love.update(.016)
local alive=actorInputs[#actorInputs]
assert(alive.left and not alive.right and alive.count==0)
-- Original game.ts: GameOverMsg(gameOver=false) is NOT final.
living.dead=true
state.gameOver={gameOver=false,teamRank=2,playerStats={}}
love.keypressed("f")
love.keypressed("7")
love.keypressed("b")
assert(#spectateActions==1 and spectateActions[1]==Spectate.Action.Begin)
love.update(.016)
local empty=actorInputs[#actorInputs]
assert(not empty.left and not empty.right and not empty.shoot
    and not empty.begin and empty.count==0 and empty.useItem=="")
assert(empty.dt==.016)
state.activeId=8
state.spectating=true
love.keypressed("left")
love.keypressed("right")
assert(spectateActions[2]==Spectate.Action.Prev)
assert(spectateActions[3]==Spectate.Action.Next)
love.keypressed("r")
love.wheelmoved(0,1)
love.update(.016)
local observed=actorInputs[#actorInputs]
assert(observed.left==false and observed.count==0,
    "spectating must not control living observed character")
love.draw() -- spectator banner and game state should render without crashing
love.mousepressed(180,60,1)
assert(spectateActions[4]==Spectate.Action.Next)
-- Server marks whole match over: no additional spectate commands.
state.gameOver={gameOver=true,teamRank=2,playerStats={}}
love.keypressed("right")
assert(#spectateActions==4)
print("Survev real LÖVE player death, spectator target, neutral InputMsg and control isolation passed")
