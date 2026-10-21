-- Byte-aligned multi-message dispatcher for the original Survev MsgStream format.
-- Deliberately rejects unknown/unported message types: without a length prefix
-- there is no safe way to skip them. UpdateMsg requires its own full port.
local Net=require("src.survev.net")
local Registry=require("src.survev.type_registry")
local types=Net.MsgType

local classes={
    [types.Join]=require("src.survev.join_msg"),
    [types.Input]=require("src.survev.input_msg"),
    [types.Joined]=require("src.survev.joined_msg"),
    [types.Map]=require("src.survev.map_msg"),
    [types.Kill]=require("src.survev.kill_msg"),
    [types.Pickup]=require("src.survev.pickup_msg"),
    [types.AliveCounts]=require("src.survev.alive_counts_msg"),
    [types.Emote]=require("src.survev.emote_msg"),
    [types.DropItem]=require("src.survev.drop_item_msg"),
    [types.Spectate]=require("src.survev.spectate_msg"),
}
local Decoder={}
function Decoder.decode(data,registry)
    assert(type(data)=="string","packet must be a binary string")
    assert(#data <= 2*1024*1024,"packet exceeds 2 MiB defensive limit")
    local stream=Net.newMsgStream(data,registry or Registry)
    local output={}
    while stream:getStream():bitsLeft()>=8 do
        local id=stream:deserializeMsgType()
        if id==types.None then break end
        local cls=classes[id]
        assert(cls,"cannot decode unported Survev MsgType "..tostring(id))
        local msg=cls.new()
        msg:deserialize(stream:getStream())
        stream:getStream():readAlignToNextByte()
        output[#output+1]={id=id,msg=msg}
    end
    return output
end
Decoder.supported=classes
return Decoder
