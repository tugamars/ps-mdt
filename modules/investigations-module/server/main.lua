local resourceName = tostring(GetCurrentResourceName())
local config = InvestigationsModule
local manifestPath = 'modules/investigations-module/manifest.json'
local manifestJson = LoadResourceFile(resourceName, manifestPath)

if not manifestJson then
    print(('^1[%s] Could not load %s^0'):format(config.ModuleId, manifestPath))
else
    exports['ps-mdt']:RegisterModule(manifestJson)
end

local function moduleTrim(value)
    return type(value) == 'string' and value:gsub('^%s+', ''):gsub('%s+$', '') or ''
end

local function moduleLimited(value, maxLength)
    value = moduleTrim(value)
    return #value > maxLength and value:sub(1, maxLength) or value
end

local function trim(value)
    if type(value) ~= 'string' then return '' end
    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function limitedString(value, maxLength)
    value = trim(value)
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function validFiveManageUrl(value)
    if type(value) ~= 'string' or #value < 12 or #value > 255 then return false end
    local host = value:match('^https://([^/%?#:]+)')
    if not host then return false end
    host = host:lower()
    return host == 'fivemanage.com'
        or host:sub(-15) == '.fivemanage.com'
        or host == 'fivemerr.com'
        or host:sub(-13) == '.fivemerr.com'
end

local function normalizeCoords(coords)
    if type(coords) ~= 'table' then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y then return nil end
    return { x = x, y = y, z = z }
end

local function normalizePhoto(photo, index)
    if type(photo) ~= 'table' or not validFiveManageUrl(photo.url) then return nil end
    return {
        url = photo.url,
        location = limitedString(photo.location, 100),
        time = tonumber(photo.time),
        coords = normalizeCoords(photo.coords),
        index = index,
    }
end

local function formatTimestamp(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then return nil end
    return os.date('!%Y-%m-%d %H:%M:%S UTC', math.floor(timestamp))
end

local function formatCoordinates(coords)
    if not coords then return nil end
    if coords.z then return ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z) end
    return ('%.2f, %.2f'):format(coords.x, coords.y)
end

