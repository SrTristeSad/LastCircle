-- Survev client/src/game.ts transport-session logic (protocol orchestration).
-- The WebSocket backend is INJECTED, not implemented here.
-- After actual websocket transport is provided, open() sends an original
-- JoinMsg and receive() applies server-authoritative messages.
local Net=require("src.survev.net")
local Join=require("src.survev.join_msg")
local Input=require("src.survev.input_msg")
local State=require("src.survev.client_state")
local Registry=require("src.survev.type_registry")
local Session={}
Session.__index=Session

local function clock()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function vectorChanged(current,previous)
    local dot=current.x*previous.x+current.y*previous.y
    dot=math.max(-1,math.min(1,dot))
    return math.deg(math.acos(dot))>.1
end
local function changed(now,previous)
    if #now.inputs>0 then return true end
    if vectorChanged(now.toMouseDir,previous.toMouseDir) then return true end
    if vectorChanged(now.touchMoveDir,previous.touchMoveDir) then return true end
    if math.abs(now.toMouseLen-previous.toMouseLen)>.5 then return true end
    if now.shootStart or now.shootStart~=previous.shootStart then return true end
    for _,key in ipairs({
        "moveLeft","moveRight","moveUp","moveDown",
        "shootHold","portrait","touchMoveActive","touchMoveLen","useItem",
    }) do
        if now[key]~=previous[key] then return true end
    end
    return false
end

-- transport must have send(self, binaryString), called only when open.
-- Session never invents server URLs or assumes connection success.
function Session.new(transport, options)
    assert(transport and type(transport.send)=="function","binary transport with send required")
    options=options or {}
    return setmetatable({
        transport=transport,
        state=options.state or State.new(),
        registry=options.registry or Registry,
        now=options.clock or clock,
        opened=false,seq=0,seqInFlight=false,seqSendTime=0,
        inputMsgTimeout=0,prevInput=Input.new(),
        ping=nil,receivedBytes=0,sentBytes=0,errors={},
    },Session)
end
function Session:sendMessage(kind,msg,bufferSize)
    assert(self.opened,"Survev transport not open")
    local packet=Net.newMsgStream(bufferSize or 128,self.registry)
    packet:serializeMsg(kind,msg)
    local bytes=packet:getBuffer()
    self.transport:send(bytes)
    self.sentBytes=self.sentBytes+#bytes
    return bytes
end
function Session:open(options)
    assert(not self.opened,"already open")
    options=options or {}
    local join=Join.new()
    join.protocol=1028
    join.joinToken=options.joinToken or ""
    join.name=options.name or ""
    join.useTouch=options.useTouch or false
    join.isMobile=options.isMobile or false
    join.bot=false
    if options.loadout then join.loadout=options.loadout end
    self.opened=true
    self.seq=0
    self.seqInFlight=false
    self.inputMsgTimeout=0
    self.prevInput=Input.new()
    self.state:reset()
    return self:sendMessage(Net.MsgType.Join,join,8192)
end
function Session:receive(bytes)
    assert(self.opened,"received network data before transport was opened")
    self.receivedBytes=self.receivedBytes+#bytes
    local decoded=self.state:receive(bytes,self.registry)
    for _,item in ipairs(decoded) do
        if item.id==Net.MsgType.Update then
            local data=item.msg
            if self.seqInFlight and data.ack==self.seq then
                self.seqInFlight=false
                self.ping=self.now()-self.seqSendTime
            end
        end
    end
    return decoded
end
function Session:sendInput(msg,dt)
    assert(self.opened,"cannot send input without open transport")
    assert(type(dt)=="number" and dt>=0,"invalid frame elapsed time")
    self.inputMsgTimeout=self.inputMsgTimeout-dt
    if not changed(msg,self.prevInput) and self.inputMsgTimeout>=0 then
        return nil
    end
    if not self.seqInFlight then
        self.seq=(self.seq+1)%256
        self.seqInFlight=true
        self.seqSendTime=self.now()
    end
    msg.seq=self.seq
    local bytes=self:sendMessage(Net.MsgType.Input,msg,128)
    self.inputMsgTimeout=1
    self.prevInput=msg
    return bytes
end
function Session:close()
    self.opened=false
    self.seqInFlight=false
end
return Session
