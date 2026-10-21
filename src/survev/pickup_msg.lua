-- shared/net/pickupMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new() return setmetatable({type=0,item="",count=0},M) end
function M:serialize(s)
    s:writeUint8(self.type)
    s:writeGameType(self.item)
    s:writeUint8(self.count)
end
function M:deserialize(s)
    self.type=s:readUint8()
    self.item=s:readGameType()
    self.count=s:readUint8()
end
return M
