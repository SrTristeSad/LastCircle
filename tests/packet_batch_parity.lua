-- Parity with real Survev TypeScript MsgStream when multiple messages share a frame.
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")
local Joined=require("src.survev.joined_msg")
local Counts=require("src.survev.alive_counts_msg")
local Pickup=require("src.survev.pickup_msg")
local Kill=require("src.survev.kill_msg")
local Emote=require("src.survev.emote_msg")
local Drop=require("src.survev.drop_item_msg")
local Spectate=require("src.survev.spectate_msg")
local function hex(binary)
    return (binary:gsub(".",function(c) return string.format("%02x",c:byte()) end))
end
local msgs=Net.newMsgStream(1024,Registry)
local t=Net.MsgType

local a=Joined.new()
a.teamMode=2
a.playerId=481
a.started=true
a.emotes={"emote_happyface"}
msgs:serializeMsg(t.Joined,a)

local b=Counts.new()
b.teamAliveCounts={10,7}
msgs:serializeMsg(t.AliveCounts,b)

local p=Pickup.new()
p.type=4
p.item="bandage"
p.count=2
msgs:serializeMsg(t.Pickup,p)

local k=Kill.new()
k.damageType=0
k.itemSourceType="bandage"
k.mapSourceType=""
k.targetId=5
k.killerId=22
k.killCreditId=22
k.killerKills=2
k.killed=true
k.downed=false
msgs:serializeMsg(t.Kill,k)

local em=Emote.new()
em.pos={x=100,y=200}
em.type="emote_happyface"
em.isPing=true
msgs:serializeMsg(t.Emote,em)

local drop=Drop.new()
drop.item="bandage"
drop.weapIdx=1
msgs:serializeMsg(t.DropItem,drop)

local spec=Spectate.new()
spec.action=2
msgs:serializeMsg(t.Spectate,spec)

local actual=hex(msgs:getBuffer())
assert(actual==arg[1],"Survev batched packet differs:\noriginal="..tostring(arg[1])..
    "\nLua="..actual)

local decoded=Decoder.decode(msgs:getBuffer())
assert(#decoded==7,"unexpected message count")
assert(decoded[1].id==t.Joined and decoded[1].msg.playerId==481)
assert(decoded[1].msg.emotes[1]=="emote_happyface")
assert(decoded[2].id==t.AliveCounts and decoded[2].msg.teamAliveCounts[2]==7)
assert(decoded[3].id==t.Pickup and decoded[3].msg.item=="bandage")
assert(decoded[4].id==t.Kill and decoded[4].msg.killed==true)
assert(decoded[5].id==t.Emote and decoded[5].msg.type=="emote_happyface")
assert(decoded[6].id==t.DropItem and decoded[6].msg.weapIdx==1)
assert(decoded[7].id==t.Spectate and decoded[7].msg.action==2)

local unknown=pcall(function() Decoder.decode(string.char(Net.MsgType.Update,0,0)) end)
assert(not unknown,"must not silently skip unsupported UpdateMsg")
print("Upstream multi-message wire packet equals Lua, and all 7 messages decoded")
