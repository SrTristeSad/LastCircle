-- Survev client/src/objects/player.ts basic BODY/HANDS/FEET pass.
-- Original source: updateVisuals(), updateRotation(), render(); idle poses
-- generated from client/src/animData.ts, tints/skins from outfitDefs.ts.
-- Does not pretend to implement weapons, recoil, full action animations,
-- armour, particles, water submersion or final PIXI render-layer sorting.
local Metadata=require("src.survev.player_art")
local Config=require("src.survev.game_config")
local Palettes=require("src.survev.map_colors")
local V=require("src.survev.v2")
local Player={}
Player.__index=Player

local function color(color)
    return math.floor(color/65536)%256/255,
        math.floor(color/256)%256/255,
        color%256/255
end
local function drawOrder(obj)
    return obj.downed and "downed" or "fists"
end
-- Survev client/src/animData.ts:Animations.fists hand-R keyframes.
-- This reproduces the visible idle -> punch -> idle pose ONLY. It never
-- creates a hit, damage, particles or sound without a real game server.
local function mix(a,b,t) return a+(b-a)*t end
function Player.fistPose(t)
    local frames=Metadata.animations and Metadata.animations.fists
    if not frames or type(t)~="number" or t<0 then return nil end
    if t>=frames[#frames].time then return nil end
    local start,finish=frames[1],frames[2]
    for idx=2,#frames do
        if t<=frames[idx].time then
            start,finish=frames[idx-1],frames[idx]
            break
        end
    end
    local weight=(t-start.time)/(finish.time-start.time)
    local a,b=start.handR,finish.handR
    return {
        pivot={x=mix(a.pivot.x,b.pivot.x,weight),
            y=mix(a.pivot.y,b.pivot.y,weight)},
        pos={x=mix(a.pos.x,b.pos.x,weight),
            y=mix(a.pos.y,b.pos.y,weight)},
        rot=mix(a.rot,b.rot,weight),
    }
end
local function worldPose(pose,bodyCenter,bodyRotation,bodyScale)
    local boneRot=pose.rot or 0
    local original=V.add(pose.pos,
        V.rotate(pose.pivot,boneRot))
    local offset=V.rotate(V.mul(original,bodyScale),bodyRotation)
    return V.add(bodyCenter,offset),bodyRotation+boneRot
end
function Player.new()
    return setmetatable({images={},missing={},drawn=0,unavailable=0},Player)
end
function Player:load(path)
    if self.images[path]~=nil then return self.images[path] or nil end
    local full="assets/survev/img/"..path
    if not love.filesystem.getInfo(full) then
        self.images[path]=false
        self.missing[full]=true
        return nil
    end
    local ok,img=pcall(love.graphics.newImage,full)
    if not ok then
        self.images[path]=false
        self.missing[full]=true
        return nil
    end
    img:setFilter("linear","linear")
    self.images[path]=img
    return img
end
function Player:commands(obj,camera,mapName)
    if not obj or not obj.pos or obj.dead then return {} end
    local outfit=Metadata.outfits[obj.outfit or "outfitBase"]
    if not outfit then
        return nil,"unknown upstream outfit: "..tostring(obj.outfit)
    end
    local yaw=math.atan2 or math.atan
    local heading=obj.dir or {x=1,y=0}
    local rad=-yaw(heading.y,heading.x)
    local center=camera:m_pointToScreen(obj.pos)
    -- Original player.ts: camera.m_pixels(1) * (m_bodyRad / player.radius).
    local bodyScale=camera:m_pixels(1)*(obj.scale or 1)/Config.player.radius
    local poses=assert(Metadata.idlePoses[drawOrder(obj)])
    local palette=Palettes[mapName or "main"]
    local ghillieColor=palette and palette.colors.playerGhillie
    local primary=outfit.ghillie and ghillieColor or outfit.baseTint
    local hand=outfit.ghillie and ghillieColor or outfit.handTint
    local foot=outfit.ghillie and ghillieColor or outfit.footTint
    local output={}
    local function append(name,path,tint,scale,pose,extraRotation)
        local at,angle=center,rad
        if pose then at,angle=worldPose(pose,center,rad,bodyScale) end
        output[#output+1]={
            name=name,asset=path,x=at.x,y=at.y,
            rotation=angle+(extraRotation or 0),
            scale=bodyScale*scale,tint=tint,
            ownerId=obj.__id,
        }
    end
    -- Original bodyContainer order: feet L/R, backpack, body, equipment,
    -- hands L/R, visor/helmet. Only layers already ported are emitted.
    if obj.downed then
        if poses.FootL then
            append("footL",outfit.footAsset,foot,Metadata.sprites.footScale,
                poses.FootL,math.pi*.5)
        end
        if poses.FootR then
            append("footR",outfit.footAsset,foot,Metadata.sprites.footScale,
                poses.FootR,math.pi*.5)
        end
    end
    append("body",outfit.baseAsset,primary,Metadata.sprites.bodyScale)
    if poses.HandL then
        append("handL",outfit.handLAsset,hand,Metadata.sprites.handScale,poses.HandL)
    end
    if poses.HandR then
        local punch=(obj.offlinePreview and Player.fistPose(obj.previewFistTicker)) or nil
        append("handR",outfit.handRAsset,hand,Metadata.sprites.handScale,punch or poses.HandR)
    end
    return output
end

function Player:draw(obj,camera,mapName)
    local commands,err=self:commands(obj,camera,mapName)
    if not commands then
        self.unavailable=self.unavailable+1
        return 0,err
    end
    local n=0
    for _,item in ipairs(commands) do
        local tex=self:load(item.asset)
        if tex then
            local width,height=tex:getDimensions()
            love.graphics.setColor(color(item.tint))
            love.graphics.draw(tex,item.x,item.y,item.rotation,
                item.scale,item.scale,width*.5,height*.5)
            n=n+1
        else
            self.unavailable=self.unavailable+1
        end
    end
    love.graphics.setColor(1,1,1,1)
    self.drawn=self.drawn+n
    return n
end
return Player
