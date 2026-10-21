-- Exact wire-packet comparisons against TypeScript upstream, not Lua-only roundtrips.
-- Executed by scripts/check_bit_parity.mjs on GitHub Actions.
local Base=require("src.survev.bit_stream")
local Net=require("src.survev.net")
local Join=require("src.survev.join_msg")
local Input=require("src.survev.input_msg")
local Map=require("src.survev.map_msg")
local Bind=require("src.survev.input_bindings")

local expectedPlain,expectedJoin,expectedInput,expectedMap,expectedUnicodeJoin=arg[1],arg[2],arg[3],arg[4],arg[5]
assert(expectedPlain and expectedJoin and expectedInput and expectedMap,"missing upstream golden wire vectors")
local function eq(actual,expected,label)
    assert(actual==expected,label.." expected "..expected.." but got "..actual)
end
local function hex(str)
    return (str:gsub(".",function(c) return string.format("%02x",c:byte()) end))
end

local s=Base.new(128)
s:writeBits(5,3)
s:writeUint16(48879)
s:writeInt8(-12)
s:writeBoolean(true)
s:writeASCIIString("OK",4)
s:writeFloat32(3.25)
eq(s:getHex(),expectedPlain,"bitBuffer")
local reader=Base.new(s:getBuffer())
assert(reader:readBits(3)==5)
assert(reader:readUint16()==48879)
assert(reader:readInt8()==-12)
assert(reader:readBoolean()==true)
assert(reader:readASCIIString(4)=="OK")
assert(reader:readFloat32()==3.25)
local overflow=pcall(function() reader:readUint32() end)
assert(not overflow,"missing out-of-bounds read protection")

local registry=require("src.survev.type_registry")
assert(registry.game.typeToId["bandage"] ~= nil,"expected upstream bandage def")
local join=Join.new()
join.protocol=1028
join.joinToken="test-token"
join.name="Alex"
join.useTouch=false
join.isMobile=false
join.bot=false
join.loadout.outfit="outfitBase"
local joined=Net.newMsgStream(256,registry)
joined:serializeMsg(Net.MsgType.Join,join)
eq(hex(joined:getBuffer()),expectedJoin,"JoinMsg")

local utfJoin=Join.new()
utfJoin.protocol=1028
utfJoin.joinToken="abc"
utfJoin.name="José"
utfJoin.loadout.outfit="outfitBase"
local utfPacket=Net.newMsgStream(256,registry)
utfPacket:serializeMsg(Net.MsgType.Join,utfJoin)
eq(hex(utfPacket:getBuffer()),expectedUnicodeJoin,"JoinMsg UTF16 low-byte")
local utfRead=Net.newMsgStream(utfPacket:getBuffer(),registry)
assert(utfRead:deserializeMsgType()==Net.MsgType.Join)
local utfCopy=Join.new()
utfCopy:deserialize(utfRead:getStream())
assert(utfCopy.name=="José","Non-ASCII Survev name mismatch")

local decode=Net.newMsgStream(joined:getBuffer(),registry)
assert(decode:deserializeMsgType()==Net.MsgType.Join)
local joinedCopy=Join.new()
joinedCopy:deserialize(decode:getStream())
assert(joinedCopy.protocol==1028 and joinedCopy.name=="Alex")
assert(joinedCopy.loadout.outfit=="outfitBase")

