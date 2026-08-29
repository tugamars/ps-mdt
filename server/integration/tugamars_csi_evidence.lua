local resourceName = tostring(GetCurrentResourceName())
local csiResourceName = 'tugamars-csi_evidence'

local validActions = {
    collected = true,
    transferred = true,
    stored = true,
    released = true,
    updated = true,
    viewed = true
}

local pendingCustodyByCsiId = {}

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function valueOrNil(value)
    if value == nil then return nil end
    local text = trim(value)
    if text == '' then return nil end
    return text
end

local function readNested(payload, key)
    if type(payload) ~= 'table' then return nil end

    local value = payload[key]
    if value ~= nil then return value end

    for _, nestedKey in ipairs({ 'item', 'metadata', 'info', 'evidence', 'box', 'destination' }) do
        local nested = payload[nestedKey]
        if type(nested) == 'table' and nested[key] ~= nil then
            return nested[key]
        end
    end

    return nil
end

local function firstValue(payload, keys)
    for _, key in ipairs(keys) do
        local value = readNested(payload, key)
        if valueOrNil(value) then
            return value
        end
    end
    return nil
end

local function boolValue(value, fallback)
    if value == nil then return fallback end
    if type(value) == 'boolean' then return value end
    if tonumber(value) then return tonumber(value) ~= 0 end

    value = tostring(value):lower()
    return value == 'true' or value == 'yes' or value == 'stored'
end

