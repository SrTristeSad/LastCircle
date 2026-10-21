-- shared/net/spectateMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
M.Action={None=0,Begin=1,Next=2,Prev=3}
function M.new() return setmetatable({action=M.Action.None},M) end
function M:serialize(s) s:writeUint8(self.action) end
function M:deserialize(s) self.action=s:readUint8() end
return M
