-- Original Survev BulletBarn impact sources -> particle sprites and MP3 groups.
-- No local hit packet, fake damage, or duplicate particle on subsequent frames.
local Fx=require("src.survev.impact_fx")
local ParticleArt=require("src.survev.hit_particle_art")
local SoundArt=require("src.survev.hit_sound_art")
local Obstacles=require("src.survev.map_obstacle_art")
local Camera=require("src.survev.camera")
local Type=require("src.survev.object_serialize_fns").Type
local function near(x,y)
    assert(type(x)=="number" and math.abs(x-y)<1e-6,
        "expected "..tostring(y).." got "..tostring(x))
end
local names=0
for _,def in pairs(ParticleArt) do
    names=names+1
    assert(def.images[1] and def.life[1]>0 and def.scaleStart[1]>0)
    assert(def.alphaLerp and def.drag and (def.rgb or def.hsv))
end
assert(names==34,"all 33 original obstacle hit particles plus bloodSplat")
assert(#ParticleArt.bloodSplat.images==3)
assert(ParticleArt.barrelChip.images[1]=="particles/part-spark-02.png")
assert(ParticleArt.woodChip.images[1]=="particles/part-woodchip-01.png")
assert(ParticleArt.bloodSplat.life[1]==.5)
assert(SoundArt.pan_bullet[1]=="audio/hits/pan_bullet_hit_01.mp3")
assert(SoundArt.player_bullet_hit[1]=="audio/hits/player_bullet_hit_01.mp3")
local obs=assert(Obstacles.house_door_02)
assert(obs.hitParticle=="barrelChip" and obs.bulletSound=="wall_bullet")
assert(SoundArt[obs.bulletSound],"obstacle impact group not resolved")
local state={
    joined=true,offlinePreview=false,objects={
        [1]={__type=Type.Player,__id=1,dead=false},
        [2]={__type=Type.Player,__id=2,dead=false},
        [3]={__type=Type.Obstacle,__id=3,type="house_door_02"},
    },bulletSeq=1,gameOver=nil,
}
local bullet={
    collided=true,impactKind="obstacle",impactId=3,
    pos={x=100,y=200},dir={x=1,y=0},layer=0,
    playerId=1,
}
local trails={trails={bullet}}
math.randomseed(777)
local fx=Fx.new()
fx:update(state,trails,0)
assert(#fx.particles==1)
assert(fx.particles[1].kind=="barrelChip")
assert(#fx.soundEvents==1)
assert(fx.soundEvents[1].group=="wall_bullet")
assert(fx.soundEvents[1].path=="audio/hits/metal_bullet_hit_01.mp3")
assert(bullet.impactFxSent)
fx:update(state,trails,.02)
assert(#fx.particles==1 and #fx.soundEvents==1)
local p=fx.particles[1]
assert(p.pos.x<100,"hit particles move back along impact normal")
assert(p.age==.02 and p.vel.x<0)
assert(p.red>=0 and p.red<=1 and p.green>=0 and p.green<=1)

-- Collision with player is blood, unless the shooter is dead.
local person={collided=true,impactKind="player",impactId=2,
    pos={x=10,y=20},dir={x=0,y=1},layer=0,playerId=1}
trails.trails={person}
fx:update(state,trails,0)
assert(#fx.particles==2 and fx.particles[2].kind=="bloodSplat")
assert(fx.soundEvents[2].group=="player_bullet_hit")
fx:update(state,trails,0)
assert(#fx.particles==2 and #fx.soundEvents==2)
state.objects[1].dead=true
local noBlood={collided=true,impactKind="player",impactId=2,
    pos={x=10,y=20},dir={x=0,y=1},layer=0,playerId=1}
trails.trails={noBlood}
fx:update(state,trails,0)
assert(noBlood.impactFxSent)
assert(#fx.particles==2 and #fx.soundEvents==2)
state.objects[1].dead=false

local pan={collided=true,impactKind="pan",impactId=2,
    pos={x=13,y=17},dir={x=1,y=0},layer=0,playerId=1}
trails.trails={pan}
fx:update(state,trails,0)
assert(fx.particles[3].kind=="barrelChip")
assert(fx.soundEvents[3].group=="pan_bullet")
assert(fx.soundEvents[3].path=="audio/hits/pan_bullet_hit_01.mp3")
local fake={collided=true,impactKind="made_up",impactId=2,
    pos={x=10,y=20},dir={x=1,y=0},layer=0,playerId=1}
trails.trails={fake}
fx:update(state,trails,0)
assert(#fx.particles==3)
assert(#fx.soundEvents==3)
-- Missing object is not a guess at an impact sprite.
local removed={collided=true,impactKind="obstacle",impactId=800,
    pos={x=0,y=0},dir={x=0,y=1},playerId=1}
trails.trails={removed}
fx:update(state,trails,0)
assert(#fx.particles==3)
-- All source lifetimes are bounded.
fx:update(state,{trails={}},1.6)
assert(#fx.particles==0 and #fx.soundEvents==3)

-- Draw original PNGs; no placeholder colored circle.
local calls={new=0,draw=0,play=0,stop=0}
love={filesystem={
    getInfo=function(path)
        return path:match("^assets/survev/img/particles/") or
            path:match("^assets/survev/audio/hits/")
    end,
},graphics={
    newImage=function(path)
        assert(path:match("^assets/survev/img/particles/"))
        calls.new=calls.new+1
        local img={path=path}
        function img:setFilter(a,b) assert(a=="linear" and b=="linear") end
        function img:getDimensions() return 32,32 end
        return img
    end,
    setColor=function() end,
    draw=function(img,x,y,angle,sx,sy,ox,oy)
        assert(img.path and sx>0 and sy>0)
        near(ox,16);near(oy,16)
        calls.draw=calls.draw+1
    end,
},audio={
    newSource=function(path,kind)
        assert(path:match("^assets/survev/audio/hits/") and kind=="static")
        local voice={volume=0,playing=false}
        function voice:setVolume(value)
            assert(value>=0 and value<=1)
            self.volume=value
        end
        function voice:play() calls.play=calls.play+1;self.playing=true end
        function voice:stop() calls.stop=calls.stop+1;self.playing=false end
        function voice:isPlaying() return self.playing end
        return voice
    end,
}}
local camera=Camera.new()
camera.m_pos={x=100,y=200}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local visual=Fx.new()
assert(visual:emit("barrelChip",{x=100,y=200},{x=1,y=0},0))
assert(visual:draw(camera,1280,720)==1 and calls.draw==1)
visual:draw(camera,1280,720)
assert(calls.new==1,"impact sprite reused from cache")
assert(visual:queueSound("pan_bullet",{x=100,y=200},0))
assert(visual:playSounds(camera)==1 and calls.play==1)
assert(#visual.soundEvents==0)
-- No spam while group cooldown has not expired.
assert(visual:queueSound("pan_bullet",{x=100,y=200},0))
assert(visual:playSounds(camera)==0)
visual:tickSound(.05)
assert(visual:queueSound("pan_bullet",{x=100,y=200},0))
assert(visual:playSounds(camera)==1)
visual.muted=true
assert(visual:queueSound("pan_bullet",{x=100,y=200},0))
assert(visual:playSounds(camera)==0 and #visual.soundEvents==0)
visual.muted=false
assert(visual:queueSound("pan_bullet",{x=200,y=200},0))
assert(visual:playSounds(camera)==0,"no sound from distant combat")
-- Reset on a new map/game must drop all previous transient FX.
visual:update(state,{trails={}},0)
state.bulletSeq=0
visual:update(state,{trails={}},0)
assert(#visual.particles==0 and #visual.soundEvents==0)
state.offlinePreview=true
visual:update(state,{trails={}},0)
assert(#visual.particles==0 and #visual.soundEvents==0)
print("Survev source impact particles and original MP3 sound groups passed")
