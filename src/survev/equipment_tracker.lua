-- Source-authoritative gear/weapon change notices for the network client.
-- Survev UpdateMsg is the ONLY source. Never infer pickups from an InputMsg
-- or grant weapons locally. No notice is created by the initial snapshot.
local Equipment=require("src.survev.equipment_art")
local Game=require("src.survev.game_config")
local Tracker={}
Tracker.__index=Tracker
local gearFields={
    {key="backpack",label="Mochila"},
    {key="helmet",label="Capacete"},
    {key="chest",label="Colete"},
}
local slotLabels={"Primaria","Secundaria","Corpo a corpo","Arremessavel"}
local function snapshot(state)
    if not state or not state.joined or state.offlinePreview or
        state.gameOver or not state.objects then return nil end
    local actor=state.objects[state.activeId]
    if not actor then return nil end
    local values={}
    for _,entry in ipairs(gearFields) do
        if actor[entry.key]~=nil then
            values[entry.key]=actor[entry.key]
        end
    end
    local weapons=state.localData and state.localData.weapons
    if type(weapons)=="table" then
        for slot=1,Game.WeaponSlot.Count do
            local weapon=weapons[slot]
            if weapon and weapon.type~=nil then
                values["slot"..slot]=weapon.type
            end
        end
    end
    return values
end
local function itemName(kind,item)
    if item=="" then return "vazio" end
    local meta=kind=="weapon" and Equipment.weapons[item] or Equipment.gear[item]
    return (meta and meta.name) or item
end
function Tracker.new()
    return setmetatable({
        state=nil,activeId=nil,updateCount=nil,previous=nil,
        events={},duration=3,
    },Tracker)
end
function Tracker:reset()
    self.state=nil
    self.activeId=nil
    self.updateCount=nil
    self.previous=nil
    self.events={}
end
function Tracker:push(message)
    table.insert(self.events,1,{message=message,remaining=self.duration})
    while #self.events>3 do table.remove(self.events) end
end
function Tracker:update(state,dt)
    local delta=math.max(0,dt or 0)
    for i=#self.events,1,-1 do
        local event=self.events[i]
        event.remaining=event.remaining-delta
        if event.remaining<=0 then table.remove(self.events,i) end
    end
    local current=snapshot(state)
    if not current then
        self:reset()
        return
    end
    local seq=state.updateCount or 0
    -- Each match and each spectated player starts a new baseline. A fresh
    -- JoinMsg resets the object state in place, so the counter can decrease.
    if state~=self.state or self.activeId~=state.activeId or
        self.updateCount==nil or seq<self.updateCount then
        self:reset()
        self.state=state
        self.activeId=state.activeId
        self.updateCount=seq
        self.previous=current
        return
    end
    if seq==self.updateCount then return end
    self.updateCount=seq
    local previous=self.previous or {}
    for _,entry in ipairs(gearFields) do
        local old,new=previous[entry.key],current[entry.key]
        if old~=nil and new~=nil and new~=old then
            self:push(entry.label..": "..itemName("gear",new))
        end
    end
    for slot=1,Game.WeaponSlot.Count do
        local key="slot"..slot
        local old,new=previous[key],current[key]
        if old~=nil and new~=nil and new~=old then
            self:push(slotLabels[slot]..": "..itemName("weapon",new))
        end
    end
    -- Preserve known values if a partial packet omits them.
    for key,value in pairs(current) do previous[key]=value end
    self.previous=previous
end
function Tracker:draw(width,height)
    if not love or not love.graphics or #self.events==0 then return false end
    local g=love.graphics
    local w=math.min(310,width-24)
    local x=12
    local y=math.max(12,height-310)
    for index,event in ipairs(self.events) do
        local top=y+(index-1)*34
        g.setColor(.035,.09,.09,.87)
        g.rectangle("fill",x,top,w,30,5,5)
        g.setColor(.75,.90,.75,.94)
        g.rectangle("line",x,top,w,30,5,5)
        g.setColor(.95,.97,.91,1)
        g.printf(event.message,x+8,top+7,w-16,"left")
    end
    g.setColor(1,1,1,1)
    return true
end
return Tracker
