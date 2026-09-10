local resourceName = tostring(GetCurrentResourceName())

-- Helpers
local function buildCourtCaseNumber(id)
    local year = os.date('%Y')
    return ('CC-%s-%05d'):format(year, id)
end

local function buildOrderNumber(id)
    local year = os.date('%Y')
    return ('CO-%s-%05d'):format(year, id)
end

local function getDisplayName(src)
    local job = ps.getJobData and ps.getJobData(src) or {}
    local grade = type(job.grade) == 'table' and (job.grade.name or job.grade.label or job.grade.title) or nil
    local department = job.label or job.name or job.department
    local details = { ps.getPlayerName(src) or 'Unknown' }
    if grade and grade ~= '' then details[#details + 1] = grade end
    if department and department ~= '' and department ~= job.name then details[#details + 1] = department end
    return table.concat(details, ' · ')
end

local function CanReviewWarrants(src)
    return CheckPermission(src, 'warrants_review') or CheckPermission(src, 'warrants_approve')
end

-- Court Cases
ps.registerCallback(resourceName .. ':server:getCourtCases', function(source, page, limit, status, case_type, search)
    local src = source
    if not CheckAuth(src) then return { cases = {}, total = 0 } end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    if limit > 100 then limit = 100 end
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if status and status ~= '' and status ~= 'all' then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = status
    end

    if case_type and case_type ~= '' and case_type ~= 'all' then
        clauses[#clauses + 1] = 'case_type = ?'
        values[#values + 1] = case_type
    end

    if search and search ~= '' then
        clauses[#clauses + 1] = '(title LIKE ? OR case_number LIKE ? OR defendant_name LIKE ?)'
        local term = '%' .. search .. '%'
        values[#values + 1] = term
        values[#values + 1] = term
        values[#values + 1] = term
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    -- Count total
    local countValues = {}
    for i = 1, #values do countValues[i] = values[i] end
    local countRow = MySQL.single.await(
        ('SELECT COUNT(*) AS total FROM mdt_court_cases %s'):format(whereClause),
        countValues
    )
    local total = countRow and countRow.total or 0

    -- Fetch page
    values[#values + 1] = limit
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT id, case_number, title, summary, status, case_type,
               presiding_judge_name, prosecutor_name, defense_attorney_name,
               defendant_citizenid, defendant_name, hearing_date, filed_date,
               closed_date, created_by_name, created_at, updated_at
        FROM mdt_court_cases
        %s
        ORDER BY updated_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    return { cases = rows or {}, total = total }
end)

ps.registerCallback(resourceName .. ':server:getCourtCase', function(source, caseId)
    local src = source
    if not CheckAuth(src) then return nil end

    caseId = tonumber(caseId)
    if not caseId then return nil end

    local row = MySQL.single.await('SELECT * FROM mdt_court_cases WHERE id = ?', { caseId })
    return row
end)

ps.registerCallback(resourceName .. ':server:createCourtCase', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local title = payload.title or 'Untitled Court Case'
    local case_type = payload.case_type or 'criminal'
    local defendant_citizenid = payload.defendant_citizenid or nil
    local defendant_name = payload.defendant_name or nil
    local notes = payload.notes or nil
    local summary = payload.summary or nil
    local linked_mdt_case_id = payload.linked_mdt_case_id and tonumber(payload.linked_mdt_case_id) or nil
    local referred_from_report_id = payload.referred_from_report_id and tonumber(payload.referred_from_report_id) or nil

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, error = 'Missing citizen id' }
    end

    local createdByName = getDisplayName(src)

    local id = MySQL.insert.await([[
        INSERT INTO mdt_court_cases
        (case_number, title, summary, case_type, defendant_citizenid, defendant_name,
         notes, linked_mdt_case_id, referred_from_report_id, created_by, created_by_name)
        VALUES ('', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        title, summary, case_type, defendant_citizenid, defendant_name,
        notes, linked_mdt_case_id, referred_from_report_id, citizenid, createdByName
    })

    if not id then
        return { success = false, error = 'Failed to create court case' }
    end

    local caseNumber = buildCourtCaseNumber(id)
    MySQL.update.await('UPDATE mdt_court_cases SET case_number = ? WHERE id = ?', { caseNumber, id })

    if ps.auditLog then
        ps.auditLog(src, 'court_case_created', 'court_case', id, { title = title, case_type = case_type })
    end

    return { success = true, id = id, case_number = caseNumber }
end)

ps.registerCallback(resourceName .. ':server:updateCourtCase', function(source, caseId, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    caseId = tonumber(caseId)
    if not caseId then return { success = false, error = 'Invalid case id' } end

    payload = payload or {}
    local updates = {}
    local values = {}

    local allowedFields = {
        'title', 'summary', 'status', 'case_type', 'notes',
        'presiding_judge', 'presiding_judge_name',
        'prosecutor', 'prosecutor_name',
        'defense_attorney', 'defense_attorney_name',
        'defendant_citizenid', 'defendant_name',
        'hearing_date', 'closed_date',
        'linked_mdt_case_id', 'referred_from_report_id'
    }

    for _, field in ipairs(allowedFields) do
        if payload[field] ~= nil then
            updates[#updates + 1] = field .. ' = ?'
            values[#values + 1] = payload[field]
        end
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    values[#values + 1] = caseId
    local ok = MySQL.update.await(
        ('UPDATE mdt_court_cases SET %s WHERE id = ?'):format(table.concat(updates, ', ')),
        values
    )

    if not ok then
        return { success = false, error = 'Failed to update court case' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'court_case_updated', 'court_case', caseId, payload)
    end

    return { success = true }
end)

-- Warrant Requests
ps.registerCallback(resourceName .. ':server:getWarrantRequests', function(source, page, limit, status, search, mine)
    local src = source
    if not CheckAuth(src) then return { requests = {}, total = 0 } end
    if status == 'pending' and not CanReviewWarrants(src) then return { requests = {}, total = 0 } end
    local canReview = CanReviewWarrants(src)
    local ownRequests = status == 'mine' and mine == true
    if (status == 'executed' or status == 'denied') and not canReview and not ownRequests then return { requests = {}, total = 0 } end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    if limit > 100 then limit = 100 end
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if ownRequests then
        clauses[#clauses + 1] = "status IN ('pending', 'executed', 'denied')"
        clauses[#clauses + 1] = 'requesting_officer = ?'
        values[#values + 1] = ps.getIdentifier(src)
    elseif status and status ~= '' and status ~= 'all' then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = status
    end
    if search and search ~= '' then
        clauses[#clauses + 1] = '(citizen_name LIKE ? OR citizenid LIKE ? OR target_text LIKE ? OR CAST(linked_report_id AS CHAR) LIKE ?)'
        local term = '%' .. search .. '%'
        for _ = 1, 4 do values[#values + 1] = term end
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    local countValues = {}
    for i = 1, #values do countValues[i] = values[i] end
    local countRow = MySQL.single.await(
        ('SELECT COUNT(*) AS total FROM mdt_warrant_requests %s'):format(whereClause),
        countValues
    )
    local total = countRow and countRow.total or 0

    values[#values + 1] = limit
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT id, warrant_type, citizenid, citizen_name, target_text, requesting_officer, officer_name,
               charges, reason, linked_report_id, status, executed_by_name, executed_at,
               reviewer_citizenid, reviewer_name, review_reason, reviewed_at, created_at
        FROM mdt_warrant_requests
        %s
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    for _, row in ipairs(rows or {}) do
        -- Profile data is the durable source for historical requests, including
        -- requests created before officer_name began storing rank/department.
        local profile = MySQL.single.await([[SELECT fullname, `rank`, department
            FROM mdt_profiles WHERE citizenid = ? LIMIT 1]], { row.requesting_officer })
        if profile and profile.fullname and profile.fullname ~= '' then
            local department = profile.department or ''
            local sharedJob = department ~= '' and ps.getSharedJob and ps.getSharedJob(department) or nil
            department = (sharedJob and (sharedJob.label or sharedJob.name)) or department
            local details = { profile.fullname }
            if profile.rank and profile.rank ~= '' then details[#details + 1] = profile.rank end
            if department ~= '' then details[#details + 1] = department end
            row.officer_name = table.concat(details, ' · ')
        elseif (not row.officer_name or row.officer_name == '' or row.officer_name == row.requesting_officer) and TableMap and TableMap.Players then
            local p = TableMap.Players
            local officer = MySQL.single.await(([[SELECT %s AS firstname, %s AS lastname FROM %s WHERE %s = ? LIMIT 1]]):format(
                p.rawFields.firstname, p.rawFields.lastname, p.table, p.joinKey
            ), { row.requesting_officer })
            if officer then
                row.officer_name = ((officer.firstname or '') .. ' ' .. (officer.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            end
        end
    end

    return { requests = rows or {}, total = total }
end)

ps.registerCallback(resourceName .. ':server:createWarrantRequest', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local warrant_type = payload.warrant_type or 'arrest'
    local citizenid = payload.citizenid
    local citizen_name = payload.citizen_name or ''
    local target_text = payload.target_text or ''
    local charges = payload.charges or '[]'
    local reason = payload.reason
    local linked_report_id = payload.linked_report_id and tonumber(payload.linked_report_id) or nil

    if warrant_type ~= 'arrest' and warrant_type ~= 'search' and warrant_type ~= 'bench' then
        return { success = false, error = 'Invalid warrant type' }
    end
    if warrant_type == 'search' then
        if target_text == '' then return { success = false, error = 'A search warrant target is required' } end
        citizenid, citizen_name = '', target_text
    elseif not citizenid or citizenid == '' then
        return { success = false, error = 'A citizen target is required' }
    end

    if not reason or reason == '' then
        return { success = false, error = 'A reason/justification is required' }
    end
    if not linked_report_id then return { success = false, error = 'An attached report is required' } end
    if not MySQL.single.await('SELECT id FROM mdt_reports WHERE id = ?', { linked_report_id }) then
        return { success = false, error = 'Attached report was not found' }
    end
    if type(charges) == 'table' then charges = json.encode(charges) end
    if (warrant_type == 'arrest' or warrant_type == 'bench') and (not charges or charges == '' or charges == '[]') then
        return { success = false, error = 'At least one charge is required for arrest and bench warrants' }
    end

    local requesting_officer = ps.getIdentifier(src)
    local officer_name = getDisplayName(src)

    if citizen_name == '' and TableMap and TableMap.Players then
        local p = TableMap.Players
        local citizen = MySQL.single.await(([[SELECT %s AS firstname, %s AS lastname
            FROM %s WHERE %s = ? LIMIT 1]]):format(
            p.rawFields.firstname, p.rawFields.lastname, p.table, p.joinKey
        ), { citizenid })
        if citizen then
            citizen_name = ((citizen.firstname or '') .. ' ' .. (citizen.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
    end

    local existing = MySQL.single.await([[SELECT id FROM mdt_warrant_requests
        WHERE citizenid = ? AND target_text = ? AND linked_report_id = ? AND warrant_type = ? AND status = 'pending' LIMIT 1
    ]], { citizenid, target_text, linked_report_id, warrant_type })
    if existing then return { success = false, error = 'An identical pending warrant request already exists' } end

    local id = MySQL.insert.await([[
        INSERT INTO mdt_warrant_requests
        (warrant_type, citizenid, citizen_name, target_text, requesting_officer, officer_name, charges, reason, linked_report_id, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], { warrant_type, citizenid, citizen_name, target_text, requesting_officer, officer_name, charges, reason, linked_report_id })

    if not id then
        return { success = false, error = 'Failed to create warrant request' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'warrant_request_created', 'warrant_request', id, {
            citizenid = citizenid, warrant_type = warrant_type,
            linked_report_id = linked_report_id
        })
    end

    return { success = true, id = id }
end)

ps.registerCallback(resourceName .. ':server:reviewWarrantRequest', function(source, request_id, decision, reason)
	local src = source
	if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
	if not CanReviewWarrants(src) then return { success = false, error = 'Missing permission: warrants_review' } end

    request_id = tonumber(request_id)
    if not request_id then return { success = false, error = 'Invalid request id' } end

    if decision ~= 'approved' and decision ~= 'denied' then
        return { success = false, error = 'Invalid decision' }
    end

    local request = MySQL.single.await('SELECT * FROM mdt_warrant_requests WHERE id = ? AND status = ?', { request_id, 'pending' })
    if not request then
        return { success = false, error = 'Warrant request not found or already reviewed' }
    end

    local reviewerCitizenid = ps.getIdentifier(src)
    local reviewerName = getDisplayName(src)

    -- Update the request status
    MySQL.update.await([[
        UPDATE mdt_warrant_requests
        SET status = ?, reviewer_citizenid = ?, reviewer_name = ?, review_reason = ?, reviewed_at = NOW()
        WHERE id = ?
    ]], { decision, reviewerCitizenid, reviewerName, reason or '', request_id })

    -- Insert audit review record
    MySQL.insert.await([[
        INSERT INTO mdt_warrant_reviews (warrant_request_id, reviewer_citizenid, reviewer_name, decision, reason)
        VALUES (?, ?, ?, ?, ?)
    ]], { request_id, reviewerCitizenid, reviewerName, decision, reason or '' })

    -- Keep existing active-warrant integrations working for citizen-based warrants.
    if decision == 'approved' and request.linked_report_id and request.warrant_type ~= 'search' and request.citizenid ~= '' then
        local reportId = tonumber(request.linked_report_id)
        if reportId then
            local reportExists = MySQL.single.await('SELECT id FROM mdt_reports WHERE id = ?', { reportId })
            if reportExists then
                local expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + (30 * 24 * 60 * 60)) -- 30 days
                MySQL.insert.await([[
                    INSERT IGNORE INTO mdt_reports_warrants (reportid, citizenid, expirydate)
                    VALUES (?, ?, ?)
                ]], { reportId, request.citizenid, expiryDate })
            end
        end
    end

    if ps.auditLog then
        ps.auditLog(src, 'warrant_request_reviewed', 'warrant_request', request_id, {
            decision = decision,
            reason = reason,
            citizenid = request.citizenid
        })
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:executeWarrantRequest', function(source, request_id)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end
    if not CheckPermission(src, 'warrants_close') then return { success = false, error = 'Missing permission: warrants_close' } end
    request_id = tonumber(request_id)
    if not request_id then return { success = false, error = 'Invalid warrant id' } end
    local request = MySQL.single.await('SELECT * FROM mdt_warrant_requests WHERE id = ? AND status = ?', { request_id, 'approved' })
    if not request then return { success = false, error = 'Warrant not found or is not approved' } end
    MySQL.update.await([[UPDATE mdt_warrant_requests SET status = 'executed', executed_by = ?, executed_by_name = ?, executed_at = NOW() WHERE id = ?]], {
        ps.getIdentifier(src), getDisplayName(src), request_id
    })
    if request.linked_report_id and request.citizenid and request.citizenid ~= '' then
        MySQL.update.await('UPDATE mdt_reports_warrants SET expirydate = NOW() WHERE reportid = ? AND citizenid = ?', { request.linked_report_id, request.citizenid })
    end
    if ps.auditLog then ps.auditLog(src, 'warrant_executed', 'warrant_request', request_id, { citizenid = request.citizenid }) end
    return { success = true }
end)

-- Court Orders
ps.registerCallback(resourceName .. ':server:getCourtOrders', function(source, page, limit, orderType, status)
    local src = source
    if not CheckAuth(src) then return { orders = {}, total = 0 } end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    if limit > 100 then limit = 100 end
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if orderType and orderType ~= '' and orderType ~= 'all' then
        clauses[#clauses + 1] = 'type = ?'
        values[#values + 1] = orderType
    end

    if status and status ~= '' and status ~= 'all' then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = status
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    local countValues = {}
    for i = 1, #values do countValues[i] = values[i] end
    local countRow = MySQL.single.await(
        ('SELECT COUNT(*) AS total FROM mdt_court_orders %s'):format(whereClause),
        countValues
    )
    local total = countRow and countRow.total or 0

    values[#values + 1] = limit
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT id, order_number, court_case_id, type, title, status,
               target_citizenid, target_name, issued_by, issued_by_name,
               effective_date, expiry_date, created_at, updated_at
        FROM mdt_court_orders
        %s
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    return { orders = rows or {}, total = total }
end)

ps.registerCallback(resourceName .. ':server:createCourtOrder', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local title = payload.title
    local orderType = payload.type
    local content = payload.content

    if not title or not orderType or not content then
        return { success = false, error = 'Missing required fields (title, type, content)' }
    end

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, error = 'Missing citizen id' }
    end

    local issuedByName = getDisplayName(src)

    local id = MySQL.insert.await([[
        INSERT INTO mdt_court_orders
        (order_number, court_case_id, type, title, content, target_citizenid, target_name,
         issued_by, issued_by_name, effective_date, expiry_date)
        VALUES ('', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.court_case_id and tonumber(payload.court_case_id) or nil,
        orderType, title, content,
        payload.target_citizenid or nil,
        payload.target_name or nil,
        citizenid, issuedByName,
        payload.effective_date or os.date('%Y-%m-%d %H:%M:%S'),
        payload.expiry_date or nil
    })

    if not id then
        return { success = false, error = 'Failed to create court order' }
    end

    local orderNumber = buildOrderNumber(id)
    MySQL.update.await('UPDATE mdt_court_orders SET order_number = ? WHERE id = ?', { orderNumber, id })

    if ps.auditLog then
        ps.auditLog(src, 'court_order_created', 'court_order', id, { title = title, type = orderType })
    end

    return { success = true, id = id, order_number = orderNumber }
end)

ps.registerCallback(resourceName .. ':server:updateCourtOrder', function(source, orderId, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    orderId = tonumber(orderId)
    if not orderId then return { success = false, error = 'Invalid order id' } end

    payload = payload or {}
    local updates = {}
    local values = {}

    local allowedFields = {
        'title', 'content', 'type', 'status',
        'target_citizenid', 'target_name',
        'court_case_id', 'effective_date', 'expiry_date'
    }

    for _, field in ipairs(allowedFields) do
        if payload[field] ~= nil then
            updates[#updates + 1] = field .. ' = ?'
            values[#values + 1] = payload[field]
        end
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    values[#values + 1] = orderId
    local ok = MySQL.update.await(
        ('UPDATE mdt_court_orders SET %s WHERE id = ?'):format(table.concat(updates, ', ')),
        values
    )

    if not ok then
        return { success = false, error = 'Failed to update court order' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'court_order_updated', 'court_order', orderId, payload)
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:revokeCourtOrder', function(source, orderId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    orderId = tonumber(orderId)
    if not orderId then return { success = false, error = 'Invalid order id' } end

    local ok = MySQL.update.await(
        'UPDATE mdt_court_orders SET status = ? WHERE id = ?',
        { 'revoked', orderId }
    )

    if not ok then
        return { success = false, error = 'Failed to revoke court order' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'court_order_revoked', 'court_order', orderId, {})
    end

    return { success = true }
end)

-- Legal Documents
ps.registerCallback(resourceName .. ':server:getLegalDocuments', function(source, page, limit, docType, status)
    local src = source
    if not CheckAuth(src) then return { documents = {}, total = 0 } end

    page = tonumber(page) or 1
    limit = tonumber(limit) or 20
    if limit > 100 then limit = 100 end
    local offset = (page - 1) * limit

    local clauses = {}
    local values = {}

    if docType and docType ~= '' and docType ~= 'all' then
        clauses[#clauses + 1] = 'type = ?'
        values[#values + 1] = docType
    end

    if status and status ~= '' and status ~= 'all' then
        clauses[#clauses + 1] = 'status = ?'
        values[#values + 1] = status
    end

    local whereClause = ''
    if #clauses > 0 then
        whereClause = 'WHERE ' .. table.concat(clauses, ' AND ')
    end

    local countValues = {}
    for i = 1, #values do countValues[i] = values[i] end
    local countRow = MySQL.single.await(
        ('SELECT COUNT(*) AS total FROM mdt_legal_documents %s'):format(whereClause),
        countValues
    )
    local total = countRow and countRow.total or 0

    values[#values + 1] = limit
    values[#values + 1] = offset

    local rows = MySQL.query.await(([[
        SELECT id, court_case_id, type, title, status,
               author_citizenid, author_name, created_at, updated_at
        FROM mdt_legal_documents
        %s
        ORDER BY updated_at DESC
        LIMIT ? OFFSET ?
    ]]):format(whereClause), values)

    return { documents = rows or {}, total = total }
end)

ps.registerCallback(resourceName .. ':server:getLegalDocument', function(source, docId)
    local src = source
    if not CheckAuth(src) then return nil end

    docId = tonumber(docId)
    if not docId then return nil end

    local row = MySQL.single.await('SELECT * FROM mdt_legal_documents WHERE id = ?', { docId })
    return row
end)

ps.registerCallback(resourceName .. ':server:createLegalDocument', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    payload = payload or {}
    local title = payload.title
    local docType = payload.type
    local content = payload.content or ''

    if not title or not docType then
        return { success = false, error = 'Missing required fields (title, type)' }
    end

    local citizenid = ps.getIdentifier(src)
    if not citizenid then
        return { success = false, error = 'Missing citizen id' }
    end

    local authorName = getDisplayName(src)

    local id = MySQL.insert.await([[
        INSERT INTO mdt_legal_documents
        (court_case_id, type, title, content, status, author_citizenid, author_name)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.court_case_id and tonumber(payload.court_case_id) or nil,
        docType, title, content,
        payload.status or 'draft',
        citizenid, authorName
    })

    if not id then
        return { success = false, error = 'Failed to create legal document' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'legal_document_created', 'legal_document', id, { title = title, type = docType })
    end

    return { success = true, id = id }
end)

ps.registerCallback(resourceName .. ':server:updateLegalDocument', function(source, docId, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    docId = tonumber(docId)
    if not docId then return { success = false, error = 'Invalid document id' } end

    payload = payload or {}
    local updates = {}
    local values = {}

    local allowedFields = { 'title', 'content', 'type', 'status', 'court_case_id' }

    for _, field in ipairs(allowedFields) do
        if payload[field] ~= nil then
            updates[#updates + 1] = field .. ' = ?'
            values[#values + 1] = payload[field]
        end
    end

    if #updates == 0 then
        return { success = false, error = 'No updates provided' }
    end

    values[#values + 1] = docId
    local ok = MySQL.update.await(
        ('UPDATE mdt_legal_documents SET %s WHERE id = ?'):format(table.concat(updates, ', ')),
        values
    )

    if not ok then
        return { success = false, error = 'Failed to update legal document' }
    end

    if ps.auditLog then
        ps.auditLog(src, 'legal_document_updated', 'legal_document', docId, payload)
    end

    return { success = true }
end)

ps.registerCallback(resourceName .. ':server:deleteLegalDocument', function(source, docId)
    local src = source
    if not CheckAuth(src) then return { success = false, error = 'Unauthorized' } end

    docId = tonumber(docId)
    if not docId then return { success = false, error = 'Invalid document id' } end

    -- Only allow deleting drafts
    local doc = MySQL.single.await('SELECT status FROM mdt_legal_documents WHERE id = ?', { docId })
    if not doc then
        return { success = false, error = 'Document not found' }
    end

    if doc.status ~= 'draft' then
        return { success = false, error = 'Only draft documents can be deleted' }
    end

    MySQL.query.await('DELETE FROM mdt_legal_documents WHERE id = ?', { docId })

    if ps.auditLog then
        ps.auditLog(src, 'legal_document_deleted', 'legal_document', docId, {})
    end

    return { success = true }
end)

-- DOJ Dashboard
ps.registerCallback(resourceName .. ':server:getDojDashboard', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local pendingWarrants = MySQL.single.await(
        "SELECT COUNT(*) AS count FROM mdt_warrant_requests WHERE status = 'pending'"
    )

    local activeCases = MySQL.single.await(
        "SELECT COUNT(*) AS count FROM mdt_court_cases WHERE status NOT IN ('closed', 'dismissed')"
    )

    local upcomingHearings = MySQL.query.await([[
        SELECT id, case_number, title, hearing_date, defendant_name
        FROM mdt_court_cases
        WHERE hearing_date IS NOT NULL AND hearing_date >= NOW() AND status NOT IN ('closed', 'dismissed')
        ORDER BY hearing_date ASC
        LIMIT 10
    ]])

    local recentOrders = MySQL.query.await([[
        SELECT id, order_number, title, type, status, issued_by_name, created_at
        FROM mdt_court_orders
        ORDER BY created_at DESC
        LIMIT 10
    ]])

    local lawyerRequests = MySQL.single.await(
        "SELECT COUNT(*) AS count FROM mdt_reports WHERE lawyer_requested = 1"
    )

    return {
        pendingWarrants = pendingWarrants and pendingWarrants.count or 0,
        activeCases = activeCases and activeCases.count or 0,
        upcomingHearings = upcomingHearings or {},
        recentOrders = recentOrders or {},
        lawyerRequests = lawyerRequests and lawyerRequests.count or 0
    }
end)
