local GuiService = game:GetService("GuiService")

local WindowManager = {}

local openWindows = {} -- стек: { {name, closeFn}, ... }

function WindowManager.push(name: string, closeFn: () -> ())
    for _, entry in openWindows do
        if entry.name == name then return end
    end
    table.insert(openWindows, { name = name, closeFn = closeFn })
end

function WindowManager.remove(name: string)
    for i = #openWindows, 1, -1 do
        if openWindows[i].name == name then
            table.remove(openWindows, i)
            return
        end
    end
end

function WindowManager.closeLast()
    if #openWindows == 0 then return false end
    local last = table.remove(openWindows)
    last.closeFn()
    return true
end

function WindowManager.closeAll()
    while #openWindows > 0 do
        local entry = table.remove(openWindows)
        entry.closeFn()
    end
end

function WindowManager.hasOpen(): boolean
    return #openWindows > 0
end

function WindowManager.isOpen(name: string): boolean
    for _, entry in openWindows do
        if entry.name == name then return true end
    end
    return false
end

-- Когда игрок нажимает Esc — Roblox-меню открывается.
-- Мы закрываем ВСЕ наши окна в этот момент.
-- Меню Roblox всё равно появится — это нормально, игрок просто нажмёт Resume.
-- Но при следующем Esc (когда наших окон нет) — менюшка откроется как обычно.
GuiService.MenuOpened:Connect(function()
    if #openWindows > 0 then
        WindowManager.closeAll()
    end
end)

return WindowManager