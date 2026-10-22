-- Survev client/src/objects/bullet.ts source-derived visual-only trail parity.
-- Game server sends all bullet events: client must not fabricate shots/hits.
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Source=require("src.survev.bullet_art")
local Trails=require("src.survev.bullet_trails")
local Camera=require("src.survev.camera")
local function near(actual,expected)
    assert(type(actual)=="number" and math.abs(actual-expected)<1e-8,
        "expected "..tostring(expected)..", got "..tostring(actual))
end
local count=0
for _,def in pairs(Source.defs) do
    assert(def.speed>0 and def.distance>0)
    assert(Source.colors[def.tracerColor],"missing original tracer palette")
    count=count+1
end
assert(count==63,"must ship ALL pinned Survev bullet definitions")
assert(Source.reflectDistDecay==1.5)
assert(Source.defs.bullet_ak47.speed==100)
assert(Source.defs.bullet_ak47.distance==200)
assert(Source.defs.bullet_ak47.tracerLength==.9)
assert(Source.defs.bullet_flare.addFlare)
assert(Source.defs.bullet_invis.tracerWidth==0)
assert(Source.colors["762mm"].regular==0xc5d6fe)
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{
    teamMode=1,playerId=4,started=true
})
local function bullet(kind,flags)
    local b={
        bulletType=kind or "bullet_ak47",
        playerId=4,layer=0,
        pos={x=320,y=330},dir={x=1,y=0},
        varianceT=0,distAdjIdx=8,reflectCount=0,
        speedMult=1,distanceMult=1,
        shotFx=false,
    }
    for k,v in pairs(flags or {}) do b[k]=v end
    return b
end
local trails=Trails.new()
state:applyUpdate({bullets={bullet()}})
trails:update(state,0)
assert(#trails.trails==1)
local a=trails.trails[1]
near(a.speed,100)
near(a.distance,200)
assert(a.color==0xc5d6fe)
assert(a.layer==0)
local cam=Camera.new()
cam.m_pos={x=320,y=330}
cam.m_screenWidth,cam.m_screenHeight=1280,720
assert(trails:project(a,cam)==nil,"the source bullet starts with zero tracer length")
trails:update(state,.1)
near(a.traveled,10)
near(a.pos.x,330)
near(a.pos.y,330)
local cmd=assert(trails:project(a,cam))
near(cmd.x,cam:m_pointToScreen({x=330,y=330}).x)
near(cmd.y,360)
near(cmd.rotation,0)
near(cmd.scaleX,cam:m_pixels(1)*5*.8)
near(cmd.scaleY,cam:m_pixels(1)*.1)
assert(cmd.asset=="player/player-bullet-trail-02.png")
trails:update(state,0)
assert(#trails.trails==1,"the same UpdateMsg must not spawn twice")

-- Clipped distance and reflection distance decay from upstream.
state:applyUpdate({bullets={
    bullet("bullet_m9",{reflectCount=1,distAdjIdx=8}),
    bullet("bullet_ak47",{clipDistance=true,distance=5,distAdjIdx=8}),
}})
trails:update(state,0)
assert(#trails.trails==3)
local reflected=trails.trails[2]
near(reflected.distance,100/1.5)
near(reflected.alpha,.5)
local clipped=trails.trails[3]
near(clipped.distance,5)
trails:update(state,.1)
near(clipped.traveled,5)
assert(clipped.collided)
trails:update(state,.1)
near(clipped.scale,.4)
trails:update(state,.1)
assert(#trails.trails==2,"finished original trail fades out")

-- Width variants, saturated and AP palette precedence.
state:applyUpdate({bullets={
    bullet("bullet_m9",{trailSmall=true,trailSaturated=true}),
    bullet("bullet_m9",{trailThick=true,apRounds=true,trailSaturated=true}),
}})
trails:update(state,0)
local small,thick=trails.trails[3],trails.trails[4]
near(small.width,.05)
near(thick.width,.2)
assert(small.color==Source.colors["9mm"].chambered)
assert(thick.color==Source.colors["9mm"].apSaturated)

-- Suppressed bullets fade by the source alphaRate each rendered update.
state:applyUpdate({bullets={bullet("bullet_grozas")}})
trails:update(state,0)
local quiet=trails.trails[#trails.trails]
assert(quiet.suppressed)
trails:update(state,.01)
near(quiet.alpha,.94)
local other=small.alpha
trails:update(state,.01)
near(small.alpha,other)
-- No fake flare or invisible tracer or unknown definitions.
local before=#trails.trails
state:applyUpdate({bullets={
    bullet("bullet_flare"),bullet("bullet_invis"),
    bullet("NEVER_DEFINED"),
}})
trails:update(state,0)
assert(#trails.trails==before)
-- Client render uses ORIGINAL SVG->PNG and PIXI source (14.5,0) pivot.
local loaded,painted,offset=0,0,nil
love={filesystem={getInfo=function(path)
    assert(path=="assets/survev/img/player/player-bullet-trail-02.png")
    return true
end},graphics={
    newImage=function(path)
        loaded=loaded+1
        local img={}
        function img:setFilter(a,b) assert(a=="linear" and b=="linear") end
        function img:getDimensions() return 32,16 end
        return img
    end,
    draw=function(_,x,y,rot,sx,sy,ox,oy)
        painted=painted+1
        offset={ox=ox,oy=oy}
        assert(type(sx)=="number" and sy>0 and sx>0)
    end,
    setColor=function() end,
}}
assert(trails:draw(cam,1280,720)>0 and painted>0)
assert(loaded==1)
near(offset.ox,30.5)
near(offset.oy,8)
trails:draw(cam,1280,720)
assert(loaded==1,"asset should be cached")
-- A large batch of consecutive socket messages should not lose bullets.
local batched=State.new()
batched:applyMessage(Net.MsgType.Joined,{
    teamMode=1,playerId=4,started=true
})
for i=1,3 do
    batched:applyUpdate({bullets={bullet("bullet_m9")}})
end
assert(batched.bulletSeq==3)
assert(#batched.bulletEvents==3)
local spriteSet=Trails.new()
spriteSet:update(batched,0)
assert(#spriteSet.trails==3)
spriteSet:update(batched,0)
assert(#spriteSet.trails==3)
for i=1,515 do batched:applyUpdate({bullets={bullet("bullet_m9")}}) end
assert(batched.bulletSeq==518 and #batched.bulletEvents==512)
assert(batched.bulletEvents[1].seq==7)
spriteSet:update(batched,0)
assert(#spriteSet.trails==512)
spriteSet:update(batched,0)
assert(#spriteSet.trails==512,"bounded replay prevents duplication")
batched:applyMessage(Net.MsgType.Joined,{
    teamMode=1,playerId=4,started=true
})
spriteSet:update(batched,0)
assert(#spriteSet.trails==0)
assert(batched.bulletSeq==0)
spriteSet:update(nil,0)
assert(spriteSet.world==nil)
print("Original Survev bullet definitions, tracer geometry and socket batch parity passed")
