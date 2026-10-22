-- The user must see real Survev API quickplay rather than an offline demo.
-- Mock only external API and WebSocket; test actual main.lua UI callbacks.
local Match=require("src.survev.matchmaking")
local Network=require("src.survev.network_client")
local calls={siteInfo=0,match=0,join=0}
Match.siteInfo=function(base,opts)
    calls.siteInfo=calls.siteInfo+1
    assert(base=="http://127.0.0.1:17983")
    assert(opts.region=="na" and opts.gameModeIdx>=0)
    return {modes={
        {mapName="main",teamMode=1,enabled=true},
        {mapName="main",teamMode=2,enabled=false},
        {mapName="main",teamMode=4,enabled=true},
    },captchaEnabled=false,pops={}}
end
Match.request=function(base,opts)
    calls.match=calls.match+1
    assert(base=="http://127.0.0.1:17983")
    assert(opts.region=="na" and #opts.zones==0)
    assert(opts.gameModeIdx==calls.join*2)
    return {joinToken="SERVER_TOKEN",urls={"ws://127.0.0.1:19998/relay?test=1"}}
end
Network.new=function(opts)
    assert(opts.timeout==5)
    local stub={state="idle"}
    function stub:connectMatch(match,join)
        assert(match.joinToken=="SERVER_TOKEN")
        assert(#match.urls==1)
        assert(join.name=="Jogador Lua")
        calls.join=calls.join+1
        return true,match.urls[1]
    end
    function stub:getGameState() return nil end
    return stub
end
local graphics={}
for _,key in ipairs({"setColor","rectangle","print","printf","clear",
    "setScissor","line","circle","draw","setLineWidth","push","pop",
    "translate","scale"}) do
    graphics[key]=function()end
end
graphics.newFont=function()return {}end
graphics.newMesh=function()return {release=function()end}end
graphics.setFont=function()end
graphics.getDimensions=function()return 1280,720 end
graphics.getWidth=function()return 1280 end
graphics.getHeight=function()return 720 end
love={
    filesystem={getInfo=function()return nil end},
    graphics=graphics,
    math={triangulate=function(p) return #p>=6 and
        {{p[1],p[2],p[3],p[4],p[5],p[6]}} or {} end},
    window={setTitle=function()end},
    keyboard={isDown=function()return false end},
    mouse={getPosition=function()return 640,360 end,
        isDown=function()return false end},
    system={getClipboardText=function()return "" end},
    event={quit=function()end},
}
dofile("main.lua")
love.load()
love.draw() -- starting screen must be the real API menu, not fake gameplay
-- Entering play without API URL must NOT fabricate a join token.
love.keypressed("return")
assert(calls.siteInfo==0 and calls.match==0 and calls.join==0)
love.textinput("http://127.0.0.1:17983")
love.keypressed("return")
assert(calls.siteInfo==1 and calls.match==1 and calls.join==1)
-- The second mode is disabled by site_info, so no join.
love.keypressed("f2")
love.keypressed("return")
assert(calls.siteInfo==1 and calls.match==1 and calls.join==1)
love.keypressed("f3")
love.keypressed("return")
assert(calls.siteInfo==1 and calls.match==2 and calls.join==2)
love.draw() -- the server's real map/mode label should not crash the menu
print("Original Survev menu quickplay, site_info and mode gating passed")
