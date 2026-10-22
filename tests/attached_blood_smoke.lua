-- Pinned original Survev bullet.ts bloodSplat is parented to player.container,
-- with local offset: (impact-player position)*camera.m_ppu, world Y inverted.
local Fx=require("src.survev.impact_fx")
local Camera=require("src.survev.camera")
local Type=require("src.survev.object_serialize_fns").Type
local function near(a,b)
    assert(type(a)=="number" and math.abs(a-b)<1e-6,
        tostring(a).." != "..tostring(b))
end
local actor={
    __id=2,__type=Type.Player,pos={x=50,y=30},
    dir={x=1,y=0},scale=1,layer=0,dead=false,
}
local shooter={__id=1,__type=Type.Player,
    pos={x=57,y=32},dead=false}
local state={joined=true,offlinePreview=false,gameOver=nil,
    bulletSeq=1,objects={[1]=shooter,[2]=actor}}
local hit={
    collided=true,impactKind="player",impactId=2,
    pos={x=51,y=30.5},dir={x=-1,y=0},
    layer=0,playerId=1,
}
local fx=Fx.new()
math.randomseed(11)
fx:update(state,{trails={hit}},0)
assert(#fx.particles==1)
local blood=fx.particles[1]
assert(blood.kind=="bloodSplat" and blood.parentId==2)
near(blood.localPx.x,16)
near(blood.localPx.y,-8)
near(blood.pos.x,51)
near(blood.pos.y,30.5)
local camera=Camera.new()
camera.m_pos={x=50,y=30}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local first=assert(fx:project(blood,camera,state.objects))
local center=camera:m_pointToScreen(actor.pos)
near(first.x,center.x+camera:m_pixels(16))
near(first.y,center.y-camera:m_pixels(8))
local initialPos=blood.pos
fx:update(state,{trails={hit}},.12)
near(blood.localPx.x,16)
near(blood.pos.x,initialPos.x)
assert(#fx.particles==1 and blood.age==.12)
assert(#fx.soundEvents==1 and hit.impactFxSent)
-- Moving the server-authoritative actor also moves the child's sprite.
actor.pos={x=52,y=31}
local second=assert(fx:project(blood,camera,state.objects))
near(second.x-first.x,2*camera:m_z())
near(second.y-first.y,-camera:m_z())
camera.m_zoom=2.5
local zoomed=assert(fx:project(blood,camera,state.objects))
near(zoomed.x-camera:m_pointToScreen(actor.pos).x,
    camera:m_pixels(16))
near(zoomed.y-camera:m_pointToScreen(actor.pos).y,
    -camera:m_pixels(8))

local calls={draw={},new=0}
love={filesystem={getInfo=function(path)
    return path:match("^assets/survev/img/particles/part%-splat%-%d+%.png$")
end},graphics={
    newImage=function(path)
        calls.new=calls.new+1
        local img={path=path}
        function img:setFilter() end
        function img:getDimensions() return 32,32 end
        return img
    end,
    setColor=function() end,
    draw=function(_,x,y,angle,sx,sy,ox,oy)
        calls.draw[#calls.draw+1]={x=x,y=y,sx=sx,sy=sy}
        near(ox,16);near(oy,16)
    end,
}}
assert(fx:draw(camera,1280,720)==0,
    "attached blood must NOT be drawn in world BulletBarn pass")
assert(#calls.draw==0)
assert(fx:drawAttached(actor,camera,1280,720,state.objects)==1)
near(calls.draw[1].x,zoomed.x)
near(calls.draw[1].y,zoomed.y)
assert(fx:drawAttached(actor,camera,1280,720,state.objects)==1)
assert(calls.new==1,"cache the pinned original blood PNG")
assert(fx:drawAttached({__id=1},camera,1280,720,state.objects)==0)
-- The target disappearing from UpdateMsg destroys the parented sprite.
state.objects[2]=nil
fx:update(state,{trails={}},0)
assert(#fx.particles==0)
assert(fx:drawAttached(actor,camera,1280,720,state.objects)==0)
-- Dead actors must not retain their blood-splat children.
actor.dead=false
state.objects[2]=actor
state.bulletSeq=2
local another={
    collided=true,impactKind="player",impactId=2,
    pos={x=52,y=31},dir={x=1,y=0},layer=0,playerId=1,
}
fx:update(state,{trails={another}},0)
assert(#fx.particles==1)
actor.dead=true
fx:update(state,{trails={}},0)
assert(#fx.particles==0)
actor.dead=false
-- Source privacy/graphics option: suppress splat but keep hit audio.
local privacy=Fx.new()
privacy.bloodEnabled=false
local privateHit={
    collided=true,impactKind="player",impactId=2,
    pos={x=52,y=31},dir={x=1,y=0},layer=0,playerId=1,
}
privacy:update(state,{trails={privateHit}},0)
assert(#privacy.particles==0)
assert(#privacy.soundEvents==1)
assert(privacy.soundEvents[1].group=="player_bullet_hit")
state.offlinePreview=true
privacy:update(state,{trails={}},.1)
assert(#privacy.particles==0 and #privacy.soundEvents==0)
print("Survev blood parent-local coordinates, player motion, draw layer and cleanup passed")
