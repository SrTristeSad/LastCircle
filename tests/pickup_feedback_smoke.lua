-- Original PickupMsg errors, one-shot server event and no optimistic pickup.
local State=require("src.survev.client_state")
local Net=require("src.survev.net")
local Feedback=require("src.survev.pickup_feedback")
local P=Net.PickupMsgType
local state=State.new()
local panel=Feedback.new()
panel:update(state,0)
assert(panel.remaining==0 and state.pickupSeq==0)
local warnings={
    {P.Full,"Sem espaco"},
    {P.AlreadyOwned,"possui"},
    {P.AlreadyEquipped,"equipado"},
    {P.BetterItemEquipped,"melhor"},
    {P.GunCannotFire,"disparar"},
    {P.MaxPerks,"vantagens"},
}
for i,data in ipairs(warnings) do
    state:applyMessage(Net.MsgType.Pickup,{
        type=data[1],item="bandage",count=2,
    })
    assert(state.pickupSeq==i and state.lastPickup.count==2)
    panel:update(state,0)
    assert(panel.remaining==3 and panel.message:find(data[2],1,true))
    assert(state.localData.inventory==nil,
        "PickupMsg must never alter authoritative inventory")
end
panel:update(state,3.1)
assert(panel.remaining==0)
state:applyMessage(Net.MsgType.Pickup,{
    type=P.Success,item="bandage",count=2,
})
panel:update(state,0)
assert(panel.message==nil and panel.remaining==0,
    "original game does not show a toast on successful pickup")
assert(state.localData.inventory==nil)
state:reset()
panel:update(state,0)
assert(panel.message==nil and panel.remaining==0)
assert(state.pickupSeq==0 and state.lastPickup==nil)
assert(Feedback.project({type=254})==nil)
print("PickupMsg authoritative failure feedback passed")