local function imageLabel(photo, index)
    local parts = { ('Photo %d'):format(index) }
    if photo.location ~= '' then parts[#parts + 1] = photo.location end
    local capturedAt = formatTimestamp(photo.time)
    if capturedAt then parts[#parts + 1] = capturedAt end
    return limitedString(table.concat(parts, ' - '), 100)
end

local function metadataNotes(baseNotes, photos)
    local lines = {}
    if baseNotes ~= '' then lines[#lines + 1] = baseNotes end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Imported from SD card:'

    for index, photo in ipairs(photos) do
        local details = { ('Photo %d'):format(index) }
        if photo.location ~= '' then details[#details + 1] = photo.location end
        local coords = formatCoordinates(photo.coords)
        if coords then details[#details + 1] = ('coords %s'):format(coords) end
        local capturedAt = formatTimestamp(photo.time)
        if capturedAt then details[#details + 1] = capturedAt end
        lines[#lines + 1] = table.concat(details, ' | ')
    end

    return limitedString(table.concat(lines, '\n'), 8000)
end

local function combinedLocation(photos)
    local seen, locations = {}, {}
    for _, photo in ipairs(photos) do
        if photo.location ~= '' and not seen[photo.location] then
            seen[photo.location] = true
            locations[#locations + 1] = photo.location
        end
    end
    return limitedString(table.concat(locations, '; '), 100)
end


local function createAttachment(source, caseId, photo, label)
    local attachmentId = MySQL.insert.await([[
        INSERT INTO mdt_case_attachments (case_id, type, url, label, uploaded_by)
        VALUES (?, 'photo', ?, ?, ?)
    ]], {
        caseId,
        photo.url,
        label,
        ps.getIdentifier(source),
    })

    if not attachmentId then return nil, 'Failed to attach an SD card photo to the case' end
    return attachmentId
end

local function createEvidence(source, caseId, title, notes, location, photos)
    local identifier = ps.getIdentifier(source)
    local evidenceId = MySQL.insert.await([[
        INSERT INTO mdt_evidence_items
            (case_id, title, type, notes, location, `stored`, last_holder, created_by)
        VALUES (?, ?, 'Photos', ?, ?, 0, ?, ?)
    ]], { caseId, title, notes, location, identifier, identifier })

    if not evidenceId then return nil, 'Failed to create evidence item' end

    for index, photo in ipairs(photos) do
        local imageId = MySQL.insert.await([[
            INSERT INTO mdt_evidence_images (evidence_id, url, label, uploaded_by)
            VALUES (?, ?, ?, ?)
        ]], { evidenceId, photo.url, imageLabel(photo, index), identifier })

        if not imageId then
            MySQL.query.await('DELETE FROM mdt_evidence_items WHERE id = ?', { evidenceId })
            return nil, 'Failed to attach an SD card photo'
        end
    end

    local custodyId = MySQL.insert.await([[
        INSERT INTO mdt_evidence_custody
            (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, NULL, ?, 'collected', 'Imported from SD card')
    ]], { evidenceId, identifier })

    if not custodyId then
        MySQL.query.await('DELETE FROM mdt_evidence_items WHERE id = ?', { evidenceId })
        return nil, 'Failed to create the evidence custody record'
    end

    return evidenceId
end

ps.registerCallback(resourceName .. ':server:investigationsModule:importPhotos', function(source, payload)
    if not MDT.HasPermission(source, config.ViewPermission)
        or not MDT.HasPermission(source, config.ImportPermission)
        or (not MDT.HasPermission(source, 'cases_view') and not MDT.HasPermission(source, 'cases_create')) then
        MDT.Notify(source, 'You cannot import SD card photos', 'error')
        return { success = false, message = 'Access denied' }
    end

    if not MDT.IsModuleAvailable(config.ModuleId) then
        return { success = false, message = config.Dependency .. ' is not running' }
    end

    payload = type(payload) == 'table' and payload or {}
    local caseId = tonumber(payload.caseId)
    local title = limitedString(payload.title, 100)
    local notes = limitedString(payload.notes, 4000)
    local mode = payload.mode == 'individual' and 'individual' or 'combined'
    local storageTarget = payload.storageTarget == 'attachment' and 'attachment' or 'evidence'
    local submittedPhotos = type(payload.photos) == 'table' and payload.photos or {}

    if not caseId or caseId < 1 then return { success = false, message = 'Select a valid case' } end
    if title == '' then return { success = false, message = 'Import title is required' } end
    if #submittedPhotos < 1 or #submittedPhotos > config.MaxPhotosPerImport then
        return { success = false, message = ('Select between 1 and %d photos'):format(config.MaxPhotosPerImport) }
    end

    local caseExists = MySQL.scalar.await('SELECT 1 FROM mdt_cases WHERE id = ? LIMIT 1', { caseId })
    if not caseExists then return { success = false, message = 'The selected case no longer exists' } end

    local photos = {}
    for index, submitted in ipairs(submittedPhotos) do
        local photo = normalizePhoto(submitted, index)
        if not photo then
            return { success = false, message = ('Photo %d does not contain a valid FiveManage URL'):format(index) }
        end
        photos[#photos + 1] = photo
    end

    local createdIds = {}
    local resultKey = storageTarget == 'attachment' and 'attachmentIds' or 'evidenceIds'

    if storageTarget == 'attachment' then
        for index, photo in ipairs(photos) do
            local label = imageLabel(photo, index)
            if #photos == 1 and title ~= '' then label = title end
            local attachmentId, createError = createAttachment(source, caseId, photo, label)
            if not attachmentId then
                for _, createdId in ipairs(createdIds) do
                    MySQL.query.await('DELETE FROM mdt_case_attachments WHERE id = ?', { createdId })
                end
                return { success = false, message = createError or 'Import failed' }
            end
            createdIds[#createdIds + 1] = attachmentId
        end
    elseif mode == 'individual' and #photos > 1 then
        for index, photo in ipairs(photos) do
            local suffix = (' - %d'):format(index)
            local itemTitle = title:sub(1, 100 - #suffix) .. suffix
            local itemNotes = metadataNotes(notes, { photo })
            local evidenceId, createError = createEvidence(source, caseId, itemTitle, itemNotes, photo.location, { photo })
            if not evidenceId then
                for _, createdId in ipairs(createdIds) do
                    MySQL.query.await('DELETE FROM mdt_evidence_items WHERE id = ?', { createdId })
                end
                return { success = false, message = createError or 'Import failed' }
            end
            createdIds[#createdIds + 1] = evidenceId
        end
    else
        local evidenceId, createError = createEvidence(
            source,
            caseId,
            title,
            metadataNotes(notes, photos),
            combinedLocation(photos),
            photos
        )
        if not evidenceId then return { success = false, message = createError or 'Import failed' } end
        createdIds[1] = evidenceId
    end

    if ps.auditLog then
        ps.auditLog(source, 'investigation_photos_imported', 'case', caseId, {
            ids = createdIds,
            storageTarget = storageTarget,
            photoCount = #photos,
            mode = mode,
        })
    end

    MDT.Notify(source, ('Imported %d SD card photo%s'):format(#photos, #photos == 1 and '' or 's'), 'success')
    return { success = true, [resultKey] = createdIds, storageTarget = storageTarget, photoCount = #photos, mode = mode }
end)

local function createInterviewEvidence(source, caseId, interview)
    local identifier = ps.getIdentifier(source)
    local evidenceId = MySQL.insert.await([[INSERT INTO mdt_evidence_items
        (case_id, title, type, notes, location, `stored`, last_holder, created_by)
        VALUES (?, ?, 'Witness Interview', ?, ?, 0, ?, ?)]], {
        caseId, moduleLimited(('Witness Interview - %s'):format(interview.witnessName), 100),
        moduleLimited(interview.notes, 8000), interview.address, identifier, identifier
    })
    if not evidenceId then return nil, 'Failed to create witness interview evidence' end
    local custodyId = MySQL.insert.await([[INSERT INTO mdt_evidence_custody
        (evidence_id, from_citizenid, to_citizenid, action, notes)
        VALUES (?, NULL, ?, 'collected', 'Imported witness interview from evidence system')]], { evidenceId, identifier })
    if not custodyId then MySQL.query.await('DELETE FROM mdt_evidence_items WHERE id = ?', { evidenceId }); return nil, 'Failed to create the evidence custody record' end
    return evidenceId
end

local function getWitnessInterviewForms(source)
    local items = {}
    if GetResourceState('ox_inventory') == 'started' then
        local ok, result = pcall(function() return exports.ox_inventory:GetInventoryItems(source) end)
        if ok and type(result) == 'table' then items = result end
    end
    if #items == 0 and GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        local player = ok and core and core.Functions.GetPlayer(source) or nil
        if player and player.PlayerData and type(player.PlayerData.items) == 'table' then items = player.PlayerData.items end
    end

    local forms = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name == 'witness_interview_form' and tonumber(item.slot) then
            local metadata = type(item.metadata) == 'table' and item.metadata or type(item.info) == 'table' and item.info or {}
            local statement = moduleLimited(metadata.statement, 7600)
            if statement ~= '' then
                forms[tonumber(item.slot)] = { witnessName = moduleLimited(metadata.citizen_name, 100), phone = moduleLimited(metadata.citizen_phone, 60), address = moduleLimited(metadata.citizen_address, 100), role = moduleLimited(metadata.role, 100), statement = statement, officerNotes = moduleLimited(metadata.officer_notes, 2000), date = moduleLimited(metadata.date, 30), officer = type(metadata.officer) == 'table' and metadata.officer or {} }
            end
        end
    end
    return forms
end

local function interviewNotes(interview)
    local officer, officerParts = interview.officer, {}
    for _, value in ipairs({ moduleLimited(officer.name, 100), moduleLimited(officer.callsign, 40), moduleLimited(officer.rank, 60), moduleLimited(officer.department, 60), moduleLimited(officer.job, 60) }) do
        if value ~= '' then officerParts[#officerParts + 1] = value end
    end
    local lines = { 'Imported from witness interview form', ('Witness: %s'):format(interview.witnessName ~= '' and interview.witnessName or 'Unknown witness') }
    if interview.phone ~= '' then lines[#lines + 1] = ('Phone: %s'):format(interview.phone) end
    if interview.role ~= '' then lines[#lines + 1] = ('Role: %s'):format(interview.role) end
    if interview.date ~= '' then lines[#lines + 1] = ('Interview date: %s'):format(interview.date) end
    if #officerParts > 0 then lines[#lines + 1] = ('Officer: %s'):format(table.concat(officerParts, ' | ')) end
    lines[#lines + 1] = ''; lines[#lines + 1] = 'Statement:'; lines[#lines + 1] = interview.statement
    if interview.officerNotes ~= '' then lines[#lines + 1] = ''; lines[#lines + 1] = 'Officer notes:'; lines[#lines + 1] = interview.officerNotes end
    return moduleLimited(table.concat(lines, '\n'), 8000)
end

ps.registerCallback(resourceName .. ':server:investigationsModule:searchProperties', function(source, payload)
    if not MDT.HasPermission(source, config.ViewPermission) or not MDT.HasPermission(source, config.PropertySearchPermission) or not MDT.HasPermission(source, 'citizens_search') then
        return { success = false, message = 'Access denied', properties = {} }
    end
    payload = type(payload) == 'table' and payload or {}
    local street, propertyNumber = moduleLimited(payload.street, 100), moduleLimited(payload.propertyNumber, 40)
    if #street < 2 then return { success = false, message = 'Enter at least two characters of the street name', properties = {} } end
    local propMap, playerMap = TableMap and TableMap.Properties, TableMap and TableMap.Players
    if not propMap or not playerMap then return { success = false, message = 'Property lookup is not configured', properties = {} } end
    local query = ([[SELECT %s AS propertyId, %s AS apartment, %s AS street, %s AS region, %s AS ownerCitizenId FROM %s WHERE %s LIKE ?]]):format(
        propMap.rawFields.property_id, propMap.rawFields.apartment, propMap.rawFields.street, propMap.rawFields.region, propMap.rawFields.owner, propMap.table, propMap.rawFields.street)
    local params = { '%' .. street .. '%' }
    if propertyNumber ~= '' then query = query .. (' AND %s LIKE ?'):format(propMap.rawFields.property_id); params[#params + 1] = '%' .. propertyNumber .. '%' end
    local rows = MySQL.query.await(query .. ' ORDER BY street ASC, propertyId ASC LIMIT 25', params) or {}
    local ownerIds, seen = {}, {}
    for _, row in ipairs(rows) do local ownerId = tostring(row.ownerCitizenId or ''); if ownerId ~= '' and not seen[ownerId] then seen[ownerId] = true; ownerIds[#ownerIds + 1] = ownerId end end
    local owners = {}
    if #ownerIds > 0 then
        local placeholders = {}; for index = 1, #ownerIds do placeholders[index] = '?' end
        local ownerRows = MySQL.query.await(([[SELECT %s AS citizenid, %s AS firstname, %s AS lastname FROM %s WHERE %s IN (%s)]]):format(playerMap.rawFields.citizenid, playerMap.rawFields.firstname, playerMap.rawFields.lastname, playerMap.table, playerMap.rawFields.citizenid, table.concat(placeholders, ',')), ownerIds) or {}
        for _, owner in ipairs(ownerRows) do owners[tostring(owner.citizenid)] = moduleTrim(('%s %s'):format(owner.firstname or '', owner.lastname or '')) end
    end
    local properties = {}
    for _, row in ipairs(rows) do
        local ownerId, ownerName = tostring(row.ownerCitizenId or ''), owners[tostring(row.ownerCitizenId or '')]
        local hasOwner = ownerId ~= '' and ownerId ~= '0' and ownerName and ownerName ~= ''
        properties[#properties + 1] = { propertyId = tostring(row.propertyId or ''), apartment = row.apartment or '', street = row.street or '', region = row.region or '', ownerCitizenId = hasOwner and ownerId or nil, ownerName = hasOwner and ownerName or 'Vacant', vacant = not hasOwner }
    end
    return { success = true, properties = properties }
end)

ps.registerCallback(resourceName .. ':server:investigationsModule:importWitnessInterviews', function(source, payload)
    if not MDT.HasPermission(source, config.ViewPermission) or not MDT.HasPermission(source, config.InterviewImportPermission) or (not MDT.HasPermission(source, 'cases_view') and not MDT.HasPermission(source, 'cases_create')) then return { success = false, message = 'Access denied' } end
    payload = type(payload) == 'table' and payload or {}; local caseId = tonumber(payload.caseId); local submitted = type(payload.interviews) == 'table' and payload.interviews or {}
    if not caseId or caseId < 1 then return { success = false, message = 'Select a valid case' } end
    if #submitted < 1 or #submitted > config.MaxInterviewsPerImport then return { success = false, message = ('Select between 1 and %d interviews'):format(config.MaxInterviewsPerImport) } end
    if not MySQL.scalar.await('SELECT 1 FROM mdt_cases WHERE id = ? LIMIT 1', { caseId }) then return { success = false, message = 'The selected case no longer exists' } end
    local forms, createdIds, usedSlots = getWitnessInterviewForms(source), {}, {}
    for index, entry in ipairs(submitted) do
        entry = type(entry) == 'table' and entry or {}
        local slot = tonumber(entry.slot)
        if slot and usedSlots[slot] then return { success = false, message = 'Each witness interview form may only be imported once' } end
        local interview = slot and forms[slot] or nil
        if not interview then return { success = false, message = ('Witness interview form %d is unavailable or incomplete'):format(index) } end
        usedSlots[slot] = true
        if interview.witnessName == '' then interview.witnessName = 'Unknown witness' end
        interview.notes = interviewNotes(interview)
        local evidenceId, createError = createInterviewEvidence(source, caseId, interview)
        if not evidenceId then return { success = false, message = createError or 'Interview import failed' } end
        createdIds[#createdIds + 1] = evidenceId
    end
    if ps.auditLog then ps.auditLog(source, 'witness_interviews_imported', 'case', caseId, { ids = createdIds, interviewCount = #createdIds }) end
    MDT.Notify(source, ('Imported %d witness interview%s'):format(#createdIds, #createdIds == 1 and '' or 's'), 'success')
    return { success = true, evidenceIds = createdIds, interviewCount = #createdIds }
end)
