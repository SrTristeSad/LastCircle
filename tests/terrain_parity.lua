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
    assert(#t.rivers==#item.rivers,"river count mismatch")
    for j,expected in ipairs(item.rivers) do
        local river=t.rivers[j]
        samePoints(river.waterPoly,expected.waterPoly,"river water "..idx..":"..j)
        samePoints(river.shorePoly,expected.shorePoly,"river shore "..idx..":"..j)
        samePoints({river.center},{expected.center},"river center")
        samePoints({river.aabb.min,river.aabb.max},
            {expected.aabb.min,expected.aabb.max},"river aabb")
        samePoints({river.spline:getPos(.35)},{expected.getPos},"river spline pos")
        samePoints({river.spline:getNormal(.35)},{expected.getNormal},"river normal")
        near(river.spline.totalArcLen,expected.totalArcLen,"river arcLen")
        near(river.spline:getClosestTtoPoint({x=280,y=300}),
            expected.getClosest,"river nearest t")
        near(river:distanceToShore({x=280,y=300}),
            expected.distanceToShore,"river distance to shore")
        assert(#river.waterWidths==#expected.waterWidths)
        assert(#river.shoreWidths==#expected.shoreWidths)
        for k=1,#expected.waterWidths do
            near(river.waterWidths[k],expected.waterWidths[k],"river water width")
            near(river.shoreWidths[k],expected.shoreWidths[k],"river shore width")
        end
    end
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
