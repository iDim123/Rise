local EnemyUtil = {}

function EnemyUtil.getHead(enemy)
    return enemy:FindFirstChild("Head")
        or enemy:FindFirstChild("UpperTorso")
        or enemy:FindFirstChild("Torso")
        or enemy:FindFirstChild("HumanoidRootPart")
        or enemy.PrimaryPart
end

return EnemyUtil