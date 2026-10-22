-- Survev source parity for InputMsg controls (headless Lua / LuaJIT).
local Buffered=require("src.survev.live_input")
local Input=require("src.survev.input_msg")
local Binds=require("src.survev.input_bindings").Input
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")

local function nextInput(buffer)
    local packet=Input.new()
    buffer:drain(packet)
    return packet
end
local function roundTrip(message)
    local stream=Net.newMsgStream(128,Registry)
    stream:serializeMsg(Net.MsgType.Input,message)
    local result=Decoder.decode(stream:getBuffer(),Registry)
    assert(#result==1 and result[1].id==Net.MsgType.Input)
    return result[1].msg
end
local buffer=Buffered.new()
assert(buffer:keypressed("7"))
local item=roundTrip(nextInput(buffer))
assert(item.useItem=="bandage")
assert(#item.inputs==0,"consumables must not use Input enum commands")
assert(nextInput(buffer).useItem=="","consumable must be one-shot")

local testItems={["8"]="healthkit",["9"]="soda",["0"]="painkiller"}
for key,expected in pairs(testItems) do
    assert(buffer:keypressed(key))
    local msg=roundTrip(nextInput(buffer))
    assert(msg.useItem==expected and #msg.inputs==0)
end
-- Original game.ts checks multiple heal hotkeys in this priority order.
for _,key in ipairs({"0","9","8","7"}) do
    assert(buffer:keypressed(key))
end
assert(nextInput(buffer).useItem=="bandage")

assert(buffer:keypressed("f"))
assert(not buffer:queueAction(Binds.Interact),"duplicate interaction")
assert(buffer:keypressed("r"))
assert(buffer:keypressed("e"))
assert(buffer:keypressed("x"))
assert(buffer:wheelmoved(1))
assert(buffer:wheelmoved(-1))
local actions=roundTrip(nextInput(buffer))
assert(#actions.inputs==6 and actions.useItem=="")
local expected={Binds.Interact,Binds.Reload,Binds.StowWeapons,Binds.Cancel,
                Binds.EquipPrevWeap,Binds.EquipNextWeap}
for i=1,#expected do assert(actions.inputs[i]==expected[i]) end

for _,key in ipairs({"1","2","3","4","q","t","f"}) do
    assert(buffer:keypressed(key))
end
assert(#buffer.actions==7)
assert(not buffer:keypressed("invalid"))
assert(not buffer:queueAction(Binds.Reload),"seventh action capacity reached")
assert(not buffer:queueAction(255),"invalid enum")
assert(#roundTrip(nextInput(buffer)).inputs==7)
assert(#nextInput(buffer).inputs==0,"actions must not leak into next frame")
assert(buffer:keypressed("8"))
assert(buffer:wheelmoved(-1))
buffer:clear()
local cleared=nextInput(buffer)
assert(cleared.useItem=="" and #cleared.inputs==0)
print("Survev network hotkey/consumable parity passed")
