local tabsCache = {}
local moduleAvailability = {}
local moduleNuiCallbacks = {}

-- Public client helpers for scripts under modules/**/client. Keeping these on a
-- small namespace avoids making module authors depend directly on ps_lib.
MDT = MDT or {}

function MDT.Notify(message, notificationType)
    if type(message) ~= 'string' or message == '' then return false end
    ps.notify(message, notificationType or 'info')
    return true
end

function MDT.GetCoreOptions(source)
    if source == 'job-types' then
        return {
            { value = Config.PoliceJobType or 'leo', label = 'Law Enforcement' },
            { value = Config.MedicalJobType or 'ems', label = 'Emergency Medical Services' },
            { value = Config.DojJobType or 'doj', label = 'Department of Justice' },
        }
    end
    if source == 'police-jobs' then return Config.PoliceJobs or {} end
    if source == 'doj-jobs' then return Config.DojJobs or {} end
    if source == 'impound-locations' then return Config.ImpoundLocations or {} end
    return {}
end

exports('Notify', MDT.Notify)
exports('GetCoreOptions', MDT.GetCoreOptions)

function RegisterModuleNUICallback(moduleId, callbackName, handler)
    if type(moduleId) ~= 'string' or not moduleId:match('^[%w_-]+$') then return false end
    if type(callbackName) ~= 'string' or not callbackName:match('^[%w_-]+$') then return false end
    if type(handler) ~= 'function' then return false end
    moduleNuiCallbacks[moduleId .. ':' .. callbackName] = handler
    return true
end

MDT.RegisterNUICallback = RegisterModuleNUICallback

exports('RegisterModuleNUICallback', RegisterModuleNUICallback)

RegisterNUICallback('moduleCallback', function(payload, cb)
    payload = payload or {}
    local moduleId = payload.moduleId
    local callbackName = payload.callback
    if type(moduleId) ~= 'string' or type(callbackName) ~= 'string' then
        cb({ success = false, message = 'Invalid module callback' })
        return
    end
    if moduleAvailability[moduleId] ~= true then
        cb({ success = false, message = 'A required module dependency is not running' })
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
RegisterNetEvent('ps-mdt:setModuleTabs', function(tabs, availability)
    tabsCache = tabs
    moduleAvailability = type(availability) == 'table' and availability or {}
    -- Send the updated tabs to the NUI
    SendNUIMessage({
        action = 'setModuleTabs',
        data = tabsCache
    })
end)

-- Read-only, permission-checked searches exposed to module UIs. Keeping the
-- domain allowlist here prevents modules from proxying arbitrary core callbacks.
RegisterNUICallback('moduleCoreSearch', function(payload, cb)
    if not MDTOpen then
        cb({ items = {}, page = 1, hasMore = false, message = 'MDT is not open' })
        return
    end

    payload = type(payload) == 'table' and payload or {}
    local domain = payload.domain
    if domain ~= 'citizens' and domain ~= 'reports' and domain ~= 'cases' then
        cb({ items = {}, page = 1, hasMore = false, message = 'Invalid search domain' })
        return
    end

    local result = ps.callback(
        tostring(GetCurrentResourceName()) .. ':server:moduleCoreSearch',
        domain,
        payload.query,
        payload.page,
        payload.limit
    )
    cb(result or { items = {}, page = 1, hasMore = false })
end)
