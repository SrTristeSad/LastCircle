local Doors=require("src.survev.door_visual")
local Registry=require("src.survev.map_obstacle_art")
local source=assert(loadfile(assert(arg[1])))()
local render=Doors.new()
local measurements=0
local function near(a,b,name)
    assert(type(a)=="number" and type(b)=="number",name.." not numbers")
    assert(math.abs(a-b)<1e-8,
        string.format("%s source=%.12g lua=%.12g",name,b,a))
    measurements=measurements+1
end
local function point(a,b,name)
    assert(a and b,name.." missing point")
    near(a.x,b.x,name..".x")
    near(a.y,b.y,name..".y")
end
for i,stage in ipairs(source.stages) do
    local o=stage.frame
    assert(Registry[o.type] and Registry[o.type].door)
    local objects={[18]=o}
    render:update(objects,stage.dt)
    local display=render:visual(o)
    point(display.pos,stage.expected.pos,"frame "..i.." position")
    near(display.rot,stage.expected.rot,"frame "..i.." rotation")
    local casing=render:casing(o)
    assert((casing~=nil)==(stage.expected.casingPos~=nil),
        "original casing presence mismatch frame "..i)
    if casing then
        point(casing.pos,stage.expected.casingPos,"frame "..i.." casing")
        assert(casing.img.asset,"casing artwork must come from original")
    end
    point(o.pos,stage.frame.pos,"network position must remain unchanged")
end
render:update({},.1)
assert(not next(render.entries),"door deleted by authoritative snapshot must clear animation")
assert(#source.stages>=18)
print("Survev door movement, shortest angle and original casing parity:",
    #source.stages,"frames,",measurements,"numeric checks")
