-- LastCircle: etapa de inspeção fiel dos recursos visuais Survev.
-- NÃO é jogo, nem substitui cliente/server originais. Referência:
-- https://github.com/survev/survev @ c6185e31fe25a4a07def77a2bb25b1710bda90ac
-- O protótipo genérico anterior está guardado no ramo historico-prototipo-generico.

local Camera = require("src.survev.camera")
local Binds = require("src.survev.input_bindings")
local Config = require("src.survev.game_config")

local camera = Camera.new()
local tile, logo, selected
local index, messages = 1, {}
local samples = {
    {"player/player-base-01.png", "Player: player-base-01.svg"},
    {"player/player-hands-01.png", "Player: player-hands-01.svg"},
    {"map/map-barrel-01.png", "Mapa: map-barrel-01.svg"},
    {"map/map-airdrop-01.png", "Mapa: map-airdrop-01.svg"},
    {"guns/gun-famas-01.png", "Arma: gun-famas-01.svg"},
    {"loot/loot-medical-healthkit.png", "Loot: loot-medical-healthkit.svg"},
    {"gui/crosshair.png", "Interface: crosshair.svg"},
}
local function loadImage(path)
    if not love.filesystem.getInfo(path) then
        return nil
    end
    local success, result = pcall(love.graphics.newImage, path)
    if success then
        result:setFilter("linear", "linear")
        return result
    end
    messages[#messages + 1] = path .. ": " .. tostring(result)
    return nil
end

local function openSample()
    selected = loadImage("assets/survev/img/" .. samples[index][1])
end

function love.load()
    love.window.setTitle("LastCircle - Porte Survev em Lua | Verificação visual")
    tile = loadImage("assets/survev/img/intro/map_tile.png")
    logo = loadImage("assets/survev/img/survev_logo_full.png")
    openSample()
end

function love.resize(w, h)
    camera.m_screenWidth, camera.m_screenHeight = w, h
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if key == "right" or key == "d" then
        index = index % #samples + 1
        openSample()
    elseif key == "left" or key == "a" then
        index = (index - 2) % #samples + 1
        openSample()
    end
end

local function drawCentered(image, cx, cy, maxSize)
    if not image then return end
    local iw, ih = image:getDimensions()
    local scale = math.min(maxSize / iw, maxSize / ih, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, cx, cy, 0, scale, scale, iw / 2, ih / 2)
end

function love.draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    camera.m_screenWidth, camera.m_screenHeight = w, h
    lg.clear(.18, .37, .22)
    if tile then
        local tw, th = tile:getDimensions()
        lg.setColor(1, 1, 1)
        for y = 0, h, th do
            for x = 0, w, tw do
                lg.draw(tile, x, y)
            end
        end
    end

    lg.setColor(.04, .10, .09, .88)
    lg.rectangle("fill", math.max(0, w / 2 - 345), 22, math.min(690, w), h - 44, 8)

    if logo then
        drawCentered(logo, w / 2, 125, 330)
    else
        lg.setColor(.96, .98, .94)
        lg.printf("SURVEV (ARTE ORIGINAL NÃO PREPARADA)", 0, 96, w, "center")
    end

    lg.setColor(1, 1, 1)
    lg.printf("PORTABILIDADE LUA - INSPEÇÃO DE ASSETS", 0, 195, w, "center")
    lg.setColor(.84, .91, .82)
    lg.printf("Esta tela verifica artes e módulos do original. Não é uma partida jogável.",
        0, 225, w, "center")
    lg.printf("Origem: survev/survev  |  Protocolo: " .. Config.protocolVersion,
        0, 249, w, "center")

    if selected then
        drawCentered(selected, w / 2, h / 2 + 20, math.min(250, h * .3))
    else
        lg.setColor(1, .62, .48)
        lg.printf("Recurso ausente. Execute o empacotamento de artes originais.",
            0, h / 2, w, "center")
    end
    lg.setColor(1, 1, 1)
    lg.printf(samples[index][2] .. "  (" .. index .. "/" .. #samples .. ")", 0, h - 133, w, "center")
    lg.printf("A/D ou setas: alternar arte original   |   ESC: sair", 0, h - 101, w, "center")
    lg.setColor(.79, .83, .78)
    lg.printf("Câmera: 16 px/unid., zoom 1.5   |   Interagir: "
        .. Binds.default.Interact[2]:upper() .. "   |   Guardar arma: "
        .. Binds.default.StowWeapons[2]:upper(), 0, h - 70, w, "center")
    if #messages > 0 then
        lg.setColor(1, .52, .45)
        lg.printf("Ocorreram erros de carregamento de imagens. Veja o console.",
            0, h - 47, w, "center")
    end
end
