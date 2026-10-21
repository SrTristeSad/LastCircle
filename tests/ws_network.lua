-- Local loopback integration against Node fixture using ACTUAL Survev TypeScript.
-- Requires socket and server tests/ws_fixture_server.mjs on 127.0.0.1:19998.
local socket=require("socket")
local Client=require("src.survev.network_client")
local Input=require("src.survev.input_msg")
local Binds=require("src.survev.input_bindings")
local c=Client.new({timeout=2})
local ok,err=c:connect("ws://127.0.0.1:19998/relay?test=1",
    {name="Network Test",joinToken="fixture-token"})
assert(ok,err)
assert(c.state=="connected","connection should be open")
local state
local received=false
for i=1,140 do
    c:poll()
    state=c:getGameState()
    if state and state.joined and state.map and state.updateCount>=1 then
        received=true
        break
    end
    socket.sleep(.015)
end
assert(received,"did not decode Joined+Map+Update fragmented packet")
assert(state.localId==7 and state.activeId==7 and state.teamMode==1)
assert(state.map.mapName=="main" and state.map.seed==321)
assert(state.map.width==720 and state.map.height==640)
assert(math.abs(state.localData.health-80)<.3)
assert(c.packetCount>=1 and c.session.sentBytes>0)

local input=Input.new()
input:addInput(Binds.Input.Reload)
input.moveRight=true
input.toMouseDir={x=1,y=0}
local sent=c:sendInput(input,.016)
assert(sent and sent:byte(1)==3,"Survev InputMsg must be sent")
assert(c.session.seq==1 and c.session.seqInFlight)
local gotAck=false
for i=1,140 do
    c:poll()
    if state.lastAck==1 and not c.session.seqInFlight then
        gotAck=true
        break
    end
    socket.sleep(.015)
end
assert(gotAck,"original server UpdateMsg ack was not applied")
assert(c.session.ping and c.session.ping>=0)
assert(not c.error,"unexpected network error "..tostring(c.error))
c:close()
assert(c.state=="closed")
print("WebSocket network integration passed: upgrade, Join, fragmented Joined/Map/Update, PING/PONG, Input and ACK")
