local ReplicatedStorage = game:GetService("ReplicatedStorage")
local configFolder = ReplicatedStorage:WaitForChild("config")
local spellsFolder = configFolder:WaitForChild("spells")

local MagicSchools = {}
local Spells = {}

for _, module in spellsFolder:GetChildren() do
    if module:IsA("ModuleScript") then
        local data = require(module)
        if data.School then
            MagicSchools[data.School.Id] = data.School
        end
        if data.Spells then
            for spellId, spell in data.Spells do
                Spells[spellId] = spell
            end
        end
    end
end

return {
    MagicSchools = MagicSchools,
    Spells = Spells,
    SpellSlots = {{
        Key = "R",
        AllowedClass = "Basic"
    }, {
        Key = "G",
        AllowedClass = "Basic"
    }, {
        Key = "Z",
        AllowedClass = "Ultimate"
    }}
}
