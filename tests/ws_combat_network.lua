-- Real client->server gameplay flow. The server runs the pinned original
-- TS InputMsg/DropItemMsg decoders and produces original UpdateMsg deltas.
-- No fake inventory mutation or client-authoritative damage.
local socket=require("socket")
local Client=require("src.survev.network_client")
local Input=require("src.survev.input_msg")
local Buffer=require("src.survev.live_input")
local Actions=require("src.survev.input_bindings").Input

local client=Client.new({timeout=2})
local connected,why=client:connect("ws://127.0.0.1:19998/relay?test=1",{
    name="Combat Test",joinToken="fixture-token",
})
assert(connected,why)

local function pollUntil(predicate,reason)
    for i=1,160 do
        client:poll()
        local state=client:getGameState()
        if state and predicate(state) then return state end
        socket.sleep(.015)
    end
    error(reason or "original TS response not received")
end
local state=pollUntil(function(s)
    return s.joined and s.map and s.updateCount>=1
        and s.localData.inventory
end,"original Joined/Map/Update with bag inventory missing")
assert(state.localId==7 and state.objects[7].pos.x>119)
assert(state.localData.inventory.bandage==2)
assert(state.localData.inventory["9mm"]==15)
assert(math.abs(state.localData.health-80)<.6)
assert(state.localData.zoom==50,"original TS zoomDirty must reach Lua camera")

local buffered=Buffer.new()
local function sendAndAck(msg,step)
    local before=state.updateCount
    local pos=state.objects[7].pos.x
    local prevHealth=state.localData.health
    local bytes=assert(client:sendInput(msg,.016),"InputMsg not serialized")
    assert(bytes:byte(1)==3 and client.session.seqInFlight)
    -- Client must NOT advance world positions, health, ammunition or loot
    -- before it has received the authoritative TS UpdateMsg.
    assert(state.objects[7].pos.x==pos)
    assert(state.localData.health==prevHealth)
    pollUntil(function(s)
        return s.updateCount>before and not client.session.seqInFlight
    end,"missing original UpdateMsg ack")
    assert(math.abs(state.objects[7].pos.x-(120+step*3))<.08,
        "server-authoritative position did not arrive")
    assert(not client.error,tostring(client.error))
end
-- First fire is shootStart + shootHold, not an Input.Fire enum action.
local fire=Input.new()
fire.moveRight=true
fire.shootStart=true
fire.shootHold=true
fire.toMouseDir={x=1,y=0}
fire.toMouseLen=23
sendAndAck(fire,1)
-- Holding the trigger is not repeatedly a new click.
local hold=Input.new()
hold.moveRight=true
hold.shootHold=true
hold.toMouseDir={x=1,y=0}
hold.toMouseLen=23
sendAndAck(hold,2)
-- Releasing trigger and using F is encoded as Input.Interact.
local interact=Input.new()
assert(buffered:keypressed("f"))
buffered:drain(interact)
assert(#interact.inputs==1 and interact.inputs[1]==Actions.Interact)
sendAndAck(interact,3)
-- Reload R is an Input.Reload enum, not a local ammunition refill.
local reload=Input.new()
assert(buffered:keypressed("r"))
buffered:drain(reload)
sendAndAck(reload,4)
-- Using bandage 7 is a game type string, not Input.UseBandage enum.
local heal=Input.new()
assert(buffered:keypressed("7"))
buffered:drain(heal)
assert(heal.useItem=="bandage" and #heal.inputs==0)
sendAndAck(heal,5)
assert(math.abs(state.localData.health-90)<.6)
assert(state.localData.inventory.bandage==1)
assert(state.localData.inventory["9mm"]==15)
-- Weapon switching 2 is EquipSecondary, and useItem is one-shot.
local equip=Input.new()
assert(buffered:keypressed("2"))
buffered:drain(equip)
assert(equip.useItem=="" and equip.inputs[1]==Actions.EquipSecondary)
sendAndAck(equip,6)
-- Drop uses a DIFFERENT original packet type, does not mutate the bag
-- until the server delivers a new inventoryDirty update.
local before=state.updateCount
local drop=assert(client:dropInventoryItem("9mm"))
assert(drop:byte(1)==12)
assert(state.localData.inventory["9mm"]==15)
pollUntil(function(s)
    return s.updateCount>before and s.localData.inventory["9mm"]==0
end,"server-controlled inventory drop not confirmed")
assert(state.localData.inventory.bandage==1)
assert(math.abs(state.localData.health-90)<.6)
assert(not client.error,tostring(client.error))
client:close()
assert(client.state=="closed")
print("Real TS Survev WebSocket combat inputs, interact, reload, heal, weapon selection and drop ACK passed")
