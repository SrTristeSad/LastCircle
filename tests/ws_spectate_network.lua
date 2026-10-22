-- Real RFC6455 socket with ORIGINAL Survev TS serializations: dead
-- player -> SpectateMsg Begin/Next/Prev -> authoritative UpdateMsg target.
-- Requires tests/ws_fixture_server.mjs on 127.0.0.1:19998.
local socket=require("socket")
local Client=require("src.survev.network_client")
local Spectate=require("src.survev.spectate_msg")
local client=Client.new({timeout=2})
local ok,why=client:connect("ws://127.0.0.1:19998/relay?test=1",
    {name="Spectator Test",joinToken="fixture-token"})
assert(ok,why)
local function untilUpdate(check)
    for _=1,160 do
        client:poll()
        local state=client:getGameState()
        if check(state) then return state end
        socket.sleep(.015)
    end
    error("Survev spectator server did not return the expected UpdateMsg")
end
local state=untilUpdate(function(s)
    return s and s.joined and s.map and s.updateCount>=1
end)
assert(state.localId==7 and state.activeId==7)
assert(state.objects[7] and state.objects[7].dead)
assert(state.objects[8] and not state.objects[8].dead)
assert(state.objects[9] and not state.objects[9].dead)
assert(not state.spectating)
-- Source server/client.ts denies control by the living player and chooses
-- the target asynchronously after receiving the SpectateMsg.
assert(client:sendSpectate(Spectate.Action.Begin))
assert(state.activeId==7 and not state.spectating)
untilUpdate(function(s)
    return s.activeId==8 and s.spectating
end)
assert(state.objects[8].pos.x>190)
local nextPacket=assert(client:sendSpectate(Spectate.Action.Next))
assert(nextPacket:byte(1)==11 and nextPacket:byte(2)==2)
assert(state.activeId==8)
untilUpdate(function(s) return s.activeId==9 end)
assert(state.spectating)
assert(client:sendSpectate(Spectate.Action.Prev))
assert(state.activeId==9)
untilUpdate(function(s) return s.activeId==8 end)
assert(not client.error,client.error)
client:close()
assert(client.state=="closed")
print("Real original Survev TS server spectator Begin/Next/Prev and UpdateMsg authority passed")
