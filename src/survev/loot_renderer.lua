-- Survev client/src/objects/loot.ts: original world loot and closest pickup.
-- Only original lootImg textures and authoritative ObjectType.Loot entities.
-- Preview pickups are handled separately by offline_demo, never here.
local Definitions=require("src.survev.loot_art")
local ObjectType=require("src.survev.object_serialize_fns").Type
local Geometry=require("src.survev.los_geometry")
local Loot={}
Loot.__index=Loot
local function rgba(n)
    n=n or 0xffffff
    return math.floor(n/65536)%256/255,math.floor(n/256)%256/255,
        n%256/255
end
function Loot.new()
    return setmetatable({cache={},missing={},rendered=0},Loot)
end
function Loot:image(path)
    if not path then return nil end
    if self.cache[path]~=nil then return self.cache[path] or nil end
    local file="assets/survev/img/"..path
    if not love.filesystem.getInfo(file) then
        self.cache[path]=false
        self.missing[file]=true
        return nil
    end
    local ok,im=pcall(love.graphics.newImage,file)
    if not ok then
        self.cache[path]=false
        self.missing[file]=true
        return nil
    end
    im:setFilter("linear","linear")
    self.cache[path]=im
    return im
end
local function lootOrder(objects)
    local ordered={}
    for id,obj in pairs(objects or {}) do
        if obj.__type==ObjectType.Loot and obj.pos and obj.type then
            ordered[#ordered+1]={id=id,obj=obj}
        end
    end
    -- Stable order approximates server's pool order for equal zOrd=13.
    table.sort(ordered,function(a,b)return a.id<b.id end)
    return ordered
end
function Loot.nearest(state)
    if not state or not state.objects then return nil end
    local actor=state.objects[state.activeId]
    if not actor or not actor.pos or actor.dead or actor.downed then
        return nil
    end
    local best,bestD2=nil,math.huge
    for _,entry in ipairs(lootOrder(state.objects)) do
        local obj=entry.obj
        local data=Definitions.loot[obj.type]
        if data and obj.count and obj.count>0 and
            Geometry.sameLayer(actor.layer or 0,obj.layer or 0)
            and ((obj.ownerId or 0)==0 or obj.ownerId==actor.__id) then
            local dx=obj.pos.x-actor.pos.x
            local dy=obj.pos.y-actor.pos.y
            local d2=dx*dx+dy*dy
            -- Exact LootBarn radius: desktop uses loot.rad, no player
            -- radius added; touch uses an alternative branch not ported.
            if d2<data.radius*data.radius and d2<bestD2 then
                bestD2=d2
                best={id=obj.__id or entry.id,object=obj,
                    def=data,distSq=d2}
            end
        end
    end
    return best
end
function Loot:draw(objects,camera,w,h)
    if not love or not love.graphics then return 0 end
    local g=love.graphics
    local drawn=0
    for _,entry in ipairs(lootOrder(objects)) do
        local obj=entry.obj
        local meta=Definitions.loot[obj.type]
        if meta and obj.count and obj.count>0 and meta.asset then
            local pt=camera:m_pointToScreen(obj.pos)
            if pt.x>-90 and pt.x<w+90 and pt.y>-90 and pt.y<h+90 then
                local scale=camera:m_pixels(meta.scale*1.25)
                local border=meta.borderAsset
                if obj.isPreloadedGun then
                    border="loot/loot-circle-outer-06.png"
                end
                if border then
                    local tex=self:image(border)
                    if tex then
                        local bw,bh=tex:getDimensions()
                        -- Source: tintDark for gun ammo, then borderTint,
                        -- otherwise 0.
                        local borderTint=meta.borderTint or 0
                        if meta.ammoType then
                            local ammo=Definitions.loot[meta.ammoType]
                            if ammo and ammo.tintDark then
                                borderTint=ammo.tintDark
                            end
                        end
                        g.setColor(rgba(borderTint))
                        g.draw(tex,pt.x,pt.y,0,scale,scale,bw*.5,bh*.5)
                    end
                end
                local image=self:image(meta.asset)
                if image then
                    local iw,ih=image:getDimensions()
                    g.setColor(rgba(meta.tint))
                    g.draw(image,pt.x,pt.y,meta.rot or 0,
                        (meta.mirror and -1 or 1)*scale*meta.innerScale,
                        scale*meta.innerScale,iw*.5,ih*.5)
                    drawn=drawn+1
                end
            end
        end
    end
    g.setColor(1,1,1,1)
    self.rendered=self.rendered+drawn
    return drawn
end
return Loot
