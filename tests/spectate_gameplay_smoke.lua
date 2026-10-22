-- Ported from Survev game.ts spectators and shared/net/spectateMsg.ts.
-- Exact byte serialization and NO optimistic target change.
local Network=require("src.survev.network_client")
local Spectate=require("src.survev.spectate_msg")
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")
local Input=require("src.survev.input_msg")
local Session=require("src.survev.protocol_session")
local Results=require("src.survev.results_overlay")
local state={
    joined=true,localId=7,activeId=7,offlinePreview=false,
    spectating=false,objects={
        [7]={__id=7,dead=false,pos={x=10,y=20}},
        [8]={__id=8,dead=false,pos={x=20,y=20}},
    },
    gameOver=nil,
}
local out={}
local client=Network.new()
client.connection={state="open"}
client.session={
    opened=true,state=state,
    sendMessage=function(_,kind,msg)
        assert(kind==Net.MsgType.Spectate)
        local stream=Net.newMsgStream(128,Registry)
        stream:serializeMsg(kind,msg)
        local bytes=stream:getBuffer()
        out[#out+1]=bytes
        return bytes
    end
}
assert(not client:sendSpectate(Spectate.Action.Begin))
assert(#out==0,"Cannot spectate while own character lives")
state.objects[7].dead=true
local packet=assert(client:sendSpectate(Spectate.Action.Begin))
assert(packet:byte(1)==Net.MsgType.Spectate)
assert(packet:byte(2)==Spectate.Action.Begin)
assert(#packet==2,"Survev SpectateMsg is one msg id and one action byte")
local decoded=Decoder.decode(packet,Registry)
assert(#decoded==1 and decoded[1].msg.action==Spectate.Action.Begin)
assert(state.activeId==7 and not state.spectating,
    "Only the actual server UpdateMsg may change target")
assert(not client:sendSpectate(Spectate.Action.Next))
assert(#out==1)
state.activeId=8
state.spectating=true
for _,action in ipairs({Spectate.Action.Next,Spectate.Action.Prev}) do
    local buf=assert(client:sendSpectate(action))
    assert(#buf==2 and buf:byte(2)==action)
    assert(state.activeId==8)
end
assert(#out==3)
assert(not client:sendSpectate(Spectate.Action.None))
assert(not client:sendSpectate(255))
assert(#out==3)

-- A "GameOver" message is emitted for individual deaths with gameOver=false.
-- It is not the end of the entire match and must permit spectating.
state.gameOver={gameOver=false,playerStats={},teamRank=4}
local projection=assert(Results.project(state))
assert(not projection.finished)
assert(client:sendSpectate(Spectate.Action.Next))
state.gameOver.gameOver=true
assert(Results.project(state).finished)
assert(not client:sendSpectate(Spectate.Action.Next))
state.gameOver=nil
state.offlinePreview=true
assert(not client:sendSpectate(Spectate.Action.Next))
state.offlinePreview=false
client.connection.state="closed"
assert(not client:sendSpectate(Spectate.Action.Next))
client.connection.state="open"
client.session.opened=false
assert(not client:sendSpectate(Spectate.Action.Next))
client.session.opened=true
state.joined=false
assert(not client:sendSpectate(Spectate.Action.Next))
state.joined=true

-- The original input packet is zeroed as soon as spectating starts.
-- The transport sends the neutral packet to release a held fire/movement
-- and avoids controlling the observed player's body.
local fakeTransport={sent={}}
function fakeTransport:send(bytes) self.sent[#self.sent+1]=bytes end
local now=5
local session=Session.new(fakeTransport,{
    clock=function() return now end,
})
session.opened=true
session.state.joined=true
local held=Input.new()
held.moveRight=true;held.shootHold=true
held.shootStart=true
held.toMouseDir={x=1,y=0}
local first=assert(session:sendInput(held,.016))
local stop=Input.new()
local second=assert(session:sendInput(stop,.016))
local msgs=Decoder.decode(second,Registry)
assert(msgs[1].id==Net.MsgType.Input)
assert(msgs[1].msg.moveRight==false and msgs[1].msg.shootHold==false)
assert(msgs[1].msg.shootStart==false and #msgs[1].msg.inputs==0)
assert(not session:sendInput(Input.new(),.016),
    "Unchanged neutral inputs should be throttled")
print("Survev original spectate Begin/Next/Prev, spectator authority and input-release passed")
