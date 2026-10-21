-- Port of survev/survev shared/utils/coldet.ts, collider.ts and
-- collisionHelpers.ts used for SURVEV CEILING LINE OF SIGHT (LOS).
-- All math runs in LuaJIT/Lua5.4 without Lua 5.3 bitwise syntax.
local V=require("src.survev.v2")
local Transform=require("src.survev.building_surfaces").transform
local G={}
local function clamp(a,lo,hi) return math.max(lo,math.min(hi,a)) end
local function length(p) return math.sqrt(p.x*p.x+p.y*p.y) end
local function lengthSq(p) return p.x*p.x+p.y*p.y end
local function norm(p)
    local l=length(p)
    if l>0.0001 then return V.mul(p,1/l) end
    return V.create(1,0)
end
local function hasBit(n,bit)
    return math.floor(n/bit)%2>=1
end
function G.sameLayer(a,b)
    a=a or 0;b=b or 0
    return hasBit(a,1)==hasBit(b,1) or
        (hasBit(a,2) and hasBit(b,2))
end
function G.intersectCircle(col,pos,rad)
    if col.type==0 then
        local toPos=V.sub(pos,col.pos)
        local sum=col.rad+rad
        local d2=lengthSq(toPos)
        if d2<sum*sum then
            local dist=math.sqrt(d2)
            return {dir=dist>0.00001 and V.mul(toPos,1/dist) or V.create(1,0),
                pen=sum-dist}
        end
        return nil
    end
    assert(col.type==1,"invalid SURVEV collider")
    local mn,mx=col.min,col.max
    if pos.x>=mn.x and pos.x<=mx.x and pos.y>=mn.y and pos.y<=mx.y then
        local e=V.mul(V.sub(mx,mn),.5)
        local c=V.add(mn,e)
        local p=V.sub(pos,c)
        local xp=math.abs(p.x)-e.x-rad
        local yp=math.abs(p.y)-e.y-rad
        if xp>yp then
            return {dir=V.create(p.x>0 and 1 or -1,0),pen=-xp}
        end
        return {dir=V.create(0,p.y>0 and 1 or -1),pen=-yp}
    end
    local near=V.create(clamp(pos.x,mn.x,mx.x),clamp(pos.y,mn.y,mx.y))
    local direction=V.sub(pos,near)
    local d2=lengthSq(direction)
    if d2<rad*rad then
        local dist=math.sqrt(d2)
        return {dir=dist>0.0001 and V.mul(direction,1/dist) or V.create(1,0),
            pen=rad-dist}
    end
    return nil
end
function G.intersectSegment(col,s0,s1)
    if col.type==0 then
        local delta=V.sub(s1,s0)
        local len=math.max(length(delta),.000001)
        local d=V.mul(delta,1/len)
        local m=V.sub(s0,col.pos)
        local b=V.dot(m,d)
        local c=V.dot(m,m)-col.rad*col.rad
        if c>0 and b>0 then return nil end
        local discriminant=b*b-c
        if discriminant<0 then return nil end
        local root=math.sqrt(discriminant)
        local t=-b-root
        if t<0 then t=-b+root end
        if t<=len then return {point=V.add(s0,V.mul(d,t))} end
        return nil
    end
    assert(col.type==1,"invalid SURVEV collider")
    local min,max=col.min,col.max
    local tmin,tmax=0,math.huge
    local eps=.00001
    local d=V.sub(s1,s0)
    local dist=length(d)
    d=dist>eps and V.mul(d,1/dist) or V.create(1,0)
    local dx,dy=math.abs(d.x),math.abs(d.y)
    -- Mirror the original coldet.ts near-axis "HACK", even though its
    -- zero-length/parallel behavior is imperfect.
    if dx<eps then d.x=eps*2;dx=d.x end
    if dy<eps then d.y=eps*2;dy=d.y end
    if dx>eps then
        local a=(min.x-s0.x)/d.x
        local b=(max.x-s0.x)/d.x
        tmin=math.max(tmin,math.min(a,b))
        tmax=math.min(tmax,math.max(a,b))
        if tmin>tmax then return nil end
    end
    if dy>eps then
        local a=(min.y-s0.y)/d.y
        local b=(max.y-s0.y)/d.y
        tmin=math.max(tmin,math.min(a,b))
        tmax=math.min(tmax,math.max(a,b))
        if tmin>tmax then return nil end
    end
    if tmin>dist then return nil end
    return {point=V.add(s0,V.mul(d,tmin))}
