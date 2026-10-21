-- Real RFC 6455 WebSocket socket transport for Survev binary packets.
-- Requires LuaSocket (LOVE ships LuaSocket). wss:// additionally requires LuaSec
-- and an explicit trusted CA bundle/path; NEVER silently falls back to ws://.
-- No gameplay rules: this is solely the original game's WebSocket transport.
local Codec=require("src.survev.ws_codec")
local Frame=require("src.survev.ws_frame")
local Ws={}
Ws.__index=Ws
local MAX_HEADER=16384
local MAX_INCOMING=Frame.MAX_PAYLOAD+1024

local function parseUrl(url)
    assert(type(url)=="string" and #url<2048,"invalid WebSocket URL")
    assert(not url:find("[\r\n%z]"),"invalid URL control characters")
    local scheme,authority,path=url:match("^(wss?)://([^/]+)(/.*)$")
    if not scheme then scheme,authority=url:match("^(wss?)://([^/]+)$");path="/" end
    assert(scheme and authority,"only ws:// and wss:// URLs supported")
    assert(not authority:find("[@#?]"),"URL must not include credentials or fragments")
    local host,port
    if authority:sub(1,1)=="[" then
        host,port=authority:match("^%[([^%]]+)%]:(%d+)$")
        if not host then host=authority:match("^%[([^%]]+)%]$") end
        assert(host,"invalid IPv6 host")
    else
        host,port=authority:match("^([^:]+):(%d+)$")
        if not host then host=authority;assert(not host:find(":"),"invalid address") end
    end
    port=tonumber(port) or (scheme=="wss" and 443 or 80)
    assert(port>=1 and port<=65535,"invalid port")
    assert(not path:find("#",1,true),"URL fragments not supported")
    local hostHeader=authority
    return {secure=scheme=="wss",host=host,port=port,
        hostHeader=hostHeader,path=path,url=url}
end
local function localhost(host)
    return host=="localhost" or host=="127.0.0.1" or host=="::1"
end
local function headerHasToken(value,token)
    if type(value)~="string" then return false end
    for word in value:gmatch("[^,]+") do
        if word:match("^%s*(.-)%s*$"):lower()==token:lower() then return true end
    end
    return false
end

local function defaultSocketFactory() return require("socket").tcp() end
function Ws.new(options)
    options=options or {}
    return setmetatable({
        options=options,
        state="closed",socket=nil,url=nil,
        inbuf="",outbuf="",fragment=nil,fragmentOpcode=nil,
        onMessage=options.onMessage, onClose=options.onClose,
        onError=options.onError, onOpen=options.onOpen,
        closeCode=nil,closeReason=nil,
        lastError=nil,
        socketFactory=options.socketFactory or defaultSocketFactory,
    },Ws)
end
function Ws:_error(err)
    self.lastError=tostring(err)
    if self.onError then self.onError(self.lastError) end
    self:_shutdown(1006,self.lastError)
    return nil,self.lastError
end
function Ws:_shutdown(code,reason)
    if self.socket then pcall(function() self.socket:close() end) end
    self.socket=nil
    local previous=self.state
    self.state="closed"
    self.closeCode=code
    self.closeReason=reason or ""
    if previous~="closed" and self.onClose then self.onClose(code,self.closeReason) end
end
local function requireTLS(sock,parsed,options)
    if not options.caFile and not options.caPath then
        error("wss:// requires a trusted CA certificate file or directory")
    end
    local ok,ssl=pcall(require,"ssl")
    assert(ok,"wss:// requires LuaSec (ssl module)")
    local cfg={
        mode="client",protocol="tlsv1_2",verify="peer",options="all",
        cafile=options.caFile,capath=options.caPath,
    }
    local secure,err=ssl.wrap(sock,cfg)
    assert(secure,err)
    if secure.sni then secure:sni(parsed.host) end
    secure:settimeout(options.timeout or 4)
    local handshakeOk,handshakeErr=secure:dohandshake()
    assert(handshakeOk,"TLS handshake: "..tostring(handshakeErr))
    local cert=secure:getpeercertificate()
    assert(cert and cert.checkhost and cert:checkhost(parsed.host),
        "TLS hostname verification unavailable or failed")
    return secure
end
local function sendComplete(sock,data)
    local index=1
    while index<=#data do
        local n,err,last=sock:send(data,index)
        if n then index=n+1
        elseif last and last>=index then index=last+1
        else return nil,err or "failed sending WebSocket handshake" end
    end
    return true
end
function Ws:connect(url)
    assert(self.state=="closed","WebSocket already active")
    local ok,parsed=pcall(parseUrl,url)
    if not ok then return self:_error(parsed) end
    if not parsed.secure and not localhost(parsed.host) and not self.options.allowInsecure then
        return self:_error("ws:// remote connection blocked; use wss:// or explicitly opt into insecure transport")
    end
    self.state="connecting"
    self.url=parsed
    local success,err=pcall(function()
        local tcp=self.socketFactory()
        assert(tcp and tcp.connect,"LuaSocket TCP transport unavailable")
        tcp:settimeout(self.options.timeout or 4)
        local connected,connectError=tcp:connect(parsed.host,parsed.port)
        assert(connected,connectError or "TCP connection failed")
        local sock=parsed.secure and requireTLS(tcp,parsed,self.options) or tcp
        self.socket=sock

        local rand=self.options.randomBytes or Codec.randomBytes
        local key=Codec.base64(rand(16))
        local req="GET "..parsed.path.." HTTP/1.1\r\n"..
            "Host: "..parsed.hostHeader.."\r\n"..
            "Upgrade: websocket\r\n"..
            "Connection: Upgrade\r\n"..
            "Sec-WebSocket-Key: "..key.."\r\n"..
            "Sec-WebSocket-Version: 13\r\n"..
            "\r\n"
        local sent,sendErr=sendComplete(sock,req)
        assert(sent,sendErr)
        local response,statusErr=sock:receive("*l")
        assert(response,statusErr or "no upgrade response")
        assert(response:match("^HTTP/1%.[01] 101 "), "invalid WebSocket upgrade status")
        local headers={}
        local size=#response
        while true do
            local line,errLine=sock:receive("*l")
            assert(line,errLine or "incomplete handshake response")
            size=size+#line+2
            assert(size<=MAX_HEADER,"WebSocket handshake headers too long")
            if line=="" then break end
            local name,value=line:match("^([^:]+):%s*(.-)%s*$")
            assert(name and value,"invalid WebSocket header")
            name=name:lower()
            headers[name]=(headers[name] and headers[name].."," or "")..value
        end
        assert(headerHasToken(headers.upgrade,"websocket"),"WebSocket Upgrade missing")
        assert(headerHasToken(headers.connection,"upgrade"),"WebSocket Connection missing")
        assert(headers["sec-websocket-accept"]==Codec.accept(key),
            "WebSocket Sec-WebSocket-Accept mismatch")
        assert(not headers["sec-websocket-extensions"],
            "WebSocket extensions are not supported")
        assert(not headers["sec-websocket-protocol"],
            "unexpected WebSocket subprotocol")
        sock:settimeout(0)
    end)
    if not success then return self:_error(err) end
    self.state="open"
    self.inbuf="";self.outbuf="";self.fragment=nil;self.fragmentOpcode=nil
    self.closeCode=nil;self.closeReason=nil;self.lastError=nil
    if self.onOpen then self.onOpen() end
    return true
end
function Ws:send(data)
    assert(self.state=="open","cannot send on closed WebSocket")
    assert(type(data)=="string","binary WebSocket payload expected")
    local rand=self.options.randomBytes or Codec.randomBytes
    local frame=Frame.encode(data,2,rand(4))
    assert(#self.outbuf+#frame<=MAX_INCOMING,"WebSocket outgoing queue too large")
    self.outbuf=self.outbuf..frame
    return self:_flush()
end
function Ws:_flush()
    if not self.socket then return nil,"WebSocket not connected" end
    local iter=0
    while #self.outbuf>0 and iter<32 do
        iter=iter+1
        local sent,err,last=self.socket:send(self.outbuf)
        if sent then
            self.outbuf=self.outbuf:sub(sent+1)
        elseif err=="timeout" or err=="wantwrite" or err=="wantread" then
            if last and last>0 then self.outbuf=self.outbuf:sub(last+1) end
            return true
        else
            return self:_error(err or "socket send failed")
        end
    end
    return true
end
function Ws:_handle(frame)
    local opcode=frame.opcode
    local body=frame.payload
    if opcode==8 then
        local code=1000
        if #body>=2 then code=body:byte(1)*256+body:byte(2) end
        local reason=body:sub(3)
        self:_shutdown(code,reason)
        return
    end
    if opcode==9 then
        local rand=self.options.randomBytes or Codec.randomBytes
        self.outbuf=self.outbuf..Frame.encode(body,10,rand(4))
        return
    end
    if opcode==10 then return end
    if opcode==1 then return self:_error("Survev requires binary frames, received text") end
    if opcode==2 then
        if self.fragment then return self:_error("nested binary fragment") end
        if frame.fin then
            if self.onMessage then self.onMessage(body) end
        else self.fragment=body;self.fragmentOpcode=2 end
    elseif opcode==0 then
        if not self.fragment then return self:_error("unexpected WebSocket continuation") end
        self.fragment=self.fragment..body
        if #self.fragment>Frame.MAX_PAYLOAD then return self:_error("fragmented payload too large") end
        if frame.fin then
            local message=self.fragment
            self.fragment=nil;self.fragmentOpcode=nil
            if self.onMessage then self.onMessage(message) end
        end
    end
end
function Ws:poll()
    if self.state~="open" then return end
    self:_flush()
    if self.state~="open" then return end
    for _=1,64 do
        local data,err,part=self.socket:receive(16384)
        local bytes=data or part
        if bytes and #bytes>0 then
            self.inbuf=self.inbuf..bytes
            if #self.inbuf>MAX_INCOMING then
                self:_error("WebSocket incoming buffer too large")
                return
            end
            local count=0
            while self.state=="open" and count<512 do
                local frame,remaining,decodeError=Frame.tryDecode(self.inbuf)
                if decodeError then self:_error(decodeError);return end
                if not frame then break end
                self.inbuf=remaining
                count=count+1
                local ok,callbackError=pcall(self._handle,self,frame)
                if not ok then self:_error(callbackError);return end
            end
        end
        if err=="closed" then self:_shutdown(1006,"TCP connection closed");return end
        if err and err~="timeout" and err~="wantread" then
            self:_error(err);return
        end
        if not data then break end
    end
    if self.state=="open" then self:_flush() end
end
function Ws:close(code,reason)
    if self.state~="open" then self:_shutdown(code or 1000,reason or "");return end
    code=code or 1000
    reason=reason or ""
    assert(type(reason)=="string" and #reason<=123,"invalid close reason")
    local data=string.char(math.floor(code/256)%256,code%256)..reason
    local rand=self.options.randomBytes or Codec.randomBytes
    self.outbuf=self.outbuf..Frame.encode(data,8,rand(4))
    self:_flush()
    self:_shutdown(code,reason)
end
Ws.parseUrl=parseUrl
return Ws
