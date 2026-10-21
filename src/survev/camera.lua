-- Porte 1:1 de client/src/camera.ts (Survev, GPL-3.0).
-- Sistema de coordenadas preservado: mundo Y+ para cima, tela Y+ para baixo.
local Camera = {}
Camera.__index = Camera

function Camera.new()
    return setmetatable({
        m_pos = { x = 0, y = 0 },
        m_ppu = 16,
        m_zoom = 1.5,
        m_targetZoom = 1.5,
        m_screenWidth = 1,
        m_screenHeight = 1,
        m_shakeEnabled = true,
        m_shakeInt = 0,
        m_interpEnabled = true,
        m_localRotationEnabled = false,
        m_interpInterval = 0,
    }, Camera)
end

function Camera:m_z()
    return self.m_ppu * self.m_zoom
end

function Camera:m_pointToScreen(point)
    return {
        x = self.m_screenWidth * .5 + (point.x - self.m_pos.x) * self:m_z(),
        y = self.m_screenHeight * .5 - (point.y - self.m_pos.y) * self:m_z(),
    }
end

function Camera:m_screenToPoint(screen)
    return {
        x = self.m_pos.x + (screen.x - self.m_screenWidth * .5) / self:m_z(),
        y = self.m_pos.y + (self.m_screenHeight * .5 - screen.y) / self:m_z(),
    }
end

function Camera:m_pixels(p)
    return p * self.m_zoom
end

function Camera:m_scaleToScreen(s)
    return s * self:m_z()
end

function Camera:m_setShakeEnabled(enabled)
    self.m_shakeEnabled = enabled
end

function Camera:m_setInterpEnabled(enabled)
    self.m_interpEnabled = enabled
end

function Camera:m_setRotationEnabled(enabled)
    self.m_localRotationEnabled = enabled
end

-- O RNG é injetado para possibilitar teste reproduzível.
-- Espelha math.delerp(dist, 40, 10) * intensity da fonte original.
function Camera:m_addShake(point, intensity)
    local dx = self.m_pos.x - point.x
    local dy = self.m_pos.y - point.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local t = (dist - 40) / (10 - 40)
    t = math.max(0, math.min(1, t))
    local nextIntensity = t * intensity
    self.m_shakeInt = math.max(self.m_shakeInt, nextIntensity)
end

function Camera:m_applyShake(randomUnit)
    if self.m_shakeEnabled and self.m_shakeInt > 0 then
        local point = randomUnit and randomUnit(self.m_shakeInt)
            or {x = math.cos(math.random() * math.pi * 2) * self.m_shakeInt,
                y = math.sin(math.random() * math.pi * 2) * self.m_shakeInt}
        self.m_pos.x = self.m_pos.x + point.x
        self.m_pos.y = self.m_pos.y + point.y
    end
    self.m_shakeInt = 0
end

return Camera
