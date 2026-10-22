-- Mirrors Survev client/src/main.ts joinGame(): server URLs are tried
-- in returned order using ONE real token. No fake fallback server.
local Client=require("src.survev.network_client")
local game={
    joinToken="SERVER-ISSUED-TOKEN",
    urls={"wss://one.example/play","wss://two.example/play"},
}
local cli=Client.new()
local attempted={}
function cli:connect(url,opts)
    assert(opts.joinToken=="SERVER-ISSUED-TOKEN")
    assert(opts.name=="Source Player")
    attempted[#attempted+1]=url
    if #attempted==1 then
        self.state="error"
        return nil,"host unavailable"
    end
    self.state="joined"
    return true
end
local ok,server=cli:connectMatch(game,{name="Source Player"})
assert(ok and server=="wss://two.example/play")
assert(#attempted==2)
assert(attempted[1]==game.urls[1] and attempted[2]==game.urls[2])
local fail=Client.new()
local checked=0
function fail:connect(url,opts)
    checked=checked+1
    assert(opts.joinToken=="SERVER-ISSUED-TOKEN")
    return nil,"dial failed"
end
local good,err=fail:connectMatch(game,{name="Source Player"})
assert(good==nil and checked==2 and fail.state=="error")
assert(err:find("dial failed") and err:find("one.example") and err:find("two.example"))
local recovered=Client.new()
local count=0
function recovered:connect(url,opts)
    count=count+1
    if count==1 then error("TLS unavailable") end
    return true
end
local success=recovered:connectMatch(game,{name="Source Player"})
assert(success and count==2)
print("Original Survev WebSocket URL failover and token reuse passed")
