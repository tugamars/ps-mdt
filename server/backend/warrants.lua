local resourceName = tostring(GetCurrentResourceName())

local function validateExpiry(expiry)
    if not expiry then
        return nil
    end
    local asNumber = tonumber(expiry)
    if asNumber then
        return asNumber
    end
    if type(expiry) == 'string' then
        local trimmed = expiry:match('^%s*(.-)%s*$')
        if trimmed and trimmed ~= '' then
            return trimmed
        end
    end
    return nil
end

local function toTimestamp(value)
    if not value then
        return nil
    end
    local numeric = tonumber(value)
    if numeric then
        if numeric > 100000000000 then
            return math.floor(numeric / 1000)
        end
        return numeric
    end
    return nil
end

local function getExpiryDate(value)
    local ts = toTimestamp(value)
    if ts then
        return os.date('%Y-%m-%d %H:%M:%S', ts)
    end
    if type(value) == 'string' and value ~= '' then
        return value
    end
    return nil
end

ps.registerCallback(resourceName .. ':server:getActiveWarrants', function(source, includeInactive)
    local src = source
    if not CheckAuth(src) then return {} end

    local _P = TableMap.Players
    local rows = MySQL.query.await(([[
        SELECT
            w.reportid,
            w.citizenid,
            w.felonies,
            w.misdemeanors,
            w.infractions,
            w.expirydate,
            %s AS firstname,
            %s AS lastname
        FROM mdt_reports_warrants w
        LEFT JOIN %s %s ON %s = w.citizenid
        WHERE (? = 1 OR w.expirydate >= NOW())
        ORDER BY w.expirydate ASC
    ]]):format(
        _P.fields.firstname,
        _P.fields.lastname,
        _P.table, _P.alias,
        _P.alias .. '.' .. _P.joinKey,
        includeInactive and 1 or 0
    ), { includeInactive and 1 or 0 })

    local results = {}
    for _, row in ipairs(rows or {}) do
        local name = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then
            name = ps.getPlayerNameByIdentifier(row.citizenid) or 'Unknown'
        end
        results[#results + 1] = {
            reportid = row.reportid,
            citizenid = row.citizenid,
            name = name,
            felonies = tonumber(row.felonies) or 0,
            misdemeanors = tonumber(row.misdemeanors) or 0,
            infractions = tonumber(row.infractions) or 0,
            expirydate = row.expirydate,
            active = row.expirydate and tostring(row.expirydate) > os.date('%Y-%m-%d %H:%M:%S') or false,
        }
    end

    return results
end)

ps.registerCallback(resourceName .. ':server:issueWarrant', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'warrants_issue') then return { success = false, error = 'Missing permission: warrants_issue' } end

    data = data or {}
    local reportId = tonumber(data.reportId)
    local citizenid = data.citizenid
    local expiryValue = validateExpiry(data.expirydate)
    local expiryDate = getExpiryDate(expiryValue)
    if not expiryDate then
        local defaultDays = (Config and Config.Warrants and Config.Warrants.DefaultExpiryDays) or 7
        expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (defaultDays * 24 * 60 * 60))
    end

    if not reportId or not citizenid then
        return { success = false, error = 'Missing required fields' }
    end

    local reportCharges = MySQL.query.await([[SELECT charge FROM mdt_reports_charges WHERE reportid = ? AND citizenid = ?]], { reportId, citizenid }) or {}
    if #reportCharges == 0 then return { success = false, error = 'Add at least one charge for this suspect before issuing a warrant' } end
    local chargeNames = {}
    for _, charge in ipairs(reportCharges) do chargeNames[#chargeNames + 1] = charge.charge end

    local existing = MySQL.single.await([[SELECT id FROM mdt_warrant_requests
        WHERE linked_report_id = ? AND citizenid = ? AND status = 'pending']], { reportId, citizenid })
    if existing then return { success = true, pending = true, requestId = existing.id } end

    local citizenName = ''
    if TableMap and TableMap.Players then
        local p = TableMap.Players
        local row = MySQL.single.await(([[SELECT %s AS firstname, %s AS lastname FROM %s WHERE %s = ? LIMIT 1]]):format(
            p.rawFields.firstname, p.rawFields.lastname, p.table, p.joinKey
        ), { citizenid })
        if row then citizenName = ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '') end
    end
    local job = ps.getJobData and ps.getJobData(src) or {}
    local grade = type(job.grade) == 'table' and (job.grade.name or job.grade.label or job.grade.title) or nil
    local department = job.label or job.department or job.name
    local officerName = ps.getPlayerName(src) or 'Unknown'
    if grade and grade ~= '' then officerName = officerName .. ' · ' .. grade end
    if department and department ~= '' and department ~= job.name then officerName = officerName .. ' · ' .. department end

    local requestId = MySQL.insert.await([[
        INSERT INTO mdt_warrant_requests
            (warrant_type, citizenid, citizen_name, target_text, requesting_officer, officer_name, charges, reason, linked_report_id, status)
        VALUES ('arrest', ?, ?, '', ?, ?, ?, ?, ?, 'pending')
    ]], { citizenid, citizenName, ps.getIdentifier(src), officerName, json.encode(chargeNames), 'Arrest warrant submitted from report for approval', reportId })
    if not requestId then return { success = false, error = 'Failed to submit warrant for approval' } end

    if ps.auditLog then
        ps.auditLog(src, 'warrant_submitted', 'warrant', reportId, {
            citizenid = citizenid,
            expirydate = expiryDate
        })
    end

    return { success = true, pending = true, requestId = requestId }
end)

ps.registerCallback(resourceName .. ':server:closeWarrant', function(source, data)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'warrants_close') then return { success = false, error = 'Missing permission: warrants_close' } end

    data = data or {}
    local reportId = tonumber(data.reportId)
    local citizenid = data.citizenid
    if not reportId or not citizenid then
        return { success = false, error = 'Missing required fields' }
    end

    local updated = MySQL.update.await([[
        UPDATE mdt_reports_warrants
        SET expirydate = NOW()
        WHERE reportid = ? AND citizenid = ?
    ]], { reportId, citizenid })

    -- Also cancel a request that has not yet been approved. The report remains intact.
    MySQL.update.await([[UPDATE mdt_warrant_requests
        SET status = 'denied', review_reason = 'Removed by authorized user', reviewed_at = NOW()
        WHERE linked_report_id = ? AND citizenid = ? AND status = 'pending']], { reportId, citizenid })

    if updated and updated > 0 then
        if ps.auditLog then
            ps.auditLog(src, 'warrant_closed', 'warrant', reportId, {
                citizenid = citizenid
            })
        end
        return { success = true }
    end

    return { success = false, error = 'Warrant not found' }
end)
