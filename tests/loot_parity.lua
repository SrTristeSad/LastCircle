local Source=require("src.survev.loot_art")
local Render=require("src.survev.loot_renderer")
local Types=require("src.survev.object_serialize_fns").Type
local golden=assert(loadfile(assert(arg[1])))()
local count=0
local function near(a,b,label)
    assert(type(a)=="number" and type(b)=="number",label.." not numeric")
    assert(math.abs(a-b)<1e-9,
        string.format("%s expected %.12g got %.12g",label,b,a))
    count=count+1
end
for typeName,expect in pairs(golden.itemData) do
    local got=assert(Source.loot[typeName],"missing original loot "..typeName)
    assert(got.type==expect.kind,typeName.." category")
    assert(got.name==expect.name,typeName.." name")
    assert(got.mirror==expect.mirror,typeName.." mirror")
    near(got.radius,expect.radius,typeName..".radius")
    near(got.scale,expect.scale,typeName..".scale")
    near(got.innerScale,expect.innerScale,typeName..".innerScale")
    near(got.tint,expect.tint,typeName..".tint")
    near(got.rot,expect.rot,typeName..".rot")
end
assert(#Source.bagKeys==#golden.bagKeys)
for i,key in ipairs(golden.bagKeys) do
    assert(Source.bagKeys[i]==key,"Original Source bag key order: "..key)
    for level=1,5 do
        near(Source.bagSizes[key][level],
            golden.capacities[key][level],key.." bag level "..level)
    end
end
local state={activeId=1,objects={}}
for _,loot in ipairs(golden.lootStates) do
    state.objects[loot.id]={
        __id=loot.id,__type=Types.Loot,
        type=loot.type,count=loot.count,
        pos=loot.pos,layer=loot.layer,ownerId=loot.ownerId,
    }
end
for i,test in ipairs(golden.nearestCases) do
    state.objects[1]={
        __id=test.actor.id,__type=Types.Player,
        pos=test.actor.pos,layer=test.actor.layer,
        dead=test.actor.dead,downed=test.actor.downed,
    }
    local actual=Render.nearest(state)
    assert((actual and actual.id or nil)==test.closest,
        "Survev LootBarn closest loot case "..i..
        " expected="..tostring(test.closest)..
        " got="..tostring(actual and actual.id))
end
assert(count>=195)
print("Survev ground-loot parity:",count,
    "TypeScript sprite/radius/capacity values plus",
    #golden.nearestCases,"actual LootBarn nearest-item cases")
