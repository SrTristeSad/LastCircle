-- Visual-only port of Survev BulletBarn.playHitFx + ParticleBarn:
-- hitParticle & sound groups are extracted from pinned upstream definitions.
-- The client never emits a network hit or changes player health.
local Source=require("src.survev.hit_particle_art")
local SoundGroups=require("src.survev.hit_sound_art")
local Obstacles=require("src.survev.map_obstacle_art")
local Fx={}
Fx.__index=Fx

local function sample(r)
    if not r then return 0 end
    return r[1]+(r[2]-r[1])*math.random()
end
local function mix(a,b,t) return a+(b-a)*t end
local function remap(t,range,a,b)
    local x=math.max(0,math.min(1,
        (t-range[1])/math.max(.000001,range[2]-range[1])))
    return mix(a,b,x)
end
local function hsv(h,s,v)
    -- util.hsvToRgb (hue is cyclical); keep source HSV ranges.
    h=h%1
    local k=math.floor(h*6)
    local f=h*6-k
    local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    local r,g,b
    if k==0 then r,g,b=v,t,p
    elseif k==1 then r,g,b=q,v,p
    elseif k==2 then r,g,b=p,v,t
    elseif k==3 then r,g,b=p,q,v
    elseif k==4 then r,g,b=t,p,v
    else r,g,b=v,p,q end
    return r,g,b
end
local function color(def)
    if def.rgb then
        return math.floor(def.rgb/65536)%256/255,
            math.floor(def.rgb/256)%256/255,def.rgb%256/255
    end
    return hsv(sample(def.hsv[1]),sample(def.hsv[2]),
        sample(def.hsv[3]))
end
function Fx.new()
    return setmetatable({
        world=nil,sequence=0,particles={},soundEvents={},
        spriteCache={},missingSprites={},lastSound={},voices={},
        muted=false,
    },Fx)
end
function Fx:reset()
    self.world=nil
    self.sequence=0
    self.particles={}
    self.soundEvents={}
    self.lastSound={}
    self.voices={}
