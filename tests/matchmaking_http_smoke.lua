-- Actual LuaSocket POST to local server with original Survev API schema.
local Match=require("src.survev.matchmaking")
local result,errorMessage=Match.request("http://127.0.0.1:17983",{
    region="na",gameModeIdx=0,zones={},timeout=3,
})
assert(result, "Matchmaking transport failed: "..tostring(errorMessage))
assert(result.joinToken=="AUTHENTIC-FIXTURE-TOKEN")
assert(#result.urls==1 and result.urls[1]=="ws://127.0.0.1:17984/play")
print("Real HTTP LuaSocket POST /api/find_game_v2 passed")
