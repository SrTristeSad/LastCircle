-- Source Survev action timer requires both full player actionType and
-- UpdateMsg.activePlayerData.action. Never predict reloads from the R key.
local Demo=require("src.survev.offline_demo")
local Progress=require("src.survev.action_progress")
local Config=require("src.survev.game_config")
local state=Demo.new():getGameState()
local actor=state.objects[state.activeId]
local A=Config.Action
assert(Progress.project(state)==nil,"offline sample must not pose as server")
state.offlinePreview=nil
actor.actionType=A.Reload
actor.actionItem="ak47"
actor.actionSeq=1
state.localData.action={time=1,duration=2,targetId=0}
local result=assert(Progress.project(state))
assert(result.kind==A.Reload and result.progress==.5)
assert(result.text=="RECARREGANDO" and result.item=="ak47")
state.localData.action.time=5
assert(Progress.project(state).progress==1)
state.localData.action.time=0
assert(Progress.project(state).progress==0)
actor.actionType=A.ReloadAlt
assert(Progress.project(state).kind==A.ReloadAlt)
actor.actionItem="does-not-exist"
assert(Progress.project(state)==nil,"unknown server item must not be labelled")
actor.actionItem="bandage"
actor.actionType=A.UseItem
state.localData.action.time=1
local using=assert(Progress.project(state))
assert(using.text:find("USANDO:",1,true)==1)
actor.actionType=A.Revive
assert(Progress.project(state).text=="REVIVENDO")
actor.actionType=A.None
assert(Progress.project(state)==nil,"completed action must disappear")
actor.actionType=A.Reload
actor.actionItem="ak47"
state.localData.action=nil
assert(Progress.project(state)==nil,"no invented duration")
state.localData.action={time=1,duration=0,targetId=0}
assert(Progress.project(state)==nil)
state.localData.action={time=-1,duration=3,targetId=0}
assert(Progress.project(state)==nil)
state.localData.action={time=1,duration=2,targetId=0}
state.gameOver={}
assert(Progress.project(state)==nil)
state.gameOver=nil
actor.dead=true
assert(Progress.project(state)==nil)
actor.dead=false
local painted=0
love={graphics={
    setColor=function() end,
    rectangle=function() painted=painted+1 end,
    printf=function() painted=painted+1 end,
}}
assert(Progress.draw(state,1280,720) and painted>=4)
state.offlinePreview=true
assert(not Progress.draw(state,1280,720))
print("Survev server-authoritative reload/use/revive timer passed")
