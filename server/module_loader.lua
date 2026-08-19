MDT = {
    Modules = {},
    Permissions = {},
    PermissionDefinitions = {},
    Tabs = {}
}

-- Public server helpers for scripts under modules/**/server. Permission checks
-- resolve CheckPermission at call time because auth.lua loads after this file.
function MDT.Notify(source, message, notificationType)
    if type(source) ~= 'number' or type(message) ~= 'string' or message == '' then return false end
    ps.notify(source, message, notificationType or 'info')
    return true
end

function MDT.HasPermission(source, permission)
    if type(CheckPermission) ~= 'function' then return false end
    return CheckPermission(source, permission) == true
end

function MDT.GetModule(moduleId)
    if type(moduleId) ~= 'string' then return nil end
    return MDT.Modules[moduleId]
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
exports('HasPermission', MDT.HasPermission)
exports('GetModule', MDT.GetModule)
exports('GetCoreOptions', MDT.GetCoreOptions)

print("Module loader started");

local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function stringList(value)
    if type(value) == 'string' then return { value } end
    if type(value) ~= 'table' then return {} end
    local result = {}
    for _, item in ipairs(value) do
        if type(item) == 'string' then table.insert(result, item) end
    end
    return result
end

local function normalizeDependencies(value)
    if value == nil then return {} end
    if type(value) ~= 'table' then return nil, 'dependencies must be an array' end

    local result = {}
    local seen = {}
    for index, dependency in ipairs(value) do
        if type(dependency) == 'string' then
            dependency = { resource = dependency, required = true }
        end
        if type(dependency) ~= 'table' or type(dependency.resource) ~= 'string' or dependency.resource == '' then
            return nil, ('dependency %d must be a resource name or dependency object'):format(index)
        end
        if not seen[dependency.resource] then
            seen[dependency.resource] = true
            table.insert(result, {
                resource = dependency.resource,
                required = dependency.required ~= false,
            })
        end
    end
    return result
end

local function resolveManifest(moduleOrId)
    if type(moduleOrId) == 'table' then return moduleOrId end
    if type(moduleOrId) == 'string' then return MDT.Modules[moduleOrId] end
    return nil
end

function MDT.GetMissingDependencies(moduleOrId, requiredOnly)
    local manifest = resolveManifest(moduleOrId)
    local missing = {}
    if not manifest then return missing end

    for _, dependency in ipairs(manifest.dependencies or {}) do
        if (not requiredOnly or dependency.required) and GetResourceState(dependency.resource) ~= 'started' then
            table.insert(missing, dependency.resource)
        end
    end
    return missing
end

function MDT.IsModuleAvailable(moduleOrId)
    return #MDT.GetMissingDependencies(moduleOrId, true) == 0
end

exports('GetMissingModuleDependencies', MDT.GetMissingDependencies)
exports('IsModuleAvailable', MDT.IsModuleAvailable)

