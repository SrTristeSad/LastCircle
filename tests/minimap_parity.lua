-- Compare Survev minimap geometry with actual pinned TypeScript.
local Mini=require("src.survev.minimap")
local source=assert(loadfile(assert(arg[1])))()
local map={mapName="main",width=720,height=640,seed=123,
    objects=source.objects,places={},rivers={},groundPatches={}}
local mini=Mini.new()
local actual=mini:mapShapes(map)
local expected=source.source
assert(#actual==#expected,
    "original minimap shape count "..#expected..", got "..#actual)
local tests=0
local function eq(a,b,label)
    assert(type(a)=="number" and type(b)=="number",label.." types")
    assert(math.abs(a-b)<1e-8,
        string.format("%s expected %.12g got %.12g",label,b,a))
    tests=tests+1
end
local function point(a,b,why)
    eq(a.x,b.x,why..".x");eq(a.y,b.y,why..".y")
end
for i,entry in ipairs(expected) do
    local got=actual[i]
    assert(got.objType==entry.objType,
        "source zIdx sorted shape type mismatch "..i)
    eq(got.zIdx,entry.zIdx,"zIdx "..i)
    eq(got.color,entry.color,"source color "..i)
    eq(got.scale,entry.scale,"map shape scaling "..i)
    eq(got.type,entry.type,"original collider type "..i)
    if got.type==0 then
        point(got.collider.pos,entry.collider.pos,"circle "..i)
        eq(got.collider.rad,entry.collider.rad,"circle radius "..i)
    else
        point(got.collider.min,entry.collider.min,"aabb min "..i)
        point(got.collider.max,entry.collider.max,"aabb max "..i)
    end
end
-- Explicitly verify world->map Y inversion and full map dimensions.
local pos=mini:project({x=360,y=320},512,map)
eq(pos.x,256,"minimap midpoint x")
eq(pos.y,256,"minimap midpoint y")
local n=mini:project({x=0,y=0},512,map)
local s=mini:project({x=720,y=640},512,map)
assert(n.x==0 and n.y<512 and s.x==512 and s.y>0)
assert(#expected>=24 and tests>=100)
print("Survev minimap: ",#expected,
    " source shapes and ",tests,"original collider/color/scale values passed")
