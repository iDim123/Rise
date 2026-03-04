local EventBus = {}
local listeners = {} -- [eventName] = { callback1, callback2, ... }

function EventBus.on(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
end

function EventBus.fire(eventName, ...)
    local cbs = listeners[eventName]
    if not cbs then return end
    for _, cb in cbs do
        task.spawn(cb, ...)
    end
end

return EventBus