-- Survev client/src/objects/building.ts: floor/ceiling sprite placement.
-- Source images, offsets, rotations, tints and z-orders come from the
-- pinned original shared/defs/mapObjects/buildings/** MapObjectDefs.
-- This is the first visible building pass: renderer layer masks, ceiling
-- line-of-sight reveal and animated transitions need a separate exact port.
local Meta=require("src.survev.map_building_art")
local ObjectTypes=require("src.survev.object_serialize_fns").Type
local V2=require("src.survev.v2")
local Visibility=require("src.survev.building_visibility")
local Biomes=require("src.survev.map_colors")
local Building={}
Building.__index=Building
local HALF_PI=math.pi/2

local function colorParts(n)
    assert(type(n)=="number","Survev tint must be numeric")
    return math.floor(n/65536)%256/255,
        math.floor(n/256)%256/255,n%256/255
end
local function placement(obj,img,camera)
    local angle=(obj.ori or 0)*HALF_PI
    local rotated=V2.rotate(img.pos,angle)
    local pos=V2.add(obj.pos,rotated)
    local point=camera:m_pointToScreen(pos)
    local size=camera:m_pixels(img.scale) -- original Building has scale = 1
    return {
        x=point.x,y=point.y,
        angle=-angle+(img.rot or 0)*HALF_PI,
        sx=img.mirrorX and -size or size,
        sy=img.mirrorY and -size or size,
        alpha=img.alpha,
        tint=img.tint,
    }
end
Building.placement=placement

function Building.new()
    return setmetatable({
        loaded={},missing={},visibility=Visibility.new(),
        drawn={floor=0,ceiling=0},
        notFound={floor=0,ceiling=0},
    },Building)
end
function Building:getImage(path)
    if self.loaded[path]~=nil then return self.loaded[path] or nil end
    local file="assets/survev/img/"..path
    if not love.filesystem.getInfo(file) then
        self.loaded[path]=false
        self.missing[file]=true
        return nil
    end
    local ok,result=pcall(love.graphics.newImage,file)
    if not ok then
        self.loaded[path]=false
        self.missing[file]=true
        return nil
    end
    result:setFilter("linear","linear")
    self.loaded[path]=result
    return result
end

-- This builds a sorted list of the EXACT upstream building image layers.
-- It is separate from GPU code so source placement can be parity-tested.
function Building:commands(objects,camera,phase)
    assert(phase=="floor" or phase=="ceiling","invalid building pass")
    local cmds={}
    for _,obj in pairs(objects) do
        if obj.__type==ObjectTypes.Building and obj.pos and obj.type then
            local def=Meta[obj.type]
            if def then
                local list=def[phase]
                for i,img in ipairs(list) do
                    if phase~="ceiling" or
                        not (obj.ceilingDamaged and img.removeOnDamaged) then
                        local info=placement(obj,img,camera)
                        if phase=="ceiling" then
                            info.alpha=info.alpha*self.visibility:alpha(obj.__id)
                        end
                        -- The original Building zOrd: floor=def.zIdx,
                        -- ceiling=750-def.zIdx, zIdx=id*100+i(0-based).
                        info.zOrd=phase=="ceiling" and 750-def.zIdx or def.zIdx
                        info.zIdx=obj.__id*100+i-1
                        info.type=obj.type
                        info.ownerId=obj.__id
                        info.sprite=img.sprite
                        info.asset=img.asset
                        cmds[#cmds+1]=info
                    end
                end
            end
        end
    end
    table.sort(cmds,function(a,b)
        if a.zOrd~=b.zOrd then return a.zOrd<b.zOrd end
        if a.zIdx~=b.zIdx then return a.zIdx<b.zIdx end
        return a.ownerId<b.ownerId
    end)
    return cmds
end

function Building:drawPhase(objects,camera,phase,width,height,mapName)
    local graphics=love.graphics
    local commands=self:commands(objects,camera,phase)
    local brightness=mapName and Biomes[mapName] and Biomes[mapName].valueAdjust or 1
    self.drawn[phase]=0
    self.notFound[phase]=0
    for _,entry in ipairs(commands) do
        -- Nil/none image in original means no image: never draw placeholders.
        if entry.asset and entry.alpha>0.001 then
            local img=self:getImage(entry.asset)
            if img then
                local iw,ih=img:getDimensions()
                -- world culling with measured artwork dimensions (not fake radii)
                local maxDimension=math.max(iw,ih)*math.max(math.abs(entry.sx),math.abs(entry.sy))
                local margin=maxDimension*.75
                if entry.x>=-margin and entry.x<=width+margin
                    and entry.y>=-margin and entry.y<=height+margin then
                    local tint=entry.tint
                    if brightness<1 then
                        -- Exact util.adjustValue: Math.round(channel * value)
                        local red=math.floor(math.floor(tint/65536)%256*brightness+.5)
                        local green=math.floor(math.floor(tint/256)%256*brightness+.5)
                        local blue=math.floor(tint%256*brightness+.5)
                        tint=red*65536+green*256+blue
                    end
                    local r,g,b=colorParts(tint)
                    graphics.setColor(r,g,b,entry.alpha)
                    graphics.draw(img,entry.x,entry.y,entry.angle,
                        entry.sx,entry.sy,iw*.5,ih*.5)
                    self.drawn[phase]=self.drawn[phase]+1
                end
            else
                self.notFound[phase]=self.notFound[phase]+1
            end
        elseif entry.sprite and entry.sprite~="none" then
            self.notFound[phase]=self.notFound[phase]+1
        end
    end
    graphics.setColor(1,1,1,1)
    return self.drawn[phase]
end

function Building:updateVisibility(dt,objects,activePlayer)
    self.visibility:update(dt,objects,activePlayer)
end

function Building:getDefinition(typeName) return Meta[typeName] end
return Building