function RegisterModule(manifestJson)
    local ok, manifest = pcall(json.decode, manifestJson)
    if not ok or type(manifest) ~= 'table' or type(manifest.id) ~= 'string' then
        print('[ps-mdt] ^1ERROR: Could not decode a module manifest, or it has no id')
        return
    end
    if not manifest.id:match('^[%w_-]+$') then
        print(('[ps-mdt] ^1ERROR: Invalid module id: %s'):format(manifest.id))
        return
    end

    local dependencies, dependencyError = normalizeDependencies(manifest.dependencies)
    if not dependencies then
        print(('[ps-mdt] ^1ERROR: Invalid dependencies for module %s: %s'):format(manifest.id, dependencyError))
        return
    end
    manifest.dependencies = dependencies

    -- Re-registering a module (for example after a resource restart) replaces its
    -- old navigation entries instead of producing duplicates.
    for index = #MDT.Tabs, 1, -1 do
        if MDT.Tabs[index].moduleId == manifest.id then
            table.remove(MDT.Tabs, index)
        end
    end
    for index = #MDT.PermissionDefinitions, 1, -1 do
        if MDT.PermissionDefinitions[index].moduleId == manifest.id then
            table.remove(MDT.PermissionDefinitions, index)
        end
    end

    MDT.Modules[manifest.id] = manifest
    print(('[ps-mdt] -> Registered module: %s'):format(manifest.name))

    local missingRequired = MDT.GetMissingDependencies(manifest, true)
    if #missingRequired > 0 then
        print(('[ps-mdt] ^3WARNING: Module %s is disabled; required resources are not started: %s'):format(
            manifest.id,
            table.concat(missingRequired, ', ')
        ))
    end
    local missingOptional = {}
    for _, dependency in ipairs(manifest.dependencies) do
        if not dependency.required and GetResourceState(dependency.resource) ~= 'started' then
            table.insert(missingOptional, dependency.resource)
        end
    end
    if #missingOptional > 0 then
        print(('[ps-mdt] ^3WARNING: Optional resources for module %s are not started: %s'):format(
            manifest.id,
            table.concat(missingOptional, ', ')
        ))
    end

    if manifest.permissions then
        for _, permission in ipairs(manifest.permissions) do
            local permissionId = type(permission) == 'table' and permission.id or permission
            if type(permissionId) == 'string' then
                if not contains(MDT.Permissions, permissionId) then
                    table.insert(MDT.Permissions, permissionId)
                end
                if Config and Config.ManagementPermissions and not contains(Config.ManagementPermissions, permissionId) then
                    table.insert(Config.ManagementPermissions, permissionId)
                end
                table.insert(MDT.PermissionDefinitions, {
                    id = permissionId,
                    label = type(permission) == 'table' and permission.label or nil,
                    description = type(permission) == 'table' and permission.description or nil,
                    category = type(permission) == 'table' and permission.category or nil,
                    moduleId = manifest.id,
                    moduleName = manifest.name,
                })
                print(('[ps-mdt] -> Registered permission: %s'):format(permissionId))
            end
        end
    end

    if manifest.tabs then
        for index, tab in ipairs(manifest.tabs) do
            if type(tab) == 'table' and type(tab.name) == 'string' then
                tab.moduleId = manifest.id
                tab.moduleName = manifest.name
                tab.id = tab.id or ('%s:%s'):format(manifest.id, index)
                tab.icon = tab.icon or 'extension'
                tab.component = tab.component or 'module_page'
                tab.permissions = stringList(tab.permissions)
                tab.jobs = stringList(tab.jobs or manifest.jobs)
                tab.group = tab.group or manifest.group
                table.insert(MDT.Tabs, tab)
                print(('[ps-mdt] -> Registered tab: %s'):format(tab.name))
            end
        end
    end
end

exports('RegisterModule', RegisterModule)

function MDT.GetMdtTabs()
    local tabs = {}
    for _, tab in ipairs(MDT.Tabs) do
        if MDT.IsModuleAvailable(tab.moduleId) then
            table.insert(tabs, tab)
        end
    end
    return tabs
end

function MDT.GetPermissionDefinitions()
    local definitions = {}
    for _, definition in ipairs(MDT.PermissionDefinitions) do
        if MDT.IsModuleAvailable(definition.moduleId) then
            table.insert(definitions, definition)
        end
    end
    return definitions
end

function MDT.GetModuleAvailability()
    local availability = {}
    for moduleId in pairs(MDT.Modules) do
        availability[moduleId] = MDT.IsModuleAvailable(moduleId)
    end
    return availability
end

local function dependencyIsUsed(resourceName)
    for _, manifest in pairs(MDT.Modules) do
        for _, dependency in ipairs(manifest.dependencies or {}) do
            if dependency.resource == resourceName then return true end
        end
    end
    return false
end

local function refreshModuleTabsForDependency(resourceName)
    if not dependencyIsUsed(resourceName) then return end
    SetTimeout(0, function()
        TriggerClientEvent('ps-mdt:setModuleTabs', -1, MDT.GetMdtTabs(), MDT.GetModuleAvailability())
    end)
end

AddEventHandler('onResourceStart', refreshModuleTabsForDependency)
AddEventHandler('onResourceStop', refreshModuleTabsForDependency)

-- We need to merge the permissions into the config at runtime
CreateThread(function()
    Wait(2000) -- Wait a couple of seconds to allow all resources to load and register.
    if Config and Config.ManagementPermissions then
        for _, permission in ipairs(MDT.Permissions) do
            if not contains(Config.ManagementPermissions, permission) then
                table.insert(Config.ManagementPermissions, permission)
            end
        end
        print('[ps-mdt] All module permissions have been merged into the config.')
    else
        print('[ps-mdt] ^1WARNING: Config.ManagementPermissions not found. Could not merge module permissions.')
    end
end)
