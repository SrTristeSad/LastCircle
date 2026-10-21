local Camera=require("src.survev.camera")
local Building=require("src.survev.building_renderer")
local ObjTypes=require("src.survev.object_serialize_fns").Type
local fixture=assert(loadfile(assert(arg[1])))()
local camera=Camera.new()
for key,value in pairs(fixture.camera) do camera[key]=value end
local objects={}
for _,obj in ipairs(fixture.objects) do
    obj.__type=ObjTypes.Building
    objects[obj.__id]=obj
end
local renderer=Building.new()
local total=0
local function near(actual,expected,name)
    assert(type(actual)=="number" and type(expected)=="number",name.." non-numeric")
    assert(math.abs(actual-expected)<1e-8,
        string.format("%s expected %.15g, got %.15g",name,expected,actual))
    total=total+1
end
for _,phase in ipairs({"floor","ceiling"}) do
    local actual=renderer:commands(objects,camera,phase)
    local expected=fixture[phase]
    assert(#actual==#expected,
        phase.." source image layer count: "..#actual.." vs "..#expected)
    for idx,row in ipairs(expected) do
        local a=actual[idx]
        for _,property in ipairs({
            "x","y","angle","sx","sy","alpha","tint","zOrd","zIdx","ownerId"
        }) do
            near(a[property],row[property],phase.."."..idx.."."..property)
        end
        assert(a.type==row.type and a.sprite==row.sprite,
            phase..":"..idx.." original type/sprite ID mismatch")
        assert(type(a.asset)=="string",
            phase..":"..idx.." original art missing from verified manifest")
    end
end
-- A damaged ceiling may remove only images whose SOURCE definition requests it.
local bank=renderer:getDefinition("bank_01")
assert(bank and #bank.floor==2 and #bank.ceiling==3)
local shack=renderer:getDefinition("shack_01")
assert(shack and #shack.floor==1 and #shack.ceiling==1)
local destroyed=renderer:commands({[99]={
    __type=ObjTypes.Building,__id=99,type="shack_01",
    pos={x=310,y=320},ori=0,ceilingDead=true,
}},camera,"ceiling")
assert(#destroyed==0,"destroyed ceilings must not obscure interiors")
print("Building image parity:",total,"numeric values matched original TS")
