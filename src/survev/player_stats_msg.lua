-- shared/net/playerStatsMsg.ts, survev/survev @ c6185e31 (GPL-3.0)
local M={}
M.__index=M
local function emptyStats()
    return {playerId=0,timeAlive=0,kills=0,dead=false,damageDealt=0,damageTaken=0}
end
function M.new() return setmetatable({playerStats=emptyStats()},M) end
function M:serialize(s)
    local p=self.playerStats
    s:writeUint16(p.playerId)
    s:writeUint16(p.timeAlive)
    s:writeUint8(p.kills)
    s:writeUint8(p.dead and 1 or 0)
    s:writeUint16(math.floor(p.damageDealt+.5))
    s:writeUint16(math.floor(p.damageTaken+.5))
end
function M:deserialize(s)
    self.playerStats={
        playerId=s:readUint16(),
        timeAlive=s:readUint16(),
        kills=s:readUint8(),
        dead=s:readUint8()~=0,
        damageDealt=s:readUint16(),
        damageTaken=s:readUint16(),
    }
end
return M
