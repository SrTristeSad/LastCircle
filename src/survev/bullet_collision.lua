-- Survev client/src/objects/bullet.ts: first visual impact along a
-- single bullet movement segment. Shared collider math and MapObjectDefs
-- are source-derived. This NEVER applies gameplay damage or hit messages.
--
-- Deliberate scope: collidable obstacles (including doors) and player
-- circles. Pan parry, destructible effects, structural stairs / masks,
-- interpolated old player transforms and ricochet creation are future work.
local LOS=require("src.survev.los_geometry")
local Types=require("src.survev.object_serialize_fns").Type
local Config=require("src.survev.game_config")
local C={}
local BULLET_HEIGHT=.25

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
function C.snapshot(objects,registry)
    local snapshot={obstacles=LOS.obstacles(objects,registry),players={}}
    for key,o in pairs(objects) do
        if o.__type==Types.Player and o.pos and not o.dead then
            snapshot.players[#snapshot.players+1]={
                __id=o.__id or key,__type=Types.Player,
                pos=o.pos,layer=o.layer,scale=o.scale or 1,dead=o.dead,
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
                o.__id~=bullet.reflectObjId) then
            consider(LOS.intersectSegment(o.collider,startPoint,endPoint),
                "obstacle",o.__id)
        end
    end
    for _,o in ipairs(snapshot.players or {}) do
        if eligiblePlayer(o,bullet) then
            local rad=Config.player.radius*(o.scale or 1)
            if rad>0 then
                consider(LOS.intersectSegment({
                    type=0,pos=o.pos,rad=rad,
                },startPoint,endPoint),"player",o.__id)
            end
        end
    end
    if best then best.distance=math.sqrt(best.distanceSq) end
    return best
end
return C
