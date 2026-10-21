-- Survev client/src/objects/building.ts ceiling visibility state.
-- Ports EXACT "inside collider" fast-path of collisionHelpers.scanCollider,
-- zoomRegions transforms and original fade/linger equations. The RAY/LOS
-- branch for viewing *from outside* the building is not yet implemented:
-- do not pretend unobstructed visibility without collision data.
local Meta=require("src.survev.map_building_art")
local Types=require("src.survev.object_serialize_fns").Type
local V=require("src.survev.v2")
local HalfPi=math.pi*.5
local Visibility={}
Visibility.__index=Visibility

local function isInRegion(region,buildingPos,ori,playerPos)
    local localPos=V.rotate(V.sub(playerPos,buildingPos),-(ori or 0)*HalfPi)
    if region.type==0 then
        return V.lengthSqr(V.sub(localPos,region.pos))<=region.rad*region.rad
    elseif region.type==1 then
        return localPos.x>=region.min.x and localPos.x<=region.max.x
            and localPos.y>=region.min.y and localPos.y<=region.max.y
    end
    return false
end
Visibility.isInRegion=isInRegion

function Visibility.new()
    return setmetatable({active={}},Visibility)
end

function Visibility:reset()
    self.active={}
end

-- Called once per rendered frame. This intentionally never claims the LOS
-- result from a player *outside* a building: that requires the upstream
-- collisionHelpers.scanCollider rays against obstacle collision geometry.
function Visibility:update(dt,objects,activePlayer)
    assert(type(dt)=="number" and dt>=0,"invalid elapsed time")
    local seen={}
    for id,building in pairs(objects) do
        if building.__type==Types.Building and building.type then
            local def=Meta[building.type]
            if def then
                seen[id]=true
                local current=self.active[id]
                if not current then
                    current={alpha=1,ticker=0}
                    self.active[id]=current
                end
                current.ticker=current.ticker-dt
                local visible=building.ceilingDead or false
                if activePlayer and activePlayer.pos and
                    ((building.layer or 0)==(activePlayer.layer or 0)
                        or (activePlayer.layer or 0)%4>=2) then
                    for _,region in ipairs(def.zoomRegions or {}) do
                        if region.zoomIn and
                            isInRegion(region.zoomIn,building.pos,building.ori,activePlayer.pos) then
                            visible=true
                            break
                        end
                    end
                end
                local vision=def.vision or {}
                if visible then
                    current.ticker=(vision.linger or 0)+.0001
                end
                if activePlayer and activePlayer.noCeilingRevealTicker and
                    activePlayer.noCeilingRevealTicker>0 and not building.ceilingDead then
                    current.ticker=0
                end
                local reveal=current.ticker>0
                local target=reveal and 0 or 1
                local delta=target-current.alpha
                local change=delta*dt*(reveal and 12 or (vision.fadeRate or 12))
                if math.abs(change)<.001 then change=delta end
                current.alpha=math.max(0,math.min(1,current.alpha+change))
            end
        end
    end
    for id in pairs(self.active) do if not seen[id] then self.active[id]=nil end end
end
function Visibility:alpha(id)
    return self.active[id] and self.active[id].alpha or 1
end
return Visibility
