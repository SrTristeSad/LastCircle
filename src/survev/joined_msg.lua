-- shared/net/joinedMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new() return setmetatable({teamMode=0,playerId=0,started=false,emotes={}},M) end
function M:serialize(s)
    s:writeUint8(self.teamMode)
    s:writeUint16(self.playerId)
    s:writeBoolean(self.started)
    s:writeArray(self.emotes,8,function(emote) s:writeGameType(emote) end)
end
function M:deserialize(s)
    self.teamMode=s:readUint8()
    self.playerId=s:readUint16()
    self.started=s:readBoolean()
    self.emotes=s:readArray(8,function() return s:readGameType() end)
end
return M
