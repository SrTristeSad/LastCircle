-- Live packet visualization for porting, NOT a substitute for the original
-- Survev renderer. Uses the ORIGINAL player-base-01 artwork (SVG -> PNG).
-- Coordinates, player positions and map dimensions are server-authoritative.
local Camera=require("src.survev.camera")
local Objects=require("src.survev.object_serialize_fns")
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
        player=image("assets/survev/img/player/player-base-01.png"),
        warning="DIAGNOSTICO DE DADOS - RENDERIZADOR SURVEV AINDA NAO PORTADO",
    },V)
end
local function drawCentered(asset,x,y,dia,angle)
    local w,h=asset:getDimensions()
    local scale=dia/math.max(w,h)
    love.graphics.draw(asset,x,y,angle or 0,scale,scale,w*.5,h*.5)
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
    local origin=cam:m_pointToScreen({x=0,y=0})
    g.setColor(.24,.31,.25)
    g.rectangle("fill",origin.x,origin.y-map.height*cam:m_z(),
        map.width*cam:m_z(),map.height*cam:m_z())
    g.setColor(.52,.70,.56,.9)
    g.setLineWidth(2)
    g.rectangle("line",origin.x,origin.y-map.height*cam:m_z(),
        map.width*cam:m_z(),map.height*cam:m_z())
    g.setLineWidth(1)

    -- Debug markers intentionally do not pretend to reproduce object graphics.
    for _,obj in pairs(state.objects) do
        if obj.pos then
            local pt=cam:m_pointToScreen(obj.pos)
            if pt.x>-80 and pt.x<w+80 and pt.y>-80 and pt.y<h+80 then
                if obj.__type==Objects.Type.Player and self.player then
                    g.setColor(1,1,1)
                    drawCentered(self.player,pt.x,pt.y,2*cam:m_z()*(obj.scale or 1))
                elseif obj.__type==Objects.Type.Player then
                    g.setColor(.96,.93,.75)
                    g.circle("line",pt.x,pt.y,cam:m_z())
                else
                    g.setColor(.84,.86,.62)
                    g.circle("line",pt.x,pt.y,7)
                    g.print(tostring(obj.__type)..":"..tostring(obj.__id),pt.x+8,pt.y-10)
                end
            end
        end
    end

    local active=state.objects[state.activeId]
    local info="MAPA: "..tostring(map.mapName)..
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
        g.print(string.format("Posicao recebida: %.2f, %.2f",active.pos.x,active.pos.y),18,54)
    end
    g.setColor(.98,.57,.38)
    g.printf(self.warning,0,h-39,w,"center")
end
return V
