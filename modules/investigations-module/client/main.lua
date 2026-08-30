local resourceName = tostring(GetCurrentResourceName())
local config = InvestigationsModule

local function dependencyStarted()
    return GetResourceState(config.Dependency) == 'started'
end

local function readCoordinate(coords, key, index)
    if coords == nil then return nil end

    local ok, value = pcall(function()
        return coords[key] or coords[index]
    end)
    if not ok then return nil end
    return tonumber(value)
end

local function normalizePhoto(photo, index)
    photo = type(photo) == 'table' and photo or {}
    local coords = photo.coords

    return {
        id = tostring(photo.id or photo.photoId or index),
        url = type(photo.url) == 'string' and photo.url or '',
        location = type(photo.location) == 'string' and photo.location or '',
        time = tonumber(photo.time),
        coords = coords and {
            x = readCoordinate(coords, 'x', 1),
            y = readCoordinate(coords, 'y', 2),
            z = readCoordinate(coords, 'z', 3),
        } or nil,
    }
end

local function normalizeCard(card, index)
    card = type(card) == 'table' and card or {}
    return {
        slot = tonumber(card.slot),
        label = type(card.label) == 'string' and card.label or 'SD Card',
        count = tonumber(card.count) or 0,
        max = tonumber(card.max) or 0,
        previewUrl = type(card.previewUrl) == 'string' and card.previewUrl or nil,
        index = index,
    }
end

local function normalizeOfficer(officer)
    officer = type(officer) == 'table' and officer or {}
    return { name = tostring(officer.name or ''), callsign = tostring(officer.callsign or ''), department = tostring(officer.department or ''), rank = tostring(officer.rank or ''), job = tostring(officer.job or '') }
end

local function normalizeWitnessInterview(item, index)
    item = type(item) == 'table' and item or {}
    local metadata = type(item.metadata) == 'table' and item.metadata or type(item.info) == 'table' and item.info or {}
    local statement, slot = tostring(metadata.statement or ''), tonumber(item.slot)
    if statement == '' or not slot then return nil end
    return { id = ('slot:%d'):format(slot), slot = slot, witnessName = tostring(metadata.citizen_name or 'Unknown witness'):sub(1, 100), phone = tostring(metadata.citizen_phone or ''):sub(1, 60), address = tostring(metadata.citizen_address or ''):sub(1, 150), role = tostring(metadata.role or ''):sub(1, 100), statement = statement:sub(1, 7600), officerNotes = tostring(metadata.officer_notes or ''):sub(1, 2000), date = tostring(metadata.date or ''):sub(1, 30), officer = normalizeOfficer(metadata.officer) }
end

local function getWitnessInterviewForms()
    local items = {}
    if GetResourceState('ox_inventory') == 'started' then
        local ok, results = pcall(function() return exports.ox_inventory:Search('slots', 'witness_interview_form') end)
        if ok and type(results) == 'table' then items = results end
    end
    if #items == 0 and GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        local player = ok and core and core.Functions.GetPlayerData() or nil
        if player and type(player.items) == 'table' then items = player.items end
    end
    local forms = {}
    for index, item in pairs(items) do
        if item and item.name == 'witness_interview_form' then
            local form = normalizeWitnessInterview(item, index)
            if form then forms[#forms + 1] = form end
        end
    end
    table.sort(forms, function(a, b) return a.slot < b.slot end)
    return forms
end

MDT.RegisterNUICallback(config.ModuleId, 'getSDCards', function()
    if not dependencyStarted() then
        return {
            success = false,
            available = false,
            message = ('%s is not running'):format(config.Dependency),
            cards = {},
        }
    end

    local ok, cards = pcall(function()
        return exports[config.Dependency]:GetPlayerSDCards()
    end)

    if not ok then
        print(('[%s] GetPlayerSDCards failed: %s'):format(config.ModuleId, tostring(cards)))
        return { success = false, available = true, message = 'Unable to read SD cards', cards = {} }
    end

    local result = {}
    for index, card in ipairs(type(cards) == 'table' and cards or {}) do
        local normalized = normalizeCard(card, index)
        if normalized.slot then result[#result + 1] = normalized end
    end

    return { success = true, available = true, cards = result }
end)

MDT.RegisterNUICallback(config.ModuleId, 'getSDCardPhotos', function(data)
    if not dependencyStarted() then
        return { success = false, available = false, message = ('%s is not running'):format(config.Dependency), photos = {} }
    end

    local slot = tonumber(type(data) == 'table' and data.slot or nil)
    if not slot or slot < 1 then
        return { success = false, available = true, message = 'Invalid SD card slot', photos = {} }
    end

    local ok, photos = pcall(function()
        return exports[config.Dependency]:GetSDCardPhotos(slot)
    end)

    if not ok then
        print(('[%s] GetSDCardPhotos(%s) failed: %s'):format(config.ModuleId, slot, tostring(photos)))
        return { success = false, available = true, message = 'Unable to read photos from this SD card', photos = {} }
    end

    local result = {}
    for index, photo in ipairs(type(photos) == 'table' and photos or {}) do
        local normalized = normalizePhoto(photo, index)
        if normalized.url ~= '' then result[#result + 1] = normalized end
    end

    return { success = true, available = true, photos = result }
end)

MDT.RegisterNUICallback(config.ModuleId, 'importPhotos', function(data)
    return ps.callback(resourceName .. ':server:investigationsModule:importPhotos', data)
end)

MDT.RegisterNUICallback(config.ModuleId, 'getWitnessInterviews', function()
    return { success = true, available = true, interviews = getWitnessInterviewForms() }
end)

MDT.RegisterNUICallback(config.ModuleId, 'searchProperties', function(data)
    return ps.callback(resourceName .. ':server:investigationsModule:searchProperties', data)
end)

MDT.RegisterNUICallback(config.ModuleId, 'importWitnessInterviews', function(data)
    return ps.callback(resourceName .. ':server:investigationsModule:importWitnessInterviews', data)
end)
