-- Gas state/interpolation translated from Survev client/src/gas.ts.
-- Rendering layer and UI notifications are deliberately separate/unimplemented.
local V2=require("src.survev.v2")
local Net=require("src.survev.net")
local Config=require("src.survev.game_config")
local Gas={}
Gas.__index=Gas
function Gas.new()
    local radius=(math.sqrt(2)+.01)*Net.Constants.MaxPosition
    return setmetatable({
        mode=Config.GasMode.Inactive,circleT=0,circleTOld=0,duration=0,
        interpolationT=0,
        circleOld={pos=V2.create(0,0),rad=radius},
        circleNew={pos=V2.create(0,0),rad=radius},
    },Gas)
end
function Gas:isActive() return self.mode~=Config.GasMode.Inactive end
function Gas:getCircle(interpT)
    local t=self.mode==Config.GasMode.Moving
        and (self.circleTOld*(1-interpT)+self.circleT*interpT) or 0
    return {
        pos=V2.lerp(t,self.circleOld.pos,self.circleNew.pos),
        rad=self.circleOld.rad*(1-t)+self.circleNew.rad*t,
    }
end
function Gas:setProgress(circleT)
    self.circleTOld=self.circleT
    self.circleT=circleT
    self.interpolationT=0
end
function Gas:setFullState(circleT,data)
    self.mode=data.mode
    self.duration=data.duration
    self:setProgress(circleT)
    self.circleOld={pos=V2.copy(data.posOld),rad=data.radOld}
    self.circleNew={pos=V2.copy(data.posNew),rad=data.radNew}
end
function Gas:step(dt,interpolationEnabled,interval)
    self.interpolationT=self.interpolationT+dt
    local interpT=1
    if interpolationEnabled then
        interpT=math.max(0,math.min(1,self.interpolationT/(interval or 0)))
    end
    return self:getCircle(interpT)
end
return Gas
