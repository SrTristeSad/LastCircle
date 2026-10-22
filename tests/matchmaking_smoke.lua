-- Regression test for exact Survev client/src/main.ts quickPlay:
-- POST /api/find_game_v2 -> authentic joinToken and WebSocket URLs.
-- No real Internet, no synthetic token and no client-invented player.
local Json=require("src.survev.json")
local Match=require("src.survev.matchmaking")
local Config=require("src.survev.game_config")
local data=Json.decode([=[{"a":true,"b":false,"c":null,"d":["ok",42,-3.75e2],"unicode":"\\uD83D\\uDE00"}]=])
assert(data.a==true and data.b==false and data.c==Json.null)
assert(data.d[3]==-375)
assert(data.unicode=="\240\159\152\128","surrogate pairs decoded as UTF-8")
assert(Json.decode(Json.encode({zones=Json.array({})})).zones
    and Json.encode({zones=Json.array({})}):find('"zones":[]',1,true))
local example=Json.decode(Json.encode({version=1028,autoFill=true,zones=Json.array({"a","b"})}))
assert(example.zones[2]=="b" and example.autoFill)
for _,invalid in ipairs({
    '{"type":"success","res":{"urls":[]}}',
    '{"a":1,"a":2}',
    '["broken",]',
    '{"a":1} trailing',
    '{"a":"\\uD800"}',
    '{"x":01}',
    '{"x":1.}',
    '9e99999',
    '[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[0]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]',
}) do
    local ok,result=pcall(Json.decode,invalid)
    assert(not ok,"bad JSON should fail "..invalid..":"..tostring(result))
end
local body=Json.decode(Match.buildBody("sa",2,{}))
assert(body.version==Config.protocolVersion)
assert(body.region=="sa" and body.gameModeIdx==2)
assert(body.playerCount==1 and body.autoFill)
assert(type(body.zones)=="table" and #body.zones==0)
local token="real-token-from-server"
local calls=0
local function fake(url,payload,options)
    calls=calls+1
    assert(url=="https://survev.example/api/find_game_v2")
    local packet=Json.decode(payload)
    assert(packet.region=="sa" and packet.version==1028)
    assert(packet.gameModeIdx==2 and packet.autoFill)
    assert(type(packet.zones)=="table" and #packet.zones==0)
    assert(options.caFile=="/tmp/ca.pem")
    return Json.encode({type="success",res={
        joinToken=token,urls=Json.array({
            "wss://one.example/play/alpha",
            "wss://two.example/play/beta",
        }),
    }}),200
end
local opts={region="sa",gameModeIdx=2,caFile="/tmp/ca.pem"}
local game,err=Match.request("https://survev.example/",opts,fake)
assert(game and not err and #game.urls==2)
assert(game.joinToken==token and calls==1)
assert(game.urls[1]=="wss://one.example/play/alpha")
local fail,cause=Match.request("http://remote.example",opts,fake)
assert(fail==nil and cause:find("requires HTTPS") and calls==1)
-- Loopback HTTP is permitted for self-hosted Survev dev API, not remote HTTP.
local localMatch=Match.request("http://127.0.0.1:8000",
    {region="na",gameModeIdx=0},function(url,payload)
        assert(url=="http://127.0.0.1:8000/api/find_game_v2")
        local req=Json.decode(payload)
        assert(req.version==1028 and req.region=="na")
        return '{"type":"error","error":"full"}',200
    end)
assert(localMatch==nil)
local denied,why=Match.request("https://survev.example",opts,
    function() return '{"type":"error","error":"invalid_captcha"}',200 end)
assert(denied==nil and why=="invalid_captcha")
denied,why=Match.request("https://survev.example",opts,
    function() return '{"type":"banned","reason":"moderation"}',200 end)
assert(denied==nil and why:find("banned") and why:find("moderation"))
denied,why=Match.request("https://survev.example",opts,
    function() return "Not found",404,"HTTP/1.1 404 Not Found" end)
assert(denied==nil and why:find("404"))
denied,why=Match.request("https://survev.example",opts,
    function() return '{"type":"success","res":{"joinToken":"","urls":["wss://foo"]}}',200 end)
assert(denied==nil and why:find("Invalid match response"))
denied,why=Match.request("https://survev.example",opts,
    function() return "garbage",200 end)
assert(denied==nil and why:find("Invalid matchmaking JSON"))
local _,notoken=Match.validateResponse({type="error",error="rate_limited"})
assert(notoken=="rate_limited")
assert(Json.encode({region='quotes " \\ \n'}):find("region",1,true))
print("Survev original matchmaking request/response and strict JSON tests passed")
