-- Survev player.ts: m_updateData(animType, animSeq), playAnim/updateAnim.
-- Source-backed keyframes from client/src/animData.ts @ c6185e31.
-- The game server is authoritative: no client input starts a melee animation.
-- Initial scope: source fists and pan HandR attacks; no fake hit or recoil.
local Game=require("src.survev.game_config")
local Metadata=require("src.survev.player_art")
local Type=require("src.survev.object_serialize_fns").Type
local Animations={}
Animations.__index=Animations

local function pose(px,py,angle)
    return {pivot={x=px,y=py},pos={x=0,y=0},rot=angle or 0}
end
local panFrames={
    {time=0,handR=pose(14,12.25)},
    {time=.15,handR=pose(22,-8.25,-math.pi*.2)},
    {time=.25,handR=pose(28,-8.25,math.pi*.5)},
    {time=.55,handR=pose(14,12.25)},
}
local framesByWeapon={
    fists=Metadata.animations.fists,
    pan=panFrames,
}
local function mix(a,b,t) return a+(b-a)*t end
local function interpolate(a,b,t)
    return {
        pivot={x=mix(a.pivot.x,b.pivot.x,t),y=mix(a.pivot.y,b.pivot.y,t)},
        pos={x=mix(a.pos.x,b.pos.x,t),y=mix(a.pos.y,b.pos.y,t)},
        rot=mix(a.rot,b.rot,t),
    }
end
function Animations.sample(weapon,time)
    local frames=framesByWeapon[weapon]
    if not frames or type(time)~="number" or time<0
        or time>=frames[#frames].time then return nil end
    for i=2,#frames do
        local a,b=frames[i-1],frames[i]
        if time<=b.time then
            local t=math.max(0,math.min(1,(time-a.time)/(b.time-a.time)))
            return {HandR=interpolate(a.handR,b.handR,t)}
        end
    end
    return nil
end
function Animations.new()
    return setmetatable({world=nil,lastUpdate=nil,entities={}},Animations)
end
function Animations:reset()
    self.world=nil
    self.lastUpdate=nil
    self.entities={}
end
function Animations:update(state,dt)
    if not state or not state.joined or state.offlinePreview or
        not state.objects then
        self:reset()
        return
    end
    local count=state.updateCount or 0
    if self.world~=state or (self.lastUpdate and count<self.lastUpdate) then
        self:reset()
        self.world=state
    end
    if self.lastUpdate~=count then
        for id,obj in pairs(state.objects) do
            if obj.__type==Type.Player and not obj.dead and
                type(obj.animSeq)=="number" and
                type(obj.animType)=="number" then
                local previous=self.entities[id]
                -- 3-bit animation sequence wraps. Compare equality, not >.
                if not previous or previous.sequence~=obj.animSeq or
                    previous.kind~=obj.animType or
                    previous.weapon~=obj.activeWeapon then
                    self.entities[id]={
                        sequence=obj.animSeq,kind=obj.animType,
                        weapon=obj.activeWeapon,ticker=0,
                    }
                end
            else
                self.entities[id]=nil
            end
        end
        for id in pairs(self.entities) do
            if not state.objects[id] then self.entities[id]=nil end
        end
        self.lastUpdate=count
    end
    local step=math.max(0,dt or 0)
    for _,entry in pairs(self.entities) do
        entry.ticker=entry.ticker+step
    end
end
function Animations:poseFor(obj)
    if not obj or obj.dead or obj.downed then return nil end
    local entry=self.entities[obj.__id]
    if not entry or entry.kind~=Game.Anim.Melee then return nil end
    if obj.animSeq~=entry.sequence or obj.activeWeapon~=entry.weapon then
        return nil
    end
    return Animations.sample(entry.weapon,entry.ticker)
end
return Animations
