-- Survev client/src/map.ts:getGroundSurface(), BUILDING branch only.
-- Original floor.surfaces/colliders are generated from MapObjectDefs.
-- Returns a known building surface or nil (let terrain handle fallback).
-- This port does not invent surface types, physical collisions or materials.
local Definitions=require("src.survev.map_building_art")
local Type=require("src.survev.object_serialize_fns").Type
local V=require("src.survev.v2")
local HALF_PI=math.pi*.5
local Surfaces={}

local function transform(col,origin,ori)
    local angle=(ori or 0)*HALF_PI
    if col.type==0 then
        local center=V.add(origin,V.rotate(col.pos,angle))
        return {type=0,pos=center,rad=col.rad}
    end
    assert(col.type==1,"Unsupported source collider type")
    local pts={
        {x=col.min.x,y=col.min.y},
        {x=col.min.x,y=col.max.y},
        {x=col.max.x,y=col.min.y},
        {x=col.max.x,y=col.max.y},
    }
    local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
    for _,p in ipairs(pts) do
        local t=V.add(origin,V.rotate(p,angle))
        minx=math.min(minx,t.x);miny=math.min(miny,t.y)
        maxx=math.max(maxx,t.x);maxy=math.max(maxy,t.y)
    end
    return {type=1,min={x=minx,y=miny},max={x=maxx,y=maxy}}
end
Surfaces.transform=transform

local function intersectsPoint(col,point,radius)
    radius=radius or .0001
    if col.type==0 then
        local dx,dy=point.x-col.pos.x,point.y-col.pos.y
        return dx*dx+dy*dy<(col.rad+radius)^2
    end
    local mn,mx=col.min,col.max
    if point.x>=mn.x and point.x<=mx.x and
        point.y>=mn.y and point.y<=mx.y then return true end
    local x=math.max(mn.x,math.min(mx.x,point.x))
    local y=math.max(mn.y,math.min(mx.y,point.y))
    local dx,dy=point.x-x,point.y-y
    return dx*dx+dy*dy<radius*radius
end
Surfaces.intersectsPoint=intersectsPoint

function Surfaces.getBuildingSurface(objects,point,layer)
    assert(point and point.x and point.y,"world position required")
    local onStairs=layer%4>=2
    local ordered={}
    for id,obj in pairs(objects) do
        if obj.__type==Type.Building and obj.type and obj.pos then
            ordered[#ordered+1]={id=id,obj=obj}
        end
    end
    -- Original Map building-pool iteration uses its insertion order; IDs are
    -- deterministic except a rare same-z overlap, not guaranteed equivalent.
    table.sort(ordered,function(a,b) return a.id<b.id end)
    local bestZ=0
    local selected=nil
    for _,entry in ipairs(ordered) do
        local obj=entry.obj
        local def=Definitions[obj.type]
        if def and def.zIdx>=bestZ and
            (obj.layer==layer or onStairs) and
            (obj.layer~=1 or not onStairs) then
            for _,surface in ipairs(def.floorSurfaces) do
                for _,col in ipairs(surface.collision) do
                    local current=transform(col,obj.pos,obj.ori)
                    if intersectsPoint(current,point,.0001) then
                        bestZ=def.zIdx
                        selected={type=surface.type,data=surface.data or {},
                            buildingId=obj.__id,zIdx=bestZ}
                        break
                    end
                end
            end
        end
    end
    return selected
end

return Surfaces
