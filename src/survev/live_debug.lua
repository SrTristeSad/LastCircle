-- Live Survev terrain renderer / state inspector. Coastline, river/lake
-- polygons, map palettes, patches and grid are ported from ORIGINAL code.
-- Terrain, player body/hands, buildings and obstacles use original sprite sizes.
local Camera=require("src.survev.camera")
local Objects=require("src.survev.object_serialize_fns")
local MapRenderer=require("src.survev.map_renderer")
local ObstacleArt=require("src.survev.obstacle_art_renderer")
local BuildingArt=require("src.survev.building_renderer")
local PlayerArt=require("src.survev.player_renderer")
local LootArt=require("src.survev.loot_renderer")
local V={}
V.__index=V
local function image(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok,asset=pcall(love.graphics.newImage,path)
    if not ok then return nil end
    asset:setFilter("linear","linear")
    return asset
end
function V.new()
    return setmetatable({
        camera=Camera.new(),
        players=PlayerArt.new(),
        lootArt=LootArt.new(),
        terrainMap=nil,terrainRenderer=nil,obstacleArt=ObstacleArt.new(),
        buildingArt=BuildingArt.new(),
        warning="PISOS, TETOS, PORTAS E RAIOS DE VISAO PORTADOS | CAMADAS FINAIS PENDENTES",
    },V)
end
function V:update(state,dt)
    if not state or not state.objects then return end
    if self.lastUpdateMap~=state.map then
        self.lastUpdateMap=state.map
        self.buildingArt.visibility:reset()
        self.obstacleArt.doors:reset()
    end
    local active=state.objects[state.activeId]
    self.buildingArt:updateVisibility(dt,state.objects,active,state.updateCount)
    self.obstacleArt:update(state.objects,dt)
end
function V:draw(state,w,h)
    local g=love.graphics
    g.setColor(.11,.14,.14)
    g.rectangle("fill",0,0,w,h)
    g.setColor(.8,.88,.82)
    if not state or not state.map then
        g.print("Aguardando MapMsg do servidor Survev...",25,90)
        return
    end
    local map=state.map
    local cam=self.camera
    cam.m_screenWidth,cam.m_screenHeight=w,h
    local tracked=state.objects[state.activeId]
    if not tracked or not tracked.pos then
        for _,obj in pairs(state.objects) do
            if obj.__type==Objects.Type.Player and obj.pos then
                tracked=obj
                break
            end
        end
    end
    if tracked and tracked.pos then
        cam.m_pos=tracked.pos
    else
        cam.m_pos={x=map.width/2,y=map.height/2}
    end
    -- Cache tessellated meshes for the entire session, not on each frame.
    if self.terrainMap~=map then
        if self.terrainRenderer then self.terrainRenderer:release() end
        self.terrainRenderer=MapRenderer.new(map)
        self.terrainMap=map
    end
    self.terrainRenderer:draw(cam,w,h)
    g.setColor(1,1,1)
    -- Original building floor textures precede players and ceiling layers.
    self.buildingArt:drawPhase(state.objects,cam,"floor",w,h,map.mapName)
    self.obstacleArt:draw(state.objects,cam,w,h,map.mapName,"belowPlayer")
    -- Survev original Loot renderer zOrd=13 (below Player zOrd=18).
    self.lootArt:draw(state.objects,cam,w,h)

    -- Debug markers intentionally do not pretend to reproduce object graphics.
    for _,obj in pairs(state.objects) do
        if obj.pos then
            local pt=cam:m_pointToScreen(obj.pos)
            if pt.x>-80 and pt.x<w+80 and pt.y>-80 and pt.y<h+80 then
                if obj.__type==Objects.Type.Player then
                    -- The player now uses source-sized body and TWO actual
                    -- fist-pose hand sprites, not a stretched debug texture.
                    local rendered=self.players:draw(obj,cam,map.mapName)
                    if rendered==0 then
                        g.setColor(.96,.93,.75)
                        g.circle("line",pt.x,pt.y,cam:m_z())
                    end
                elseif obj.__type~=Objects.Type.Obstacle and
                    obj.__type~=Objects.Type.Building and
                    obj.__type~=Objects.Type.Loot then
                    g.setColor(.84,.86,.62)
                    g.circle("line",pt.x,pt.y,7)
                    g.print(tostring(obj.__type)..":"..tostring(obj.__id),pt.x+8,pt.y-10)
                end
            end
        end
    end

    -- Survev draw order around Player (zOrd 18) and roof (about zOrd 750).
    self.obstacleArt:draw(state.objects,cam,w,h,map.mapName,"betweenPlayerAndRoof")
    self.buildingArt:drawPhase(state.objects,cam,"ceiling",w,h,map.mapName)
    self.obstacleArt:draw(state.objects,cam,w,h,map.mapName,"aboveRoof")

    local active=state.objects[state.activeId]
    local info=(state.offlinePreview and "CENARIO LOCAL: " or "MAPA: ")..tostring(map.mapName)..
        " | SEED: "..tostring(map.seed)..
        " | "..tostring(map.width).."x"..tostring(map.height)
    g.setColor(.05,.10,.1,.88)
    g.rectangle("fill",0,0,w,78)
    g.setColor(.97,.98,.90)
    g.print(info,18,10)
    g.print("Jogador: "..tostring(state.localId)..
        "   Ativo: "..tostring(state.activeId)..
        "   Objetos: "..tostring((function()
            local n=0;for _ in pairs(state.objects) do n=n+1 end;return n
        end)())..
        "   UpdateMsg: "..tostring(state.updateCount),18,32)
    if active and active.pos then
        local label=state.offlinePreview and "Posicao simulada local" or "Posicao recebida"
        g.print(string.format("%s: %.2f, %.2f",label,active.pos.x,active.pos.y),18,54)
    end
    if not state.offlinePreview then
        g.setColor(.98,.57,.38)
        g.printf(self.warning,0,h-30,w,"center")
    end
end
return V
