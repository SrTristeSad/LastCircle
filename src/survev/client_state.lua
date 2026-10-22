-- Transport state projection for the future LÖVE client.
-- Applies Survev client/src/game.ts:m_processGameUpdate network ordering.
-- Does not implement game physics/renderers/animations.
local Net=require("src.survev.net")
local Decode=require("src.survev.packet_decoder")
local Gas=require("src.survev.gas")
local State={}
State.__index=State

local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for k,v in pairs(value) do result[k]=copy(v) end
    return result
end
local function overlay(target,patch)
    for k,v in pairs(patch) do
        if k~="__id" and k~="__type" then target[k]=copy(v) end
    end
end
local function recordError(self,reason)
    self.errors[#self.errors+1]=reason
    if #self.errors>30 then table.remove(self.errors,1) end
end
local function copyAndMark(obj)
    return copy(obj)
end

function State.new()
    return setmetatable({
        teamMode=1,joined=false,started=false,localId=0,activeId=0,
        spectating=false,map=nil,objects={},playerInfos={},localData={},
        playerStatus={},groupStatus={},gas=Gas.new(),
        bullets={},shotFxEvents={},shotFxSeq=0,
        explosions={},emotes={},planes={},airstrikeZones={},
        mapIndicators={},killLeaderId=0,killLeaderKills=0,
        lastAck=0,updateCount=0,errors={},
        gameOver=nil,score=nil,aliveCounts={},lastPickup=nil,pickupSeq=0,
        lastKill=nil,
    },State)
end

function State:reset()
    local fresh=State.new()
    for k in pairs(self) do self[k]=nil end
    for k,v in pairs(fresh) do self[k]=v end
end
function State:getObject(id) return self.objects[id] end

function State:applyUpdate(msg)
    self.updateCount=self.updateCount+1
    self.lastAck=msg.ack

    if msg.activePlayerIdDirty then self.activeId=msg.activePlayerId end
    for _,info in ipairs(msg.playerInfos or {}) do
        self.playerInfos[info.playerId]=copy(info)
    end
    for _,playerId in ipairs(msg.deletedPlayerIds or {}) do
        self.playerInfos[playerId]=nil
    end

    if msg.playerStatusDirty then self.playerStatus=copy(msg.playerStatus) end
    if msg.groupStatusDirty then self.groupStatus=copy(msg.groupStatus) end

    -- Order matches client/src/game.ts: delete -> full -> partial.
    for _,id in ipairs(msg.delObjIds or {}) do self.objects[id]=nil end
    for _,obj in ipairs(msg.fullObjects or {}) do
        if obj.__id and obj.__type then self.objects[obj.__id]=copyAndMark(obj) end
    end
    for _,patch in ipairs(msg.partObjects or {}) do
        local target=self.objects[patch.__id]
        if not target or target.__type~=patch.__type then
            recordError(self,"Survev partial type mismatch or missing object id="..
                tostring(patch.__id).." received="..tostring(patch.__type)..
                " existing="..tostring(target and target.__type or 0))
        else
            overlay(target,patch)
        end
    end
    self.spectating=self.localId~=0 and self.activeId~=self.localId

    local d=msg.activePlayerData or {}
    for _,group in ipairs({
        {"healthDirty","health"},{"boostDirty","boost"},{"zoomDirty","zoom"},
        {"actionDirty","action"},{"inventoryDirty","scope","inventory"},
        {"weapsDirty","curWeapIdx","weapons"},
        {"spectatorCountDirty","spectatorCount"}
    }) do
        if d[group[1]] then
            for i=2,#group do self.localData[group[i]]=copy(d[group[i]]) end
        end
    end

    if msg.gasDirty then self.gas:setFullState(msg.gasT,msg.gasData) end
    if msg.gasTDirty then self.gas:setProgress(msg.gasT) end

    -- Effects are one-update events, not permanent world objects.
    self.bullets=copy(msg.bullets or {})
    -- The socket can deliver several UpdateMsgs in a single render frame.
    -- Keep bounded, numbered shotFx events so the recoil renderer receives
    -- each authoritative shot once, not only the final packet's bullets.
    for _,bullet in ipairs(self.bullets) do
        if bullet.shotFx==true then
            self.shotFxSeq=self.shotFxSeq+1
            local shot=copy(bullet)
            shot.seq=self.shotFxSeq
            self.shotFxEvents[#self.shotFxEvents+1]=shot
            if #self.shotFxEvents>256 then
                table.remove(self.shotFxEvents,1)
            end
        end
    end
    self.explosions=copy(msg.explosions or {})
    self.emotes=copy(msg.emotes or {})
    self.planes=copy(msg.planes or {})
    self.airstrikeZones=copy(msg.airstrikeZones or {})
    self.mapIndicators=copy(msg.mapIndicators or {})
    if msg.killLeaderDirty then
        self.killLeaderId=msg.killLeaderId
        self.killLeaderKills=msg.killLeaderKills
    end
end

function State:applyMessage(id,msg)
    local t=Net.MsgType
    if id==t.Joined then
        self:reset()
        self.teamMode=msg.teamMode
        self.localId=msg.playerId
        self.activeId=msg.playerId
        self.joined=true
        self.started=msg.started
    elseif id==t.Map then
        self.map=copy(msg)
    elseif id==t.Update then
        self:applyUpdate(msg)
    elseif id==t.AliveCounts then
        self.aliveCounts=copy(msg.teamAliveCounts)
    elseif id==t.GameOver then
        self.gameOver=copy(msg)
    elseif id==t.PlayerStats then
        self.score=copy(msg.playerStats)
    elseif id==t.Kill then
        self.lastKill=copy(msg)
    elseif id==t.Pickup then
        self.lastPickup=copy(msg)
        self.pickupSeq=self.pickupSeq+1
    elseif id==t.RoleAnnouncement then
        self.lastRole=copy(msg)
    elseif id==t.Emote or id==t.Spectate or id==t.DropItem then
        -- Client-sent messages do not alter the world state here.
    else
        recordError(self,"Unsupported state message type "..tostring(id))
    end
end

-- The decoder refuses message types without a Lua schema, avoiding the unsafe
-- attempt to skip unknown payloads in this unlength-prefixed protocol.
function State:receive(bytes,registry)
    local decoded=Decode.decode(bytes,registry)
    for _,item in ipairs(decoded) do self:applyMessage(item.id,item.msg) end
    return decoded
end
return State
