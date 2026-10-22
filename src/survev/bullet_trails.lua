-- Survev client/src/objects/bullet.ts: BulletBarn.addBullet/m_update/m_render.
-- Visual-only port. Positions originate ONLY from server UpdateMsg.bullets.
-- Visual collision against known obstacle/player colliders is ported;
-- authoritative damage, projectile physics and impacts remain server-owned.
local Art=require("src.survev.bullet_art")
local Collision=require("src.survev.bullet_collision")
local Trails={}
Trails.__index=Trails

local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function decodeColor(value)
    return math.floor(value/65536)%256/255,
        math.floor(value/256)%256/255,value%256/255
end
local function addSourceBullet(self,b)
    if type(b)~="table" or not b.pos or not b.dir or
        not finite(b.pos.x) or not finite(b.pos.y) or
        not finite(b.dir.x) or not finite(b.dir.y) then return nil end
    local def=Art.defs[b.bulletType]
    -- The original delegates flare to FlareBarn; invisible bullets have no
    -- visible tracer. Never draw a stand-in for missing source definitions.
    if not def or def.addFlare or def.tracerWidth<=0 or
        def.tracerColor=="invis" then return nil end
    local palette=Art.colors[def.tracerColor]
    if not palette then return nil end
    local variance=1+(b.varianceT or 0)*(def.variance or 0)
    local reflect=math.max(0,math.min(3,b.reflectCount or 0))
    local distance=(b.clipDistance and b.distance or
        def.distance/(Art.reflectDistDecay^reflect))
    local speed=(def.speed or 0)*(b.speedMult or 1)*variance
    local adjustment=(b.distAdjIdx or 8)/16*2-1
    local maxDistance=(distance or 0)*(b.distanceMult or 1)*
        variance+adjustment
    if not finite(speed) or speed<=0 or not finite(maxDistance)
        or maxDistance<=0 then return nil end
    local width=def.tracerWidth
    if b.trailSmall then width=width*.5 end
    if b.trailThick then width=width*2 end
    local tint=palette.regular
    if b.apRounds and palette.apSaturated then
        tint=palette.apSaturated
    elseif b.trailSaturated then
        tint=palette.chambered or palette.saturated or tint
    end
    local projectile={
        startPos={x=b.pos.x,y=b.pos.y},
        pos={x=b.pos.x,y=b.pos.y},
        dir={x=b.dir.x,y=b.dir.y},
        speed=speed,distance=maxDistance,traveled=0,
        layer=b.layer or 0,width=width,
        playerId=b.playerId,reflectCount=reflect,
        reflectObjId=b.reflectObjId,
        damageSelf=not not def.shrapnel or reflect>0,
        tracerLength=def.tracerLength,
        color=tint,alpha=reflect>0 and .5 or 1,
        suppressed=not not def.suppressed,
        alphaRate=palette.alphaRate,alphaMin=palette.alphaMin or 0,
        collided=false,scale=1,
        source=b.bulletType,
    }
    self.trails[#self.trails+1]=projectile
    if #self.trails>512 then table.remove(self.trails,1) end
    return projectile
end
function Trails.new()
    return setmetatable({world=nil,lastSeq=0,trails={},
        colliders=nil,colliderUpdate=nil,
        image=nil,imageMissing=false},Trails)
end
function Trails:reset()
    self.world=nil
    self.lastSeq=0
    self.trails={}
    self.colliders=nil
    self.colliderUpdate=nil
end
function Trails:addBullet(b)
    return addSourceBullet(self,b)
end
function Trails:update(state,dt)
    if not state or not state.joined or state.offlinePreview or
        state.gameOver or not state.objects then
        self:reset()
        return
    end
    local seq=state.bulletSeq or 0
    if self.world~=state or seq<self.lastSeq then
        self:reset()
        self.world=state
    end
    if self.colliderUpdate~=state.updateCount then
        self.colliders=Collision.snapshot(state.objects)
        self.colliderUpdate=state.updateCount
    end
    local step=math.max(0,dt or 0)
    -- Advance previously spawned projectiles, then add new network events.
    -- Newly received bullets are drawn at origin until the next update.
    for i=#self.trails,1,-1 do
        local bullet=self.trails[i]
        if bullet.collided then
            bullet.scale=math.max(0,bullet.scale-step*6)
            if bullet.scale<=0 then table.remove(self.trails,i) end
        else
            local travel=math.min(
                math.max(0,bullet.distance-bullet.traveled),
                step*bullet.speed)
            local start={x=bullet.pos.x,y=bullet.pos.y}
            local finish={
                x=start.x+bullet.dir.x*travel,
                y=start.y+bullet.dir.y*travel,
            }
            local hit=nil
            if travel>0 then
                hit=Collision.firstHit(self.colliders,bullet,start,finish)
            end
            if hit then
                bullet.traveled=bullet.traveled+math.min(travel,hit.distance)
                bullet.pos.x,bullet.pos.y=hit.point.x,hit.point.y
                bullet.collided=true
                bullet.impactKind=hit.kind
                bullet.impactId=hit.id
            else
                bullet.traveled=bullet.traveled+travel
                bullet.pos.x,bullet.pos.y=finish.x,finish.y
            end
            if bullet.suppressed and bullet.alphaRate then
                bullet.alpha=math.max(
                    bullet.alphaMin,bullet.alpha*bullet.alphaRate)
            end
            if bullet.traveled>=bullet.distance-1e-9 then
                -- Original BulletBarn uses the same fade after a collision
                -- or max-distance event. No impact or hit is fabricated.
                bullet.collided=true
            end
        end
    end
    for _,b in ipairs(state.bulletEvents or {}) do
        if type(b.seq)=="number" and b.seq>self.lastSeq then
            self:addBullet(b)
        end
    end
    self.lastSeq=seq
end
function Trails:project(b,camera)
    local p=camera:m_pointToScreen(b.pos)
    local z=camera:m_pixels(1)
    local trailLength=math.min(b.tracerLength*15,b.traveled/2)
    if trailLength<=0 or b.width<=0 or b.scale<=0 then return nil end
    local atan2=math.atan2 or math.atan
    return {
        x=p.x,y=p.y,
        rotation=atan2(b.dir.x,b.dir.y)-math.pi/2,
        scaleX=z*trailLength*b.scale*.8,
        scaleY=z*b.width,
        tint=b.color,alpha=b.alpha,
        asset=Art.trailAsset,
        layer=b.layer,
    }
end
function Trails:draw(camera,w,h)
    if not love or not love.graphics or #self.trails==0 then
        return 0
    end
    local g=love.graphics
    if not self.image and not self.imageMissing then
        local path="assets/survev/img/"..Art.trailAsset
        if love.filesystem.getInfo(path) then
            local ok,img=pcall(g.newImage,path)
            if ok and img then
                self.image=img
                img:setFilter("linear","linear")
            else self.imageMissing=true end
        else self.imageMissing=true end
    end
    if not self.image then return 0 end
    local tw,th=self.image:getDimensions()
    local drawn=0
    for _,bullet in ipairs(self.trails) do
        local cmd=self:project(bullet,camera)
        if cmd and cmd.x>-200 and cmd.x<w+200 and
            cmd.y>-200 and cmd.y<h+200 then
            local red,green,blue=decodeColor(cmd.tint)
            g.setColor(red,green,blue,cmd.alpha)
            -- PIXI sprite anchor is (.5,.5); container pivot is (14.5,0).
            g.draw(self.image,cmd.x,cmd.y,cmd.rotation,
                cmd.scaleX,cmd.scaleY,tw/2+14.5,th/2)
            drawn=drawn+1
        end
    end
    g.setColor(1,1,1,1)
    return drawn
end
return Trails
