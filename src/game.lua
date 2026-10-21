local World = require("src.world")
local Game = {}
Game.__index = Game

local TAU = 2 * math.pi
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function distance2(ax, ay, bx, by) return (ax - bx)^2 + (ay - by)^2 end
local function norm(dx, dy)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < .0001 then return 0, 0 end
    return dx / d, dy / d
end

local gunData = {
    pistol = {name = "Pistola", magazine = 12, cooldown = .23, reload = 1.15, speed = 920, damage = 24, spread = .045},
    smg = {name = "SMG", magazine = 30, cooldown = .095, reload = 1.7, speed = 840, damage = 13, spread = .13}
}

function Game.new()
    local self = setmetatable({}, Game)
    self.world = World.new()
    self.player = {
        x = 1600, y = 1600, r = 17, angle = 0, hp = 100, maxhp = 100,
        speed = 235, energy = 100, kits = 2, gun = "pistol",
        guns = {
            pistol = {ammo = 12, reserve = 84, cooldown = 0, reloading = 0},
            smg = {ammo = 30, reserve = 150, cooldown = 0, reloading = 0}
        }
    }
    self.bots, self.bullets, self.particles = {}, {}, {}
    self.time, self.kills, self.state = 0, 0, "playing"
    self.zone = {x = 1600, y = 1600, radius = 2150, delay = 22, duration = 240, minRadius = 135}
    local rng = self.world.rng
    for i = 1, 16 do
        local x, y, attempts = 0, 0, 0
        repeat
            x, y = rng:random(70, 3130), rng:random(70, 3130)
            attempts = attempts + 1
        until attempts > 200 or
            (distance2(x, y, self.player.x, self.player.y) > 490^2
            and not self.world:collides(x, y, 17))
        if not self.world:collides(x, y, 17) then
            self.bots[#self.bots + 1] = {
                x = x, y = y, r = 17, angle = 0, hp = 68, maxhp = 68,
                speed = rng:random(130, 190), shotTimer = rng:random() * 2,
                wander = rng:random() * TAU, wanderTimer = 0,
                color = {rng:random(52, 93) / 100, rng:random(33, 72) / 100, .27}
            }
        end
    end
    return self
end

function Game:reload()
    if self.state ~= "playing" then return end
    local p = self.player
    local g = p.guns[p.gun]
    local info = gunData[p.gun]
    if g.reloading <= 0 and g.ammo < info.magazine and g.reserve > 0 then
        g.reloading = info.reload
    end
end

function Game:equip(id)
    if gunData[id] and self.state == "playing" then self.player.gun = id end
end

function Game:heal()
    local p = self.player
    if self.state == "playing" and p.kits > 0 and p.hp < p.maxhp then
        p.kits = p.kits - 1
        p.hp = math.min(p.maxhp, p.hp + 60)
    end
end

function Game:shootPlayer()
    if self.state ~= "playing" then return end
    local p = self.player
    local g = p.guns[p.gun]
    local info = gunData[p.gun]
    if g.reloading > 0 or g.cooldown > 0 then return end
    if g.ammo == 0 then self:reload() return end
    local spread = (self.world.rng:random() - .5) * 2 * info.spread
    local a = p.angle + spread
    g.ammo = g.ammo - 1
    g.cooldown = info.cooldown
    self.bullets[#self.bullets + 1] = {
        x = p.x + math.cos(a) * 23, y = p.y + math.sin(a) * 23,
        vx = math.cos(a) * info.speed, vy = math.sin(a) * info.speed,
        damage = info.damage, owner = "player", life = 1.15
    }
end

function Game:shootBot(bot)
    if self.state ~= "playing" then return end
    local angle = math.atan2(self.player.y - bot.y, self.player.x - bot.x)
    angle = angle + (self.world.rng:random() - .5) * .23
    self.bullets[#self.bullets + 1] = {
        x = bot.x + math.cos(angle) * 22, y = bot.y + math.sin(angle) * 22,
        vx = math.cos(angle) * 680, vy = math.sin(angle) * 680,
        damage = 9, owner = "bot", life = 1.3
    }
end

