-- Direct translation of survev/survev shared/net/joinMsg.ts @ c6185e31.
-- Only binary payload encoding; no server connection, authentication or UI.
local Config = require("src.survev.game_config")
local Constants = require("src.survev.net").Constants
local Join = {}
Join.__index = Join

function Join.new()
    return setmetatable({
        protocol=Config.protocolVersion,
        joinToken="",
        name="",
        useTouch=false,
        isMobile=false,
        bot=false,
        loadout={outfit="",melee="",heal="",boost="",emotes={}}
    },Join)
end
function Join:serialize(s)
    -- Exactly four bytes, first field, required by the upstream protocol.
    s:writeUint32(self.protocol)
    s:writeString(self.joinToken)
    s:writeString(self.name, Constants.PlayerNameMaxLen)
    s:writeBoolean(self.useTouch)
    s:writeBoolean(self.isMobile)
    s:writeBoolean(self.bot)
    s:writeGameType(self.loadout.outfit)
    s:writeGameType(self.loadout.melee)
    s:writeGameType(self.loadout.heal)
    s:writeGameType(self.loadout.boost)
    s:writeArray(self.loadout.emotes,8,function(emote) s:writeGameType(emote) end)
end
function Join:deserialize(s)
    self.protocol=s:readUint32()
    self.joinToken=s:readString()
    self.name=s:readString(Constants.PlayerNameMaxLen)
    self.useTouch=s:readBoolean()
    self.isMobile=s:readBoolean()
    self.bot=s:readBoolean()
    self.loadout.outfit=s:readGameType()
    self.loadout.melee=s:readGameType()
    self.loadout.heal=s:readGameType()
    self.loadout.boost=s:readGameType()
    self.loadout.emotes=s:readArray(8,function() return s:readGameType() end)
end
return Join
