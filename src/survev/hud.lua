-- Survev client/src/ui/ui2.ts: UI state projection and initial LÖVE HUD.
-- Live mode uses ONLY authoritative UpdateMsg localData. Offline preview is
-- explicitly a simulated loadout, never a real inventory or combat system.
-- Graphics layout is adapted for LÖVE; not an exact port of original CSS.
local Game=require("src.survev.game_config")
local Gear=require("src.survev.equipment_art")
local HUD={}
HUD.__index=HUD
local function clamp(v,a,b) return math.max(a,math.min(v,b)) end
local healthSteps={
    {100,{179,179,179}},{100,{255,255,255}},
    {75,{255,255,255}},{75,{255,158,158}},
    {25,{255,82,82}},{25,{255,0,0}},
    {0,{255,0,0}}
}
function HUD.healthColor(value,downed)
    if downed then return {255,0,0} end
    value=clamp(value or 0,0,100)
    local i=1
    while i<#healthSteps and healthSteps[i][1]>math.ceil(value) do i=i+1 end
    local a,b=healthSteps[math.max(i-1,1)],healthSteps[i]
    local dif=b[1]-a[1]
    local t=dif==0 and 0 or clamp((value-a[1])/dif,0,1)
    local rgb={}
    for n=1,3 do rgb[n]=math.floor(a[2][n]*(1-t)+b[2][n]*t) end
    return rgb
end
function HUD.boostSegments(amount)
    local breakpoints=Game.player.boostBreakpoints
    local total=0
    for _,n in ipairs(breakpoints) do total=total+n end
    local left=clamp(amount or 0,0,100)/100
    local segments={}
    for i,n in ipairs(breakpoints) do
        local width=n/total
        segments[i]=clamp(left/width,0,1)
        left=math.max(left-width,0)
    end
    return segments
end
function HUD.project(state)
    if not state or not state.joined or not state.objects then return nil end
    local actor=state.objects[state.activeId]
    if not actor then return nil end
    local d=state.localData or {}
    local health=d.health~=nil and
        (actor.dead and 0 or math.max(d.health,1)) or nil
    local equipped=d.curWeapIdx~=nil and d.curWeapIdx+1 or nil
    local slots={}
    for i=1,Game.WeaponSlot.Count do
        local item=(d.weapons and d.weapons[i]) or {}
        local def=Gear.weapons[item.type or ""]
        local ammo=item.ammo
        if i==Game.WeaponSlot.Throwable+1 then
            ammo=d.inventory and d.inventory[item.type or ""] or nil
        end
        slots[i]={
            index=i-1,type=item.type or "",name=def and def.name or "",
            equipped=equipped==i,ammo=ammo,kind=def and def.type or nil,
            icon=def and def.world and def.world.asset or nil,
            tint=def and def.world and def.world.tint or 0xffffff,
        }
    end
    local active=equipped and slots[equipped] or nil
    local def=active and Gear.weapons[active.type] or nil
    local clip=def and def.type=="gun" and active.ammo or nil
    local reserve=def and def.type=="gun" and d.inventory
        and d.inventory[def.ammoType] or nil
    return {
        localPreview=not not state.offlinePreview,
        health=health,boost=d.boost,downed=not not actor.downed,
        healthColor=health and HUD.healthColor(health,actor.downed) or nil,
        boostSegments=d.boost~=nil and HUD.boostSegments(d.boost) or nil,
        slots=slots,active=active,clip=clip,reserve=reserve,
        actor=actor,scope=d.scope,
    }
end
local function rgba(c,alpha)
    if type(c)=="table" then
        return c[1]/255,c[2]/255,c[3]/255,alpha or 1
    end
    c=c or 0xffffff
    return math.floor(c/65536)%256/255,math.floor(c/256)%256/255,
        c%256/255,alpha or 1
end
local function panel(g,x,y,w,h,selected)
    g.setColor(.045,.08,.10,.89)
    g.rectangle("fill",x,y,w,h,6,6)
    g.setColor(selected and .97 or .42,selected and .80 or .62,
        selected and .32 or .65,.88)
    g.setLineWidth(selected and 2 or 1)
    g.rectangle("line",x+.5,y+.5,w-1,h-1,6,6)
    g.setLineWidth(1)
end
function HUD.new()
    return setmetatable({cache={},missing={}},HUD)
