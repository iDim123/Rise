local ContextActionService = game:GetService("ContextActionService")

local WindowManager = {}

local openWindows = {} -- стек: { {name, closeFn}, ... }
local ACTION_NAME = "WindowManager_Escape"
local bound = false

local function updateEscBind()
    if #openWindows > 0 and not bound then
        ContextActionService:BindActionAtPriority(
            ACTION_NAME,
            function(_actionName, inputState, _inputObj)
                if inputState == Enum.UserInputState.Begin then
                    WindowManager.closeLast()
                    return Enum.ContextActionResult.Sink
                end
                return Enum.ContextActionResult.Pass
            end,
            false,
            3000,
            Enum.KeyCode.Escape
        )
        bound = true
    elseif #openWindows == 0 and bound then
        ContextActionService:UnbindAction(ACTION_NAME)
        bound = false
    end
end

function WindowManager.push(name: string, closeFn: () -> ())
    for _, entry in openWindows do
        if entry.name == name then return end
    end
    table.insert(openWindows, { name = name, closeFn = closeFn })
    updateEscBind()
end

function WindowManager.remove(name: string)
    for i = #openWindows, 1, -1 do
        if openWindows[i].name == name then
            table.remove(openWindows, i)
            break
        end
    end
    updateEscBind()
end

function WindowManager.closeLast()
    if #openWindows == 0 then return false end
    local last = table.remove(openWindows)
    last.closeFn()
    updateEscBind()
    return true
end

function WindowManager.closeAll()
    while #openWindows > 0 do
        local entry = table.remove(openWindows)
        entry.closeFn()
    end
    updateEscBind()
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

return WindowManager