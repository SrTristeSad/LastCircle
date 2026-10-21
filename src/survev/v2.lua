-- Port of survev/survev shared/utils/v2.ts @ c6185e31
-- GPL-3.0. Preserve the upstream API names and math semantics.
local v2 = {}
function v2.create(x, y) return {x = x, y = y == nil and x or y} end
function v2.copy(v) return {x = v.x, y = v.y} end
function v2.set(a, b) a.x, a.y = b.x, b.y end
function v2.add(a,b) return {x=a.x+b.x,y=a.y+b.y} end
function v2.sub(a,b) return {x=a.x-b.x,y=a.y-b.y} end
function v2.mul(a,s) return {x=a.x*s,y=a.y*s} end
function v2.div(a,s) return {x=a.x/s,y=a.y/s} end
function v2.neg(a) return {x=-a.x,y=-a.y} end
function v2.lengthSqr(a) return a.x*a.x+a.y*a.y end
function v2.length(a) return math.sqrt(v2.lengthSqr(a)) end
function v2.normalize(a)
    local len = v2.length(a)
    if len > .000001 then return {x=a.x/len,y=a.y/len} end
    return v2.copy(a)
end
function v2.distance(a,b) return v2.length(v2.sub(a,b)) end
function v2.manhattanDistance(a,b)
    return math.abs(a.x-b.x)+math.abs(a.y-b.y)
end
function v2.midpoint(a,b)
    return v2.create((a.x+b.x)/2,(a.y+b.y)/2)
end
function v2.directionNormalized(a,b)
    return v2.normalize(v2.sub(b,a))
end
function v2.normalizeSafe(a, fallback)
    fallback = fallback or {x=1,y=0}
    local len = v2.length(a)
    if len > .000001 then return {x=a.x/len,y=a.y/len} end
    return v2.copy(fallback)
end
function v2.dot(a,b) return a.x*b.x+a.y*b.y end
function v2.perp(a) return {x=-a.y,y=a.x} end
function v2.proj(a,b) return v2.mul(b,v2.dot(a,b)/v2.dot(b,b)) end
function v2.rotate(a, rad)
    local c,s=math.cos(rad),math.sin(rad)
    return {x=a.x*c-a.y*s,y=a.x*s+a.y*c}
end
function v2.mulElems(a,b) return {x=a.x*b.x,y=a.y*b.y} end
function v2.divElems(a,b) return {x=a.x/b.x,y=a.y/b.y} end
function v2.minElems(a,b)
    return {x=math.min(a.x,b.x),y=math.min(a.y,b.y)}
end
function v2.maxElems(a,b)
    return {x=math.max(a.x,b.x),y=math.max(a.y,b.y)}
end
-- Optional injectable random fn mirrors upstream Math.random parameter.
function v2.randomUnit(length, rand)
    length = length == nil and 1 or length
    rand = rand or math.random
    return v2.rotate(v2.create(length,0),2*rand()*math.pi)
end
function v2.lerp(t,a,b)
    return v2.add(v2.mul(a,1-t),v2.mul(b,t))
end
function v2.eq(a,b,epsilon)
    epsilon = epsilon or .0001
    return math.abs(a.x-b.x)<=epsilon and math.abs(a.y-b.y)<=epsilon
end
return v2
