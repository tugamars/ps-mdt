local function getCoreObject()
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then
        return core
    end

    local okQbx, qbx = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if okQbx and qbx then
        return qbx
    end

    return nil
end

local Core = getCoreObject()
local resourceName = tostring(GetCurrentResourceName())

local function formatLabel(value)
    if not value or value == '' then
        return 'Unknown'
    end
    local formatted = tostring(value)
    formatted = formatted:gsub("^%l", string.upper)
    formatted = formatted:gsub("_%l", function(s)
        return " " .. string.upper(s:sub(2))
    end)
    return formatted
end

local function getVehicleShared(model)
    if not Core or not Core.Shared or not Core.Shared.Vehicles then
        return nil
    end
    return Core.Shared.Vehicles[model]
end

local function buildVehicleFlags(stolen, hasActiveBolo, status)
    local flags = {}
    if hasActiveBolo then
        table.insert(flags, 'Bolo')
    end
    if stolen then
        table.insert(flags, 'Stolen')
    end
    if status and status ~= 'valid' then
        table.insert(flags, ('Status: %s'):format(formatLabel(status)))
    end
    return flags
end

local function countSetItems(set)
    if not set then
        return 0
    end
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    return count
end

ps.registerCallback(resourceName .. ':server:GetVehicles', function(source)
    local startTime = os.clock()
    local src = source
    if not CheckAuth(src) then return end

    local _V = TableMap.Vehicles
    local vehList = MySQL.query.await(([[
        SELECT
            %s AS id,
            %s AS plate,
            %s AS vehicle,
            %s as brand,
            %s as model,
            %s as color,
            %s as stateRegistered,
            %s AS citizenid,
            %s AS information,
            %s AS points,
            %s AS status,
            %s AS stolen,
            %s AS boloactive,
            %s AS image,
            %s AS core_state
        FROM %s %s
    ]]):format(
        _V.fields.id, _V.fields.plate, _V.fields.vehicle,  _V.fields.brand,  _V.fields.model,  _V.fields.color,  _V.fields.stateRegistered, _V.fields.citizenid,
        _V.fields.information, _V.fields.points, _V.fields.status,
        _V.fields.stolen, _V.fields.boloactive, _V.fields.image, _V.fields.state,
        _V.table, _V.alias
    ))

    local boloRows = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? AND status = ?', {'vehicle', 'active'})
    local reportIdsByPlate = {}
    local activeBoloByPlate = {}
    local bolos = {}

    for _, bolo in pairs(boloRows) do
        local plate = bolo.subject_id and string.upper(tostring(bolo.subject_id)) or nil
        if plate then
            reportIdsByPlate[plate] = reportIdsByPlate[plate] or {}
            if bolo.reportId then
                reportIdsByPlate[plate][tostring(bolo.reportId)] = true
            end
            if bolo.status == 'active' then
                activeBoloByPlate[plate] = true
            end
        end
        table.insert(bolos, {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            name = bolo.subject_name or 'Unknown Vehicle',
            type = bolo.type,
            notes = bolo.notes or '',
            status = bolo.status,
            plate = bolo.subject_id or 'Unknown',
            image = bolo.image or 'https://docs.fivem.net/vehicles/elegy.webp',
        })
    end

    local vehicles = {}
    for _, v in ipairs(vehList) do
        local vehicleData = getVehicleShared(v.vehicle)
        local plate = v.plate and string.upper(v.plate) or 'UNKNOWN'
        local reportCount = countSetItems(reportIdsByPlate[plate])
        local hasActiveBolo = activeBoloByPlate[plate] == true or v.boloactive == 1
        local flags = buildVehicleFlags(v.stolen == 1, hasActiveBolo, v.status)

        table.insert(vehicles, {
            id = v.id,
            model = v.vehicle,
            label = v.brand .. " "  .. v.model,
            plate = plate,
            owner = ps.getPlayerNameByIdentifier(v.citizenid) or 'Unknown',
            class = v.color or 'Unknown',
            type = formatLabel(vehicleData and vehicleData.type or 'Unknown'),
            flags = flags,
            image = (v.image and v.image ~= '' and v.image) or ('https://docs.fivem.net/vehicles/' .. v.vehicle .. '.webp'),
            seenIn = reportCount,
            points = tonumber(v.points) or 0,
            status = v.status or 'valid',
            core_state = tonumber(v.core_state) or 0,
        })
    end

    local endTime = os.clock()
    local elapsedTime = (endTime - startTime) * 1000
    ps.debug(string.format("getVehicles callback executed in %.2f ms", elapsedTime))

    if vehicles[1] then
        ps.debug('[getVehicles] Sample vehicle data structure:', vehicles[1])
    end
    if bolos[1] then
        ps.debug('[getVehicles] Sample bolo data structure:', bolos[1])
    end

    return {vehicles = vehicles, bolos = bolos}
end)

