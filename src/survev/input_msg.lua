-- Faithful field order for survev/survev shared/net/inputMsg.ts.
-- Protocol 1028; serialization only. This module does not open connections.
local Net = require("src.survev.net")
local V2 = require("src.survev.v2")
local Input={}
Input.__index=Input

function Input.new()
    return setmetatable({
        seq=0,
        moveLeft=false, moveRight=false, moveUp=false, moveDown=false,
        shootStart=false, shootHold=false, portrait=false,
        touchMoveActive=false,
        touchMoveDir=V2.create(1,0), touchMoveLen=255,
        toMouseDir=V2.create(1,0), toMouseLen=0,
        inputs={}, useItem="",
    },Input)
end
function Input:addInput(input)
    if #self.inputs>=7 then return end
    for i=1,#self.inputs do if self.inputs[i]==input then return end end
    self.inputs[#self.inputs+1]=input
end
function Input:serialize(s)
    s:writeUint8(self.seq)
    s:writeBoolean(self.moveLeft)
    s:writeBoolean(self.moveRight)
    s:writeBoolean(self.moveUp)
    s:writeBoolean(self.moveDown)
    s:writeBoolean(self.shootStart)
    s:writeBoolean(self.shootHold)
    s:writeBoolean(self.portrait)
    s:writeBoolean(self.touchMoveActive)
    if self.touchMoveActive then
        s:writeUnitVec(self.touchMoveDir,8)
        s:writeUint8(self.touchMoveLen)
    end
    s:writeUnitVec(self.toMouseDir,10)
    s:writeFloat(self.toMouseLen,0,Net.Constants.MouseMaxDist,8)
    s:writeArray(self.inputs,4,function(id)
        s:writeUint8(id)
    end)
    s:writeGameType(self.useItem)
end
function Input:deserialize(s)
    self.seq=s:readUint8()
    self.moveLeft=s:readBoolean()
    self.moveRight=s:readBoolean()
    self.moveUp=s:readBoolean()
    self.moveDown=s:readBoolean()
    self.shootStart=s:readBoolean()
    self.shootHold=s:readBoolean()
    self.portrait=s:readBoolean()
    self.touchMoveActive=s:readBoolean()
    if self.touchMoveActive then
        self.touchMoveDir=s:readUnitVec(8)
        self.touchMoveLen=s:readUint8()
    end
    self.toMouseDir=s:readUnitVec(10)
    self.toMouseLen=s:readFloat(0,Net.Constants.MouseMaxDist,8)
    self.inputs=s:readArray(4,function() return s:readUint8() end)
    self.useItem=s:readGameType()
end
return Input