end
G.transform=Transform

-- Generate colliders as client/src/objects/obstacle.ts does at update.
-- World snapshots remain authoritative; NO guessed NPC or walls.
function G.obstacles(objects,registry)
    registry=registry or require("src.survev.map_obstacle_art")
    local Type=require("src.survev.object_serialize_fns").Type
    local obstacles={}
    for id,o in pairs(objects) do
        if o.__type==Type.Obstacle and o.type and o.pos then
            local def=registry[o.type]
            if def and def.collision then
                obstacles[#obstacles+1]={
                    __id=o.__id or id,active=true,dead=o.dead or false,
                    collidable=(def.collidable~=false) and not o.isSkin,
                    isWindow=not not def.isWindow,
                    height=def.height or 0,
                    layer=o.layer or 0,
                    collider=Transform(def.collision,o.pos,o.ori or 0,o.scale or 1),
                }
            end
        end
    end
    return obstacles
end
local function blockedBy(o,start,last,height,layer,hackStairs)
    if not o.active or o.dead or not o.collidable or o.isWindow
        or o.height<height or not G.sameLayer(o.layer,layer) then return nil end
    if hackStairs and hasBit(layer,2) and o.layer==0 then return nil end
    return G.intersectSegment(o.collider,start,last)
end
function G.intersectSegmentDist(obstacles,pos,dir,len,height,layer,hackStairs)
    local distance=len
    local endpoint=V.add(pos,V.mul(dir,len))
    for _,o in ipairs(obstacles) do
        local hit=blockedBy(o,pos,endpoint,height,layer,hackStairs)
        if hit then distance=math.min(distance,length(V.sub(hit.point,pos))) end
    end
    return distance
end
local function segmentEnd(obstacles,pos,dir,len,layer)
    local dist=G.intersectSegmentDist(obstacles,pos,dir,len,0,layer,false)
    return V.add(pos,V.mul(dir,dist))
end
function G.scanCollider(col,obstacles,pos,layer,height,scanWidth,scanDist,rayCount)
    local toCol=G.intersectCircle(col,pos,scanDist)
    if not toCol then return nil end
    if toCol.pen>=scanDist then return {dist=0} end
    local perp=V.perp(toCol.dir)
    local halfWidth=.5*scanWidth
    local start=segmentEnd(obstacles,pos,V.neg(perp),halfWidth,layer)
    local finish=segmentEnd(obstacles,pos,perp,halfWidth,layer)
    local diff=V.sub(finish,start)
    local scanLen=length(diff)
    local direction=scanLen>.0001 and V.mul(diff,1/scanLen) or V.create(1,0)
    for i=0,rayCount-1 do
        local t=i/math.max(rayCount-1,1)
        local rayPos=V.add(start,V.mul(direction,scanLen*t))
        local hitCollider=G.intersectCircle(col,rayPos,scanDist)
        if hitCollider then
            local rayDir=V.neg(hitCollider.dir)
            local maxDist=G.intersectSegmentDist(
                obstacles,rayPos,rayDir,scanDist,height,layer,true)
            local intersection=G.intersectSegment(col,
                rayPos,V.add(rayPos,V.mul(rayDir,scanDist)))
            local distance=intersection and length(V.sub(intersection.point,rayPos)) or 0
            if intersection and distance<=maxDist then return {dist=distance} end
        end
    end
    return nil
end
return G
