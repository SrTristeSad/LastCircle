-- Full loopback chain: LuaSocket HTTP original API -> server-issued token
-- -> genuine RFC6455 WebSocket -> ORIGINAL Survev TS Joined, Map, Update
-- -> original Lua InputMsg -> server ACK. No mock client/player state.
local socket=require("socket")
local Match=require("src.survev.matchmaking")
local Client=require("src.survev.network_client")
local Input=require("src.survev.input_msg")
local game,reason=Match.request("http://127.0.0.1:17983",{
    region="na",gameModeIdx=0,zones={},timeout=2,
})
assert(game,reason)
assert(game.joinToken=="fixture-token")
local client=Client.new({timeout=2})
local ok,url=client:connectMatch(game,{name="Network Test"})
assert(ok,url)
assert(url=="ws://127.0.0.1:19998/relay?test=1")
local world
for i=1,140 do
    client:poll()
    world=client:getGameState()
    if world and world.joined and world.map and world.updateCount>=1 then
        break
    end
    socket.sleep(.015)
end
assert(world and world.joined and world.map and world.updateCount>=1,
    "No authentic Survev Joined/Map/Update after matchmaking")
assert(world.localId==7 and world.objects[7] and
    world.objects[7].outfit=="outfitBase")
assert(math.abs(world.objects[7].pos.x-120)<.06)
local input=Input.new()
input.moveRight=true
input.toMouseDir={x=1,y=0}
assert(client:sendInput(input,.016))
local received=false
for i=1,140 do
    client:poll()
    if world.lastAck==1 and math.abs(world.objects[7].pos.x-125)<.06 then
        received=true
        break
    end
    socket.sleep(.015)
end
assert(received and not client.session.seqInFlight)
assert(client.packetCount>0 and not client.error)
client:close()
print("Full Survev HTTP matchmaking -> WebSocket -> original TS messages -> Input ACK passed")
