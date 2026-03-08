-- Единый клиентский скрипт.
-- Когда в workspace появляется модель контейнера —
-- ищет внутри неё AnimController и запускает его.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

-- controllers[containerId] = { onOpen(), onClose() }
local controllers = {}

-- ─── Инициализация контроллера для модели ─────────────────────
local function initModel(model)
    local containerId = model:GetAttribute("ContainerId")
    if not containerId then
        return
    end

    -- Ищем AnimController (ModuleScript) внутри модели
    local controllerModule = model:FindFirstChild("AnimController")
    if not controllerModule then
        return
    end -- модель без анимации — ок

    -- Запускаем фабрику — она получает модель и возвращает { onOpen, onClose }
    local ok, result = pcall(function()
        local factory = require(controllerModule)
        return factory(model)
    end)

    if ok and result then
        controllers[containerId] = result
        print(string.format("[ContainerAnimator] Инициализирован '%s'", containerId))
    else
        warn("[ContainerAnimator] Ошибка в AnimController модели: " .. model.Name, result)
    end
end

-- ─── Следим за появлением моделей в workspace ─────────────────
workspace.ChildAdded:Connect(function(child)
    task.wait() -- один фрейм чтобы атрибуты ContainerId успели проставиться
    initModel(child)
end)

-- Регистрируем уже существующие модели
for _, child in workspace:GetChildren() do
    initModel(child)
end

-- ─── Очистка при удалении модели (despawn) ────────────────────
workspace.ChildRemoved:Connect(function(child)
    local containerId = child:GetAttribute("ContainerId")
    if containerId then
        controllers[containerId] = nil
    end
end)

-- ─── Remotes ──────────────────────────────────────────────────
Remotes.ContainerOpened.OnClientEvent:Connect(function(containerId, slots, name)
    local ctrl = controllers[containerId]
    if ctrl then
        ctrl.onOpen()
    end
end)

Remotes.ContainerClosed.OnClientEvent:Connect(function(containerId)
    local ctrl = controllers[containerId]
    if ctrl then
        ctrl.onClose()
    end
end)
