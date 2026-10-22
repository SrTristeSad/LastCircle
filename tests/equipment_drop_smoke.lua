-- Survev client/src/game.ts DropItemMsg: weapon slots and equipped armour.
-- Requests are tested with real binary framing; inventory remains server-owned.
local Demo=require("src.survev.offline_demo")
local HUD=require("src.survev.hud")
local Network=require("src.survev.network_client")
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local Decoder=require("src.survev.packet_decoder")
local state=Demo.new():getGameState()
state.offlinePreview=nil
local sent={}
local client=Network.new()
client.connection={state="open"}
client.session={
    opened=true,state=state,
    sendMessage=function(_,kind,msg)
        local s=Net.newMsgStream(128,Registry)
        s:serializeMsg(kind,msg)
        local bytes=s:getBuffer()
        sent[#sent+1]=bytes
        return bytes
    end,
}
local function check(kind,item,slot)
    local bytes,err
    if kind=="weapon" then bytes,err=client:dropWeaponSlot(slot)
    elseif kind=="armor" then bytes,err=client:dropArmor(slot)
    end
    assert(bytes,err)
    local messages=Decoder.decode(bytes,Registry)
    assert(#messages==1 and messages[1].id==Net.MsgType.DropItem)
    assert(messages[1].msg.item==item)
    assert(messages[1].msg.weapIdx==(kind=="weapon" and slot or 0))
end
local primary=assert(HUD.hitTest(state,1280,720,945,425))
assert(primary.kind=="weapon" and primary.slot==0 and primary.item=="ak47")
local secondary=assert(HUD.hitTest(state,1280,720,1028,425))
assert(secondary.slot==1 and secondary.item=="m9")
assert(HUD.hitTest(state,1280,720,1106,425)==nil,"fists not droppable")
assert(HUD.hitTest(state,1280,720,1187,425)==nil,"empty throwable not droppable")
assert(HUD.hitTest(state,1280,720,940,360)==nil,"backpacks not droppable")
local helmet=assert(HUD.hitTest(state,1280,720,1050,360))
assert(helmet.kind=="armor" and helmet.field=="helmet"
    and helmet.item=="helmet02")
local chest=assert(HUD.hitTest(state,1280,720,1160,360))
assert(chest.kind=="armor" and chest.field=="chest"
    and chest.item=="chest02")
check("weapon","ak47",0)
check("weapon","m9",1)
check("armor","helmet02","helmet")
check("armor","chest02","chest")
assert(state.localData.weapons[1].type=="ak47")
assert(state.objects[1].helmet=="helmet02" and state.objects[1].chest=="chest02")
state.localData.weapons[3]={type="pan",ammo=0}
local melee=assert(HUD.hitTest(state,1280,720,1106,425))
assert(melee.slot==2 and melee.item=="pan")
check("weapon","pan",2)
assert(not client:dropWeaponSlot(3))
assert(not client:dropWeaponSlot(-1))
assert(not client:dropWeaponSlot(1.5))
assert(not client:dropArmor("backpack"))
state.localData.weapons[3]={type="fists",ammo=0}
assert(not client:dropWeaponSlot(2))
state.objects[1].helmet=""
assert(not client:dropArmor("helmet"))
state.objects[1].helmet="helmet02"
state.spectating=true
assert(not client:dropWeaponSlot(0))
assert(not client:dropArmor("chest"))
state.spectating=false
state.objects[1].downed=true
assert(not client:dropArmor("chest"))
state.objects[1].downed=false
state.offlinePreview=true
assert(HUD.hitTest(state,1280,720,945,425)==nil)
assert(not client:dropWeaponSlot(0))
state.offlinePreview=nil
client.connection.state="closed"
assert(not client:dropWeaponSlot(0))
client.connection.state="open"
state.gameOver={}
assert(not client:dropArmor("chest"))
assert(#sent==5,"only validated requests can emit a packet")
local hud=HUD.new()
hud:flash("Pedido enviado")
assert(hud.noticeTime==3)
hud:update(2)
assert(hud.noticeTime==1)
hud:update(2)
assert(hud.notice==nil)
print("Survev equipment DropItemMsg, HUD hit zones and server authority passed")
