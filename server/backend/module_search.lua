local resourceName = tostring(GetCurrentResourceName())

local domainPermissions = {
    citizens = { 'citizens_search' },
    reports = { 'reports_view', 'reports_create' },
    cases = { 'cases_view', 'cases_create' },
}

local function hasDomainPermission(source, domain)
    if not CheckAuth(source, true) then return false end
    for _, permission in ipairs(domainPermissions[domain] or {}) do
        if MDT.HasPermission(source, permission) then return true end
    end
    return false
end

local function normalizeRequest(query, page, limit)
    query = type(query) == 'string' and query:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #query < 2 then return nil end
    if #query > 100 then query = query:sub(1, 100) end
    page = math.max(1, tonumber(page) or 1)
    limit = math.min(50, math.max(1, tonumber(limit) or 10))
    return query, page, limit, (page - 1) * limit
end

local function getEffectiveJobType(source)
    local jobType = ps.getJobType(source)
    local jobName = ps.getJobName(source)
    if Config.DojJobType and jobType == Config.DojJobType then return 'doj' end
    for _, dojJob in ipairs(Config.DojJobs or {}) do
        if dojJob == jobName then return 'doj' end
    end
    if jobType == Config.MedicalJobType then return 'ems' end
    return 'leo'
end

local function searchCitizens(query, limit, offset)
    local players = TableMap.Players
    local likeQuery = '%' .. query:lower() .. '%'
    return MySQL.query.await(([[
        SELECT DISTINCT
            mp.id AS profileId,
            %s AS citizenid,
            %s AS firstName,
            %s AS lastName,
            %s AS dateOfBirth,
            %s AS phone,
            %s AS occupation,
            mp.profilepicture AS image
        FROM %s AS %s
        LEFT JOIN mdt_profiles AS mp ON %s
        WHERE LOWER(%s) LIKE ?
           OR LOWER(%s) LIKE ?
           OR LOWER(%s) LIKE ?
           OR LOWER(%s) LIKE ?
           OR LOWER(%s) LIKE ?
        ORDER BY %s, %s
        LIMIT ? OFFSET ?
    ]]):format(
        players.fields.citizenid,
        players.fields.firstname,
        players.fields.lastname,
        players.fields.dateofbirth,
        players.fields.phone,
        players.fields.joblabel,
        players.table,
        players.alias,
        TableMap.joinCondition('mp'),
        players.fields.firstname,
        players.fields.lastname,
        TableMap.fullNameConcat(),
        players.fields.citizenid,
        players.fields.phone,
        players.fields.lastname,
        players.fields.firstname
    ), { likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, limit + 1, offset }) or {}
end

local function searchReports(source, query, limit, offset)
    local identifier = ps.getIdentifier(source)
    local job = ps.getJobName(source)
    local jobType = getEffectiveJobType(source)
    local likeQuery = '%' .. query .. '%'
    return MySQL.query.await([[
        SELECT mr.id, mr.id AS reportId, mr.title, mr.type,
               mr.authorplaintext AS author, mr.datecreated, mr.dateupdated,
               (SELECT mrt.tag FROM mdt_reports_tags mrt WHERE mrt.reportid = mr.id LIMIT 1) AS tag
        FROM mdt_reports mr
        LEFT JOIN mdt_reports_restrictions mrr ON mr.id = mrr.reportid
        WHERE (
            (? = 'doj' AND NOT EXISTS (
                SELECT 1 FROM mdt_reports_restrictions restricted
                WHERE restricted.reportid = mr.id
                  AND restricted.type = 'jobtype'
                  AND restricted.identifier = 'ems'
            ))
            OR (mrr.reportid IS NULL AND (? = 'leo' OR ? = 'ems'))
            OR (mrr.type = 'citizenid' AND mrr.identifier = ?)
            OR (mrr.type = 'job' AND mrr.identifier = ?)
            OR (mrr.type = 'jobtype' AND mrr.identifier = ?)
        )
        AND (
            CAST(mr.id AS CHAR) LIKE ?
            OR mr.title LIKE ?
            OR mr.type LIKE ?
            OR mr.authorplaintext LIKE ?
        )
        GROUP BY mr.id
        ORDER BY mr.datecreated DESC
        LIMIT ? OFFSET ?
    ]], {
        jobType, jobType, jobType, identifier, job, jobType,
        likeQuery, likeQuery, likeQuery, likeQuery,
        limit + 1, offset,
    }) or {}
end

local function searchCases(query, limit, offset)
    local likeQuery = '%' .. query .. '%'
    return MySQL.query.await([[
        SELECT mc.id, mc.case_number, mc.title, mc.summary, mc.status, mc.priority,
               mc.assigned_department, mc.created_by, mc.created_by_name,
               mc.created_at, mc.updated_at,
               mp.fullname AS primary_officer_name,
               mp.callsign AS primary_officer_callsign
        FROM mdt_cases mc
        LEFT JOIN mdt_case_officers mco ON mco.case_id = mc.id AND mco.role = 'primary'
        LEFT JOIN mdt_profiles mp
          ON mp.citizenid COLLATE utf8mb4_general_ci = mco.citizenid COLLATE utf8mb4_general_ci
        WHERE CAST(mc.id AS CHAR) LIKE ?
           OR mc.case_number LIKE ?
           OR mc.title LIKE ?
           OR mc.summary LIKE ?
           OR mc.assigned_department LIKE ?
        GROUP BY mc.id
        ORDER BY mc.updated_at DESC
        LIMIT ? OFFSET ?
    ]], { likeQuery, likeQuery, likeQuery, likeQuery, likeQuery, limit + 1, offset }) or {}
end

ps.registerCallback(resourceName .. ':server:moduleCoreSearch', function(source, domain, query, page, limit)
    if not domainPermissions[domain] or not hasDomainPermission(source, domain) then
        return { items = {}, page = 1, hasMore = false, message = 'Access denied' }
    end

    local normalizedQuery, normalizedPage, normalizedLimit, offset = normalizeRequest(query, page, limit)
    if not normalizedQuery then
        return { items = {}, page = 1, hasMore = false }
    end

    local rows
    if domain == 'citizens' then
        rows = searchCitizens(normalizedQuery, normalizedLimit, offset)
        for _, row in ipairs(rows) do
            row.id = row.citizenid
            row.cid = row.citizenid
            row.name = ((row.firstName or '') .. ' ' .. (row.lastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
            row.dob = row.dateOfBirth
        end
    elseif domain == 'reports' then
        rows = searchReports(source, normalizedQuery, normalizedLimit, offset)
    else
        rows = searchCases(normalizedQuery, normalizedLimit, offset)
        for _, row in ipairs(rows) do
            row.caseNumber = row.case_number
        end
    end

    local hasMore = #rows > normalizedLimit
    if hasMore then table.remove(rows, #rows) end

    if ps.auditLog then
        ps.auditLog(source, 'module_search_' .. domain, 'search', nil, {
            query = normalizedQuery,
            page = normalizedPage,
        })
    end

    return {
        items = rows,
        page = normalizedPage,
        hasMore = hasMore,
    }
end)
