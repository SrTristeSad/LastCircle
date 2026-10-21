-- shared/net/gameOverMsg.ts, survev/survev @ c6185e31 (GPL-3.0)
local PlayerStats=require("src.survev.player_stats_msg")
local M={}
M.__index=M
function M.new()
    return setmetatable({
        teamId=0,teamRank=0,gameOver=false,winningTeamId=0,playerStats={}
    },M)
end
function M:serialize(s)
    s:writeUint8(self.teamId)
    s:writeUint8(self.teamRank)
    s:writeUint8(self.gameOver and 1 or 0)
    s:writeUint8(self.winningTeamId)
    s:writeArray(self.playerStats,8,function(stats)
        local msg=PlayerStats.new()
        msg.playerStats=stats
        msg:serialize(s)
    end)
end
function M:deserialize(s)
    self.teamId=s:readUint8()
    self.teamRank=s:readUint8()
    self.gameOver=s:readUint8()~=0
    self.winningTeamId=s:readUint8()
    self.playerStats=s:readArray(8,function()
        local msg=PlayerStats.new()
        msg:deserialize(s)
        return msg.playerStats
    end)
end
return M
