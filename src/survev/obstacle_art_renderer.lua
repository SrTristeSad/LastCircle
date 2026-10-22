-- Obstacle sprite renderer from Survev client/src/objects/obstacle.ts.
-- Metadata generated from actual MapObjectDefs and original public/img files.
-- Static/damaged sprite selection, tint, rotation and scale ported.
-- Door movement and source zOrd strata are ported; PIXI masks remain pending.
local Registry=require("src.survev.map_obstacle_art")
local Objects=require("src.survev.object_serialize_fns")
local DoorVisual=require("src.survev.door_visual")
local Structure=require("src.survev.structure_layer")
local Biomes=require("src.survev.map_colors")
local Art={}
Art.__index=Art
local PI2=math.pi*.5
local function rgb(tint)
    return math.floor(tint/65536)%256/255,
        math.floor(tint/256)%256/255,
        tint%256/255
end
function Art.new()
    return setmetatable({cache={},missing={},doors=DoorVisual.new(),drawn=0,unavailable=0},Art)
end
function Art:image(path)
    if self.cache[path]~=nil then return self.cache[path] or nil end
    local full="assets/survev/img/"..path
    if not love.filesystem.getInfo(full) then
        self.cache[path]=false
        self.missing[full]=true
        return nil
    end
    local ok,texture=pcall(love.graphics.newImage,full)
    if not ok then
        self.cache[path]=false
        self.missing[full]=true
        return nil
    end
    texture:setFilter("linear","linear")
    self.cache[path]=texture
    return texture
end
function Art:update(objects,dt)
    self.doors:update(objects,dt)
end
local function adjustTint(tint,mapName)
    local map=mapName and Biomes[mapName]
    local brightness=map and map.valueAdjust or 1
    if brightness>=1 then return tint end
    local r=math.floor((math.floor(tint/65536)%256)*brightness+.5)
    local g=math.floor((math.floor(tint/256)%256)*brightness+.5)
    local b=math.floor((tint%256)*brightness+.5)
    return r*65536+g*256+b
end
local function selectTexture(meta,obj)
    if obj.dead then return meta.residue end
    if obj.isButton and obj.button then
        if obj.button.onOff and meta.buttonOn then return meta.buttonOn end
        if obj.button.canUse==false and meta.buttonOff then return meta.buttonOff end
    end
    return meta.asset
end
local function screenVisible(camera,pos,width,height,margin)
    local pt=camera:m_pointToScreen(pos)
    return pt.x>=-margin and pt.x<=width+margin and
        pt.y>=-margin and pt.y<=height+margin,pt
end
-- Coarse ordered render strata from the ORIGINAL Survev zOrd values.
-- Player objects have zOrd=18 and most building roofs approximately 750.
-- The final PIXI layer/mask compositor is still a separate future port.
local function inStratum(z,part)
    if not part or part=="all" then return true end
    if part=="belowPlayer" then return z<18 end
    if part=="betweenPlayerAndRoof" then return z>=18 and z<750 end
    if part=="aboveRoof" then return z>=750 end
    error("unknown upstream obstacle stratum "..tostring(part))
end
Art.inStratum=inStratum
-- Source obstacle.ts render(): corpses become zOrd=5. When the active
-- player is on ground floor, high objects (zOrd>=50) on layer 0 are
-- promoted to stairs layer 2 with zOrd+100. These are rendered AFTER
-- the ground/roof pass and are clipped by structure mask holes.
function Art.visualOrder(meta,obj,activePlayer)
    local z=obj.dead and 5 or (meta and meta.zIdx or 0)
    local layer=obj.layer or 0
    local high=false
    if not obj.dead and z>=50 and layer==0 and
        activePlayer and (activePlayer.layer or 0)==0 then
        z=z+100
        layer=2
        high=true
    end
    return {z=z,layer=layer,high=high,
        zIdx=math.floor((obj.scale or 1)*1000)*65535+(obj.__id or 0)}
