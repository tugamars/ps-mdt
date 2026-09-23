
local resourceName = tostring(GetCurrentResourceName())

local function getChargeCodeTypes()
    local configured = Config and Config.ChargeCodeTypes
    if type(configured) ~= 'table' or #configured == 0 then
        return { { value = 'penal', label = 'Penal Code' } }
    end
    return configured
end

local function getCodeTypeLabel(value)
    for _, item in ipairs(getChargeCodeTypes()) do
        if item.value == value then return item.label end
    end
    return value == 'penal' and 'Penal Code' or value
end

ps.registerCallback('ps-mdt:getChargeList', function(source)
    -- Allow civilians to view charges (legislation) if civilian access is enabled
    local civAccess = Config.CivilianAccess
    if not CheckAuth(source) and not (civAccess and civAccess.enabled) then return {} end

    local codeTypeCases = {}
    for _, item in ipairs(getChargeCodeTypes()) do
        codeTypeCases[#codeTypeCases + 1] = "WHEN '" .. tostring(item.value):gsub("'", "''") .. "' THEN '" .. tostring(item.label):gsub("'", "''") .. "'"
    end
    codeTypeCases[#codeTypeCases + 1] = 'ELSE code_type'

    local query = ([[
        SELECT
            code,
            code_type AS codeType,
            CASE code_type %s END AS codeTypeLabel,
            label,
            charge_class AS type,
            description,
            expanded_definition AS expandedDefinition,
            months AS time,
            fine,
            CASE
                WHEN charge_class = 'felony' THEN 'Offenses Against Persons'
                WHEN charge_class = 'misdemeanor' THEN 'Offenses Against Public Order'
                WHEN charge_class = 'infraction' THEN 'Offenses Against Public Safety'
                ELSE 'Uncategorized'
            END AS category
        FROM mdt_penal_codes
        ORDER BY code_type, charge_class, label
    ]]):format(table.concat(codeTypeCases, ' '))
    local rows = MySQL.query.await(query, {})
    ps.debug('[getChargeList] rows', rows and #rows or 0)
    if Config and Config.Debug and rows and rows[1] then
        ps.debug('[getChargeList] sample', rows[1])
    end
    return rows
end)

ps.registerCallback(resourceName .. ':server:getChargeCodeTypes', function(source)
    if not CheckAuth(source) then return {} end
    local result = {}
    for _, item in ipairs(getChargeCodeTypes()) do
        result[#result + 1] = { value = item.value, label = item.label }
    end
    return result
end)

-- Process a fine - deduct money from citizen's bank account
-- Ported from ps-mdt v1 (mdt:server:removeMoney)
local fineAntiSpam = false
ps.registerCallback(resourceName .. ':server:processFine', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenid
    local fine = tonumber(payload.fine)
    local reportId = payload.reportId

    local jfConfig = GetJailFinesConfig and GetJailFinesConfig() or {}
    local maxFine = jfConfig.maxFineAmount or (Config and Config.Fines and Config.Fines.MaxAmount) or 100000
    if not citizenId or not fine or fine <= 0 then
        return { success = false, message = 'Missing citizen ID or invalid fine amount' }
    end
    if fine > maxFine then
        return { success = false, message = 'Fine amount exceeds maximum of $' .. maxFine }
    end

    if fineAntiSpam then
        return { success = false, message = 'Fine processing on cooldown' }
    end

    -- Try to get online player first
    local Player = ps.getPlayerByIdentifier(citizenId)
    if not Player then
        return { success = false, message = 'Player must be online to process fine' }
    end

    -- Remove money from bank
    local removed = ps.removeMoney(Player.source or Player.PlayerData.source, 'bank', fine, 'mdt-fine')
    if removed then
        ps.notify(Player.source or Player.PlayerData.source, '$' .. fine .. ' fine deducted from your bank account', 'error')

        -- Anti-spam cooldown
        fineAntiSpam = true
        local cooldown = (Config and Config.Fines and Config.Fines.CooldownMs) or 30000
        SetTimeout(cooldown, function()
            fineAntiSpam = false
        end)

        if ps.auditLog then
            local officerName = ps.getPlayerName(src) or 'Unknown Officer'
            ps.auditLog(src, 'fine_processed', 'fine', reportId and tostring(reportId) or nil, {
                citizenid = citizenId,
                fine = fine,
                officer = officerName,
            })
        end

        return { success = true, message = 'Fine of $' .. fine .. ' processed' }
    else
        return { success = false, message = 'Failed to remove money - insufficient funds?' }
    end
end)

ps.registerCallback(resourceName .. ':server:updateCharge', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'charges_edit') then
        return { success = false, message = 'You do not have permission to edit charges' }
    end

    payload = payload or {}
    if not payload.code then
        return { success = false, message = 'Missing charge code' }
    end

    local penalUpdates = {}
    local penalValues = {}
    if payload.fine ~= nil then
        penalUpdates[#penalUpdates + 1] = 'fine = ?'
        penalValues[#penalValues + 1] = math.max(0, tonumber(payload.fine) or 0)
    end
    if payload.time ~= nil then
        penalUpdates[#penalUpdates + 1] = 'months = ?'
        penalValues[#penalValues + 1] = math.max(0, tonumber(payload.time) or 0)
    end
    if payload.label ~= nil and type(payload.label) == 'string' and payload.label ~= '' then
        penalUpdates[#penalUpdates + 1] = 'label = ?'
        penalValues[#penalValues + 1] = payload.label
    end
    if payload.description ~= nil and type(payload.description) == 'string' then
        penalUpdates[#penalUpdates + 1] = 'description = ?'
        penalValues[#penalValues + 1] = payload.description
    end
    if payload.expandedDefinition ~= nil and type(payload.expandedDefinition) == 'string' then
        penalUpdates[#penalUpdates + 1] = 'expanded_definition = ?'
        penalValues[#penalValues + 1] = payload.expandedDefinition
    end
    if payload.codeType ~= nil then
        local codeType = tostring(payload.codeType)
        local valid = false
        for _, item in ipairs(getChargeCodeTypes()) do
            if item.value == codeType then valid = true break end
        end
        if not valid then return { success = false, message = 'Invalid code type' } end
        penalUpdates[#penalUpdates + 1] = 'code_type = ?'
        penalValues[#penalValues + 1] = codeType
    end

    if #penalUpdates == 0 then
        return { success = true }
    end

    penalValues[#penalValues + 1] = payload.code
    local penalUpdated = MySQL.update.await(([[
        UPDATE mdt_penal_codes
        SET %s
        WHERE code = ?
    ]]):format(table.concat(penalUpdates, ', ')), penalValues)

    if penalUpdated and penalUpdated > 0 and ps.auditLog then
        ps.auditLog(src, 'charge_updated', 'charge', payload.code, {
            label = payload.label,
            fine = payload.fine,
            time = payload.time,
            description = payload.description
        })
    end
    return { success = penalUpdated and penalUpdated > 0 }
end)

ps.registerCallback(resourceName .. ':server:addCharge', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'charges_manage') then
        return { success = false, message = 'You do not have permission to manage charges' }
    end

    payload = payload or {}
    local code = payload.code and tostring(payload.code):gsub('^%s*(.-)%s*$', '%1') or ''
    local label = payload.label and tostring(payload.label):gsub('^%s*(.-)%s*$', '%1') or ''
    local chargeClass = payload.type and tostring(payload.type):lower() or 'infraction'
    local codeType = payload.codeType and tostring(payload.codeType) or 'penal'
    local description = payload.description and tostring(payload.description) or ''
    local expandedDefinition = payload.expandedDefinition and tostring(payload.expandedDefinition) or ''
    local months = math.max(0, tonumber(payload.time) or 0)
    local fine = math.max(0, tonumber(payload.fine) or 0)

    if code == '' or label == '' then
        return { success = false, message = 'Missing charge code or label' }
    end
    if chargeClass ~= 'felony' and chargeClass ~= 'misdemeanor' and chargeClass ~= 'infraction' then
        return { success = false, message = 'Invalid charge type' }
    end
    local validCodeType = false
    for _, item in ipairs(getChargeCodeTypes()) do
        if item.value == codeType then validCodeType = true break end
    end
    if not validCodeType then return { success = false, message = 'Invalid code type' } end

    local exists = MySQL.single.await('SELECT code FROM mdt_penal_codes WHERE code = ?', { code })
    if exists then
        return { success = false, message = 'A charge with that code already exists' }
    end

    local inserted = MySQL.insert.await([[
        INSERT INTO mdt_penal_codes (code, label, charge_class, description, expanded_definition, months, fine, code_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { code, label, chargeClass, description, expandedDefinition, months, fine, codeType })

    if inserted and ps.auditLog then
        ps.auditLog(src, 'charge_created', 'charge', code, {
            label = label,
            type = chargeClass,
            fine = fine,
            time = months,
        })
    end

    return { success = inserted ~= nil, charge = {
        code = code,
        codeType = codeType,
        codeTypeLabel = getCodeTypeLabel(codeType),
        expandedDefinition = expandedDefinition,
        label = label,
        type = chargeClass,
        description = description,
        time = months,
        fine = fine,
    } }
end)

ps.registerCallback(resourceName .. ':server:deleteCharge', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'charges_manage') then
        return { success = false, message = 'You do not have permission to manage charges' }
    end

    payload = payload or {}
    local code = payload.code and tostring(payload.code) or ''
    if code == '' then
        return { success = false, message = 'Missing charge code' }
    end

    local deleted = MySQL.update.await('DELETE FROM mdt_penal_codes WHERE code = ?', { code })
    if deleted and deleted > 0 and ps.auditLog then
        ps.auditLog(src, 'charge_deleted', 'charge', code, {})
    end

    return { success = deleted and deleted > 0 }
end)
