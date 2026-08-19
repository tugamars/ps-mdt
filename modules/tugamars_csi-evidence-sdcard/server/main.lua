local resourceName = tostring(GetCurrentResourceName())
local config = TugamarsCsiEvidenceSdcard
local manifestPath = 'modules/tugamars_csi-evidence-sdcard/manifest.json'
local manifestJson = LoadResourceFile(resourceName, manifestPath)

if not manifestJson then
    print(('^1[%s] Could not load %s^0'):format(config.ModuleId, manifestPath))
else
    exports['ps-mdt']:RegisterModule(manifestJson)
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

ps.registerCallback(resourceName .. ':server:tugamarsCsiSdcard:importPhotos', function(source, payload)
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
    local submittedPhotos = type(payload.photos) == 'table' and payload.photos or {}

    if not caseId or caseId < 1 then return { success = false, message = 'Select a valid case' } end
    if title == '' then return { success = false, message = 'Evidence title is required' } end
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
    if mode == 'individual' and #photos > 1 then
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
        ps.auditLog(source, 'sdcard_photos_imported', 'case', caseId, {
            evidenceIds = createdIds,
            photoCount = #photos,
            mode = mode,
        })
    end

    MDT.Notify(source, ('Imported %d SD card photo%s'):format(#photos, #photos == 1 and '' or 's'), 'success')
    return { success = true, evidenceIds = createdIds, photoCount = #photos, mode = mode }
end)
