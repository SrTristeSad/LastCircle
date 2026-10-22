-- Survev BulletBarn.m_update structure-layer rule from client/src/objects/bullet.ts
-- Uses exact upstream StructureDefs stairs + masks exported by
-- scripts/generate_structure_collision.mjs, never guessed geometry.
-- Source transforms are reused from los_geometry/building_surfaces.
local LOS=require("src.survev.los_geometry")
local Types=require("src.survev.object_serialize_fns").Type
local S={}
local defaultDefs=nil
local function defs()
    if defaultDefs then return defaultDefs end
    local ok,source=pcall(require,"src.survev.map_structure_collision")
    if ok then defaultDefs=source end
    return ok and source or {}
end
function S.snapshot(objects,registry)
    registry=registry or defs()
    local structures={}
    for id,o in pairs(objects or {}) do
        if o.__type==Types.Structure and o.type and o.pos then
            local d=registry[o.type]
            if d then
                local e={__id=o.__id or id,stairs={},mask={}}
                for _,stair in ipairs(d.stairs or {}) do
                    e.stairs[#e.stairs+1]={
                        collision=LOS.transform(
                            stair.collision,o.pos,o.ori or 0,1),
                        lootOnly=not not stair.lootOnly,
                    }
                end
                for _,mask in ipairs(d.mask or {}) do
                    e.mask[#e.mask+1]=LOS.transform(
                        mask,o.pos,o.ori or 0,1)
                end
                structures[#structures+1]=e
            end
        end
    end
    return structures
end
function S.updateLayer(structures,bullet,oldPoint,newPoint)
    if not bullet or not oldPoint or not newPoint then return nil end
    local layer=bullet.layer or 0
    if math.floor(layer/2)%2==1 then return layer end
    for _,s in ipairs(structures or {}) do
        local onStair=false
        for _,stair in ipairs(s.stairs) do
            if not stair.lootOnly and
                LOS.intersectSegment(stair.collision,newPoint,oldPoint) then
                onStair=true
                break
            end
        end
        if onStair then
            local onMask=false
            for _,mask in ipairs(s.mask) do
                if LOS.intersectSegment(mask,newPoint,oldPoint) then
                    onMask=true
                    break
                end
            end
            if not onMask then
                layer=layer+2
                break
            end
        end
    end
    bullet.layer=layer
    return layer
end
return S
