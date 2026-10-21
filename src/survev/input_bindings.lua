-- Ordem dos enums e keybinds copiada fielmente de
-- shared/gameConfig.ts e client/src/inputBinds.ts (Survev, GPL-3.0).
-- IDs do protocolo sao zero-based; nunca reordenar.
local inputNames = {
    "MoveLeft", "MoveRight", "MoveUp", "MoveDown", "Fire", "Reload",
    "Cancel", "Interact", "Revive", "Use", "Loot", "EquipPrimary",
    "EquipSecondary", "EquipMelee", "EquipThrowable", "EquipFragGrenade",
    "EquipSmokeGrenade", "EquipNextWeap", "EquipPrevWeap",
    "EquipLastWeap", "EquipOtherGun", "EquipPrevScope", "EquipNextScope",
    "UseBandage", "UseHealthKit", "UseSoda", "UsePainkiller",
    "StowWeapons", "SwapWeapSlots", "ToggleMap", "CycleUIMode",
    "EmoteMenu", "TeamPingMenu", "Fullscreen", "HideUI", "TeamPingSingle",
}
local Input = {Count = #inputNames}
for i, name in ipairs(inputNames) do Input[name] = i - 1 end

local default = {
    MoveLeft = {"key", "a"},
    MoveRight = {"key", "d"},
    MoveUp = {"key", "w"},
    MoveDown = {"key", "s"},
    Fire = {"mouse", 1},
    Reload = {"key", "r"},
    Cancel = {"key", "x"},
    Interact = {"key", "f"},
    EquipPrimary = {"key", "1"},
    EquipSecondary = {"key", "2"},
    EquipMelee = {"key", "3"},
    EquipThrowable = {"key", "4"},
    EquipNextWeap = {"wheel", "down"},
    EquipPrevWeap = {"wheel", "up"},
    EquipLastWeap = {"key", "q"},
    StowWeapons = {"key", "e"},
    UseBandage = {"key", "7"},
    UseHealthKit = {"key", "8"},
    UseSoda = {"key", "9"},
    UsePainkiller = {"key", "0"},
    SwapWeapSlots = {"key", "t"},
    ToggleMap = {"key", "m"},
    CycleUIMode = {"key", "v"},
    EmoteMenu = {"mouse", 2},
    TeamPingMenu = {"key", "c"},
    Fullscreen = {"key", "l"},
}
local function actionsFor(kind, key)
    local result = {}
    for i, name in ipairs(inputNames) do
        local binding = default[name]
        if binding and binding[1] == kind and binding[2] == key then
            result[#result + 1] = i - 1
        end
    end
    return result
end

return {
    Input = Input,
    names = inputNames,
    default = default,
    actionsFor = actionsFor,
}
