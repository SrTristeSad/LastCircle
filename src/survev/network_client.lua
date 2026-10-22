-- Survev WebSocket + protocol session integration.
-- The server MUST provide the game URL + join token as in the original
-- find_game API. Never use a guessed URL or silently substitute a fake token.
local Ws=require("src.survev.ws_connection")
local Session=require("src.survev.protocol_session")
local Input=require("src.survev.input_msg")
local Net=require("src.survev.net")
local Drop=require("src.survev.drop_item_msg")
local LootDefs=require("src.survev.loot_art")
local Equipment=require("src.survev.equipment_art")
local Config=require("src.survev.game_config")
local Client={}
Client.__index=Client
function Client.new(options)
    options=options or {}
    local self=setmetatable({
        options=options,connection=nil,session=nil,state="idle",
        error=nil,closeCode=nil,closeReason=nil,packetCount=0,
        lastMessages={},lastInput=nil,
    },Client)
    return self
end
function Client:connect(url,joinOptions)
    assert(self.state=="idle" or self.state=="closed" or self.state=="error",
        "connection already active")
    joinOptions=joinOptions or {}
    -- Exactly the original shared/utils/loadout.ts defaultLoadout(), not
    -- a made-up weapon or appearance. Used only when caller supplied no loadout.
    if not joinOptions.loadout then
        joinOptions.loadout={
            outfit="outfitBase",melee="fists",heal="heal_basic",
            boost="boost_basic",
            emotes={"emote_happyface","emote_thumbsup","emote_surviv","emote_sadface","",""},
        }
    end
    assert(type(joinOptions.name)=="string","player name required")
    assert(type(joinOptions.joinToken)=="string","join token required")
    self.error=nil
    self.packetCount=0
    self.lastMessages={}
    local opts={}
    for k,v in pairs(self.options) do opts[k]=v end
    self.connection=Ws.new(opts)
    self.session=Session.new(self.connection,opts)
    local ws=self.connection
    ws.onOpen=function()
        self.state="connected"
        local ok,err=pcall(function() self.session:open(joinOptions) end)
        if not ok then
            self.error=tostring(err)
            self.state="error"
            ws:close(1000,"join failed")
        end
    end
    ws.onMessage=function(data)
        local ok,result=pcall(function() return self.session:receive(data) end)
        if not ok then
            self.error=tostring(result)
            self.state="error"
            ws:close(1002,"invalid game protocol")
            return
        end
        self.packetCount=self.packetCount+1
        self.lastMessages=result
        if self.session.state.joined then self.state="joined" end
        if self.session.state.gameOver then self.state="finished" end
    end
    ws.onError=function(err)
        self.error=err
        self.state="error"
    end
    ws.onClose=function(code,reason)
        self.closeCode,self.closeReason=code,reason
        if self.session then self.session:close() end
        if self.state~="error" then self.state="closed" end
    end
    self.state="connecting"
    local connected,err=ws:connect(url)
    if not connected then
        self.error=err
        self.state="error"
        return nil,err
    end
    return self.state=="connected" or self.state=="joined"
