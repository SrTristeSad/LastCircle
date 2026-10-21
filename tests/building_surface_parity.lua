-- Test against original TypeScript collider.transform + Map.getGroundSurface
-- source building material selection (not fake materials).
local Surfaces=require("src.survev.building_surfaces")
local source=assert(loadfile(assert(arg[1])))()
local buildings={}
for _,obj in ipairs(source.buildings) do buildings[obj.__id]=obj end
local count=0
local function near(a,b,label)
    assert(type(a)=="number" and type(b)=="number")
    if math.abs(a-b)>1e-8 then
        error(string.format("%s expected %.12f got %.12f",label,b,a))
    end
    count=count+1
end
for i,test in ipairs(source.cases) do
    if test.sourceCol then
        local obj=buildings[test.transformFor]
        local actual=Surfaces.transform(test.sourceCol,obj.pos,obj.ori)
        assert(actual.type==test.transformed.type)
        if actual.type==0 then
            near(actual.pos.x,test.transformed.pos.x,"circle pos x")
            near(actual.pos.y,test.transformed.pos.y,"circle pos y")
            near(actual.rad,test.transformed.rad,"circle radius")
        else
            near(actual.min.x,test.transformed.min.x,"aabb min x")
            near(actual.min.y,test.transformed.min.y,"aabb min y")
            near(actual.max.x,test.transformed.max.x,"aabb max x")
            near(actual.max.y,test.transformed.max.y,"aabb max y")
        end
    end
    local actual=Surfaces.getBuildingSurface(buildings,test.pos,test.layer)
    local exp=test.expected
    if exp==nil then
        assert(actual==nil,"expected no floor material, case "..i)
    else
        assert(actual,"missing Survev floor surface at "..i)
        assert(actual.type==exp.type,
            "case "..i.." expected "..exp.type.." got "..actual.type)
        assert(actual.buildingId==exp.buildingId,
            "surface should come from same original building id case "..i)
        near(actual.zIdx,exp.zIdx,"source floor priority")
    end
end
print("Building floor materials: "..#source.cases.." positions and "..
    count.." original collider values matched TypeScript")