ps.registerCallback(resourceName .. ':server:UpdateVehicle', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local plate = payload.plate
    if not plate or plate == '' then
        return { success = false, message = 'Missing plate' }
    end

    local ownerRow = MySQL.single.await(
        ('SELECT %s AS citizenid FROM %s WHERE %s = ? LIMIT 1'):format(
            TableMap.Vehicles.rawFields.citizenid, TableMap.Vehicles.table,
            TableMap.Vehicles.rawFields.plate
        ), { plate })
    if not ownerRow or not ownerRow.citizenid then
        return { success = false, message = 'Vehicle not found' }
    end

    local existing = MySQL.single.await(
        ('SELECT %s AS points, %s AS status, %s AS information FROM %s WHERE %s = ? LIMIT 1'):format(
            TableMap.Vehicles.rawFields.points, TableMap.Vehicles.rawFields.status,
            TableMap.Vehicles.rawFields.information, TableMap.Vehicles.table,
            TableMap.Vehicles.rawFields.plate
        ), { plate })
    local previousPoints = existing and tonumber(existing.mdt_vehicle_points) or 0

    local points = tonumber(payload.points)
    if points and points < 0 then
        points = 0
    end

    local allowedStatus = {
        valid = true,
        suspended = true,
        expired = true,
        impounded = true
    }
    local status = payload.status
    if status and not allowedStatus[status] then
        status = nil
    end

    local updates = {}
    local values = {}

    if payload.information ~= nil then
        updates[#updates + 1] = TableMap.Vehicles.rawFields.information .. ' = ?'
        values[#values + 1] = payload.information
    end

    if points ~= nil then
        updates[#updates + 1] = TableMap.Vehicles.rawFields.points .. ' = ?'
        values[#values + 1] = points
    end

    if status ~= nil then
        updates[#updates + 1] = TableMap.Vehicles.rawFields.status .. ' = ?'
        values[#values + 1] = status
    end

    if #updates == 0 then
        return { success = true }
    end

    values[#values + 1] = plate

    MySQL.update.await(
        ('UPDATE %s SET %s WHERE %s = ?'):format(
            TableMap.Vehicles.table, table.concat(updates, ', '),
            TableMap.Vehicles.rawFields.plate
        ), values)

    if ps.auditLog then
        ps.auditLog(src, 'vehicle_updated', 'vehicle', plate, {
            plate = plate,
            points = points,
            status = status,
            information = payload.information
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:GetVehicle', function(source, plate)
    local src = source
    if not CheckAuth(src) then return end

    if not plate or plate == '' then
        return { success = false, message = 'Missing plate' }
    end

    local _V = TableMap.Vehicles
    local vehicleRow = MySQL.query.await(([[
        SELECT
            %s AS id,
            %s AS plate,
            %s AS vehicle,
            %s as brand,
            %s as model,
            %s as color,
            %s as stateRegistered,
            %s AS citizenid,
            %s AS information,
            %s AS points,
            %s AS status,
            %s AS stolen,
            %s AS boloactive,
            %s AS image,
            %s as vin,
            %s AS core_state
        FROM %s %s
        WHERE %s = ?
        LIMIT 1
    ]]):format(
        _V.fields.id, _V.fields.plate, _V.fields.vehicle,  _V.fields.brand,  _V.fields.model,  _V.fields.color,  _V.fields.stateRegistered, _V.fields.citizenid,
        _V.fields.information, _V.fields.points, _V.fields.status,
        _V.fields.stolen, _V.fields.boloactive, _V.fields.image, _V.fields.vinNumber, _V.fields.state,
        _V.table, _V.alias, _V.fields.plate
    ), { plate })

    if not vehicleRow or not vehicleRow[1] then
        return { success = false, message = 'Vehicle not found' }
    end

    local row = vehicleRow[1]
    local vehicleData = getVehicleShared(row.vehicle)
    local plateUpper = row.plate and string.upper(row.plate) or 'UNKNOWN'

    local boloRows = MySQL.query.await('SELECT * FROM mdt_bolos WHERE type = ? AND subject_id = ?', { 'vehicle', plate })
    local reportIdSet = {}
    local bolos = {}
    local hasActiveBolo = false
    for _, bolo in pairs(boloRows) do
        if bolo.reportId then
            reportIdSet[tostring(bolo.reportId)] = true
        end
        if bolo.status == 'active' then
            hasActiveBolo = true
        end
        table.insert(bolos, {
            id = bolo.id,
            reportId = bolo.reportId and tostring(bolo.reportId) or 'N/A',
            notes = bolo.notes or '',
            status = bolo.status,
            type = bolo.type,
        })
    end

    local reportCount = countSetItems(reportIdSet)
    local flags = buildVehicleFlags(row.stolen == 1, hasActiveBolo or row.boloactive == 1, row.status)

    return {
        success = true,
        vehicle = {
            id = row.id,
            model = row.vehicle,
            label = row.brand .. " "  .. row.model,
            brand = row.brand,
            plate = plateUpper,
            owner = ps.getPlayerNameByIdentifier(row.citizenid) or 'Unknown',
            class = formatLabel(row.color or 'Unknown'),
            type = formatLabel(row.stateRegistered or 'Unknown'),
            vin = row.vin or 'N/A',
            image = (row.image and row.image ~= '' and row.image) or ('https://docs.fivem.net/vehicles/' .. row.vehicle .. '.webp'),
            information = row.information or '',
            points = tonumber(row.points) or 0,
            status = row.status or 'Valid',
            core_state = tonumber(row.core_state) or 0,
            stolen = row.stolen == 1,
            boloactive = row.boloactive == 1,
            flags = flags,
            seenIn = reportCount,
            bolos = bolos,
        }
    }
end)
