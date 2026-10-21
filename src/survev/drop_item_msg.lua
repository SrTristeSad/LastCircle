-- shared/net/dropItemMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new() return setmetatable({item="",weapIdx=0},M) end
function M:serialize(s)
    s:writeGameType(self.item)
    s:writeUint8(self.weapIdx)
end
function M:deserialize(s)
    self.item=s:readGameType()
    self.weapIdx=s:readUint8()
end
return M
