local function getOfficerJobName(source)
    local job = ps.getJob(source)
    local jobName = job and job.name or nil

    if not jobName and job and job.id then
        jobName = job.id
    end

    jobName = tostring(jobName or 'police')
    return jobName:gsub('^business_', '')
end

local function getDueAt(days)
    return os.date('!%Y-%m-%d %H:%M:%S', os.time() + ((days or 7) * 86400))
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function valueOrNil(value)
    if value == nil then return nil end
    local trimmed = trim(value)
    if trimmed == '' or trimmed == 'Unknown' or trimmed == 'Unknown Officer' or trimmed == 'NO CALLSIGN' then
        return nil
    end
    return value
end

local function valueOrEmpty(value)
    return valueOrNil(value) or ''
end

local function setString(info, key, value)
    info[key] = valueOrEmpty(value)
end

local function splitName(fullName)
    fullName = trim(fullName)
    local firstname, surname = fullName:match('^(%S+)%s+(.+)$')
    return firstname or fullName, surname or ''
end

local function getOfficerFullName(source)
    return valueOrNil(ps.getPlayerName(source) or GetPlayerName(source))
end

local function getOfficerDepartmentName(source)
    local jobData = ps.getJobData and ps.getJobData(source) or nil
    if jobData then
        local label = jobData.label or jobData.fullName or jobData.department
        if valueOrNil(label) then return label end
    end

    local job = ps.getJob(source)
    if job then
        local label = job.label or job.fullName or job.department
        if valueOrNil(label) then return label end
    end

    local jobName = getOfficerJobName(source)
    local sharedJob = ps.getSharedJob and ps.getSharedJob(jobName) or nil
    if sharedJob and valueOrNil(sharedJob.label) then
        return sharedJob.label
    end

    if jobName then
        local ok, row = pcall(function()
            return MySQL.single.await('SELECT * FROM bs_businesses WHERE name = ? OR id = ? LIMIT 1', { jobName, jobName })
        end)
        if ok and row and valueOrNil(row.label) then return row.label end
        if ok and row and valueOrNil(row.name) then return row.name end
    end

    return nil
end

local function getOfficerStreetName(source)
    if not GetPlayerPed or not GetEntityCoords or not GetStreetNameAtCoord or not GetStreetNameFromHashKey then
        return nil
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    if not coords then return nil end

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    if not streetHash or streetHash == 0 then return nil end

    return valueOrNil(GetStreetNameFromHashKey(streetHash))
end

local function buildFineInvoiceItems(reportId, citizenId, payloadCharges, fallbackFine)
    local chargeLines = {}
    local total = 0

    local function addChargeLine(description, quantity, unitPrice)
        quantity = math.max(1, tonumber(quantity) or 1)
        unitPrice = math.max(0, tonumber(unitPrice) or 0)
        if unitPrice <= 0 then return end

        chargeLines[#chargeLines + 1] = {
            description = tostring(description or 'MDT Fine'),
            quantity = quantity,
            unitPrice = unitPrice,
            total = quantity * unitPrice
        }
        total = total + (quantity * unitPrice)
    end

    if type(payloadCharges) == 'table' then
        for _, charge in ipairs(payloadCharges) do
            if charge and (not charge.citizenid or charge.citizenid == citizenId) then
                addChargeLine(charge.charge, charge.count, charge.fine)
            end
        end
    end

    if #chargeLines == 0 and reportId then
        local rows = MySQL.query.await([[
            SELECT charge, count, fine
            FROM mdt_reports_charges
            WHERE reportid = ? AND citizenid = ?
        ]], { reportId, citizenId })

        for _, charge in ipairs(rows or {}) do
            addChargeLine(charge.charge, charge.count, charge.fine)
        end
    end

    if #chargeLines == 0 then
        addChargeLine('MDT Fine', 1, fallbackFine)
    end

    local targetTotal = math.max(0, tonumber(fallbackFine) or total)
    if targetTotal > 0 and total > 0 and targetTotal ~= total then
        local scaledItems = {}
        local assignedTotal = 0

        for i, line in ipairs(chargeLines) do
            local lineTotal
            if i == #chargeLines then
                lineTotal = math.max(0, targetTotal - assignedTotal)
            else
                lineTotal = math.floor((line.total / total) * targetTotal + 0.5)
                assignedTotal = assignedTotal + lineTotal
            end

            local description = line.description
            if line.quantity > 1 then
                description = ('%s x%s'):format(description, line.quantity)
            end

            scaledItems[#scaledItems + 1] = {
                description = description,
                quantity = 1,
                unit_price = lineTotal
            }
        end

        return scaledItems, targetTotal
    end

    local items = {}
    for _, line in ipairs(chargeLines) do
        items[#items + 1] = {
            description = line.description,
            quantity = line.quantity,
            unit_price = line.unitPrice
        }
    end

    return items, total
end

