-- Source-registered Survev inventory display. ORIGINAL 25 bag keys,
-- source capacities by backpack level, and UpdateMsg localData only.
-- Full-panel layout is adapted to LÖVE; no browser UI/CSS copied.
local Source=require("src.survev.loot_art")
local Gear=require("src.survev.equipment_art")
local Inventory={}
Inventory.__index=Inventory
function Inventory.project(state)
    if not state or not state.joined or not state.objects then return nil end
    local actor=state.objects[state.activeId]
    if not actor then return nil end
    local inventory=state.localData and state.localData.inventory or nil
    local equipped=actor.backpack
    -- Unknown backpack in live state must NOT be treated as capacity zero.
    local level=nil
    if equipped=="" or equipped=="backpack00" then level=0 end
    if Gear.gear[equipped or ""] then
        level=Gear.gear[equipped].level
    end
    local rows={}
    for i,name in ipairs(Source.bagKeys) do
        local def=Source.loot[name]
        local capacities=Source.bagSizes[name]
        local max=level and capacities and capacities[level+1] or nil
        local count=inventory and inventory[name] or nil
        rows[i]={type=name,category=def and def.type or nil,
            name=def and def.name or name,
            count=count,max=max,
            texture=def and def.asset or nil,
            tint=def and def.tint or 0xffffff,
        }
    end
    return {
        rows=rows,level=level,backpack=equipped,
        preview=state.offlinePreview or false,
        available=inventory~=nil,
    }
end
function Inventory.new()
    return setmetatable({visible=false,cache={},missing={},
        notice=nil,noticeTime=0},Inventory)
end
function Inventory:toggle()
    self.visible=not self.visible
    return self.visible
end
-- The inventory's grid is shared by rendering and mouse hit testing.
local function geometry(width,height)
    local x,y,w,h,rowsPerColumn,rowHeight,slotW=geometry(width,height)
    local perCol=math.ceil(#Source.bagKeys/2)
    local rowHeight=math.min(34,(h-136)/perCol)
    local slotW=(w-34)/2
    return x,y,w,h,perCol,rowHeight,slotW
end
function Inventory:hitTest(state,width,height,px,py)
    if not self.visible then return nil end
    local model=Inventory.project(state)
    if not model then return nil end
    local x,y,_,_,perCol,rowHeight,slotW=geometry(width,height)
    if rowHeight<=3 then return nil end
    for i,item in ipairs(model.rows) do
        local col=math.floor((i-1)/perCol)
        local row=(i-1)%perCol
        local left=x+10+col*(slotW+14)
        local top=y+100+row*rowHeight
        if px>=left and px<=left+slotW and
            py>=top and py<=top+rowHeight-3 then
            return item
        end
    end
    return nil
end
function Inventory:flash(message)
    self.notice=message
    self.noticeTime=3
end
function Inventory:update(dt)
    self.noticeTime=math.max(0,self.noticeTime-math.max(0,dt or 0))
    if self.noticeTime==0 then self.notice=nil end
end
function Inventory:image(path)
    if not path then return nil end
    if self.cache[path]~=nil then return self.cache[path] or nil end
    local file="assets/survev/img/"..path
    if not love.filesystem.getInfo(file) then
        self.cache[path]=false
        self.missing[file]=true
        return nil
    end
    local ok,img=pcall(love.graphics.newImage,file)
    if not ok then
        self.cache[path]=false;self.missing[file]=true
        return nil
    end
    img:setFilter("linear","linear")
    self.cache[path]=img
    return img
end
local function rgba(c)
    return math.floor(c/65536)%256/255,
        math.floor(c/256)%256/255,c%256/255
end
function Inventory:draw(state,width,height)
    if not self.visible then return false end
    local projected=Inventory.project(state)
    if not projected then return false end
    local g=love.graphics
    local w=math.min(680,width-32)
    local h=math.min(570,height-92)
    local x,y=(width-w)*.5,(height-h)*.5
    g.setColor(.025,.07,.08,.96)
    g.rectangle("fill",x,y,w,h,10,10)
    g.setColor(.68,.82,.70,.9)
    g.setLineWidth(2)
    g.rectangle("line",x,y,w,h,10,10)
    g.setLineWidth(1)
    g.setColor(.96,.96,.88)
    g.printf("INVENTARIO  [I / TAB] fechar",x+10,y+10,w-20,"center")
    g.setColor(.72,.84,.79)
    local label=projected.preview and
        "TESTE LOCAL — valores demonstrativos, sem servidor"
        or "DADOS RECEBIDOS DO SERVIDOR SURVEV"
    g.printf(label,x+10,y+38,w-20,"center")
    g.setColor(.86,.9,.85)
    g.printf("Mochila: "..(projected.level~=nil and
        ("nivel "..tostring(projected.level)) or "desconhecida"),
        x+10,y+64,w-20,"center")
    local rows=projected.rows
    for i,item in ipairs(rows) do
        local col=math.floor((i-1)/rowsPerColumn)
        local row=(i-1)%rowsPerColumn
        local left=x+10+col*(slotW+14)
        local top=y+100+row*rowHeight
        g.setColor(.105,.17,.16,(row%2==0) and .96 or .88)
        g.rectangle("fill",left,top,slotW,rowHeight-3,4,4)
        local image=self:image(item.texture)
        if image then
            local iw,ih=image:getDimensions()
            local scale=math.min((rowHeight-7)/math.max(iw,1),
                (rowHeight-7)/math.max(ih,1))
            g.setColor(rgba(item.tint))
            g.draw(image,left+16,top+rowHeight*.48,0,scale,scale,
                iw*.5,ih*.5)
        end
        g.setColor(.94,.94,.85)
        g.print(item.name,left+36,top+5)
        local count=item.count==nil and "—" or tostring(item.count)
        local max=item.max==nil and "—" or tostring(item.max)
        g.setColor(item.count and item.count>0 and {.99,.85,.46}
            or {.7,.78,.74})
        g.printf(count.." / "..max,left+slotW-112,top+5,106,"right")
    end
    g.setColor(.71,.81,.77)
    local footer=projected.preview and
        "Amostra offline: coleta apenas no cenario local."
        or "Botao direito: solicitar descarte (servidor confirma)."
    if self.notice and self.noticeTime>0 then footer=self.notice end
    g.printf(footer,x+10,y+h-29,w-20,"center")
    g.setColor(1,1,1,1)
    return true
end
return Inventory
