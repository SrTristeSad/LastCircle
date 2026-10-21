local World = {}
World.__index = World

local TAU = math.pi * 2
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

function World.new()
    local self = setmetatable({}, World)
    self.width, self.height = 3200, 3200
    self.rng = love.math.newRandomGenerator(251026)
    self.objects, self.pickups = {}, {}
    self.seed = 251026

    for i = 1, 410 do
        local x = self.rng:random(64, self.width - 64)
        local y = self.rng:random(64, self.height - 64)
        if (x - self.width / 2)^2 + (y - self.height / 2)^2 > 230^2 then
            local p = self.rng:random()
            local kind = p < .53 and "tree" or (p < .83 and "rock" or "crate")
            local radius = kind == "tree" and 27 or (kind == "rock" and 23 or 20)
            local blocked = false
            for _, o in ipairs(self.objects) do
                if (o.x - x)^2 + (o.y - y)^2 < (radius + o.r + 17)^2 then
                    blocked = true
                    break
                end
            end
            if not blocked then
                self.objects[#self.objects + 1] = {
                    x = x, y = y, r = radius, kind = kind,
                    hp = kind == "rock" and 180 or (kind == "tree" and 130 or 65)
                }
            end
        end
    end

    for i = 1, 50 do
        local x, y = self.rng:random(100, 3100), self.rng:random(100, 3100)
        self.pickups[#self.pickups + 1] = {
            x = x, y = y, kind = i % 4 == 0 and "med" or "ammo", amount = i % 4 == 0 and 1 or 18
        }
    end
    return self
end

function World:collides(x, y, r)
    if x - r < 0 or y - r < 0 or x + r > self.width or y + r > self.height then
        return true
    end
    for _, o in ipairs(self.objects) do
        if o.hp > 0 and (o.x - x)^2 + (o.y - y)^2 < (r + o.r)^2 then
            return true
        end
    end
    return false
end

function World:move(entity, dx, dy)
    local nx = clamp(entity.x + dx, entity.r, self.width - entity.r)
    if not self:collides(nx, entity.y, entity.r) then entity.x = nx end
    local ny = clamp(entity.y + dy, entity.r, self.height - entity.r)
    if not self:collides(entity.x, ny, entity.r) then entity.y = ny end
end

function World:hitObstacle(x, y, radius, damage)
    for i = #self.objects, 1, -1 do
        local o = self.objects[i]
        if (o.x - x)^2 + (o.y - y)^2 <= (radius + o.r)^2 then
            o.hp = o.hp - damage
            if o.hp <= 0 then
                if o.kind == "crate" and self.rng:random() < .7 then
                    self.pickups[#self.pickups + 1] = {
                        x = o.x, y = o.y, kind = self.rng:random() < .35 and "med" or "ammo",
                        amount = 24
                    }
                end
                table.remove(self.objects, i)
            end
            return true
        end
    end
    return false
end

local function visible(x, y, margin, camera, sw, sh)
    return x > camera.x - margin and y > camera.y - margin
        and x < camera.x + sw + margin and y < camera.y + sh + margin
end

function World:draw(camera, sw, sh)
    local g = love.graphics
    g.setColor(.30, .55, .29)
    g.rectangle("fill", 0, 0, self.width, self.height)
    local firstX = math.max(0, math.floor(camera.x / 96) - 1)
    local lastX = math.min(math.floor(self.width / 96), math.ceil((camera.x + sw) / 96))
    local firstY = math.max(0, math.floor(camera.y / 96) - 1)
    local lastY = math.min(math.floor(self.height / 96), math.ceil((camera.y + sh) / 96))
    for gx = firstX, lastX do
        for gy = firstY, lastY do
            local x, y = gx * 96, gy * 96
            local v = ((gx * 31 + gy * 17 + gx * gy * 7) % 13) / 13
            g.setColor(.32 + v * .05, .58 + v * .03, .31 + v * .04, .56)
            g.circle("fill", x + 26, y + 17, 7 + v * 5)
            g.setColor(.21, .45, .23, .25)
            g.line(x + 62, y + 68, x + 68, y + 58)
            g.line(x + 67, y + 69, x + 73, y + 62)
        end
    end

    g.setColor(.95, .93, .75, .8)
    g.setLineWidth(7)
    g.rectangle("line", 3, 3, self.width - 6, self.height - 6)
    g.setLineWidth(1)

    for _, o in ipairs(self.objects) do
        if visible(o.x, o.y, 70, camera, sw, sh) then
            if o.kind == "tree" then
                g.setColor(.13, .32, .18, .5)
                g.ellipse("fill", o.x + 7, o.y + 9, 29, 23)
                g.setColor(.24, .32, .17)
                g.circle("fill", o.x, o.y, 13)
                g.setColor(.12, .38, .18)
                g.circle("fill", o.x + 2, o.y - 5, 30)
                g.setColor(.21, .54, .23)
                g.circle("fill", o.x - 8, o.y - 13, 19)
                g.setColor(.31, .63, .26)
                g.circle("fill", o.x - 11, o.y - 16, 9)
            elseif o.kind == "rock" then
                g.setColor(.24, .32, .29, .45)
                g.ellipse("fill", o.x + 6, o.y + 7, 25, 18)
                g.setColor(.37, .43, .43)
                g.polygon("fill", o.x - 24, o.y - 5, o.x - 10, o.y - 22,
                    o.x + 15, o.y - 19, o.x + 24, o.y + 7, o.x + 1, o.y + 22, o.x - 22, o.y + 12)
                g.setColor(.60, .66, .63)
                g.polygon("fill", o.x - 24, o.y - 5, o.x - 10, o.y - 22,
                    o.x + 15, o.y - 19, o.x + 2, o.y - 3)
            else
                g.setColor(.25, .22, .13, .45)
                g.rectangle("fill", o.x - 18 + 5, o.y - 18 + 6, 36, 36)
                g.setColor(.55, .34, .15)
                g.rectangle("fill", o.x - 18, o.y - 18, 36, 36)
                g.setColor(.77, .52, .24)
                g.rectangle("line", o.x - 15, o.y - 15, 30, 30)
                g.line(o.x - 15, o.y - 15, o.x + 15, o.y + 15)
            end
        end
    end

    for _, p in ipairs(self.pickups) do
        if visible(p.x, p.y, 35, camera, sw, sh) then
            g.setColor(.08, .20, .12, .50)
            g.circle("fill", p.x + 2, p.y + 3, 14)
            if p.kind == "med" then
                g.setColor(.91, .92, .82)
                g.rectangle("fill", p.x - 12, p.y - 12, 24, 24, 3)
                g.setColor(.79, .21, .23)
                g.rectangle("fill", p.x - 3, p.y - 9, 6, 18)
                g.rectangle("fill", p.x - 9, p.y - 3, 18, 6)
            else
                g.setColor(.82, .65, .25)
                g.rectangle("fill", p.x - 10, p.y - 8, 20, 17, 3)
                g.setColor(.28, .20, .12)
                g.rectangle("line", p.x - 8, p.y - 6, 16, 13, 2)
            end
        end
    end
end

return World
