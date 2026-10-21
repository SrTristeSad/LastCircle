-- Compare every vertex to original TS generateTerrain/traceGroundPatch.
local Terrain=require("src.survev.terrain_gen")
local fixture=assert(loadfile(assert(arg[1])))()
local tested=0
local function near(a,b,label)
    assert(type(a)=="number" and type(b)=="number")
    local diff=math.abs(a-b)
    if diff>1e-9 then
        error(string.format("%s: expected %.16g, got %.16g (diff %.4g)",label,b,a,diff))
    end
    tested=tested+1
end
local function samePoints(actual,expect,label)
    assert(#actual==#expect,label.." point count mismatch: "..#actual.." vs "..#expect)
    for i=1,#expect do
        near(actual[i].x,expect[i].x,label.."["..i.."].x")
        near(actual[i].y,expect[i].y,label.."["..i.."].y")
    end
end
for idx,item in ipairs(fixture.cases) do
    local t=Terrain.generate(item.map)
    samePoints(t.shore,item.shore,"shore case "..idx)
    samePoints(t.grass,item.grass,"grass case "..idx)
    assert(#t.shore==260 and #t.grass==260)
end
for idx,patch in ipairs(fixture.patches) do
    local polygon=Terrain.patchPolygon(patch,fixture.seed)
    samePoints(polygon,fixture.polygons[idx],"patch "..idx)
    samePoints(Terrain.patchPolygon(patch,fixture.seed),polygon,"patch deterministic "..idx)
end
local seeded=Terrain.seededRand(100)
for i,expected in ipairs(fixture.sequence) do
    near(seeded(-7.5,4.25),expected,"RNG "..i)
end
print("Terrain parity: "..tested.." numeric values matched original TypeScript")
