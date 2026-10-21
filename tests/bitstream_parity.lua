-- Exact wire-packet comparisons against TypeScript upstream, not Lua-only roundtrips.
-- Executed by scripts/check_bit_parity.mjs on GitHub Actions.
local Base=require("src.survev.bit_stream")
local Net=require("src.survev.net")
local Join=require("src.survev.join_msg")
local Input=require("src.survev.input_msg")
local Bind=require("src.survev.input_bindings")

local expectedPlain,expectedJoin,expectedInput=arg[1],arg[2],arg[3]
assert(expectedPlain and expectedJoin and expectedInput,"missing upstream golden wire vectors")
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

-- The input.addInput rule from upstream limits duplicates and list length.
local test=Input.new()
for i=0,25 do test:addInput(i) end
assert(#test.inputs==7)
test:addInput(0)
assert(#test.inputs==7)
print("All upstream TypeScript -> Lua byte-level comparisons passed")