end
function HUD:image(path)
    if not path then return nil end
    if self.cache[path]~=nil then return self.cache[path] or nil end
    local filename="assets/survev/img/"..path
    if not love.filesystem.getInfo(filename) then
        self.missing[filename]=true;self.cache[path]=false;return nil
    end
    local ok,img=pcall(love.graphics.newImage,filename)
    if not ok then
        self.missing[filename]=true;self.cache[path]=false;return nil
    end
    img:setFilter("linear","linear")
    self.cache[path]=img
    return img
end
function HUD:draw(state,w,h)
    local model=HUD.project(state)
    if not model then return false end
    local g=love.graphics
    local baseX=math.max(8,w-355)
    local baseY=math.max(105,h-343)
    panel(g,baseX,baseY,343,153,false)
    g.setColor(.76,.91,.80)
    g.printf(model.localPreview and "INVENTARIO • TESTE LOCAL"
        or "INVENTARIO • SERVIDOR",baseX+4,baseY+8,335,"center")
    for i,slot in ipairs(model.slots) do
        local x,y=baseX+10+(i-1)*82,baseY+34
        panel(g,x,y,76,74,slot.equipped)
        g.setColor(.96,.97,.88)
        g.print(tostring(i),x+6,y+4)
        local image=self:image(slot.icon)
        if image then
            local iw,ih=image:getDimensions()
            local scale=44/math.max(iw,ih)
            g.setColor(rgba(slot.tint))
            g.draw(image,x+38,y+35,0,scale,scale,iw*.5,ih*.5)
        elseif slot.name~="" then
            g.setColor(.92,.95,.89)
            g.printf(slot.name,x+2,y+32,72,"center")
        end
        if slot.ammo~=nil and slot.kind=="gun" then
            g.setColor(.94,.94,.85)
            g.printf(tostring(slot.ammo),x+3,y+55,69,"right")
        end
    end
    g.setColor(.93,.94,.82)
    g.printf(model.active and model.active.name or "—",
        baseX+12,baseY+115,167,"left")
    if model.clip~=nil then
        g.setColor(.97,.89,.59)
        g.printf(tostring(model.clip).." / "..
            (model.reserve~=nil and tostring(model.reserve) or "—"),
            baseX+173,baseY+115,160,"right")
    end
    -- True four-part boost ratios from GameConfig.player.boostBreakpoints.
    local gaugeX=math.max(14,w*.5-182)
    local gaugeY=math.max(100,h-260)
    local gaugeW=math.min(364,w-28)
    panel(g,gaugeX,gaugeY,gaugeW,83,false)
    g.setColor(.82,.92,.85)
    g.print("HP",gaugeX+10,gaugeY+8)
    local gx,gw=gaugeX+49,gaugeW-62
    g.setColor(.18,.23,.22)
    g.rectangle("fill",gx,gaugeY+11,gw,17,4,4)
    if model.healthColor then
        g.setColor(rgba(model.healthColor))
        g.rectangle("fill",gx,gaugeY+11,gw*
            clamp(model.health,0,100)/100,17,4,4)
    end
    g.setColor(.95,.96,.89)
    g.printf(model.health and tostring(math.floor(model.health+.5))
        or "—",gx,gaugeY+30,gw,"center")
    g.setColor(.82,.92,.85)
    g.print("BOOST",gaugeX+10,gaugeY+59)
    if model.boostSegments then
        local gap=3
        local slotW=(gaugeW-100-3*gap)/4
        for i,fill in ipairs(model.boostSegments) do
            local x=gaugeX+83+(i-1)*(slotW+gap)
            g.setColor(.18,.23,.22)
            g.rectangle("fill",x,gaugeY+60,slotW,12,2,2)
            g.setColor(.95,.67,.24)
            g.rectangle("fill",x,gaugeY+60,slotW*fill,12,2,2)
        end
    end
    -- Keep armor badges compact: complete localized names can wrap and
    -- accidentally overlap the weapon slot caption on 720p displays.
    local gearNames={}
    for _,info in ipairs({
        {model.actor.backpack or "","Moch."},
        {model.actor.helmet or "","Cap."},
        {model.actor.chest or "","Colete"},
    }) do
        local def=Gear.gear[info[1]]
        if def then
            gearNames[#gearNames+1]=info[2].." "..tostring(def.level)
        end
    end
    if #gearNames>0 then
        g.setColor(.82,.90,.82)
        g.printf(table.concat(gearNames,"  |  "),
            baseX,baseY-20,343,"center")
    end
    g.setColor(1,1,1,1)
    return true
end
return HUD