end
-- Survev main.ts joinGame(matchData) tries all server-issued URLs in
-- order. The join token is never synthesized or stored by the client.
function Client:connectMatch(match,options)
    assert(type(match)=="table" and type(match.joinToken)=="string" and
        #match.joinToken>0 and type(match.urls)=="table" and
        #match.urls>0,"A real matchmaking result is required")
    options=options or {}
    local errors={}
    for _,url in ipairs(match.urls) do
        if type(url)=="string" and url:match("^wss?://") then
            local join={
                name=options.name or "Jogador Lua",
                joinToken=match.joinToken,
                useTouch=options.useTouch or false,
                isMobile=options.isMobile or false,
                loadout=options.loadout,
            }
            local ok,result,err=pcall(self.connect,self,url,join)
            if ok and result then return true,url end
            errors[#errors+1]=url..": "..tostring(ok and err or result)
        end
    end
    self.state="error"
    self.error=table.concat(errors," | ")
    return nil,self.error~="" and self.error or "No usable game address"
end
function Client:poll()
    if self.connection then self.connection:poll() end
end
function Client:sendInput(msg,dt)
    assert(self.session and self.connection and self.connection.state=="open",
        "not connected")
    assert(self.session.state.joined,"must receive JoinedMsg before sending inputs")
    assert(msg and getmetatable(msg)==Input,"Survev InputMsg required")
    self.lastInput=msg
    return self.session:sendInput(msg,dt)
end
-- All drop requests use the original Survev DropItemMsg, with server
-- authority. A sent packet never mutates local weapons, armour or inventory.
local function activeDropState(self)
    if not self.session or not self.session.opened or
        not self.connection or self.connection.state~="open" then
        return nil,"Sem conexao com a partida"
    end
    local state=self.session.state
    if not state or not state.joined or state.gameOver or
        state.offlinePreview or state.spectating or
        state.activeId~=state.localId then
        return nil,"Jogador nao pode soltar itens agora"
    end
    local actor=state.objects and state.objects[state.activeId]
    if not actor or actor.dead or actor.downed then
        return nil,"Jogador sem personagem ativo"
    end
    return state,actor
end
local function sendDrop(self,item,slot)
    local message=Drop.new()
    message.item=item
    message.weapIdx=slot or 0
    local ok,bytes=pcall(function()
        return self.session:sendMessage(Net.MsgType.DropItem,message,128)
    end)
    if not ok then return nil,tostring(bytes) end
    return bytes
end
-- Bag contents use weapIdx=0; amount is decided by the server.
function Client:dropInventoryItem(item)
    local state,reason=activeDropState(self)
    if not state then return nil,reason end
    local valid=false
    for _,key in ipairs(LootDefs.bagKeys) do
        if key==item then valid=true;break end
    end
    if not valid then return nil,"Item nao pertence ao inventario" end
    local inventory=state.localData and state.localData.inventory
    if not inventory or type(inventory[item])~="number" or
        inventory[item]<=0 then
        return nil,"Item indisponivel ou quantidade desconhecida"
    end
    return sendDrop(self,item,0)
end
-- Original game.ts emits weapon slot index from the UI (zero-based).
-- WeaponManager on the Survev server decides whether a drop is allowed.
function Client:dropWeaponSlot(slot)
    local state,reason=activeDropState(self)
    if not state then return nil,reason end
    if type(slot)~="number" or slot~=math.floor(slot) or
        slot<Config.WeaponSlot.Primary or slot>Config.WeaponSlot.Melee then
        return nil,"Slot nao admite descarte de arma"
    end
    local weapons=state.localData and state.localData.weapons
    local weapon=weapons and weapons[slot+1]
    local item=weapon and weapon.type
    local def=item and Equipment.weapons[item]
    if not def or (def.type~="gun" and def.type~="melee") or
        item=="fists" then
        return nil,"Arma ausente ou nao descartavel neste slot"
    end
    if (slot==Config.WeaponSlot.Melee)~=(def.type=="melee") then
        return nil,"Tipo de arma incompatível com slot"
    end
    return sendDrop(self,item,slot)
end
-- Original game.ts sends the equipped helmet/chest game type, never
-- the UI labels "helmet" or "chest". Backpack is not a server drop case.
function Client:dropArmor(kind)
    local state,actor=activeDropState(self)
    if not state then return nil,actor end
    if kind~="helmet" and kind~="chest" then
        return nil,"Equipamento nao descartavel"
    end
    local item=actor[kind]
    local def=item and Equipment.gear[item]
    if not def or def.type~=kind then
        return nil,"Armadura nao recebida do servidor"
    end
    return sendDrop(self,item,0)
end
function Client:close()
    if self.connection then self.connection:close() end
    if self.session then self.session:close() end
    if self.state~="error" then self.state="closed" end
end
function Client:getGameState()
    return self.session and self.session.state or nil
end
return Client