local function stringifyCoords(coords)
    if type(coords) ~= 'table' then return valueOrNil(coords) end

    local x = coords.x or coords[1]
    local y = coords.y or coords[2]
    local z = coords.z or coords[3]
    if not x or not y then return nil end

    if z then
        return ('%.2f, %.2f, %.2f'):format(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    end

    return ('%.2f, %.2f'):format(tonumber(x) or 0, tonumber(y) or 0)
end

local function getCitizenId(value)
    if value == nil then return nil end

    local playerSource = tonumber(value)
    if playerSource and playerSource > 0 and GetPlayerName(playerSource) then
        local identifier = ps.getIdentifier(playerSource)
        if valueOrNil(identifier) then return identifier end
    end

    return valueOrNil(value)
end

local function getActorSource(src, payload)
    local actorSource = tonumber(src)
    if actorSource and actorSource > 0 then return actorSource end

    actorSource = tonumber(firstValue(payload, {
        'source',
        'src',
        'player',
        'playerId',
        'playerSource',
        'loggedBySource',
        'performedBySource'
    }))

    if actorSource and actorSource > 0 then return actorSource end
    return nil
end

local function mapCustodyAction(action)
    action = valueOrNil(action)
    if not action then return 'updated' end

    action = action:lower():gsub('%s+', '_')
    local aliases = {
        log = 'collected',
        logged = 'stored',
        logged_in = 'stored',
        collect = 'collected',
        collected = 'collected',
        transfer = 'transferred',
        transferred = 'transferred',
        move = 'transferred',
        moved = 'transferred',
        store = 'stored',
        stored = 'stored',
        release = 'released',
        released = 'released',
        update = 'updated',
        updated = 'updated',
        view = 'viewed',
        viewed = 'viewed'
    }

    action = aliases[action] or action
    return validActions[action] and action or 'updated'
end

local function isLoggedCustodyAction(action)
    action = valueOrNil(action)
    if not action then return false end

    action = action:lower():gsub('%s+', '_')
    return action == 'log' or action == 'logged' or action == 'logged_in'
end

local function ensureMapTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mdt_csi_evidence_map` (
            `csi_evidence_id` varchar(64) NOT NULL,
            `mdt_evidence_id` int(10) unsigned NOT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`csi_evidence_id`),
            KEY `mdt_evidence_id` (`mdt_evidence_id`)
        )
    ]])
end

local function getMappedEvidenceId(csiEvidenceId)
    csiEvidenceId = valueOrNil(csiEvidenceId)
    if not csiEvidenceId then return nil end

    local row = MySQL.single.await(
        'SELECT mdt_evidence_id FROM mdt_csi_evidence_map WHERE csi_evidence_id = ? LIMIT 1',
        { csiEvidenceId }
    )

    return row and tonumber(row.mdt_evidence_id) or nil
end

local function getPendingCustodyKey(csiEvidenceId)
    return valueOrNil(csiEvidenceId)
end

local function saveEvidenceMap(csiEvidenceId, mdtEvidenceId)
    csiEvidenceId = valueOrNil(csiEvidenceId)
    mdtEvidenceId = tonumber(mdtEvidenceId)
    if not csiEvidenceId or not mdtEvidenceId then return end

    MySQL.insert.await([[
        INSERT INTO mdt_csi_evidence_map (csi_evidence_id, mdt_evidence_id)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE mdt_evidence_id = VALUES(mdt_evidence_id)
    ]], { csiEvidenceId, mdtEvidenceId })
end

local function buildNotes(csiEvidenceId, data)
    local notes = valueOrNil(firstValue(data, { 'notes', 'note', 'description', 'desc' }))
    local parts = {}

    if notes then parts[#parts + 1] = notes end
    parts[#parts + 1] = ('CSI evidence ID: %s'):format(tostring(csiEvidenceId))

    local loggedBy = firstValue(data, { 'loggedBy', 'logged_by', 'performedBy', 'performed_by', 'officer', 'officerName' })
    if valueOrNil(loggedBy) then
        parts[#parts + 1] = ('Logged by: %s'):format(tostring(loggedBy))
    end

    local amount = firstValue(data, { 'amount', 'count', 'quantity' })
    if valueOrNil(amount) then
        parts[#parts + 1] = ('Quantity: %s'):format(tostring(amount))
    end

    return table.concat(parts, '\n')
end

local function buildRegistrationCustodyNotes(data)
    data = type(data) == 'table' and data or {}

    local parts = {}
    local notes = valueOrNil(firstValue(data, { 'notes' }))
    local box = valueOrNil(firstValue(data, {
        'boxId'
    }))
    local stash = valueOrNil(firstValue(data, {
        'stashName',
    }))

    if notes then parts[#parts + 1] = notes end
    if box then parts[#parts + 1] = ('Box Number: %s.'):format(box) end

    return table.concat(parts, '\n ')
end

local function applyPendingLoggedCustodyNotes(csiEvidenceId, data)
    local key = getPendingCustodyKey(csiEvidenceId)
    local pendingRows = key and pendingCustodyByCsiId[key] or nil
    if not pendingRows or #pendingRows == 0 then return data end

    data = type(data) == 'table' and data or {}

    local pendingNotes = {}
    for _, pending in ipairs(pendingRows) do
        local custody = pending.custody or {}
        if isLoggedCustodyAction(custody.action) and valueOrNil(custody.notes) then
            pendingNotes[#pendingNotes + 1] = tostring(custody.notes)
        end
    end

    if #pendingNotes == 0 then return data end

    local existingNotes = valueOrNil(data.custodyNotes or data.custody_notes or data.logNotes or data.log_notes)
    local mergedNotes = table.concat(pendingNotes, '\n')
    if existingNotes then
        mergedNotes = ('%s\n%s'):format(existingNotes, mergedNotes)
    end

    data.custodyNotes = mergedNotes
    return data
end

local function buildEvidencePayload(csiEvidenceId, data, actorSource)
    data = type(data) == 'table' and data or {}

    local title = firstValue(data, { 'title', 'label', 'name', 'itemLabel', 'itemName', 'evidenceLabel' })
        or ('CSI Evidence #%s'):format(tostring(csiEvidenceId))

    local evidenceType = firstValue(data, { 'type', 'category', 'evidenceType', 'itemType' }) or 'CSI Evidence'
    local serial = firstValue(data, { 'serial', 'serialNumber', 'fingerprint', 'dna', 'plate' }) or tostring(csiEvidenceId)
    local location = stringifyCoords(firstValue(data, { 'location', 'coords', 'coordinates' }))
    local stashId = firstValue(data, { 'stashName' })
    local actorCitizenId = actorSource and ps.getIdentifier(actorSource) or nil
    local loggedBy = getCitizenId(firstValue(data, { 'loggedBy', 'logged_by', 'createdBy', 'created_by', 'performedBy', 'performed_by' }))

    return {
        title = title,
        type = evidenceType,
        serial = serial,
        notes = buildNotes(csiEvidenceId, data),
        location = location or '',
        stashId = stashId or '',
        stored = boolValue(firstValue(data, { 'stored', 'isStored', 'inStorage' }), true),
        createdBy = loggedBy or actorCitizenId,
        lastHolder = loggedBy or actorCitizenId,
        custodyCitizenId = loggedBy or actorCitizenId,
        custodyNotes = buildRegistrationCustodyNotes(data)
    }
end

local function createMappedEvidence(src, csiEvidenceId, data)
    local existingMdtEvidenceId = getMappedEvidenceId(csiEvidenceId)
    if existingMdtEvidenceId then return existingMdtEvidenceId end

    data = applyPendingLoggedCustodyNotes(csiEvidenceId, data)
    local actorSource = getActorSource(src, data)
    local result = exports[resourceName]:CreateEvidence(buildEvidencePayload(csiEvidenceId, data, actorSource), actorSource)
    if not result or not result.success or not result.id then
        if ps and ps.warn then
            ps.warn(('[CSI Evidence] Failed to create MDT evidence for CSI ID %s: %s'):format(
                tostring(csiEvidenceId),
                tostring(result and result.error or 'unknown error')
            ))
        end
        return nil
    end

    saveEvidenceMap(csiEvidenceId, result.id)
    return tonumber(result.id)
end

local function normalizeCustodyRow(row, fallbackEvidenceId)
    if type(row) ~= 'table' then
        return {
            csiEvidenceId = fallbackEvidenceId,
            action = 'updated',
            notes = valueOrNil(row)
        }
    end

    return {
        csiEvidenceId = row.evidenceId or row.evidence_id or row[1] or fallbackEvidenceId,
        action = row.action or row[2] or 'updated',
        performedBy = row.performedBy or row.performed_by or row.actor or row[3],
        notes = row.notes or row.note or row[4],
        timestamp = row.timestamp or row.created_at or row[5],
        fromCitizenId = row.fromCitizenId or row.from_citizenid or row.from,
        toCitizenId = row.toCitizenId or row.to_citizenid or row.to
    }
end

local function mergeLoggedCustodyIntoCreation(mdtEvidenceId, custody)
    mdtEvidenceId = tonumber(mdtEvidenceId)
    if not mdtEvidenceId or not isLoggedCustodyAction(custody.action) then return false end

    local notes = valueOrNil(custody.notes)
    if not notes then return true end

    local creationRow = MySQL.single.await([[
        SELECT id, notes
        FROM mdt_evidence_custody
        WHERE evidence_id = ?
        ORDER BY id ASC
        LIMIT 1
    ]], { mdtEvidenceId })

    if not creationRow or not creationRow.id then return true end

    local existingNotes = valueOrNil(creationRow.notes)
    if existingNotes and existingNotes:find(notes, 1, true) then return true end

    local mergedNotes = notes
    if existingNotes then
        mergedNotes = ('%s\n%s'):format(existingNotes, notes)
    end

    MySQL.update.await('UPDATE mdt_evidence_custody SET notes = ? WHERE id = ?', { mergedNotes, creationRow.id })
    return true
end

local function sendCustodyToMdt(src, mdtEvidenceId, custody)
    if not mdtEvidenceId then return false end
    if isLoggedCustodyAction(custody.action) then
        return mergeLoggedCustodyIntoCreation(mdtEvidenceId, custody)
    end

    local action = mapCustodyAction(custody.action)

    local actorSource = getActorSource(src, { performedBy = custody.performedBy })
    local performedCitizenId = getCitizenId(custody.performedBy) or (actorSource and ps.getIdentifier(actorSource)) or nil
    local notes = valueOrNil(custody.notes) or ('Evidence %s.'):format(action)

    if valueOrNil(custody.timestamp) then
        notes = ('%s\nCSI timestamp: %s'):format(notes, tostring(custody.timestamp))
    end

    exports[resourceName]:UpdateEvidenceCustody({
        evidenceId = mdtEvidenceId,
        action = action,
        fromCitizenId = custody.fromCitizenId,
        toCitizenId = custody.toCitizenId or (action ~= 'released' and performedCitizenId or nil),
        notes = notes
    }, actorSource)

    return true
end

local function queuePendingCustody(src, csiEvidenceId, custody)
    local key = getPendingCustodyKey(csiEvidenceId)
    if not key then return end

    pendingCustodyByCsiId[key] = pendingCustodyByCsiId[key] or {}
    pendingCustodyByCsiId[key][#pendingCustodyByCsiId[key] + 1] = {
        src = src,
        custody = custody
    }
end

local function flushPendingCustody(csiEvidenceId, mdtEvidenceId)
    local key = getPendingCustodyKey(csiEvidenceId)
    mdtEvidenceId = tonumber(mdtEvidenceId)
    if not key or not mdtEvidenceId then return end

    local pendingRows = pendingCustodyByCsiId[key]
    if not pendingRows or #pendingRows == 0 then return end

    pendingCustodyByCsiId[key] = nil
    for _, pending in ipairs(pendingRows) do
        sendCustodyToMdt(pending.src, mdtEvidenceId, pending.custody)
    end
end

local function updateMappedCustody(src, fallbackEvidenceId, rows)
    if type(rows) ~= 'table' then rows = { rows } end
    if rows[1] == nil and (rows.action or rows.evidenceId or rows.evidence_id) then
        rows = { rows }
    end

    for _, row in ipairs(rows) do
        local custody = normalizeCustodyRow(row, fallbackEvidenceId)
        local csiEvidenceId = custody.csiEvidenceId
        local mdtEvidenceId = getMappedEvidenceId(csiEvidenceId)

        if not mdtEvidenceId then
            queuePendingCustody(src, csiEvidenceId, custody)
        else
            sendCustodyToMdt(src, mdtEvidenceId, custody)
        end
    end
end

CreateThread(function()
    ensureMapTable()
end)

AddEventHandler('tugamars_csi:server:OnEvidenceLogged', function(src, csiEvidenceId, data)
    if not csiEvidenceId then return end
    local mdtEvidenceId = createMappedEvidence(src, csiEvidenceId, data)
    if mdtEvidenceId then
        flushPendingCustody(csiEvidenceId, mdtEvidenceId)
    end
end)

AddEventHandler('tugamars_csi:server:OnEvidenceCustodyUpdated', function(src, csiEvidenceId, custodyRows)
    if not csiEvidenceId then return end
    updateMappedCustody(src, csiEvidenceId, custodyRows)
end)
