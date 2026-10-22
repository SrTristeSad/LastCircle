-- Headless regression test: results are only shown after a server GameOverMsg.
package.path="./?.lua;./?/init.lua;"..package.path
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Overlay=require("src.survev.results_overlay")
local state=State.new()
assert(Overlay.project(state)==nil)
state:applyMessage(Net.MsgType.GameOver,{
  teamId=2,teamRank=3,gameOver=true,winningTeamId=1,playerStats={}
})
local result=assert(Overlay.project(state))
assert(result.finished and not result.won and result.rank==3)
state:applyMessage(Net.MsgType.GameOver,{
  teamId=2,teamRank=1,gameOver=true,winningTeamId=2,playerStats={}
})
result=assert(Overlay.project(state))
assert(result.finished and result.won and result.rank==1)
state:reset()
assert(Overlay.project(state)==nil)
print("GameOverMsg results projection passed")
