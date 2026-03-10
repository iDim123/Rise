local EventBus = {}
local listeners = {} -- [eventName] = { callback1, callback2, ... }

function EventBus.on(eventName, callback)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], callback)
    return callback -- return handle for off()
end

function EventBus.off(eventName, callback)
    local cbs = listeners[eventName]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i] == callback then
            table.remove(cbs, i)
            break
        end
    end
end

function EventBus.fire(eventName, ...)
    local cbs = listeners[eventName]
    if not cbs then return end
    for _, cb in cbs do
        task.spawn(cb, ...)
    end
end

return EventBus