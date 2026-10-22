-- Survev client/src/ui/ui2.ts interaction-target logic for source doors.
-- Mirrors getInteraction() + collider.intersectCircle selection by maximum
-- penetration. Objects and their canUse flags come from UpdateMsg; when
-- unknown we display NO actionable object, not an invented pickup.
local Config=require("src.survev.game_config")
local Registry=require("src.survev.map_obstacle_art")
local Shapes=require("src.survev.building_surfaces")
local Geometry=require("src.survev.los_geometry")
local Type=require("src.survev.object_serialize_fns").Type
local Hint={}
function Hint.scan(state)
    if not state or not state.objects then return nil end
    local player=state.objects[state.activeId]
    if not player or not player.pos or player.dead then return nil end
    local bestPen=0
    local best=nil
    for id,obj in pairs(state.objects) do
        if obj.__type==Type.Obstacle and obj.pos and obj.type
            and not obj.dead and obj.door and obj.door.canUse then
            local def=Registry[obj.type]
            local door=def and def.door
            if door and door.interactionRad and
                not door.autoOpen and
                Geometry.sameLayer(player.layer or 0,obj.layer or 0) then
                local col=Shapes.transform(def.collision,obj.pos,obj.ori or 0,
                    obj.scale or 1)
                local hit=Geometry.intersectCircle(col,player.pos,
                    door.interactionRad+Config.player.radius*
                        (player.scale or 1))
                -- The original UI ranks candidates by intersection
                -- penetration, NOT distance to their central point.
                if hit and hit.pen>bestPen then
                    bestPen=hit.pen
                    best={id=obj.__id or id,obj=obj,
                        type=obj.type,penetration=hit.pen,
                        action=obj.door.open and "Fechar porta"
                            or "Abrir porta",key="F",
                        usable=not obj.door.locked}
                end
            end
        end
    end
    return best
end
function Hint.draw(state,width,height)
    local target=Hint.scan(state)
    if not target then return false end
    local g=love.graphics
    local w=210
    local x=(width-w)*.5
    local y=height-225
    g.setColor(.035,.095,.10,.90)
    g.rectangle("fill",x,y,w,39,8,8)
    g.setColor(target.usable and {.93,.84,.49} or {.89,.51,.47})
    g.rectangle("line",x+.5,y+.5,w-1,38,8,8)
    g.setColor(1,1,1,.96)
    g.printf(target.usable and "F   "..target.action or "Porta trancada",
        x,y+9,w,"center")
    g.setColor(1,1,1,1)
    return true
end
return Hint
