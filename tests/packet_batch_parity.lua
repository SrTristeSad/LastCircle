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
local Stats=require("src.survev.player_stats_msg")
local GameOver=require("src.survev.game_over_msg")
local Role=require("src.survev.role_announcement_msg")
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

local stats=Stats.new()
stats.playerStats={playerId=481,timeAlive=87,kills=3,dead=true,damageDealt=149.6,damageTaken=51.4}
msgs:serializeMsg(t.PlayerStats,stats)

local gameOver=GameOver.new()
gameOver.teamId=4
gameOver.teamRank=2
gameOver.gameOver=true
gameOver.winningTeamId=3
gameOver.playerStats={stats.playerStats}
msgs:serializeMsg(t.GameOver,gameOver)

local role=Role.new()
role.playerId=481
role.killerId=222
role.role=""
role.assigned=true
role.killed=false
msgs:serializeMsg(t.RoleAnnouncement,role)

local actual=hex(msgs:getBuffer())
assert(actual==arg[1],"Survev batched packet differs:\noriginal="..tostring(arg[1])..
    "\nLua="..actual)

local decoded=Decoder.decode(msgs:getBuffer())
assert(#decoded==10,"unexpected message count")
assert(decoded[1].id==t.Joined and decoded[1].msg.playerId==481)
assert(decoded[1].msg.emotes[1]=="emote_happyface")
assert(decoded[2].id==t.AliveCounts and decoded[2].msg.teamAliveCounts[2]==7)
assert(decoded[3].id==t.Pickup and decoded[3].msg.item=="bandage")
assert(decoded[4].id==t.Kill and decoded[4].msg.killed==true)
assert(decoded[5].id==t.Emote and decoded[5].msg.type=="emote_happyface")
assert(decoded[6].id==t.DropItem and decoded[6].msg.weapIdx==1)
assert(decoded[7].id==t.Spectate and decoded[7].msg.action==2)
assert(decoded[8].id==t.PlayerStats and decoded[8].msg.playerStats.playerId==481)
assert(decoded[8].msg.playerStats.damageDealt==150)
assert(decoded[8].msg.playerStats.damageTaken==51)
assert(decoded[9].id==t.GameOver and decoded[9].msg.gameOver)
assert(decoded[9].msg.playerStats[1].playerId==481)
assert(decoded[10].id==t.RoleAnnouncement and decoded[10].msg.assigned)
assert(decoded[10].msg.playerId==481)

local unknown=pcall(function() Decoder.decode(string.char(Net.MsgType.Update,0,0)) end)
assert(not unknown,"must not silently skip unsupported UpdateMsg")
print("Upstream multi-message wire packet equals Lua, and all 10 messages decoded")
