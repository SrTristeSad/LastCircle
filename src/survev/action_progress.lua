-- Source: Survev client/src/ui/ui.ts, action pie timer.
-- The original starts its timer from player.m_action.type, time and duration
-- provided by full ObjectType.Player + UpdateMsg.activePlayerData.action.
-- This is a read-only LÖVE bar, NOT an animation or local reload prediction.
local Config=require("src.survev.game_config")
local Equipment=require("src.survev.equipment_art")
local Loot=require("src.survev.loot_art")
local Action={}
local A=Config.Action
local function clamp(v) return math.max(0,math.min(1,v)) end

function Action.project(state)
    if not state or not state.joined or state.offlinePreview or
        state.gameOver or not state.objects then return nil end
    local actor=state.objects[state.activeId]
    local data=state.localData
    if not actor or actor.dead or not data or
        type(data.action)~="table" then return nil end
    local kind=actor.actionType
    local time=tonumber(data.action.time)
    local duration=tonumber(data.action.duration)
    if not time or not duration or duration<=0 or time<0 then
        return nil
    end
    local text=nil
    local item=actor.actionItem
    if kind==A.Reload or kind==A.ReloadAlt then
        if item and Equipment.weapons[item] and
            Equipment.weapons[item].type=="gun" then
            text="RECARREGANDO"
        end
    elseif kind==A.UseItem then
        local def=item and Loot.loot[item]
        if def then text="USANDO: "..(def.name or item) end
    elseif kind==A.Revive then
        text="REVIVENDO"
    end
    if not text then return nil end
    return {kind=kind,text=text,item=item,time=time,
        duration=duration,progress=clamp(time/duration),
        sequence=actor.actionSeq}
end
function Action.draw(state,w,h)
    local view=Action.project(state)
    if not view or not love or not love.graphics then return false end
    local g=love.graphics
    local width=math.min(340,w-28)
    local x=(w-width)*.5
    local y=math.max(87,h-326)
    g.setColor(.04,.085,.09,.91)
    g.rectangle("fill",x,y,width,49,7,7)
    g.setColor(.83,.90,.82,1)
    g.printf(view.text,x+8,y+5,width-16,"center")
    g.setColor(.17,.23,.23)
    g.rectangle("fill",x+14,y+32,width-28,9,3,3)
    g.setColor(.91,.70,.33)
    g.rectangle("fill",x+14,y+32,(width-28)*view.progress,9,3,3)
    g.setColor(1,1,1,1)
    return true
end
return Action
