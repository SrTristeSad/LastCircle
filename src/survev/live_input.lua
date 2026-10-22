-- InputMsg controls ported from Survev client/src/game.ts (pinned c6185e31).
-- The original sends consumables via InputMsg.useItem, NOT via Input enums.
-- Only the server can consume, collect or equip an item.
local Binds=require("src.survev.input_bindings")
local Input=Binds.Input
local Buffer={}
Buffer.__index=Buffer

local keyActions={
    r=Input.Reload, f=Input.Interact, e=Input.StowWeapons,
    x=Input.Cancel, q=Input.EquipLastWeap, t=Input.SwapWeapSlots,
    ["1"]=Input.EquipPrimary, ["2"]=Input.EquipSecondary,
    ["3"]=Input.EquipMelee, ["4"]=Input.EquipThrowable,
}
-- Same precedence as Survev game.ts:
-- UseBandage / UseHealthKit / UseSoda / UsePainkiller.
local consumables={
    ["7"]={item="bandage",priority=1},
    ["8"]={item="healthkit",priority=2},
    ["9"]={item="soda",priority=3},
    ["0"]={item="painkiller",priority=4},
}
function Buffer.new()
    return setmetatable({actions={},useItem="",priority=nil},Buffer)
end
function Buffer:clear()
    self.actions={}
    self.useItem=""
    self.priority=nil
end
function Buffer:queueAction(id)
    if type(id)~="number" or id<0 or id>=Input.Count then
        return false
    end
    for _,existing in ipairs(self.actions) do
        if id==existing then return false end
    end
    -- Original InputMsg.addInput accepts up to 7 distinct enum actions.
    if #self.actions>=7 then return false end
    self.actions[#self.actions+1]=id
    return true
end
function Buffer:keypressed(key)
    local consumable=consumables[key]
    if consumable then
        if not self.priority or consumable.priority<self.priority then
            self.useItem=consumable.item
            self.priority=consumable.priority
        end
        return true
    end
    local action=keyActions[key]
    if action~=nil then
        self:queueAction(action)
        return true
    end
    return false
end
function Buffer:wheelmoved(dy)
    if dy>0 then
        return self:queueAction(Input.EquipPrevWeap)
    elseif dy<0 then
        return self:queueAction(Input.EquipNextWeap)
    end
    return false
end
function Buffer:drain(message)
    assert(message and type(message.addInput)=="function",
        "Survev InputMsg required")
    for _,id in ipairs(self.actions) do message:addInput(id) end
    message.useItem=self.useItem
    self:clear()
    return message
end
return Buffer
