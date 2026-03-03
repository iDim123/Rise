local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

-- Отключаем окно чата (оставляем bubble chat над головами)
local chatWindow = TextChatService:WaitForChild("ChatWindowConfiguration", 5)
if chatWindow then
	chatWindow.Enabled = false
end

-- Убираем иконку чата из CoreGui
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)