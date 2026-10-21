local Game = require("src.game")

local game
local font, bigFont, smallFont

local function camera()
    local w, h = love.graphics.getDimensions()
    -- O personagem permanece no centro da tela, inclusive nas bordas do mapa.
    return {x = game.player.x - w / 2, y = game.player.y - h / 2}, w, h
end

local function box(x, y, w, h, color, border)
    local g = love.graphics
    g.setColor(color)
    g.rectangle("fill", x, y, w, h, 5)
    if border then
        g.setColor(border)
        g.rectangle("line", x, y, w, h, 5)
    end
end

local function bar(x, y, w, h, value, total, fill)
    box(x, y, w, h, {.09, .14, .13, .85})
    local ratio = math.max(0, math.min(1, value / total))
    if ratio > 0 then box(x + 3, y + 3, (w - 6) * ratio, h - 6, fill) end
end

local function reset()
    game = Game.new()
end

function love.load()
    love.graphics.setBackgroundColor(.08, .17, .12)
    love.graphics.setDefaultFilter("nearest", "nearest")
    font = love.graphics.newFont(17)
    bigFont = love.graphics.newFont(40)
    smallFont = love.graphics.newFont(13)
    reset()
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() return end
    if game.state ~= "playing" then
        if key == "return" or key == "kpenter" then reset() end
        return
    end
    if key == "r" then game:reload()
    elseif key == "1" then game:equip("pistol")
    elseif key == "2" then game:equip("smg")
    elseif key == "e" then game:heal()
    end
end

function love.update(dt)
    if game.state ~= "playing" then return end
    local k = love.keyboard
    local dx = (k.isDown("d") and 1 or 0) - (k.isDown("a") and 1 or 0)
    local dy = (k.isDown("s") and 1 or 0) - (k.isDown("w") and 1 or 0)
    local cam = camera()
    local mouseX, mouseY = love.mouse.getPosition()
    local player = game.player
    local aim = math.atan2(mouseY + cam.y - player.y, mouseX + cam.x - player.x)
    game:update(dt, dx, dy, aim, love.mouse.isDown(1), k.isDown("space", "lshift"))
end

local function drawMinimap(w, h)
    local g = love.graphics
    local sz = 164
    local x, y = w - sz - 20, 20
    box(x - 5, y - 5, sz + 10, sz + 10, {.06, .13, .13, .86}, {.75, .84, .74, .4})
    g.setColor(.31, .53, .32)
    g.rectangle("fill", x, y, sz, sz)
    local scale = sz / game.world.width
    local z = game.zone
    g.setColor(.68, .83, .98)
    g.setLineWidth(1.5)
    g.circle("line", x + z.x * scale, y + z.y * scale, z.radius * scale)
    g.setColor(.9, .36, .3)
    for _, bot in ipairs(game.bots) do
        g.circle("fill", x + bot.x * scale, y + bot.y * scale, 2)
    end
    g.setColor(1, .94, .55)
    g.circle("fill", x + game.player.x * scale, y + game.player.y * scale, 3.7)
    g.setLineWidth(1)
    g.setColor(.91, .95, .88)
    g.setFont(smallFont)
    g.print("MAPA", x + 4, y + 4)
end

local function drawHud(w, h)
    local g = love.graphics
    local p = game.player
    g.setFont(font)
    box(15, 15, 305, 87, {.06, .15, .13, .85}, {.87, .95, .81, .30})
    g.setColor(.96, .98, .90)
    g.print("LASTCIRCLE", 29, 24)
    g.setFont(smallFont)
    g.setColor(.81, .88, .79)
    g.print("Sobreviventes: " .. tostring(#game.bots + (game.state == "dead" and 0 or 1))
        .. "   |   Abates: " .. game.kills, 29, 53)
    g.print(string.format("Zona: %.0f m    |    %.0f s", game.zone.radius / 10, game.time),
        29, 74)

    local panelWidth = 390
    local x = math.max(15, w / 2 - panelWidth / 2)
    local y = h - 102
    box(x, y, panelWidth, 88, {.06, .15, .13, .87}, {.85, .96, .88, .32})
    bar(x + 12, y + 12, 210, 18, p.hp, p.maxhp, {.80, .22, .23})
    bar(x + 12, y + 40, 210, 10, p.energy, 100, {.31, .71, .91})
    g.setColor(.98, .96, .89)
    g.setFont(smallFont)
    g.print(string.format("VIDA %03d/100", math.ceil(p.hp)), x + 230, y + 12)
    g.print("ENERGIA", x + 230, y + 37)
    local info, gun = game:getGunInfo()
    g.setFont(font)
    g.print(info.name .. "   " .. gun.ammo .. " / " .. gun.reserve, x + 12, y + 58)
    if gun.reloading > 0 then
        g.setColor(.94, .73, .34)
        g.print("RECARREGANDO", x + 230, y + 58)
    end

    g.setColor(.95, .97, .92)
    g.setFont(smallFont)
    g.print("WASD Mover | Mouse Mirar/Atirar | 1/2 Armas | R Recarregar | E Kit ("
        .. p.kits .. ") | ESPAÇO Correr", 20, h - 127)
    g.print("FPS: " .. love.timer.getFPS() .. "  |  OFFLINE v0.1", 20, h - 20)
    drawMinimap(w, h)
    if (p.x - game.zone.x)^2 + (p.y - game.zone.y)^2 > game.zone.radius^2
        and game.state == "playing" then
        g.setFont(font)
        g.setColor(1, .38, .38)
        g.printf("FORA DA ZONA SEGURA!", 0, 120, w, "center")
    end
end

local function drawEnd(w, h)
    if game.state == "playing" then return end
    local g = love.graphics
    g.setColor(.02, .06, .07, .72)
    g.rectangle("fill", 0, 0, w, h)
    g.setFont(bigFont)
    g.setColor(game.state == "won" and {.92, .79, .35} or {.98, .43, .4})
    g.printf(game.state == "won" and "VITÓRIA!" or "VOCÊ MORREU", 0, h / 2 - 90, w, "center")
    g.setFont(font)
    g.setColor(.94, .95, .88)
    g.printf("Abates: " .. game.kills .. "    Tempo: " .. math.floor(game.time) .. " s",
        0, h / 2 - 22, w, "center")
    g.printf("Pressione ENTER para jogar novamente", 0, h / 2 + 18, w, "center")
end

function love.draw()
    local g = love.graphics
    local cam, w, h = camera()
    g.push()
    g.translate(-cam.x, -cam.y)
    game:draw(cam, w, h)
    g.pop()
    drawHud(w, h)
    drawEnd(w, h)
end
