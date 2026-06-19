-- Load the manifest file
local manifestJson = LoadResourceFile(GetCurrentResourceName(), 'modules/example_module/manifest.json')
if not manifestJson then
    print('^1[example_module] ERROR: Could not load manifest.json')
    return
end

-- Register this module with the MDT core
exports['ps-mdt']:RegisterModule(manifestJson)

print('^2[example_module] Registered with MDT Core.^0')
