-- Survev minimap: original map.ts:renderMap/getMinimapRender geometry.
-- Terrain mesh comes from the SAME live TerrainRenderer as the main world.
-- Static map is cached in a LÖVE canvas; dynamic marker reads the current
-- authoritative active player. LÖVE dimensions and panel styling are adapted
-- from the PIXI/browser UI, never claimed pixel-perfect CSS fidelity.
local Camera=require("src.survev.camera")
local TerrainRenderer=require("src.survev.map_renderer")
local Shapes=require("src.survev.minimap_defs")
local Transform=require("src.survev.building_surfaces").transform
local Mini={}
Mini.__index=Mini
local function clamp(v,a,b)return math.max(a,math.min(v,b))end
local function rgb(c)
    c=c%16777216
    return math.floor(c/65536)%256/255,
        math.floor(c/256)%256/255,c%256/255
end

function Mini.new()
    return setmetatable({
        map=nil,canvas=nil,commands={},ownTerrain=nil,expanded=false,
        visible=true,builds=0,
    },Mini)
end
function Mini:toggleExpanded() self.expanded=not self.expanded end
function Mini:toggleVisible() self.visible=not self.visible end
function Mini:reset()
    if self.canvas and self.canvas.release then self.canvas:release() end
    if self.ownTerrain then self.ownTerrain:release() end
    self.map,self.canvas,self.commands,self.ownTerrain=nil,nil,{},nil
end
function Mini:project(point,side,map)
    map=map or self.map
    assert(map and map.width>0 and map.height>0)
    local scale=side/math.max(map.width,map.height)
    return {
        x=(side-map.width*scale)*.5+point.x*scale,
        y=(side-map.height*scale)*.5+(map.height-point.y)*scale,
    }
end

-- MapMsg.objects is already a static summary. Don't use UpdateMsg
-- objects here: the original map's minimap draws pre-generated objects.
function Mini:mapShapes(map)
    local sorted={}
    for i,obj in ipairs(map.objects or {}) do
        local def=Shapes[obj.type]
        if def and def.shapes then
            sorted[#sorted+1]={def=def,obj=obj,index=i,z=def.zIdx}
        end
    end
    table.sort(sorted,function(a,b)
        if a.z==b.z then return a.index<b.index end
        return a.z<b.z
    end)
    local commands={}
    for _,item in ipairs(sorted) do
        local obj=item.obj
        for _,shape in ipairs(item.def.shapes) do
            local col=Transform(shape.collider,obj.pos,obj.ori or 0,
                obj.scale or 1)
            commands[#commands+1]={
                type=col.type,color=shape.color,zIdx=item.z,
                collider=col,scale=shape.scale or 1,objType=obj.type,
            }
        end
    end
    return commands
end
function Mini:build(map,terrain)
    assert(map and map.mapName and map.seed and map.width and map.height)
    if self.map==map then return end
    self:reset()
    self.map=map
    self.commands=self:mapShapes(map)
    local g=love.graphics
    local size=512
    if not (g.newCanvas and g.setCanvas) then return end
    local can=g.newCanvas(size,size)
    can:setFilter("linear","linear")
    self.canvas=can
    self.builds=self.builds+1
    if not terrain then
        terrain=TerrainRenderer.new(map)
        self.ownTerrain=terrain
    end
    -- The original world meshes are drawn once into the map texture, just
    -- like renderMap()'s PIXI RenderTexture path.
    local miniCamera=Camera.new()
    miniCamera.m_pos={x=map.width*.5,y=map.height*.5}
    miniCamera.m_ppu=1
    miniCamera.m_zoom=size/math.max(map.width,map.height)
    miniCamera.m_screenWidth=size
    miniCamera.m_screenHeight=size
    g.push("all")
    g.setCanvas(can)
    terrain:draw(miniCamera,size,size)
    g.setLineWidth(1)
    for _,entry in ipairs(self.commands) do
        local col=entry.collider
        local scale=entry.scale
        g.setColor(rgb(entry.color))
        if entry.type==0 then
            local at=self:project(col.pos,size,map)
            local factor=size/math.max(map.width,map.height)
            g.circle("fill",at.x,at.y,col.rad*scale*factor)
        elseif entry.type==1 then
            local center={x=(col.min.x+col.max.x)*.5,
                y=(col.min.y+col.max.y)*.5}
            local dx=(col.max.x-col.min.x)*scale*.5
            local dy=(col.max.y-col.min.y)*scale*.5
            local at=self:project({x=center.x-dx,y=center.y+dy},size,map)
            local factor=size/math.max(map.width,map.height)
            g.rectangle("fill",at.x,at.y,dx*2*factor,dy*2*factor)
        end
    end
    g.setColor(1,1,1,.8)
    for _,place in ipairs(map.places or {}) do
        if type(place.pos)=="table" and type(place.name)=="string" then
            -- Original places are normalized to map HEIGHT on both axes.
            local at=self:project({
                x=place.pos.x*map.height,
                y=place.pos.y*map.height
            },size,map)
            g.print(place.name,at.x,at.y)
        end
    end
    g.pop()
end
function Mini:draw(state,w,h,terrain)
    if not self.visible and not self.expanded then return false end
    if not state or not state.map then return false end
    self:build(state.map,terrain)
    local g=love.graphics
    local wide=self.expanded
    local side=wide and math.max(100,math.min(w-120,h-125)) or
        math.min(205,math.max(100,w*.24))
    local x=wide and (w-side)*.5 or w-side-15
    local y=wide and (h-side)*.5 or 91
    if wide then
        g.setColor(0,0,0,.75)
        g.rectangle("fill",0,0,w,h)
    end
    g.setColor(.025,.085,.09,.92)
    g.rectangle("fill",x-5,y-24,side+10,side+31,6,6)
    g.setColor(.87,.94,.88)
    g.printf(wide and "MAPA - M para fechar" or "MINIMAPA [M] ampliar",
        x,y-19,side,"center")
    if self.canvas then
        g.setColor(1,1,1,1)
        local iw,ih=self.canvas:getDimensions()
        g.draw(self.canvas,x,y,0,side/iw,side/ih)
    end
    local active=state.objects and state.objects[state.activeId]
    if active and active.pos then
        local marker=self:project(active.pos,side,state.map)
        local px,py=x+marker.x,y+marker.y
        g.setColor(.04,.10,.10,.9)
        g.circle("fill",px,py,wide and 9 or 7)
        g.setColor(.99,.88,.31)
        g.circle("fill",px,py,wide and 6 or 4)
        local dir=active.dir or {x=1,y=0}
        g.setLineWidth(2)
        g.line(px,py,px+dir.x*(wide and 17 or 12),
            py-dir.y*(wide and 17 or 12))
        g.setLineWidth(1)
    end
    g.setColor(.87,.96,.87,.95)
    g.rectangle("line",x,y,side,side)
    g.setColor(1,1,1,1)
    return true
end
return Mini
