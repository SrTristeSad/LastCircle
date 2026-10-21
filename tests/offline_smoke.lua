-- Pequeno teste do gameplay sem janela, usando uma simulação do RNG LÖVE.
-- NÃO substitui rodar o cliente no LÖVE2D.
math.randomseed(251026)
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
love = {
    math = {
        newRandomGenerator = function(seed)
            math.randomseed(seed)
            return {random = function(_, a, b)
                if a == nil then return math.random() end
                if b == nil then return math.random(a) end
                return math.random(a, b)
            end}
        end
    }
}
local Game = require("src.game")
local game = Game.new()
assert(game.state == "playing", "Partida não inicializada")
assert(#game.bots > 0, "Bots ausentes")
assert(game.player.x == 1600 and game.player.y == 1600, "Spawn incorreto")
assert(not game.world:collides(game.player.x, game.player.y, game.player.r), "Spawn bloqueado")
local before = game.player.guns.pistol.ammo
game:update(1 / 60, 0, 0, 0, true, false)
assert(game.player.guns.pistol.ammo == before - 1, "Tiro não consumiu munição")
assert(#game.bullets > 0, "Projétil ausente")
game:equip("smg")
assert(game.player.gun == "smg", "Troca de arma falhou")
game.player.hp = 20
local kits = game.player.kits
game:heal()
assert(game.player.hp == 80 and game.player.kits == kits - 1, "Kit médico falhou")
game.player.x, game.player.y = 18, 18
game.world:move(game.player, -100, -100)
assert(game.player.x >= game.player.r and game.player.y >= game.player.r, "Saiu do mapa")
game.bots = {}
game:update(1 / 60, 0, 0, 0, false, false)
assert(game.state == "won", "Vitória não detectada")
print("Offline gameplay smoke tests passed")
