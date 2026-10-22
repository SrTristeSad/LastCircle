-- Drop requests use the ORIGINAL DropItemMsg wire schema.
-- No optimistic bag mutation: only an actual UpdateMsg can change counts.
local Client=require("src.survev.network_client")
local Demo=require("src.survev.offline_demo")
local Inventory=require("src.survev.inventory_panel")
local Loot=require("src.survev.loot_art")
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")

local state=Demo.new():getGameState()
state.offlinePreview=nil -- Exercise the network gate with known test data.
local sent={}
local client=Client.new()
client.connection={state="open"}
client.session={
    opened=true,state=state,
    sendMessage=function(_,kind,msg)
        assert(kind==Net.MsgType.DropItem)
        local stream=Net.newMsgStream(128,Registry)
        stream:serializeMsg(kind,msg)
        local bytes=stream:getBuffer()
        sent[#sent+1]=bytes
        return bytes
    end,
}
local before=state.localData.inventory["9mm"]
assert(before>0)
local bytes=assert(client:dropInventoryItem("9mm"))
assert(type(bytes)=="string" and #sent==1)
local decoded=Decoder.decode(bytes,Registry)
assert(#decoded==1 and decoded[1].id==Net.MsgType.DropItem)
assert(decoded[1].msg.item=="9mm" and decoded[1].msg.weapIdx==0)
assert(state.localData.inventory["9mm"]==before,
    "DropItemMsg must not mutate inventory optimistically")
assert(not client:dropInventoryItem("invalid_type"))
assert(#sent==1)
state.localData.inventory["9mm"]=0
assert(not client:dropInventoryItem("9mm"))
assert(#sent==1)
state.localData.inventory["9mm"]=nil
assert(not client:dropInventoryItem("9mm"))
assert(#sent==1)
state.localData.inventory["9mm"]=before

state.spectating=true
assert(not client:dropInventoryItem("9mm"))
state.spectating=false
state.offlinePreview=true
assert(not client:dropInventoryItem("9mm"))
state.offlinePreview=nil
state.objects[state.activeId].dead=true
assert(not client:dropInventoryItem("9mm"))
state.objects[state.activeId].dead=false
state.gameOver={}
assert(not client:dropInventoryItem("9mm"))
state.gameOver=nil
client.connection.state="closed"
assert(not client:dropInventoryItem("9mm"))
client.connection.state="open"

local panel=Inventory.new()
local firstType=Loot.bagKeys[1]
assert(not panel:hitTest(state,1280,720,315,180))
panel:toggle()
-- x=(1280-680)/2=300; y=(720-570)/2=75; row 1 begins 310,175
local row=assert(panel:hitTest(state,1280,720,315,180))
assert(row.type==firstType)
assert(panel:hitTest(state,1280,720,20,20)==nil)
panel:flash("Solicitacao enviada (sem confirmacao)")
assert(panel.noticeTime==3)
panel:update(1.5)
assert(panel.noticeTime>0)
panel:update(2)
assert(panel.notice==nil and panel.noticeTime==0)
panel:toggle()
assert(not panel:hitTest(state,1280,720,315,180))
print("Survev inventory DropItemMsg, hit testing and no optimistic mutations passed")
