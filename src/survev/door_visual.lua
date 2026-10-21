-- Door VISUAL state from survev/survev client/src/objects/obstacle.ts.
-- m_update(): position interpolation, shortest-angle rotation and casing.
-- Authoritative world coords are never modified by visual smoothing.
local V=require("src.survev.v2")
local Objects=require("src.survev.object_serialize_fns").Type
local Registry=require("src.survev.map_obstacle_art")
local HalfPi=math.pi*.5
local TWO_PI=math.pi*2
local D={}
D.__index=D
local function fmod(a,b) return a-math.floor(a/b)*b end
local function angleDiff(a,b)
    local d=fmod(b-a+math.pi,TWO_PI)-math.pi
    return d<-math.pi and (d+TWO_PI) or d
end
D.angleDiff=angleDiff
local function angle(o) return (o.ori or 0)%4*HalfPi end
function D.new() return setmetatable({entries={}},D) end
function D:reset() self.entries={} end
function D:update(objects,dt)
    assert(type(dt)=="number" and dt>=0)
    local live={}
    for id,obj in pairs(objects) do
        if obj.__type==Objects.Obstacle and obj.pos and obj.type then
            local def=Registry[obj.type]
            if def and def.door then
                live[id]=true
                local state=self.entries[id]
                local newAngle=angle(obj)
                if not state then
                    state={interpPos=V.copy(obj.pos),interpRot=newAngle,type=obj.type}
                    self.entries[id]=state
                end
                if state.type~=obj.type then
                    state.type=obj.type
                    state.interpPos=V.copy(obj.pos)
                    state.interpRot=newAngle
                end
                local speed=def.door.openSpeed
                local posDiff=V.sub(obj.pos,state.interpPos)
                local distance=V.length(posDiff)
                local move=math.min(speed*dt,distance)
                local direction=distance>.0001 and V.div(posDiff,distance) or V.create(1,0)
                state.interpPos=V.add(state.interpPos,V.mul(direction,move))
                local diff=angleDiff(state.interpRot,newAngle)
                local amt=(diff<0 and -1 or 1)*math.pi*speed*dt
                if math.abs(diff)<math.abs(amt) then amt=diff end
                state.interpRot=state.interpRot+amt
            end
        end
    end
    for id in pairs(self.entries) do if not live[id] then self.entries[id]=nil end end
end
function D:visual(obj)
    local entry=self.entries[obj.__id]
    if entry and entry.type==obj.type then
        return {pos=entry.interpPos,rot=entry.interpRot}
    end
    return {pos=obj.pos,rot=angle(obj)}
end
function D:casing(obj,def)
    def=def or Registry[obj.type]
    local door=def and def.door
    if not door or not door.casing then return nil end
    local rot=angle(obj)
    local currentOffset=V.rotate(V.create(door.slideOffset or 0,0),rot+HalfPi)
    local closedPos=(obj.door and obj.door.open) and V.add(obj.pos,currentOffset)
        or V.copy(obj.pos)
    local imageOffset=V.rotate(door.casing.pos or V.create(0,0),rot+HalfPi)
    return {pos=V.add(closedPos,imageOffset),rot=rot,img=door.casing}
end
return D