end
local function maskHighFoliage(g,objects,camera,activePlayer)
    if not activePlayer or (activePlayer.layer or 0)~=0 then return false end
    if not g.stencil or not g.setStencilTest then return false end
    local masks={}
    for _,structure in ipairs(Structure.snapshot(objects)) do
        for _,rect in ipairs(structure.mask) do
            if rect.type==1 then
                local left=camera:m_pointToScreen(rect.min)
                local right=camera:m_pointToScreen(rect.max)
                masks[#masks+1]={
                    x=math.min(left.x,right.x),
                    y=math.min(left.y,right.y),
                    w=math.abs(left.x-right.x),
                    h=math.abs(left.y-right.y),
                }
            end
        end
    end
    if #masks==0 then return false end
    g.stencil(function()
        for _,rect in ipairs(masks) do
            g.rectangle("fill",rect.x,rect.y,rect.w,rect.h)
        end
    end,"replace",1)
    g.setStencilTest("equal",0)
    return true
end
Art.maskHighFoliage=maskHighFoliage
function Art:draw(objects,camera,width,height,mapName,part,activePlayer)
    local graphics=love.graphics
    local visible={}
    self.drawn,self.unavailable=0,0
    for _,obj in pairs(objects) do
        if obj.__type==Objects.Type.Obstacle and obj.pos and obj.type then
            local meta=Registry[obj.type]
            local ok,pt=screenVisible(camera,obj.pos,width,height,200)
            local order=Art.visualOrder(meta,obj,activePlayer)
            local accepted=(part=="stairsOverlay" and order.high)
                or (part~="stairsOverlay" and
                    not order.high and inStratum(order.z,part))
            -- The original sprite becomes invisible when a dead object
            -- has no residue; never draw a diagnostic placeholder for it.
            if ok and accepted and
                (not meta or selectTexture(meta,obj)~=nil) then
                visible[#visible+1]={
                    obj=obj,meta=meta,pt=pt,
                    z=order.z,zIdx=order.zIdx,
                }
            end
        end
    end
    table.sort(visible,function(a,b)
        if a.z~=b.z then return a.z<b.z end
        return a.zIdx<b.zIdx
    end)
    local masked=false
    if part=="stairsOverlay" and #visible>0 then
        masked=maskHighFoliage(graphics,objects,camera,activePlayer)
    end
    for _,entry in ipairs(visible) do
        local meta,obj,pt=entry.meta,entry.obj,entry.pt
        local isDoor=meta and meta.door~=nil
        local model=isDoor and self.doors:visual(obj) or nil
        if model then pt=camera:m_pointToScreen(model.pos) end
        local path=meta and selectTexture(meta,obj)
        local sprite=path and self:image(path)
        if sprite then
            local iw,ih=sprite:getDimensions()
            local screenScale=camera:m_pixels((obj.scale or 1)*meta.imageScale)
            local flipX=meta.mirrorX and -1 or 1
            local flipY=meta.mirrorY and -1 or 1
            local originalRotation=model and model.rot or (obj.ori or 0)*PI2
            local offset=meta.randomRotation and math.rad((obj.__id or 0)%360) or 0
            local anchor=meta.doorAnchor or {x=.5,y=.5}
            local r,g,b=rgb(adjustTint(meta.tint,mapName))
            graphics.setColor(r,g,b,obj.dead and .75 or (meta.alpha or 1))
            graphics.draw(sprite,pt.x,pt.y,-originalRotation+offset,
                screenScale*flipX,screenScale*flipY,
                iw*anchor.x,ih*anchor.y)
            self.drawn=self.drawn+1
            if isDoor and not obj.dead then
                local casing=self.doors:casing(obj,meta)
                local casingSprite=casing and casing.img.asset
                    and self:image(casing.img.asset)
                if casingSprite then
                    local x,y=casingSprite:getDimensions()
                    local p=camera:m_pointToScreen(casing.pos)
                    local s=camera:m_pixels((obj.scale or 1)*casing.img.scale)
                    local cr,cg,cb=rgb(adjustTint(casing.img.tint,mapName))
                    graphics.setColor(cr,cg,cb,casing.img.alpha)
                    graphics.draw(casingSprite,p.x,p.y,-casing.rot,s,s,x*.5,y*.5)
                end
            end
        else
            -- Explicit diagnostic, never a fake stand-in for original art.
            graphics.setColor(1,.55,.33,.7)
            graphics.circle("line",pt.x,pt.y,8)
            graphics.print("ARTE: "..tostring(obj.type),pt.x+9,pt.y-10)
            self.unavailable=self.unavailable+1
        end
    end
    if masked then graphics.setStencilTest() end
    graphics.setColor(1,1,1,1)
end
return Art
