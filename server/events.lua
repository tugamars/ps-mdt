RegisterNetEvent('ps-mdt:getModuleTabs', function()
    local src = source
    local tabs = MDT.GetMdtTabs()

    TriggerClientEvent('ps-mdt:setModuleTabs', src, tabs)
end)
