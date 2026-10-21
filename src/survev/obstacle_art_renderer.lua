-- Obstacle sprite renderer from Survev client/src/objects/obstacle.ts.
-- Metadata generated from actual MapObjectDefs and original public/img files.
-- Static/damaged sprite selection, tint, rotation and scale ported.
-- Doors/animations and four rendering layers remain incomplete.
local Registry=require("src.survev.map_obstacle_art")
local Objects=require("src.survev.object_serialize_fns")
local Art={}
Art.__index=Art
local PI2=math.pi*.5
local function rgb(tint)
    return math.floor(tint/65536)%256/255,
        math.floor(tint/256)%256/255,
        tint%256/255
end
function Art.new()
    return setmetatable({cache={},missing={},drawn=0,unavailable=0},Art)
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
function Art:draw(objects,camera,width,height)
    local graphics=love.graphics
    local visible={}
    self.drawn,self.unavailable=0,0
    for _,obj in pairs(objects) do
        if obj.__type==Objects.Type.Obstacle and obj.pos and obj.type then
            local meta=Registry[obj.type]
            local ok,pt=screenVisible(camera,obj.pos,width,height,200)
            if ok then
                visible[#visible+1]={obj=obj,meta=meta,pt=pt,
                    z=meta and meta.zIdx or 0}
            end
        end
    end
    table.sort(visible,function(a,b)
        if a.z~=b.z then return a.z<b.z end
        return a.obj.__id<b.obj.__id
    end)
    for _,entry in ipairs(visible) do
        local meta,obj,pt=entry.meta,entry.obj,entry.pt
        local path=meta and selectTexture(meta,obj)
        local sprite=path and self:image(path)
        if sprite then
            local iw,ih=sprite:getDimensions()
            local screenScale=camera:m_pixels((obj.scale or 1)*meta.imageScale)
            local flipX=meta.mirrorX and -1 or 1
            local flipY=meta.mirrorY and -1 or 1
            local originalRotation=(obj.ori or 0)*PI2
            local offset=meta.randomRotation and math.rad((obj.__id or 0)%360) or 0
            local anchor=meta.doorAnchor or {x=.5,y=.5}
            local r,g,b=rgb(meta.tint)
            graphics.setColor(r,g,b,meta.alpha or 1)
            graphics.draw(sprite,pt.x,pt.y,-originalRotation+offset,
                screenScale*flipX,screenScale*flipY,
                iw*anchor.x,ih*anchor.y)
            self.drawn=self.drawn+1
        else
            -- Explicit diagnostic, never a fake stand-in for original art.
            graphics.setColor(1,.55,.33,.7)
            graphics.circle("line",pt.x,pt.y,8)
            graphics.print("ARTE: "..tostring(obj.type),pt.x+9,pt.y-10)
            self.unavailable=self.unavailable+1
        end
    end
    graphics.setColor(1,1,1,1)
end
return Art
