local resourceName = tostring(GetCurrentResourceName())

RegisterNetEvent(resourceName..':server:viewWarrant', function(warrantId)
    local src = source
    local Player = ps.getPlayer(src)

    if not Player then return end

    ps.debug("Server: Viewing warrant:", warrantId)
end)

RegisterNetEvent(resourceName..':server:viewBolo', function(boloId)
    local src = source
    local Player = ps.getPlayer(src)

    if not Player then return end
    if not boloId then
        ps.warn("No BOLO ID provided")
        return
    end

    local id = tonumber(boloId)
    if not id then
        ps.warn("Invalid BOLO ID type: " .. type(boloId))
        return
    end

    local reportId = MySQL.scalar.await('SELECT reportId FROM mdt_bolos WHERE id = ? LIMIT 1', { id })
    reportId = reportId and tonumber(reportId) or nil
    if not reportId then
        ps.warn("BOLO report not found for ID: " .. id)
        return
    end

    ps.info("Player ID: " .. src .. " is viewing BOLO report ID: " .. reportId)
    TriggerClientEvent('ps-mdt:client:viewReport', src, reportId)
end)

--- @description Handles the event for viewing a report in the MDT
--- @param reportId number The ID of the report to view
RegisterNetEvent(resourceName..':server:viewReport', function(reportId)
    local src = source
    local Player = ps.getPlayer(src)

    -- Validate input
    if not reportId then
        ps.warn("No report ID provided")
    return end

    if type(reportId) ~= "number" then
        ps.warn("Invalid report ID type: " .. type(reportId))
    return end

    if not Player then
        ps.warn("Player not found for report viewing: " .. reportId)
    return end

    ps.info("Player ID: " ..  src .. " is viewing report ID: " .. reportId)
    ps.debug("Server: Viewing report:", reportId)
end)

local plateCache={};

local plateCacheSrcs={};

RegisterNetEvent("wk:onPlateScanned")
AddEventHandler("wk:onPlateScanned", function(cam, plate, index)
    local src = source
    local Player = ps.getPlayer(src)
    local driversLicense = ps.getMetadata(src, 'licences') and ps.getMetadata(src, 'licences').driver

    local vehicleOwner, bolo, title, boloid, warrant, owner, incidentId, ownerId = nil, false, nil, nil, false, nil, nil;

    if(plateCache[plate] ~= nil) then
        local pc=plateCache[plate];
        vehicleOwner=pc.vehicleOwner;
        bolo=pc.bolo;
        title=pc.title;
        boloid=pc.boloId;
        warrant=pc.warrant;
        owner=pc.owner;
        incidentId=pc.incidentId;
    else
        vehicleOwner, ownerId = GetVehicleOwner(plate)
        bolo, title, boloid = GetBoloStatus(plate,ownerId)
        warrant, owner, incidentId = GetWarrantStatus(plate, ownerId)
    end

    plateCache[plate] = {
        vehicleOwner = vehicleOwner,
        bolo = bolo,
        title = title,
        boloId = boloid,
        warrant = warrant,
        owner = owner,
        incidentId = incidentId
    }

    SetTimeout(1000 * 60 * 10, function()
        plateCache[plate] = nil
    end)

    if bolo == true then
        ps.notify(src, 'BOLO ID: '..boloid..' | Title: '..title..' | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)

        plateCacheSrcs[src] = plate

        setTimeout(Config.WknightNotifyTime*2, function()
            if plateCacheSrcs[src] and plateCacheSrcs[src] == plate then
                plateCacheSrcs[src] = nil
            end
        end)

    end
    if warrant == true then
        ps.notify(src, 'WANTED - INCIDENT ID: '..incidentId..' | Registered Owner: '..owner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)

        plateCacheSrcs[src] = plate

        setTimeout(Config.WknightNotifyTime*2, function()
            if plateCacheSrcs[src] and plateCacheSrcs[src] == plate then
                plateCacheSrcs[src] = nil
            end
        end)
    end

    if Config.PlateScanForDriversLicense and driversLicense == false and vehicleOwner then
        ps.notify(src, 'NO DRIVERS LICENCE | Registered Owner: '..vehicleOwner..' | Plate: '..plate, 'error', Config.WolfknightNotifyTime)

        plateCacheSrcs[src] = plate

        setTimeout(Config.WknightNotifyTime*2, function()
            if plateCacheSrcs[src] and plateCacheSrcs[src] == plate then
                plateCacheSrcs[src] = nil
            end
        end)

    end

    if bolo or warrant or (Config.PlateScanForDriversLicense and not driversLicense) and vehicleOwner then
        TriggerClientEvent("wk:togglePlateLock", src, cam, true, 1)
    end
end)

RegisterNetEvent("wk:onPlateLocked", function(cam, plate, index)
    if(plateCacheSrcs[source] and plateCacheSrcs[source] == plate) then
        return false;
    end
    local src = source
    local Player = ps.getPlayer(src)
    local driversLicense = ps.getMetadata(src, 'licences') and ps.getMetadata(src, 'licences').driver

    local vehicleOwner, bolo, title, boloid, warrant, owner, incidentId, ownerId = nil, false, nil, nil, false, nil, nil;

    if(plateCache[plate] ~= nil) then
        local pc=plateCache[plate];
        vehicleOwner=pc.vehicleOwner;
        bolo=pc.bolo;
        title=pc.title;
        boloid=pc.boloId;
        warrant=pc.warrant;
        owner=pc.owner;
        incidentId=pc.incidentId;
    else
        vehicleOwner, ownerId = GetVehicleOwner(plate)
        bolo, title, boloid = GetBoloStatus(plate,ownerId)
        warrant, owner, incidentId = GetWarrantStatus(plate, ownerId)
    end

    plateCache[plate] = {
        vehicleOwner = vehicleOwner,
        bolo = bolo,
        title = title,
        boloId = boloid,
        warrant = warrant,
        owner = owner,
        incidentId = incidentId
    }

    SetTimeout(1000 * 60 * 10, function()
        plateCache[plate] = nil
    end)

    if(not vehicleOwner or not ownerId) then
        ps.notify(src, 'Plate: '..plate..' | Return: No registered owner found.', 'error', Config.WolfknightNotifyTime)
        return
    else
        if(not vehicleOwner or not ownerId) then
            ps.notify(src, 'Plate: '..plate..' | Registered owner: ' .. tostring(vehicleOwner), 'info', Config.WolfknightNotifyTime)
            return
        end
    end



end)