-- Source: Survev client/src/objects/shot.ts (ShotBarn.m_update)
-- and player.ts (Player.addRecoil / decay). Source pin c6185e31.
-- Only UpdateMsg.bullets with shotFx may move hands. This module never
-- shoots, consumes ammo, applies damage, or predicts the server outcome.
local Gear=require("src.survev.equipment_art")
local Types=require("src.survev.object_serialize_fns").Type
local Recoil={}
Recoil.__index=Recoil

function Recoil.new()
    return setmetatable({world=nil,lastUpdate=nil,hands={}},Recoil)
end
function Recoil:reset()
    self.world=nil
    self.lastUpdate=nil
    self.hands={}
end
local function decay(amount,dt)
    return math.max(0,amount-amount*dt*5-dt)
end
function Recoil:update(state,dt)
    if not state or not state.joined or state.offlinePreview
        or state.gameOver or not state.objects then
        self:reset()
        return
    end
    local count=state.updateCount or 0
    if self.world~=state or (self.lastUpdate and
        count<self.lastUpdate) then
        self:reset()
        self.world=state
    end
    -- Original player.ts reduces existing recoil once each render frame.
    local delta=math.max(0,dt or 0)
    for id,hands in pairs(self.hands) do
        local obj=state.objects[id]
        if not obj or obj.__type~=Types.Player or obj.dead then
            self.hands[id]=nil
        else
            hands.left=decay(hands.left,delta)
            hands.right=decay(hands.right,delta)
        end
    end
    -- Survev UpdateMsg effects are one-packet events. Do not add the same
    -- recoil again when several LÖVE frames run between network updates.
    if self.lastUpdate==count then return end
    self.lastUpdate=count
    for _,shot in ipairs(state.bullets or {}) do
        if shot.shotFx==true and
            type(shot.playerId)=="number" and
            type(shot.shotSourceType)=="string" then
            local obj=state.objects[shot.playerId]
            local def=Gear.weapons[shot.shotSourceType]
            local world=def and def.world
            local amount=world and world.recoil
            if obj and obj.__type==Types.Player and not obj.dead
                and def and def.type=="gun" and type(amount)=="number"
                and amount>0 then
                local value=self.hands[shot.playerId]
                if not value then
                    value={left=0,right=0}
                    self.hands[shot.playerId]=value
                end
                -- shot.ts: an ordinary gun kicks both hands; dual guns
                -- kick only the hand identified by shotOffhand.
                if shot.shotOffhand or not def.isDual then
                    value.left=value.left+amount
                end
                if not shot.shotOffhand or not def.isDual then
                    value.right=value.right+amount
                end
            end
        end
    end
end
function Recoil:forPlayer(obj)
    if not obj or obj.dead or obj.downed then return nil end
    local def=Gear.weapons[obj.activeWeapon or ""]
    if not def or def.type~="gun" then return nil end
    local value=self.hands[obj.__id]
    if not value or (value.left<=0 and value.right<=0) then return nil end
    return {left=value.left,right=value.right}
end
return Recoil
