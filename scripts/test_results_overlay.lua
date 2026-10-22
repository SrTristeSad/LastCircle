package.path="./?.lua;./?/init.lua;"..package.path
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Overlay=require("src.survev.results_overlay")
local state=State.new()
assert(Overlay.project(state)==nil)
state:applyMessage(Net.MsgType.GameOver,{
 teamId=2,teamRank=3,gameOver=true,winningTeamId=1,
 playerStats={{playerId=7,kills=2,timeAlive=315,dead=true,
 damageDealt=450,damageTaken=188}}
})
local result=assert(Overlay.project(state))
assert(result.finished and not result.won and result.rank==3)
assert(#result.stats==1 and result.stats[1].kills==2)
assert(result.stats[1].damageDealt==450 and result.stats[1].timeAlive==315)
state:applyMessage(Net.MsgType.GameOver,{
 teamId=2,teamRank=1,gameOver=true,winningTeamId=2,playerStats={}
})
result=assert(Overlay.project(state))
assert(result.finished and result.won and result.rank==1)
assert(#result.stats==0)
state:reset()
assert(Overlay.project(state)==nil)
print("Survev authoritative match result projection passed")
