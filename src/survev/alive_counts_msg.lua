-- shared/net/aliveCountsMsg.ts @ Survev c6185e31 (GPL-3.0)
local M={}; M.__index=M
function M.new() return setmetatable({teamAliveCounts={}},M) end
function M:serialize(s)
    s:writeArray(self.teamAliveCounts,8,function(n) s:writeUint8(n) end)
end
function M:deserialize(s)
    self.teamAliveCounts=s:readArray(8,function() return s:readUint8() end)
end
return M
