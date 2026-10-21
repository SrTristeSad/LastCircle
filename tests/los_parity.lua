-- Compare 549 wall/window/door/stair/roof rays against ORIGINAL
-- survev/survev shared/utils/collisionHelpers.ts.
local G=require("src.survev.los_geometry")
local fixture=assert(loadfile(assert(arg[1])))()
local counts={rays=0,segment=0,circle=0,visible=0,blocked=0}
local function close(a,b,where)
    assert(type(a)=="number" and type(b)=="number",where.." bad numbers")
    assert(math.abs(a-b)<2e-7,
        string.format("%s source=%.12g lua=%.12g",where,b,a))
end
local function point(a,b,where)
    close(a.x,b.x,where..".x")
    close(a.y,b.y,where..".y")
end
for i,c in ipairs(fixture.segmentCases) do
    local hit=G.intersectSegment(c.col,c.p,c.q)
    assert((hit~=nil)==(c.expected~=nil),"segment intersection "..i)
    if hit then point(hit.point,c.expected,"segment "..i) end
    counts.segment=counts.segment+1
end
for i,c in ipairs(fixture.circleCases) do
    local hit=G.intersectCircle(c.col,c.pos,5.5)
    assert((hit~=nil)==(c.expected~=nil),"circle intersection "..i)
    if hit then
        point(hit.dir,c.expected.dir,"circle direction "..i)
        close(hit.pen,c.expected.pen,"circle penetration "..i)
    end
    counts.circle=counts.circle+1
end
for i,c in ipairs(fixture.fixtures) do
    local objects={}
    for _,o in ipairs(c.obstacles) do objects[o.__id]=o end
    local obstacles=G.obstacles(objects)
    assert(#obstacles==#c.obstacles,"source obstacle definition missing "..i)
    local result=G.scanCollider(c.box,obstacles,c.pos,c.layer or 0,0,5.5,5.5,5)
    assert((result~=nil)==(c.expected~=nil),
        "source scan vs Lua mismatch in case "..i.." source wall "..fixture.wallType)
    if result then
        close(result.dist,c.expected.dist,"ray "..i)
        counts.visible=counts.visible+1
    else counts.blocked=counts.blocked+1 end
    counts.rays=counts.rays+1
end
assert(counts.rays>=500 and counts.visible>0 and counts.blocked>0,
    "LOS fixtures insufficient")
print(string.format("Survev LOS parity passed: %d ray scans, %d visible, %d blocked; %d segment + %d circle tests",
    counts.rays,counts.visible,counts.blocked,counts.segment,counts.circle))
