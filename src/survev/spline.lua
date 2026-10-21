-- Port of survev/survev shared/utils/spline.ts (Catmull-Rom).
-- Index conversion preserves the zero-based control selection of TypeScript.
local V2=require("src.survev.v2")
local S={};S.__index=S
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function lerp(t,a,b) return a*(1-t)+b*t end
local function fmod(n,m) return n-math.floor(n/m)*m end
function S.control(t,points,looped)
    local count=#points
    local i,i0,i1,i2,i3
    if looped then
        t=fmod(t,1)
        i=math.floor(t*(count-1))
        i1=i
        i2=(i1+1)%(count-1)
        i0=i1>0 and (i1-1) or (count-2)
        i3=(i2+1)%(count-1)
    else
        t=clamp(t,0,1)
        i=math.floor(t*(count-1))
        i1=i==count-1 and (i-1) or i
        i2=i1+1
        i0=i1>0 and i1-1 or i1
        i3=i2<count-1 and i2+1 or i2
    end
    return t*(count-1)-i1,points[i0+1],points[i1+1],
        points[i2+1],points[i3+1]
end
function S.catmullRom(t,p0,p1,p2,p3)
    return .5*(2*p1 + t*(-p0+p2)
        + t*t*(2*p0-5*p1+4*p2-p3)
        + t*t*t*(-p0+3*p1-3*p2+p3))
end
function S.derivative(t,p0,p1,p2,p3)
    return .5*(-p0+p2+2*t*(2*p0-5*p1+4*p2-p3)
        +3*t*t*(-p0+3*p1-3*p2+p3))
end
function S.new(points,looped)
    assert(type(points)=="table" and #points>1,
        "original Spline requires at least two points")
    local self=setmetatable({points={},arcLens={},totalArcLen=0,
        looped=not not looped},S)
    for i,point in ipairs(points) do self.points[i]=V2.copy(point) end
    local samples=#points*4
    local cur=self.points[1]
    for i=0,samples do
        local t=i/samples
        local nextPoint=self:getPos(t)
        local previous=i==0 and 0 or self.arcLens[i]
        self.arcLens[i+1]=previous+V2.length(V2.sub(nextPoint,cur))
        cur=V2.copy(nextPoint)
    end
    self.totalArcLen=self.arcLens[#self.arcLens]
    return self
end
function S:getPos(t)
    local pt,p0,p1,p2,p3=S.control(t,self.points,self.looped)
    return V2.create(S.catmullRom(pt,p0.x,p1.x,p2.x,p3.x),
        S.catmullRom(pt,p0.y,p1.y,p2.y,p3.y))
end
function S:getTangent(t)
    local pt,p0,p1,p2,p3=S.control(t,self.points,self.looped)
    return V2.create(S.derivative(pt,p0.x,p1.x,p2.x,p3.x),
        S.derivative(pt,p0.y,p1.y,p2.y,p3.y))
end
function S:getNormal(t)
    return V2.perp(V2.normalizeSafe(self:getTangent(t),V2.create(1,0)))
end
local function distToSegmentSq(p,a,b)
    local ab=V2.sub(b,a)
    local c=V2.dot(V2.sub(p,a),ab)/V2.dot(ab,ab)
    local d=V2.add(a,V2.mul(ab,clamp(c,0,1)))
    return V2.lengthSqr(V2.sub(d,p))
end
function S:getClosestTtoPoint(pos)
    local closest,idx=math.huge,0
    for i=1,#self.points-1 do
        local d=distToSegmentSq(pos,self.points[i],self.points[i+1])
        if d<closest then closest,idx=d,i-1 end
    end
    local s0,s1=self.points[idx+1],self.points[idx+2]
    local seg=V2.sub(s1,s0)
    local t=clamp(V2.dot(V2.sub(pos,s0),seg)/V2.dot(seg,seg),0,1)
    local len=#self.points-1
    local low=clamp((idx+t-.1)/len,0,1)
    local high=clamp((idx+t+.1)/len,0,1)
    local nearest=(idx+t)/len
    local nearestSq=math.huge
    for i=0,8 do
        local tt=lerp(i/8,low,high)
        local dist=V2.lengthSqr(V2.sub(self:getPos(tt),pos))
        if dist<nearestSq then nearest,nearestSq=tt,dist end
    end
    local tangent=self:getTangent(nearest)
    local tanLen=V2.length(tangent)
    if tanLen>0 then
        local nearPoint=self:getPos(nearest)
        local offset=V2.dot(tangent,V2.sub(pos,nearPoint))/tanLen
        local nextT=nearest+offset/(tanLen*len)
        if V2.lengthSqr(V2.sub(pos,self:getPos(nextT))) <
            V2.lengthSqr(V2.sub(pos,nearPoint)) then
            nearest=nextT
        end
    end
    return nearest
end
function S:getTfromArcLen(length)
    length=clamp(length,0,self.totalArcLen)
    local idx=0
    while idx<#self.arcLens-1 and length>self.arcLens[idx+1] do idx=idx+1 end
    if idx==0 then return 0 end
    local a,b=self.arcLens[idx],self.arcLens[idx+1]
    local t=clamp((length-a)/(b-a),0,1)
    local n=#self.arcLens-1
    return lerp(t,(idx-1)/n,idx/n)
end
function S:getArcLen(t)
    t=clamp(t,0,1)
    local count=#self.arcLens-1
    local idx=math.floor(t*count)
    local idx1=idx<count-1 and idx+1 or idx
    local arcT=fmod(t,1/count)/(1/count)
    return lerp(arcT,self.arcLens[idx+1],self.arcLens[idx1+1])
end
return S