local input=Input.new()
input.seq=31
input.moveLeft=true
input.moveUp=true
input.shootStart=true
input.touchMoveActive=true
input.touchMoveDir={x=0,y=1}
input.touchMoveLen=201
input.toMouseDir={x=1,y=0}
input.toMouseLen=27.25
input:addInput(Bind.Input.Reload)
input:addInput(Bind.Input.EquipMelee)
input.useItem="bandage"
local framed=Net.newMsgStream(256,registry)
framed:serializeMsg(Net.MsgType.Input,input)
eq(hex(framed:getBuffer()),expectedInput,"InputMsg")
local stream=Net.newMsgStream(framed:getBuffer(),registry)
assert(stream:deserializeMsgType()==Net.MsgType.Input)
local inputCopy=Input.new()
inputCopy:deserialize(stream:getStream())
assert(inputCopy.seq==31 and inputCopy.moveLeft and inputCopy.moveUp)
assert(inputCopy.touchMoveActive and inputCopy.touchMoveLen==201)
assert(#inputCopy.inputs==2)
assert(inputCopy.useItem=="bandage")
assert(math.abs(inputCopy.toMouseLen-27.25)<.26)

local map=Map.new()
map.mapName="main"
map.seed=123456
map.width=720
map.height=640
map.shoreInset=8
map.grassInset=12
map.rivers={{width=7,looped=false,points={{x=20,y=30},{x=48,y=75}}}}
map.places={{name="Town",pos={x=.25,y=.65}}}
map.objects={{pos={x=200,y=150},scale=1,type=registry.map.idToType[1],ori=2}}
map.groundPatches={
    {bound={type=0,pos={x=300,y=200},rad=17},
        color=0x113355,roughness=.25,offsetDist=3.5,order=2,useAsMapShape=true},
    {bound={type=1,min={x=50,y=100},max={x=100,y=140}},
        color=0x8899aa,roughness=.5,offsetDist=1.25,order=1,useAsMapShape=false},
}
local mapPacket=Net.newMsgStream(2048,registry)
mapPacket:serializeMsg(Net.MsgType.Map,map)
eq(hex(mapPacket:getBuffer()),expectedMap,"MapMsg")
local mapRead=Net.newMsgStream(mapPacket:getBuffer(),registry)
assert(mapRead:deserializeMsgType()==Net.MsgType.Map)
local decodedMap=Map.new()
decodedMap:deserialize(mapRead:getStream())
assert(decodedMap.mapName=="main" and decodedMap.seed==123456)
assert(decodedMap.width==720 and decodedMap.height==640)
assert(decodedMap.shoreInset==8 and decodedMap.grassInset==12)
assert(#decodedMap.rivers==1 and #decodedMap.rivers[1].points==2)
assert(#decodedMap.places==1 and decodedMap.places[1].name=="Town")
assert(#decodedMap.objects==1 and decodedMap.objects[1].type==registry.map.idToType[1])
assert(#decodedMap.groundPatches==2)
assert(decodedMap.groundPatches[1].bound.type==0)
assert(decodedMap.groundPatches[2].bound.type==1)
assert(decodedMap.groundPatches[2].color==0x8899aa)

-- The input.addInput rule from upstream limits duplicates and list length.
local test=Input.new()
for i=0,25 do test:addInput(i) end
assert(#test.inputs==7)
test:addInput(0)
assert(#test.inputs==7)

-- Transport-independent session must frame precisely the same Join/Input bytes
-- that the original TypeScript test generated above.
local Session=require("src.survev.protocol_session")
local Update=require("src.survev.update_msg")
local clock=0
local sent={}
local transport={send=function(_,bytes) sent[#sent+1]=bytes end}
local session=Session.new(transport,{clock=function() return clock end})
local handshake=session:open({
    joinToken="test-token",name="Alex",
    loadout={outfit="outfitBase",melee="",heal="",boost="",emotes={}},
})
eq(hex(handshake),expectedJoin,"Session Join handshake")
assert(#sent==1 and session.opened)
session.seq=30
local first=session:sendInput(input,.016)
eq(hex(first),expectedInput,"Session Input")
assert(session.seq==31 and session.seqInFlight and #sent==2)
local idle=Input.new()
assert(session:sendInput(idle,.1)~=nil,"shootStart release should be sent")
assert(session:sendInput(idle,.1)==nil,"unchanged input should be throttled")
local ack=Update.new()
ack.ack=31
local ackStream=Net.newMsgStream(512,registry)
ackStream:serializeMsg(Net.MsgType.Update,ack)
clock=.27
session:receive(ackStream:getBuffer())
assert(session.state.updateCount==1 and session.state.lastAck==31)
assert(not session.seqInFlight and math.abs(session.ping-.27)<.0001)
session:close()
assert(not session.opened)
assert(not pcall(function() session:sendInput(input,.1) end))

print("All upstream TypeScript -> Lua byte-level comparisons passed")
