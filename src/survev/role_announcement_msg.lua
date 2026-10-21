-- shared/net/roleAnnouncementMsg.ts, Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new()
    return setmetatable({
        playerId=0,killerId=0,role="",assigned=false,killed=false
    },M)
end
function M:serialize(s)
    s:writeUint16(self.playerId)
    s:writeUint16(self.killerId)
    s:writeGameType(self.role)
    s:writeBoolean(self.assigned)
    s:writeBoolean(self.killed)
end
function M:deserialize(s)
    self.playerId=s:readUint16()
    self.killerId=s:readUint16()
    self.role=s:readGameType()
    self.assigned=s:readBoolean()
    self.killed=s:readBoolean()
end
return M
