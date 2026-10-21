-- Survev shared/utils/river.ts river-water and river-bank polygon port.
-- Uses the original Catmull-Rom spline and exact edge/clipping rules.
local V=require("src.survev.v2")
local Spline=require("src.survev.spline")
local R={};R.__index=R
local function clamp(v,a,b) return math.max(a,math.min(v,b)) end
local function lerp(t,a,b) return a*(1-t)+b*t end
local function bounded(pos,aabb)
    return V.create(clamp(pos.x,aabb.min.x,aabb.max.x),
        clamp(pos.y,aabb.min.y,aabb.max.y))
end
local function pointInside(point,poly)
    local inside=false
    local last=#poly
    for i=1,#poly do
        local a,b=poly[i],poly[last]
        if (a.y>point.y)~=(b.y>point.y)
            and point.x<(b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x then
            inside=not inside
        end
        last=i
    end
    return inside
end
local function raySegment(origin,direction,a,b)
    local segment=V.sub(b,a)
    local perpendicular=V.create(segment.y,-segment.x)
    local divisor=V.dot(direction,perpendicular)
    if math.abs(divisor)<=.000001 then return nil end
    local delta=V.sub(a,origin)
    local t=V.dot(perpendicular,delta)/divisor
    local s=V.dot(V.create(direction.y,-direction.x),delta)/divisor
    if t>=0 and s>=0 and s<=1 then return t end
end
local function rayPolygon(origin,direction,poly)
    local nearest=math.huge
    local last=#poly
    for i=1,#poly do
        local t=raySegment(origin,direction,poly[last],poly[i])
        if t and t<nearest then nearest=t end
        last=i
    end
    if nearest~=math.huge then return nearest end
end
local function clipRay(point,direction,poly)
    if not pointInside(V.add(point,direction),poly) then
        local t=rayPolygon(point,direction,poly)
        if t then return V.mul(direction,t) end
    end
    return direction
end
function R.new(points,width,looped,existing,mapBounds)
    assert(type(points)=="table" and #points>1)
    existing=existing or {}
    local self=setmetatable({
        spline=Spline.new(points,looped),waterWidth=width,
        shoreWidth=clamp(width*.75,4,8),looped=not not looped,
        waterPoly={},shorePoly={},waterWidths={},shoreWidths={}
    },R)
    local center=V.create(0,0)
    for _,point in ipairs(self.spline.points) do center=V.add(center,point) end
    center=V.div(center,#self.spline.points)
    self.center=center
    local avgDistance=0
    for _,point in ipairs(self.spline.points) do
        avgDistance=avgDistance+V.distance(point,center)
    end
    avgDistance=avgDistance/#self.spline.points
    local mapExtent=V.mul(V.sub(mapBounds.max,mapBounds.min),.5)
    local mapCenter=V.add(mapBounds.min,mapExtent)
    local leftWater,rightWater,leftShore,rightShore={},{},{},{}
    for i=1,#points do
        local originalIndex=i-1
        local point=points[i]
        local normal=self.spline:getNormal(originalIndex/(#points-1))
        local nearEdge=false
        if not looped and (i==1 or i==#points) then
            local ext=V.sub(point,mapCenter)
            local edgePosition,edgeNormal
            if math.abs(ext.x)>math.abs(ext.y) then
                edgePosition=V.create(ext.x>0 and mapBounds.max.x or mapBounds.min.x,point.y)
                edgeNormal=V.create(ext.x>0 and 1 or -1,0)
            else
                edgePosition=V.create(point.x,ext.y>0 and mapBounds.max.y or mapBounds.min.y)
                edgeNormal=V.create(0,ext.y>0 and 1 or -1)
            end
            if V.lengthSqr(V.sub(edgePosition,point))<1 then
                local perpendicular=V.perp(edgeNormal)
                if V.dot(normal,perpendicular)<0 then perpendicular=V.neg(perpendicular) end
                normal=perpendicular;nearEdge=true
            end
        end

        local waterWidth=self.waterWidth
        if not looped then
            local len=#points
            local ending=2*(math.max(1-originalIndex/len,originalIndex/len)-.5)
            waterWidth=(1+ending^3*1.5)*self.waterWidth
        end
        self.waterWidths[i]=waterWidth

        local shoreWidth=self.shoreWidth
        local bounding=nil
        for _,other in ipairs(existing) do
            local t=other.spline:getClosestTtoPoint(point)
            local nearest=other.spline:getPos(t)
            local dist=V.distance(nearest,point)
            if dist<other.waterWidth*2 then
                shoreWidth=math.max(shoreWidth,other.shoreWidth)
            end
            if (i==1 or i==#points) and dist<1.5 and not nearEdge then
                bounding=other
            end
        end
        if i>1 then shoreWidth=(self.shoreWidths[i-1]+shoreWidth)/2 end
        self.shoreWidths[i]=shoreWidth
        shoreWidth=shoreWidth+waterWidth

        local waterA,waterB,shoreA,shoreB
        if looped then
            local toPoint=V.sub(point,center)
            local dist=V.length(toPoint)
            if dist>.0001 then toPoint=V.div(toPoint,dist)
            else toPoint=V.create(1,0) end
            local innerWater=lerp(math.min(waterWidth/avgDistance,1)^.5,
                waterWidth,(1-(avgDistance-waterWidth)/dist)*dist)
            local innerShore=lerp(math.min(shoreWidth/avgDistance,1)^.5,
                shoreWidth,(1-(avgDistance-shoreWidth)/dist)*dist)
            waterA=V.add(point,V.mul(toPoint,waterWidth))
            waterB=V.add(point,V.mul(toPoint,-innerWater))
            shoreA=V.add(point,V.mul(toPoint,shoreWidth))
            shoreB=V.add(point,V.mul(toPoint,-innerShore))
        else
            local wa=V.mul(normal,waterWidth)
            local wb=V.mul(normal,-waterWidth)
            local sa=V.mul(normal,shoreWidth)
            local sb=V.mul(normal,-shoreWidth)
            if bounding then
                wa=clipRay(point,wa,bounding.waterPoly)
                wb=clipRay(point,wb,bounding.waterPoly)
                sa=clipRay(point,sa,bounding.shorePoly)
                sb=clipRay(point,sb,bounding.shorePoly)
            end
            waterA=V.add(point,wa);waterB=V.add(point,wb)
            shoreA=V.add(point,sa);shoreB=V.add(point,sb)
        end
        leftWater[i]=bounded(waterA,mapBounds)
        rightWater[i]=bounded(waterB,mapBounds)
        leftShore[i]=bounded(shoreA,mapBounds)
        rightShore[i]=bounded(shoreB,mapBounds)
    end
    for i=1,#points do
        self.waterPoly[#self.waterPoly+1]=leftWater[i]
        self.shorePoly[#self.shorePoly+1]=leftShore[i]
    end
    for i=#points,1,-1 do
        self.waterPoly[#self.waterPoly+1]=rightWater[i]
        self.shorePoly[#self.shorePoly+1]=rightShore[i]
    end
    local mn,mx=V.create(math.huge,math.huge),V.create(-math.huge,-math.huge)
    for _,point in ipairs(self.shorePoly) do
        mn=V.minElems(mn,point);mx=V.maxElems(mx,point)
    end
    self.aabb={min=mn,max=mx}
    return self
end
function R:distanceToShore(pos)
    local t=self.spline:getClosestTtoPoint(pos)
    return math.max(self.waterWidth - V.distance(pos,self.spline:getPos(t)),0)
end
function R:getWaterWidth(t)
    local index=clamp(math.floor(t*#self.spline.points),0,#self.spline.points)
    return self.waterWidths[index+1]
end
return R