function Game:update(dt, moveX, moveY, aimAngle, shooting, sprinting)
    if self.state ~= "playing" then return end
    dt = math.min(dt, .05)
    self.time = self.time + dt
    local p = self.player
    p.angle = aimAngle

    local desired = math.sqrt(moveX * moveX + moveY * moveY)
    if desired > 1 then moveX, moveY = moveX / desired, moveY / desired end
    local sprint = sprinting and p.energy > 0 and desired > .01
    local speed = p.speed * (sprint and 1.5 or 1)
    self.world:move(p, moveX * speed * dt, moveY * speed * dt)
    p.energy = clamp(p.energy + (sprint and -32 or 21) * dt, 0, 100)

    for _, id in ipairs({"pistol", "smg"}) do
        local weapon = p.guns[id]
        weapon.cooldown = math.max(0, weapon.cooldown - dt)
        if weapon.reloading > 0 then
            weapon.reloading = weapon.reloading - dt
            if weapon.reloading <= 0 then
                local n = math.min(gunData[id].magazine - weapon.ammo, weapon.reserve)
                weapon.ammo = weapon.ammo + n
                weapon.reserve = weapon.reserve - n
                weapon.reloading = 0
            end
        end
    end
    if shooting then self:shootPlayer() end

    for i = #self.world.pickups, 1, -1 do
        local item = self.world.pickups[i]
        if distance2(p.x, p.y, item.x, item.y) < 36^2 then
            if item.kind == "ammo" then
                p.guns.pistol.reserve = p.guns.pistol.reserve + item.amount
                p.guns.smg.reserve = p.guns.smg.reserve + item.amount
            else
                p.kits = math.min(6, p.kits + 1)
            end
            table.remove(self.world.pickups, i)
        end
    end

    for _, bot in ipairs(self.bots) do
        local dx, dy = p.x - bot.x, p.y - bot.y
        local d2 = dx * dx + dy * dy
        local nx, ny = norm(dx, dy)
        bot.angle = math.atan2(dy, dx)
        bot.shotTimer = bot.shotTimer - dt
        if d2 < 590^2 then
            local dir = d2 > 195^2 and 1 or (d2 < 120^2 and -1 or 0)
            self.world:move(bot, nx * bot.speed * dir * dt, ny * bot.speed * dir * dt)
            if d2 < 510^2 and bot.shotTimer <= 0 then
                self:shootBot(bot)
                bot.shotTimer = .55 + self.world.rng:random() * .8
            end
        else
            bot.wanderTimer = bot.wanderTimer - dt
            if bot.wanderTimer <= 0 then
                bot.wander = self.world.rng:random() * TAU
                bot.wanderTimer = 1.5 + self.world.rng:random() * 2
            end
            self.world:move(bot, math.cos(bot.wander) * bot.speed * .4 * dt,
                math.sin(bot.wander) * bot.speed * .4 * dt)
        end
        if distance2(bot.x, bot.y, self.zone.x, self.zone.y) > self.zone.radius^2 then
            bot.hp = bot.hp - 5 * dt
        end
    end

    -- Subpassos evitam que projéteis atravessem árvores ou personagens.
    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i]
        b.life = b.life - dt
        local hit = b.life <= 0
        if not hit then
            local dx, dy = b.vx * dt, b.vy * dt
            local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 7))
            for _ = 1, steps do
                b.x, b.y = b.x + dx / steps, b.y + dy / steps
                if b.x < 0 or b.y < 0 or b.x > self.world.width or b.y > self.world.height then
                    hit = true
                elseif self.world:hitObstacle(b.x, b.y, 3, b.damage) then
                    hit = true
                elseif b.owner == "bot" then
                    if distance2(b.x, b.y, p.x, p.y) <= (p.r + 3)^2 then
                        p.hp = p.hp - b.damage
                        hit = true
                    end
                else
                    for _, bot in ipairs(self.bots) do
                        if bot.hp > 0 and distance2(b.x, b.y, bot.x, bot.y) <= (bot.r + 3)^2 then
                            bot.hp = bot.hp - b.damage
                            hit = true
                            break
                        end
                    end
                end
                if hit then break end
            end
        end
        if hit then table.remove(self.bullets, i) end
    end

    local remaining = {}
    for _, bot in ipairs(self.bots) do
        if bot.hp > 0 then
            remaining[#remaining + 1] = bot
        else
            if distance2(bot.x, bot.y, self.zone.x, self.zone.y) <= self.zone.radius^2 then
                self.world.pickups[#self.world.pickups + 1] = {
                    x = bot.x, y = bot.y,
                    kind = self.world.rng:random() < .3 and "med" or "ammo",
                    amount = 24
                }
            end
            if bot.hp <= 0 and distance2(bot.x, bot.y, p.x, p.y) < 560^2 then
                -- A contagem registra apenas eliminações recentes pelo jogador.
                -- Para o protótipo offline, mortes pela zona não são contabilizadas.
                if bot.hp <= -1 then self.kills = self.kills + 1 end
            end
        end
    end
    self.bots = remaining

    local z = self.zone
    local elapsed = math.max(0, self.time - z.delay)
    local progress = clamp(elapsed / z.duration, 0, 1)
    z.radius = 2150 + (z.minRadius - 2150) * progress
    if distance2(p.x, p.y, z.x, z.y) > z.radius^2 then
        p.hp = p.hp - (7 + progress * 10) * dt
    end

    if p.hp <= 0 then p.hp, self.state = 0, "dead"
    elseif #self.bots == 0 then self.state = "won" end
end

local function drawActor(actor, isPlayer)
    local g = love.graphics
    g.setColor(.12, .21, .13, .5)
    g.ellipse("fill", actor.x + 5, actor.y + 7, actor.r + 3, actor.r - 2)
    if isPlayer then g.setColor(.96, .78, .47)
    else g.setColor(actor.color[1], actor.color[2], actor.color[3]) end
    g.circle("fill", actor.x, actor.y, actor.r)
    g.setColor(.16, .23, .2)
    g.setLineWidth(3)
    g.circle("line", actor.x, actor.y, actor.r)
    g.push()
    g.translate(actor.x, actor.y)
    g.rotate(actor.angle)
    g.setColor(.20, .23, .20)
    g.rectangle("fill", 12, -5, 22, 10, 2)
    g.setColor(.58, .61, .57)
    g.rectangle("fill", 27, -3, 13, 6, 2)
    g.pop()
    g.setColor(.07, .1, .08)
    g.circle("fill", actor.x + math.cos(actor.angle - .65) * 9,
        actor.y + math.sin(actor.angle - .65) * 9, 2.4)
    g.circle("fill", actor.x + math.cos(actor.angle + .65) * 9,
        actor.y + math.sin(actor.angle + .65) * 9, 2.4)
    if not isPlayer then
        g.setColor(.13, .13, .13, .7)
        g.rectangle("fill", actor.x - 19, actor.y - 28, 38, 5)
        g.setColor(.86, .22, .20)
        g.rectangle("fill", actor.x - 19, actor.y - 28, 38 * clamp(actor.hp / actor.maxhp, 0, 1), 5)
    end
    g.setLineWidth(1)
end

function Game:draw(camera, sw, sh)
    local g = love.graphics
    self.world:draw(camera, sw, sh)
    g.stencil(function()
        g.circle("fill", self.zone.x, self.zone.y, self.zone.radius)
    end, "replace", 1)
    g.setStencilTest("equal", 0)
    g.setColor(.20, .26, .62, .33)
    g.rectangle("fill", camera.x, camera.y, sw, sh)
    g.setStencilTest()
    g.setColor(.63, .83, 1, .88)
    g.setLineWidth(4)
    g.circle("line", self.zone.x, self.zone.y, self.zone.radius)
    g.setLineWidth(1)

    for _, b in ipairs(self.bullets) do
        g.setColor(b.owner == "player" and {.99, .85, .43} or {.98, .44, .37})
        g.circle("fill", b.x, b.y, 4)
    end
    for _, bot in ipairs(self.bots) do
        if bot.x > camera.x - 60 and bot.x < camera.x + sw + 60
            and bot.y > camera.y - 60 and bot.y < camera.y + sh + 60 then
            drawActor(bot, false)
        end
    end
    drawActor(self.player, true)
end

function Game:getGunInfo()
    local id = self.player.gun
    return gunData[id], self.player.guns[id]
end

return Game
