local HUD=require("src.survev.hud")
local Config=require("src.survev.game_config")
local source=assert(loadfile(assert(arg[1])))()
assert(source.weaponSlotCount==Config.WeaponSlot.Count)
assert(source.weaponSlotCount==4)
for i,slot in ipairs(source.ammoSource) do
    assert(slot==i-1,"official Survev weapon slot order")
end
local checks=0
local function near(actual,expected,label)
    assert(math.abs(actual-expected)<1e-9,
        string.format("%s expected %0.10f got %0.10f",label,expected,actual))
    checks=checks+1
end
for _,item in ipairs(source.healthCases) do
    local actual=HUD.healthColor(item.value,item.downed)
    for i=1,3 do
        near(actual[i],item.expected[i],"Survev health gradient "..item.value)
    end
end
for _,item in ipairs(source.boostCases) do
    local actual=HUD.boostSegments(item.value)
    assert(#actual==4,"Survev defines four boost bars")
    for i=1,4 do
        near(actual[i],item.expected[i],"Survev boost "..item.value)
    end
end
print("HUD fidelity passed:",checks,
    "numbers from original ui2.ts and GameConfig; four real weapon slots")
