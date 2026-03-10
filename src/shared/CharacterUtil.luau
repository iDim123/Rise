--[[
    CharacterUtil — shared validation helpers for player/entity characters.
    Use on both server and client to avoid duplicating validation logic.
]]

local Players = game:GetService("Players")

local CharacterUtil = {}

--- Validate that an entity has Humanoid, HumanoidRootPart, and is alive.
--- @param entity Model
--- @return Humanoid?, HumanoidRootPart?
function CharacterUtil.validate(entity)
    if not entity or not entity.Parent then
        return nil, nil
    end
    if entity:GetAttribute("IsDead") then
        return nil, nil
    end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil, nil
    end
    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return nil, nil
    end
    return humanoid, rootPart
end

--- Validate a player's character. Returns humanoid, rootPart or nil.
--- @param player Player
--- @return Humanoid?, HumanoidRootPart?
function CharacterUtil.validatePlayer(player)
    local character = player.Character
    if not character then
        return nil, nil
    end
    return CharacterUtil.validate(character)
end

--- Get the Player for a character model, or nil if it's an NPC.
--- @param entity Model
--- @return Player?
function CharacterUtil.getPlayer(entity)
    return Players:GetPlayerFromCharacter(entity)
end

--- Check if entity is alive (not dead attribute and humanoid health > 0).
--- @param entity Model
--- @return boolean
function CharacterUtil.isAlive(entity)
    if not entity or not entity.Parent then
        return false
    end
    if entity:GetAttribute("IsDead") then
        return false
    end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

return CharacterUtil
