-- Survev client/src/objects/bullet.ts: first visual impact along a
-- single bullet movement segment. Shared collider math and MapObjectDefs
-- are source-derived. This NEVER applies gameplay damage or hit messages.
--
-- Deliberate scope: collidable obstacles, player circles and source pan
-- segments. Structural stairs/masks and ricochet creation remain separate.
local LOS=require("src.survev.los_geometry")
local Types=require("src.survev.object_serialize_fns").Type
local Config=require("src.survev.game_config")
local C={}
local BULLET_HEIGHT=.25
local HALF_PI=math.pi/2
local PAN={
    equipped={p0={x=2.65,y=-.125},p1={x=1.35,y=-.74}},
    unequipped={p0={x=-.625,y=-1.2},p1={x=-1.4,y=-.25}},
}
local function transformPoint(p,pos,dir)
    local x,y=dir.x,dir.y
    local angle=math.atan2 and math.atan2(y,x) or math.atan(y,x)
    local sn,cs=math.sin(angle),math.cos(angle)
    return {x=pos.x+p.x*cs-p.y*sn,
            y=pos.y+p.x*sn+p.y*cs}
end
local function segmentIntersection(a0,a1,b0,b1)
    -- coldet.ts: strict signed-area intersection (no endpoint touch).
    local function area(p,q,r)
        return (q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x)
    end
    local x1=area(a0,a1,b1)
    local x2=area(a0,a1,b0)
    if x1==0 or x2==0 or x1*x2>=0 then return nil end
    local x3=area(b0,b1,a0)
    local x4=x3+x2-x1
    if x3*x4>=0 then return nil end
    local t=x3/(x3-x4)
    return {point={x=a0.x+(a1.x-a0.x)*t,
                   y=a0.y+(a1.y-a0.y)*t}}
end
local function panPoints(o,pos,dir)
    if not pos or not dir then return nil end
    local data=PAN[o.wearingPan and "unequipped" or "equipped"]
    local scale=o.scale or 1
    local p0,p1={x=data.p0.x,y=data.p0.y},{x=data.p1.x,y=data.p1.y}
    if scale~=1 then
        if o.wearingPan then
            p0.x,p0.y=p0.x*scale,p0.y*scale
            p1.x,p1.y=p1.x*scale,p1.y*scale
        else
            local s=(scale-1)*.75
            p0.x,p0.y=p0.x+s,p0.y-s
            p1.x,p1.y=p1.x+s,p1.y-s
        end
    end
    return transformPoint(p0,pos,dir),transformPoint(p1,pos,dir)
end
local function panIntersects(o,a,b)
    if not (o.wearingPan or
        (o.activeWeapon=="pan" and o.animType~=Config.Anim.Melee)) then
        return nil
    end
    local np0,np1=panPoints(o,o.pos,o.dir)
    local op0,op1=panPoints(o,o.oldPos or o.pos,o.oldDir or o.dir)
    if not np0 or not op0 then return nil end
    -- Source bullet.ts evaluates old/new pan segments independently.
    return segmentIntersection(a,b,op0,op1) or
        segmentIntersection(a,b,np0,np1)
end
C.panIntersects=panIntersects


local function dist2(a,b)
    local x,y=a.x-b.x,a.y-b.y
    return x*x+y*y
end
local function eligiblePlayer(o,bullet)
    if o.__type~=Types.Player or o.dead or not o.pos then return false end
    if not (LOS.sameLayer(o.layer,bullet.layer) or
        math.floor((o.layer or 0)/2)%2==1) then return false end
    if o.__id==bullet.playerId and not bullet.damageSelf then return false end
    return true
end
-- Return an array of source-transformed obstacle colliders and real
-- connected player snapshots. Caller builds this once per UpdateMsg.
function C.snapshot(objects,registry,previous)
    local snapshot={obstacles=LOS.obstacles(objects,registry),players={}}
    local prior={}
    for _,p in ipairs(previous and previous.players or {}) do
        prior[p.__id]=p
    end
    for key,o in pairs(objects) do
        if o.__type==Types.Player and o.pos and not o.dead then
            local prev=prior[o.__id or key]
            snapshot.players[#snapshot.players+1]={
                __id=o.__id or key,__type=Types.Player,
                pos=o.pos,dir=o.dir or {x=1,y=0},
                oldPos=(prev and prev.pos) or o.pos,
                oldDir=(prev and prev.dir) or o.dir or {x=1,y=0},
                layer=o.layer,scale=o.scale or 1,dead=o.dead,
                wearingPan=o.wearingPan,
                activeWeapon=o.activeWeapon,animType=o.animType,
            }
        end
    end
    return snapshot
end
-- Test every potential collider, choose the first by travel distance.
-- Non-collidable obstacles do not stop the visual trail, per source.
function C.firstHit(snapshot,bullet,startPoint,endPoint)
    if not snapshot or not bullet or not startPoint or not endPoint then
        return nil
    end
    -- Conservative swept AABB broad phase: this does not replace the
    -- original line/collider test, it only skips distant world entities.
    -- A small margin covers the original coldet near-axis epsilon hack.
    local epsilon=.001
    local minX=math.min(startPoint.x,endPoint.x)-epsilon
    local maxX=math.max(startPoint.x,endPoint.x)+epsilon
    local minY=math.min(startPoint.y,endPoint.y)-epsilon
    local maxY=math.max(startPoint.y,endPoint.y)+epsilon
    local function inSweep(collider)
        if collider.type==0 then
            local p,r=collider.pos,collider.rad
            return p.x+r>=minX and p.x-r<=maxX and
                p.y+r>=minY and p.y-r<=maxY
        end
        local mn,mx=collider.min,collider.max
        return mx.x>=minX and mn.x<=maxX and
            mx.y>=minY and mn.y<=maxY
    end
    local best=nil
    local function consider(hit,kind,id)
        if not hit or not hit.point then return end
        local distance=dist2(hit.point,startPoint)
        if not best or distance<best.distanceSq then
            best={point=hit.point,kind=kind,id=id,distanceSq=distance}
        end
    end
    for _,o in ipairs(snapshot.obstacles or {}) do
        if o.active and not o.dead and o.collidable and
            o.height>=BULLET_HEIGHT and
            LOS.sameLayer(o.layer,bullet.layer) and
            (not bullet.reflectCount or bullet.reflectCount==0 or
                o.__id~=bullet.reflectObjId) and
            inSweep(o.collider) then
            consider(LOS.intersectSegment(o.collider,startPoint,endPoint),
                "obstacle",o.__id)
        end
    end
    for _,o in ipairs(snapshot.players or {}) do
        if eligiblePlayer(o,bullet) then
            local rad=Config.player.radius*(o.scale or 1)
            local circle={type=0,pos=o.pos,rad=rad}
            local body=(rad>0 and inSweep(circle)) and
                LOS.intersectSegment(circle,startPoint,endPoint) or nil
            local pan=panIntersects(o,startPoint,endPoint)
            -- Original chooses pan only when its crossing precedes body.
            if body and pan and
                dist2(body.point,startPoint)<dist2(pan.point,startPoint) then
                pan=nil
            end
            if pan then consider(pan,"pan",o.__id)
            else consider(body,"player",o.__id) end
        end
    end
    if best then best.distance=math.sqrt(best.distanceSq) end
    return best
end
return C
