local LevelColorUtil = {}

local LVL_WHITE = Color3.fromRGB(220, 220, 220)
local LVL_YELLOW = Color3.fromRGB(200, 180, 50)
local LVL_ORANGE = Color3.fromRGB(230, 130, 30)
local LVL_RED = Color3.fromRGB(210, 40, 40)

LevelColorUtil.Colors = {
    White = LVL_WHITE,
    Yellow = LVL_YELLOW,
    Orange = LVL_ORANGE,
    Red = LVL_RED,
}

LevelColorUtil.SkullText = "☠"
LevelColorUtil.SkullIcon = "rbxassetid://116793517"  -- skull decal; replace if needed

function LevelColorUtil.getColor(targetLevel, playerLevel)
    local diff = targetLevel - playerLevel
    if diff <= -5 then return LVL_WHITE
    elseif diff <= 0 then return LVL_YELLOW
    elseif diff <= 4 then return LVL_ORANGE
    elseif diff <= 9 then return LVL_RED
    else return LVL_RED end
end

function LevelColorUtil.isSkull(targetLevel, playerLevel)
    return (targetLevel - playerLevel) >= 10
end

return LevelColorUtil