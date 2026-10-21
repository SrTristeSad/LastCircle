-- shared/net/emoteMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new() return setmetatable({pos={x=0,y=0},type="",isPing=false},M) end
function M:serialize(s)
    s:writeVec(self.pos,0,0,1024,1024,16)
    s:writeGameType(self.type)
    s:writeBoolean(self.isPing)
end
function M:deserialize(s)
    self.pos=s:readVec(0,0,1024,1024,16)
    self.type=s:readGameType()
    self.isPing=s:readBoolean()
end
return M
