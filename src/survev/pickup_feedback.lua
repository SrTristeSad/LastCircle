-- Survev client/src/game.ts PickupMsg -> ui2.ts displayPickupMessage.
-- The original displays a 3-second warning for failed pickups.
-- Success is signalled by the server's inventory/weapon UpdateMsg and SFX,
-- not by client-side modifications or a fabricated success toast.
local Net=require("src.survev.net")
local Pickup=Net.PickupMsgType
local Feedback={}
Feedback.__index=Feedback
local warning={
    [Pickup.Full]="Sem espaco na mochila",
    [Pickup.AlreadyOwned]="Voce ja possui esse item",
    [Pickup.AlreadyEquipped]="Item ja equipado",
    [Pickup.BetterItemEquipped]="Voce ja tem um equipamento melhor",
    [Pickup.GunCannotFire]="Esta arma nao pode disparar",
    [Pickup.MaxPerks]="Limite de vantagens atingido",
}
function Feedback.project(msg)
    if type(msg)~="table" then return nil end
    -- Pickup.Success is not an error; never treat it as bag-full.
    return warning[msg.type]
end
function Feedback.new()
    return setmetatable({state=nil,lastSeq=0,message=nil,remaining=0},Feedback)
end
function Feedback:update(state,dt)
    if self.state~=state then
        self.state=state
        self.lastSeq=0
        self.message=nil
        self.remaining=0
    end
    if not state then return end
    local seq=state.pickupSeq or 0
    if seq<self.lastSeq then
        -- JoinedMsg resets the state in place for a new match.
        self.lastSeq=0
        self.message=nil
        self.remaining=0
    end
    if seq>self.lastSeq then
        self.lastSeq=seq
        self.message=Feedback.project(state.lastPickup)
        self.remaining=self.message and 3 or 0
    else
        self.remaining=math.max(0,self.remaining-math.max(dt or 0,0))
    end
end
function Feedback:draw(width,height)
    if not self.message or self.remaining<=0 or
        not love or not love.graphics then return false end
    local g=love.graphics
    local w=math.min(410,width-24)
    local x=(width-w)*.5
    local y=math.max(12,height-280)
    g.setColor(.08,.045,.035,.92)
    g.rectangle("fill",x,y,w,42,7,7)
    g.setColor(.98,.60,.37)
    g.rectangle("line",x,y,w,42,7,7)
    g.setColor(1,.95,.86)
    g.printf(self.message,x+9,y+12,w-18,"center")
    g.setColor(1,1,1,1)
    return true
end
return Feedback
