local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

-- Отключаем окно чата
local chatWindow = TextChatService:WaitForChild("ChatWindowConfiguration", 5)
if chatWindow then
	chatWindow.Enabled = false
end

-- Убираем иконку чата
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

-- Убираем стандартный Backpack (инвентарь Roblox)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)