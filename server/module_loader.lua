MDT = {
    Modules = {},
    Permissions = {},
    PermissionDefinitions = {},
    Tabs = {}
}

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
    return MDT.Tabs
end

function MDT.GetPermissionDefinitions()
    return MDT.PermissionDefinitions
end

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
