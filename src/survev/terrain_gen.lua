-- Exact deterministic shoreline, beach/grass outline and ground-patch
-- generation from survev/survev shared/utils/terrainGen.ts and
-- client/src/map.ts:traceGroundPatch, commit c6185e31.
-- Rivers are handled separately by the spline/River port: do not improvise.
local V2=require("src.survev.v2")
local Config=require("src.survev.game_config")
local T={}

-- Identical Park-Miller RNG from shared/utils/util.ts:seededRand.
-- Multiplication stays below 2^53: standard Lua doubles are precise here.
function T.seededRand(seed)
    assert(type(seed)=="number" and seed==math.floor(seed))
    local rng=seed
    return function(min,max)
        min=min or 0;max=max or 1
        rng=(rng*16807)%2147483647
        return min+(max-min)*(rng/2147483647)
    end
end
function T.jaggedAabb(aabb,divisionsX,divisionsY,variation,rand)
    local ll,lr,ur,ul=
        V2.create(aabb.min.x,aabb.min.y),
        V2.create(aabb.max.x,aabb.min.y),
        V2.create(aabb.max.x,aabb.max.y),
        V2.create(aabb.min.x,aabb.max.y)
    local spanX=(lr.x-ll.x)/(divisionsX+1)
    local spanY=(ul.y-ll.y)/(divisionsY+1)
    local points={V2.copy(ll)}
    for i=1,divisionsX do
        points[#points+1]=V2.create(ll.x+spanX*i,ll.y+rand(-variation,variation))
    end
    points[#points+1]=V2.copy(lr)
    for i=1,divisionsY do
        points[#points+1]=V2.create(lr.x+rand(-variation,variation),lr.y+spanY*i)
    end
    points[#points+1]=V2.copy(ur)
    for i=1,divisionsX do
        points[#points+1]=V2.create(ur.x-spanX*i,ur.y+rand(-variation,variation))
    end
    points[#points+1]=V2.copy(ul)
    for i=1,divisionsY do
        points[#points+1]=V2.create(ul.x+rand(-variation,variation),ul.y-spanY*i)
    end
    return points
end
function T.jaggedCircle(center,radius,divisions,variation,rand)
    local points={}
    for i=0,divisions-1 do
        local angle=(i/divisions)*math.pi*2
        local r=radius+rand(-variation,variation)
        points[#points+1]=V2.create(center.x+math.cos(angle)*r,
            center.y+math.sin(angle)*r)
    end
    return points
end

function T.generate(map)
    assert(type(map)=="table" and map.width and map.height and map.seed,
        "MapMsg with dimensions and seed required")
    local rand=T.seededRand(map.seed)
    local inset=map.shoreInset
    local bounds={min=V2.create(inset,inset),
        max=V2.create(map.width-inset,map.height-inset)}
    local shore=T.jaggedAabb(bounds,64,64,Config.map.shoreVariation,rand)
    local center=V2.create(map.width*.5,map.height*.5)
    local grass={}
    for _,point in ipairs(shore) do
        local toward=V2.normalize(V2.sub(center,point))
        local variation=rand(-Config.map.grassVariation,Config.map.grassVariation)
        local dist=map.grassInset+variation
        grass[#grass+1]=V2.add(point,V2.mul(toward,dist))
    end
    return {shore=shore,grass=grass}
end

function T.patchPolygon(patch,seed)
    assert(patch and patch.bound,"ground patch bounds required")
    local offset=math.max(patch.offsetDist,.001)
    local rough=patch.roughness
    -- The upstream resets the RNG to the map seed for EACH ground patch.
    local rand=T.seededRand(seed)
    if patch.bound.type==0 then
        local c=patch.bound
        local count=math.floor((2*math.pi*c.rad*rough)/offset+.5)
        if count<3 then return {} end
        return T.jaggedCircle(c.pos,c.rad,count,offset,rand)
    end
    local aabb=patch.bound
    local dx=math.floor(((aabb.max.x-aabb.min.x)*rough)/offset+.5)
    local dy=math.floor(((aabb.max.y-aabb.min.y)*rough)/offset+.5)
    return T.jaggedAabb(aabb,dx,dy,offset,rand)
end
return T