local function getFineCharges(reportId, citizenId, payloadCharges)
    local charges = {}

    if type(payloadCharges) == 'table' then
        for _, charge in ipairs(payloadCharges) do
            if charge and (not charge.citizenid or charge.citizenid == citizenId) then
                charges[#charges + 1] = charge
            end
        end
    end

    if #charges > 0 or not reportId then
        return charges
    end

    return MySQL.query.await([[
        SELECT charge, count, fine
        FROM mdt_reports_charges
        WHERE reportid = ? AND citizenid = ?
        ORDER BY id ASC
    ]], { reportId, citizenId }) or {}
end

local function getCitationData(source, payload, total)
    local data = payload.citationData or payload
    local info = {}
    local reportId = payload.reportId
    local citizenId = payload.citizenId

    local citizenName = valueOrNil(data.fullname or data.name or ps.getPlayerNameByIdentifier(citizenId))
    local firstname, surname = splitName(citizenName)
    setString(info, 'firstname', data.firstname or firstname)
    setString(info, 'surname', data.surname or data.lastname or surname)
    setString(info, 'citationId', reportId)
    setString(info, 'date', data.date or os.date('%Y-%m-%d'))
    setString(info, 'postal', data.postal)
    setString(info, 'street', getOfficerStreetName(source))

    local vehicle = nil
    if reportId then
        vehicle = MySQL.single.await([[
            SELECT plate, vehicle_label
            FROM mdt_report_vehicles
            WHERE reportid = ?
            ORDER BY id ASC
            LIMIT 1
        ]], { reportId })
    end

    local plate = data.plate or payload.plate or (vehicle and vehicle.plate)
    setString(info, 'plate', plate)
    setString(info, 'veh_make', data.veh_make or data.vehicle_label or (vehicle and vehicle.vehicle_label))
    setString(info, 'veh_color', data.veh_color)
    setString(info, 'veh_type', data.veh_type)

    local callsign = ps.getMetadata and ps.getMetadata(source, 'callsign') or nil
    callsign = valueOrNil(callsign or data.badge)
    local officerName = valueOrNil(data.officer or getOfficerFullName(source))
    setString(info, 'officer', officerName)
    info.badge = callsign or ''
    setString(info, 'agency', data.agency or getOfficerDepartmentName(source))

    local charges = getFineCharges(reportId, citizenId, payload.charges)
    for i = 1, 3 do
        local charge = charges[i]
        if charge then
            local penalCode = MySQL.single.await([[
                SELECT code, label, description
                FROM mdt_penal_codes
                WHERE label = ? OR code = ?
                LIMIT 1
            ]], { charge.charge, charge.code or charge.vi_code })

            setString(info, 'vi_code_' .. i, charge.vi_code or charge.code or (penalCode and penalCode.code) or charge.charge)
            setString(info, 'vi_descrip_' .. i, charge.vi_descrip or charge.label or (penalCode and penalCode.label) or charge.charge)
        else
            setString(info, 'vi_code_' .. i, data['vi_code_' .. i])
            setString(info, 'vi_descrip_' .. i, data['vi_descrip_' .. i] or data['vi_description_' .. i])
        end
    end

    setString(info, 'officersig', data.officersig)
    setString(info, 'offendersig', data.offendersig)
    setString(info, 'comments', data.comments)
    info.fineAmount = data.fineAmount or total or payload.fine or ''

    return info
end

local function addCitationItem(source, info)
    if GetResourceState('qb-inventory') == 'started' then
        local ok, added = pcall(function()
            return exports['qb-inventory']:AddItem(source, 'citation', 1, false, info)
        end)
        if ok and added ~= false then return true end
    end

    if GetResourceState('ox_inventory') == 'started' then
        local ok, added = pcall(function()
            return exports.ox_inventory:AddItem(source, 'citation', 1, info)
        end)
        if ok and added ~= false then return true end
    end

    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    local Player = ok and QBCore and QBCore.Functions.GetPlayer(source) or nil
    if Player and Player.Functions and Player.Functions.AddItem then
        return Player.Functions.AddItem('citation', 1, false, info) ~= false
    end

    return false
end

SentencingIntegration = SentencingIntegration or {}

function SentencingIntegration.IssueFine(source, payload)
    payload = payload or {}
    local items, total = buildFineInvoiceItems(payload.reportId, payload.citizenId, payload.charges, payload.fine)

    if total <= 0 then
        return {
            success = false,
            message = 'No charge fines found for this invoice'
        }
    end

    local result = exports.bs_core:CreateInvoice(source, {
        fromType = 'business',
        fromId = getOfficerJobName(source),
        toType = 'personal',
        toId = payload.citizenId,
        items = items,
        notes = payload.notes,
        reference = payload.reference,
        dueAt = getDueAt(7)
    })

    if result and result.ok then
        local citationInfo = getCitationData(source, payload, total)
        local citationAdded = addCitationItem(source, citationInfo)
        if not citationAdded and ps and ps.warn then
            ps.warn(('[Sentencing] Failed to add citation item for source %s, report %s'):format(source, tostring(payload.reportId)))
        end

        return {
            success = true,
            id = result.id,
            invoiceNo = result.invoice_no,
            status = result.status or 'pending',
            amount = total,
            items = items,
            citation = citationInfo,
            citationAdded = citationAdded
        }
    end

    return {
        success = false,
        message = result and result.reason or 'Invoice failed'
    }
end

function SentencingIntegration.SendToJail(source, payload)

    TriggerEvent("tgm:sna:framework:server:sendToJail", source, payload.sentence);

    return {
        success = true
    }
end

RegisterNetEvent('bs_core:updateInvoiceStatus', function(id, status, paidAt)
    if not id then return end

    MySQL.update.await([[
        UPDATE mdt_sentencing_actions
        SET status = ?, paid_at = ?
        WHERE action = 'fine' AND external_id = ?
    ]], {
        tostring(status or 'unknown'),
        paidAt,
        tostring(id)
    })
end)
