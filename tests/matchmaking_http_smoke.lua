-- Actual LuaSocket POST to local server with original Survev API schema.
local Match=require("src.survev.matchmaking")
local info,infoError=Match.siteInfo("http://127.0.0.1:17983",{timeout=3})
assert(info,"Site info transport failed: "..tostring(infoError))
assert(#info.modes==3 and info.modes[1].enabled==true)
assert(info.modes[2].enabled==false and info.modes[3].teamMode==4)
assert(info.pops.na.playerCount==22 and info.captchaEnabled==false)
local result,errorMessage=Match.request("http://127.0.0.1:17983",{
    region="na",gameModeIdx=0,zones={},timeout=3,
})
assert(result, "Matchmaking transport failed: "..tostring(errorMessage))
assert(result.joinToken=="fixture-token")
assert(#result.urls==1 and result.urls[1]=="ws://127.0.0.1:19998/relay?test=1")
print("Real HTTP LuaSocket POST /api/find_game_v2 passed")
