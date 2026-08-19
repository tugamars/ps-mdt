local resourceName = tostring(GetCurrentResourceName())
local config = TugamarsCsiEvidenceSdcard

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
    return ps.callback(resourceName .. ':server:tugamarsCsiSdcard:importPhotos', data)
end)