end
function Fx:emit(kind,pos,normal,layer)
    local def=Source[kind]
    if not def or not pos then return false end
    local r,g,b=color(def)
    local velocity=normal or {x=0,y=1}
    -- Survev bullet.ts playHitFx: one-or-two original sprite particles,
    -- velocity=9.5*normal rotated through +/- pi/6. Fixed one per hit here
    -- until ParticleBarn pooling / network prediction is fully ported.
    local angle=(math.random()-.5)*math.pi/3
    local cs,sn=math.cos(angle),math.sin(angle)
    local img=def.images[math.random(1,#def.images)]
    local rotVel=sample(def.rotVel)
    if math.random()<.5 then rotVel=-rotVel end
    self.particles[#self.particles+1]={
        kind=kind,image=img,
        pos={x=pos.x,y=pos.y},
        vel={x=(velocity.x*cs-velocity.y*sn)*9.5,
             y=(velocity.x*sn+velocity.y*cs)*9.5},
        layer=layer or 0,
        life=sample(def.life),age=0,
        drag=sample(def.drag),rotDrag=sample(def.drag)/2,
        rotVel=rotVel,rot=math.random()*2*math.pi,
        scaleStart=sample(def.scaleStart),
        scaleEnd=sample(def.scaleEnd),
        scaleLerp={sample(def.scaleLerp),sample(def.scaleLerp)},
        alphaStart=sample(def.alphaStart),
        alphaEnd=sample(def.alphaEnd),
        alphaLerp={sample(def.alphaLerp),sample(def.alphaLerp)},
        red=r,green=g,blue=b,
    }
    if #self.particles>256 then table.remove(self.particles,1) end
    return true
end
function Fx:queueSound(group,pos,layer)
    local options=SoundGroups[group]
    if not options or not pos then return false end
    self.soundEvents[#self.soundEvents+1]={
        group=group,pos={x=pos.x,y=pos.y},layer=layer or 0,
        path=options[math.random(1,#options)],
    }
    if #self.soundEvents>128 then table.remove(self.soundEvents,1) end
    return true
end
local function validImpact(state,bullet)
    local kind=bullet.impactKind
    if not (kind=="obstacle" or kind=="player" or kind=="pan") then
        return nil
    end
    local obj=state.objects[bullet.impactId]
    if not obj then return nil end
    if kind=="player" then
        local shooter=state.objects[bullet.playerId]
        if shooter and (shooter.dead or shooter.downed) then return nil end
        return "bloodSplat","player_bullet_hit",obj
    elseif kind=="pan" then
        return "barrelChip","pan_bullet",obj
    end
    local def=Obstacles[obj.type or ""]
    if not def then return nil end
    return def.hitParticle,def.bulletSound,obj
end
function Fx:advance(dt)
    for i=#self.particles,1,-1 do
        local p=self.particles[i]
        p.age=p.age+dt
        if p.age>=p.life then
            table.remove(self.particles,i)
        else
            p.vel.x=p.vel.x/(1+dt*p.drag)
            p.vel.y=p.vel.y/(1+dt*p.drag)
            p.pos.x=p.pos.x+p.vel.x*dt
            p.pos.y=p.pos.y+p.vel.y*dt
            p.rotVel=p.rotVel/(1+dt*p.rotDrag)
            p.rot=p.rot+p.rotVel*dt
        end
    end
end
-- Called once AFTER BulletTrails:update so newly stopped trails create
-- exactly one source-derived sprite + appropriate sound event.
function Fx:update(state,trails,dt)
    if not state or not state.joined or state.offlinePreview or
        state.gameOver or not state.objects or not trails then
        self:reset()
        return
    end
    if self.world~=state or (state.bulletSeq or 0)<self.sequence then
        self:reset()
        self.world=state
    end
    self.sequence=state.bulletSeq or 0
    self:advance(math.max(0,dt or 0))
    for _,bullet in ipairs(trails.trails or {}) do
        if bullet.collided and bullet.impactKind and
            not bullet.impactFxSent then
            bullet.impactFxSent=true
            local part,snd,obj=validImpact(state,bullet)
            if part and Source[part] then
                local dir=bullet.impactNormal or
                    {x=-(bullet.dir.x or 0),
                     y=-(bullet.dir.y or 0)}
                self:emit(part,bullet.pos,dir,bullet.layer)
            end
            if snd and snd~="none" then
                self:queueSound(snd,bullet.pos,bullet.layer)
            end
        end
    end
end
function Fx:draw(camera,w,h)
    if not love or not love.graphics or not love.filesystem then return 0 end
    local g=love.graphics
    local drawn=0
    for _,p in ipairs(self.particles) do
        local point=camera:m_pointToScreen(p.pos)
        if point.x>-80 and point.x<w+80 and
            point.y>-80 and point.y<h+80 then
            local img=self.spriteCache[p.image]
            if not img and not self.missingSprites[p.image] then
                local file="assets/survev/img/"..p.image
                if love.filesystem.getInfo(file) then
                    local ok,loaded=pcall(g.newImage,file)
                    if ok then
                        img=loaded
                        self.spriteCache[p.image]=img
                        img:setFilter("linear","linear")
                    end
                end
                if not img then self.missingSprites[p.image]=true end
            end
            if img then
                local def=Source[p.kind]
                local t=math.min(1,p.age/p.life)
                local scale=remap(t,p.scaleLerp,p.scaleStart,p.scaleEnd)
                local alpha=remap(t,p.alphaLerp,p.alphaStart,p.alphaEnd)
                local width,height=img:getDimensions()
                g.setColor(p.red,p.green,p.blue,alpha)
                g.draw(img,point.x,point.y,p.rot,
                    camera:m_pixels(scale),camera:m_pixels(scale),
                    width/2,height/2)
                drawn=drawn+1
            end
        end
    end
    g.setColor(1,1,1,1)
    return drawn
end
-- Audio files are upstream MP3s. If the installed LÖVE decoder does not
-- support the format, skip rather than play a substitute.
function Fx:playSounds(camera)
    local events=self.soundEvents
    self.soundEvents={}
    if self.muted or not love or not love.audio or
        not love.filesystem then return 0 end
    local played=0
    for _,event in ipairs(events) do
        local dx,dy=event.pos.x-camera.m_pos.x,
            event.pos.y-camera.m_pos.y
        local distance=math.sqrt(dx*dx+dy*dy)
        if distance<45 and
            (not self.lastSound[event.group] or
             self.lastSound[event.group]>=.04) then
            local path="assets/survev/"..event.path
            if love.filesystem.getInfo(path) then
                local ok,src=pcall(love.audio.newSource,path,"static")
                if ok and src then
                    src:setVolume(.32*math.max(0,1-distance/45))
                    src:play()
                    self.voices[#self.voices+1]=src
                    played=played+1
                    self.lastSound[event.group]=0
                end
            end
        end
    end
    -- Retain live sources to avoid premature audio-object collection.
    for i=#self.voices,1,-1 do
        if not self.voices[i]:isPlaying() then
            table.remove(self.voices,i)
        end
    end
    while #self.voices>24 do
        local older=table.remove(self.voices,1)
        older:stop()
    end
    return played
end
function Fx:tickSound(dt)
    for key,t in pairs(self.lastSound) do
        self.lastSound[key]=t+math.max(0,dt or 0)
    end
end
return Fx
