-- Survev map.ts:renderTerrain in LÖVE2D, using original MapMsg polygons,
-- terrainGen.ts/River.ts points and MapDefs biome colors. No invented tiles.
-- This renders only the terrain layers, NOT objects/interiors/animations.
local Terrain=require("src.survev.terrain_gen")
local Config=require("src.survev.game_config")
local Palettes=require("src.survev.map_colors")
local Renderer={}
Renderer.__index=Renderer

local function rgba(color)
    assert(type(color)=="number","upstream map color must be numeric")
    local rgb=color%0x1000000
    return math.floor(rgb/65536)%256/255,
        math.floor(rgb/256)%256/255,
        rgb%256/255
end

local function geometryMesh(points,color)
    if not points or #points<3 then return nil end
    local vertices={}
    local flat={}
    local r,g,b=rgba(color)
    for _,point in ipairs(points) do
        flat[#flat+1]=point.x
        flat[#flat+1]=point.y
    end
    -- LÖVE triangulates the exact upstream polygon; vertices are never
    -- resampled or replaced with an imagined shape.
    local triangles=love.math.triangulate(flat)
    for _,triangle in ipairs(triangles) do
        for i=1,#triangle,2 do
            vertices[#vertices+1]={triangle[i],triangle[i+1],0,0,r,g,b,1}
        end
    end
    if #vertices==0 then return nil end
    return love.graphics.newMesh(vertices,"triangles","static")
end

function Renderer.new(mapMsg)
    assert(mapMsg and mapMsg.mapName and mapMsg.seed~=nil,"MapMsg required")
    local palette=Palettes[mapMsg.mapName]
    assert(palette,"Survev map biome is unknown: "..mapMsg.mapName)
    local terrain=Terrain.generate(mapMsg)
    local self=setmetatable({
        map=mapMsg,colors=palette.colors,terrain=terrain,
        shore=geometryMesh(terrain.shore,palette.colors.beach),
        grass=geometryMesh(terrain.grass,palette.colors.grass),
        groundPatches={[0]={},[1]={}},rivers={},
    },Renderer)

    -- Same render order as original client/src/map.ts:renderTerrain.
    for _,patch in ipairs(mapMsg.groundPatches or {}) do
        if patch.order==0 or patch.order==1 then
            local polygon=Terrain.patchPolygon(patch,mapMsg.seed)
            if #polygon>=3 then
                local mesh=geometryMesh(polygon,patch.color)
                if mesh then
                    self.groundPatches[patch.order][#self.groundPatches[patch.order]+1]=mesh
                end
            end
        end
    end
    for _,river in ipairs(terrain.rivers) do
        local bankColor=river.looped
            and (palette.colors.lakeRiverbank or palette.colors.riverbank)
            or palette.colors.riverbank
        local waterColor=river.looped
            and (palette.colors.lakeWater or palette.colors.water)
            or palette.colors.water
        self.rivers[#self.rivers+1]={
            bank=geometryMesh(river.shorePoly,bankColor),
            water=geometryMesh(river.waterPoly,waterColor),
        }
    end
    return self
end

function Renderer:draw(camera,width,height)
    local g=love.graphics
    local map=self.map
    local c=self.colors
    local r,b,bl=rgba(c.background)
    g.clear(r,b,bl)
    local px=camera:m_z()
    local origin=camera:m_pointToScreen({x=0,y=0})
    g.push()
    g.translate(origin.x,origin.y)
    g.scale(px,-px)

    -- The original Survev ground is first ocean-colored, followed by
    -- beach polygon and then grass inset polygon.
    g.setColor(rgba(c.water))
    g.rectangle("fill",0,0,map.width,map.height)
    g.setColor(1,1,1,1)
    if self.shore then g.draw(self.shore) end
    if self.grass then g.draw(self.grass) end
    for _,mesh in ipairs(self.groundPatches[0]) do g.draw(mesh) end
    for _,river in ipairs(self.rivers) do
        if river.bank then g.draw(river.bank) end
    end
    for _,river in ipairs(self.rivers) do
        if river.water then g.draw(river.water) end
    end

    -- Original grid spacing and relative thickness/alpha.
    local bounds={
        left=math.max(0,camera.m_pos.x-width/(2*px)-1),
        right=math.min(map.width,camera.m_pos.x+width/(2*px)+1),
        low=math.max(0,camera.m_pos.y-height/(2*px)-1),
        high=math.min(map.height,camera.m_pos.y+height/(2*px)+1),
    }
    g.setLineWidth(2/camera.m_ppu)
    g.setColor(0,0,0,.15)
    local spacing=Config.map.gridSize
    for x=math.ceil(bounds.left/spacing)*spacing,bounds.right,spacing do
        g.line(x,bounds.low,x,bounds.high)
    end
    for y=math.ceil(bounds.low/spacing)*spacing,bounds.high,spacing do
        g.line(bounds.left,y,bounds.right,y)
    end
    g.setColor(1,1,1,1)
    for _,mesh in ipairs(self.groundPatches[1]) do g.draw(mesh) end
    g.pop()
    g.setLineWidth(1)
    g.setColor(1,1,1,1)
end
function Renderer:release()
    local function releaseMesh(mesh)
        if mesh and mesh.release then mesh:release() end
    end
    releaseMesh(self.shore);releaseMesh(self.grass)
    for _,river in ipairs(self.rivers) do
        releaseMesh(river.bank);releaseMesh(river.water)
    end
    for _,order in ipairs({0,1}) do
        for _,mesh in ipairs(self.groundPatches[order]) do releaseMesh(mesh) end
    end
end
Renderer.hexToRgb=rgba
return Renderer
