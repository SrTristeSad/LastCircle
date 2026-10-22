-- Survev client/src/main.ts findGame() / joinGame() protocol.
-- Matchmaking MUST obtain its URLs and token from a real Survev API.
-- Pure-Lua JSON, HTTP (LuaSocket) and HTTPS (LuaSec) with verified TLS.
-- Does not fabricate games, tokens, region lists, or bypass Turnstile.
local Json=require("src.survev.json")
local Game=require("src.survev.game_config")
local Match={}
local function cleanBase(base)
    assert(type(base)=="string" and #base>0 and #base<=512,
        "Provide the actual Survev API URL")
    assert(not base:find("[%c%s]"),"API URL contains whitespace/control")
    local scheme,host,path=base:match("^(https?)://([^/]+)(.*)$")
    assert(scheme and host and not host:find("[@?#]"),
        "API must begin with http:// or https:// and a hostname")
    assert(not path:find("[?#]"),"Do not provide API URL query/fragment")
    assert(path=="" or path:sub(1,1)=="/","Invalid API prefix")
    if scheme=="http" and
        not (host=="localhost" or host:match("^localhost:%d+$")
            or host=="127.0.0.1" or host:match("^127%.0%.0%.1:%d+$")
            or host=="[::1]" or host:match("^%[::1%]:%d+$")) then
        -- Explicit override is handled by Match.request, not this parser.
    end
    return base:gsub("/+$",""),scheme,host
end
function Match.validateResponse(response)
    assert(type(response)=="table","Invalid match response")
    if response.type=="error" then
        assert(type(response.error)=="string","Invalid matchmaking error")
        return nil,response.error
    end
    if response.type=="banned" then
        return nil,"banned"..(type(response.reason)=="string"
            and (": "..response.reason) or "")
    end
    assert(response.type=="success" and type(response.res)=="table",
        "Unexpected matchmaking response")
    local data=response.res
    assert(type(data.joinToken)=="string" and #data.joinToken>0
        and #data.joinToken<=2048,
        "Matchmaker did not provide a valid join token")
    assert(type(data.urls)=="table" and #data.urls>0 and
        #data.urls<=16,"Matchmaker returned no WebSocket URLs")
    local urls={}
    for i=1,#data.urls do
        local url=data.urls[i]
        assert(type(url)=="string" and #url<2048
            and url:match("^wss?://") and not url:find("[%c%s]"),
            "Matchmaker returned an invalid WebSocket URL")
        urls[i]=url
    end
    return {urls=urls,joinToken=data.joinToken}
end
function Match.buildBody(region,mode,zones,turnstile)
    assert(type(region)=="string" and region:match("^[%w_-]+$")
        and #region<=24,"Invalid region")
    assert(type(mode)=="number" and mode==math.floor(mode)
        and mode>=0 and mode<=2,"Invalid game mode")
    zones=zones or {}
    assert(type(zones)=="table" and #zones<=32,"Invalid zones")
    for i=1,#zones do
        assert(type(zones[i])=="string" and #zones[i]<=50
            and zones[i]:match("^[%w_-]+$"),"Invalid zone")
    end
    local body={
        version=Game.protocolVersion,
        region=region,zones=Json.array(zones),
        playerCount=1,autoFill=true,gameModeIdx=mode,
    }
    if turnstile and turnstile~="" then
        assert(type(turnstile)=="string" and #turnstile<=4096,
            "Invalid Turnstile token")
        body.turnstileToken=turnstile
    end
    return Json.encode(body)
end
local function httpSend(url,body,opts)
    local ltn12=require("ltn12")
    local chunks={}
    local options={
        url=url,method="POST",
        headers={
            ["Content-Type"]="application/json; charset=utf-8",
            ["Content-Length"]=tostring(#body),
            ["Accept"]="application/json",
        },
        source=ltn12.source.string(body),
        sink=ltn12.sink.table(chunks),
        redirect=false,
    }
    local secure=url:sub(1,8)=="https://"
    local module
    if secure then
        assert(opts.caFile or opts.caPath,
            "HTTPS requires a trusted CA file or directory")
        module=require("ssl.https")
        options.verify="peer"
        options.protocol="tlsv1_2"
        options.options="all"
        options.cafile=opts.caFile
        options.capath=opts.caPath
    else
        module=require("socket.http")
    end
    local socket=require("socket")
    options.create=function()
        local tcp=assert(socket.tcp())
        tcp:settimeout(opts.timeout or 10)
        return tcp
    end
    local _,status,headers,statusLine=module.request(options)
    return table.concat(chunks),tonumber(status),statusLine or headers
end
function Match.request(base,options,sender)
    options=options or {}
    local ok,url,scheme,host=pcall(cleanBase,base)
    if not ok then return nil,tostring(url) end
    if scheme=="http" and not options.allowInsecure and not
        (host=="localhost" or host:match("^localhost:%d+$")
        or host=="127.0.0.1" or host:match("^127%.0%.0%.1:%d+$")
        or host=="[::1]" or host:match("^%[::1%]:%d+$")) then
        return nil,"Remote API requires HTTPS (HTTP only for localhost)"
    end
    local bodyOk,body=pcall(Match.buildBody,
        options.region or "na",options.gameModeIdx or 0,
        options.zones or {},options.turnstileToken)
    if not bodyOk then return nil,tostring(body) end
    local endpoint=url.."/api/find_game_v2"
    local sent,response,status,statusLine=pcall(sender or httpSend,
        endpoint,body,options)
    if not sent then return nil,"Matchmaking HTTP: "..tostring(response) end
    if status~=200 then
        return nil,"Matchmaking HTTP status "..tostring(status or "?")..
            (type(statusLine)=="string" and (" "..statusLine) or "")
    end
    local parsed,decoded=pcall(Json.decode,response)
    if not parsed then return nil,"Invalid matchmaking JSON: "..tostring(decoded) end
    local valid,game,errorMessage=pcall(Match.validateResponse,decoded)
    if not valid then return nil,"Invalid match response: "..tostring(game) end
    return game,errorMessage
end
return Match
