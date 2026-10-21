-- shared/net/killMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new()
    return setmetatable({
        itemSourceType="",mapSourceType="",damageType=0,targetId=0,
        killerId=0,killCreditId=0,killerKills=0,downed=false,killed=false,
    },M)
end
function M:serialize(s)
    s:writeUint8(self.damageType)
    s:writeGameType(self.itemSourceType)
    s:writeMapType(self.mapSourceType)
    s:writeUint16(self.targetId)
    s:writeUint16(self.killerId)
    s:writeUint16(self.killCreditId)
    s:writeUint8(self.killerKills)
    s:writeBoolean(self.downed)
    s:writeBoolean(self.killed)
end
function M:deserialize(s)
    self.damageType=s:readUint8()
    self.itemSourceType=s:readGameType()
    self.mapSourceType=s:readMapType()
    self.targetId=s:readUint16()
    self.killerId=s:readUint16()
    self.killCreditId=s:readUint16()
    self.killerKills=s:readUint8()
    self.downed=s:readBoolean()
    self.killed=s:readBoolean()
end
return M
