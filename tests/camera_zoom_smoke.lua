-- Faithful camera scope zoom from pinned survev/client/src/game.ts and
-- player.ts. Server activePlayerData.zoom owns the field of view.
local Camera=require("src.survev.camera")
local World=require("src.survev.live_debug")
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Types=require("src.survev.object_serialize_fns").Type
local function near(x,expected,msg)
    assert(type(x)=="number" and math.abs(x-expected)<1e-7,
        (msg or "zoom").." "..tostring(x).." vs "..tostring(expected))
end
local camera=Camera.new()
camera.m_screenWidth=1280;camera.m_screenHeight=720
-- Original maxScreenDim=max(min*16/9,max)=1280, target=640/(50*16).
assert(camera:m_updateZoom(50,.1,false))
near(camera.m_targetZoom,.8)
near(camera.m_zoom,1.5*(1-.14)+.8*.14)
-- Zoom in is faster than zoom out (2/s instead of 1.4/s).
local old=camera.m_zoom
assert(camera:m_updateZoom(20,.1,false))
near(camera.m_targetZoom,2)
near(camera.m_zoom,old*.8+2*.2)
-- Scope change forces fast interpolation, regardless of direction.
old=camera.m_zoom
camera:m_updateZoom(80,.1,true)
near(camera.m_zoom,old*.7+.5*.3)
-- Portrait uses a virtual 16:9 width in the original.
camera.m_screenWidth=900;camera.m_screenHeight=900
camera.m_zoom=1
camera:m_updateZoom(50,.1,false)
near(camera.m_targetZoom,(900*16/9*.5)/(50*16))
local stable=camera.m_zoom
assert(not camera:m_updateZoom(nil,.1,true))
assert(not camera:m_updateZoom(0,.1,true))
near(camera.m_zoom,stable)
-- No artificially clamped lerp: matches math.lerp(t,a,b) from source.
camera.m_screenWidth=1280;camera.m_screenHeight=720
camera.m_zoom=1.5
camera:m_updateZoom(50,0,false)
near(camera.m_zoom,1.5)

local world=World.new()
world.camera.m_screenWidth=1280
world.camera.m_screenHeight=720
local state=State.new()
state:applyMessage(Net.MsgType.Joined,{teamMode=1,playerId=7,started=true})
state.map={mapName="main",width=720,height=640,seed=1}
state.objects[7]={
    __id=7,__type=Types.Player,pos={x=120,y=120},
    dir={x=1,y=0},scale=1,layer=0,dead=false,
}
state.localData.zoom=50
state.localData.scope="1xscope"
state.updateCount=1
world:update(state,.1)
near(world.camera.m_targetZoom,.8)
near(world.camera.m_zoom,1.402)
assert(not world.zoomFast)
-- Scope changes speed transition (source player.ts sets zoomFast).
state.localData.scope="2xscope"
world:update(state,.1)
assert(world.zoomFast)
near(world.camera.m_zoom,1.402*.7+.8*.3)
-- An authentic zoomDirty update resets fast unless scope also changes.
state.localData.zoom=60
world:update(state,.1)
assert(not world.zoomFast)
near(world.camera.m_targetZoom,640/(60*16))
local saved=world.camera.m_zoom
-- The local preview must NOT gain zoom/authority from a past match.
state.offlinePreview=true
state.localData.zoom=20
world:update(state,.1)
near(world.camera.m_zoom,saved)
-- New map/session cannot carry previous scope-fast transitions.
state.offlinePreview=false
state.map={mapName="main",seed=2,width=720,height=640}
world:update(state,.1)
assert(not world.zoomFast)
near(world.camera.m_targetZoom,2)
print("Original Survev server-authoritative scope camera zoom and fast transitions passed")
