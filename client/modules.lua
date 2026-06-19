

local tabsCache = {}
local moduleNuiCallbacks = {}

function RegisterModuleNUICallback(moduleId, callbackName, handler)
    if type(moduleId) ~= 'string' or not moduleId:match('^[%w_-]+$') then return false end
    if type(callbackName) ~= 'string' or not callbackName:match('^[%w_-]+$') then return false end
    if type(handler) ~= 'function' then return false end
    moduleNuiCallbacks[moduleId .. ':' .. callbackName] = handler
    return true
end

exports('RegisterModuleNUICallback', RegisterModuleNUICallback)

RegisterNUICallback('moduleCallback', function(payload, cb)
    payload = payload or {}
    local moduleId = payload.moduleId
    local callbackName = payload.callback
    if type(moduleId) ~= 'string' or type(callbackName) ~= 'string' then
        cb({ success = false, message = 'Invalid module callback' })
        return
    end

    local handler = moduleNuiCallbacks[moduleId .. ':' .. callbackName]
    if not handler then
        cb({ success = false, message = 'Module callback not found' })
        return
    end

    local replied = false
    local function reply(result)
        if replied then return end
        replied = true
        cb(result == nil and {} or result)
    end

    local ok, result = pcall(handler, payload.data or {}, reply)
    if not ok then
        print(('[ps-mdt] ^1Module NUI callback failed (%s:%s): %s'):format(moduleId, callbackName, result))
        reply({ success = false, message = 'Module callback failed' })
    elseif result ~= nil then
        reply(result)
    end
end)

-- NUI Callback to get the tabs
RegisterNUICallback('getModuleTabs', function(_, cb)
    -- Trigger a server event to request the tabs
    TriggerServerEvent('ps-mdt:getModuleTabs')
    -- The response will be handled by the 'ps-mdt:setModuleTabs' event below.
    -- We'll return the cached tabs for now, which will be populated by the event.
    cb(tabsCache)
end)

-- Listen for the server's response
RegisterNetEvent('ps-mdt:setModuleTabs', function(tabs)
    tabsCache = tabs
    -- Send the updated tabs to the NUI
    SendNUIMessage({
        action = 'setModuleTabs',
        data = tabsCache
    })
end)