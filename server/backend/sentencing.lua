local resourceName = tostring(GetCurrentResourceName())
local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
if not ok then QBCore = nil end

local function normalizeReportId(reportId)
    local normalized = tonumber(reportId)
    if not normalized or normalized <= 0 then
        return nil
    end
    return normalized
end

local function getExistingSentencingAction(reportId, citizenId, action)
    if not reportId then return nil end

    return MySQL.single.await([[
        SELECT id, status, external_reference
        FROM mdt_sentencing_actions
        WHERE reportid = ? AND citizenid = ? AND action = ?
        LIMIT 1
    ]], { reportId, citizenId, action })
end

local function saveSentencingAction(payload)
    local metadata = payload.metadata and json.encode(payload.metadata) or nil

    return MySQL.insert.await([[
        INSERT INTO mdt_sentencing_actions
            (reportid, citizenid, action, amount, sentence, status, external_id, external_reference, metadata, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.reportId,
        payload.citizenId,
        payload.action,
        payload.amount,
        payload.sentence,
        payload.status,
        payload.externalId,
        payload.externalReference,
        metadata,
        payload.createdBy
    })
end

-- Send to Jail
ps.registerCallback(resourceName .. ':server:sendToJail', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenId
    local sentence = tonumber(payload.sentence)
    local reportId = normalizeReportId(payload.reportId)

    if not citizenId or not sentence or sentence <= 0 then
        return { success = false, message = 'Missing citizen ID or invalid sentence' }
    end
    if not reportId then
        return { success = false, message = 'Missing report ID' }
    end
    if getExistingSentencingAction(reportId, citizenId, 'jail') then
        return { success = false, message = 'This jail sentence has already been issued for this report' }
    end

    local targetPlayer = ps.getPlayerByIdentifier(citizenId)
    if not targetPlayer then
        return { success = false, message = 'Player must be online to send to jail' }
    end

    local targetSource = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSource then
        return { success = false, message = 'Could not resolve player source' }
    end

    local OtherPlayer = QBCore and QBCore.Functions.GetPlayer(targetSource)
    if not OtherPlayer then
        return { success = false, message = 'Could not find target player' }
    end

    local currentDate = os.date('*t')
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    OtherPlayer.Functions.SetMetaData('injail', sentence)
    OtherPlayer.Functions.SetMetaData('criminalrecord', {
        ['hasRecord'] = true,
        ['date'] = currentDate
    })
    TriggerClientEvent('police:client:SendToJail', targetSource, sentence)

    local integrationResult = SentencingIntegration and SentencingIntegration.SendToJail and SentencingIntegration.SendToJail(src, {
        citizenId = citizenId,
        sentence = sentence,
        reportId = reportId,
        targetSource = targetSource
    }) or { success = true }

    if not integrationResult.success then
        return { success = false, message = integrationResult.message or 'Jail integration failed' }
    end

    saveSentencingAction({
        reportId = reportId,
        citizenId = citizenId,
        action = 'jail',
        sentence = sentence,
        status = 'sent',
        createdBy = ps.getIdentifier(src),
        metadata = {
            targetSource = targetSource
        }
    })

    ps.notify(src, 'Sent to jail for ' .. sentence .. ' months', 'success')

    if ps.auditLog then
        ps.auditLog(src, 'sent_to_jail', 'citizen', citizenId, {
            sentence = sentence,
            reportId = reportId,
        })
    end

    return { success = true, message = 'Sent to jail for ' .. sentence .. ' months' }
end)

ps.registerCallback(resourceName .. ':server:giveCitation', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end

    payload = payload or {}
    local citizenId = payload.citizenId
    local fine = tonumber(payload.fine) or 0
    local reportId = normalizeReportId(payload.reportId)

    if not citizenId then
        return { success = false, message = 'Missing citizen ID' }
    end
    if fine <= 0 then
        return { success = false, message = 'Invalid fine amount' }
    end
    if not reportId then
        return { success = false, message = 'Missing report ID' }
    end
    if getExistingSentencingAction(reportId, citizenId, 'fine') then
        return { success = false, message = 'This fine has already been issued for this report' }
    end

    local invoice = SentencingIntegration and SentencingIntegration.IssueFine and SentencingIntegration.IssueFine(src, {
        citizenId = citizenId,
        fine = fine,
        reportId = reportId,
        charges = payload.charges,
        description = 'MDT Fine',
        reference = ('MDT-%s-%s'):format(reportId, citizenId),
        notes = ('MDT report #%s fine'):format(reportId)
    }) or { success = false, message = 'Fine integration is not available' }

    if not invoice.success then
        return { success = false, message = invoice.message or 'Could not create invoice' }
    end

    saveSentencingAction({
        reportId = reportId,
        citizenId = citizenId,
        action = 'fine',
        amount = invoice.amount or fine,
        status = invoice.status or 'pending',
        externalId = invoice.id and tostring(invoice.id) or nil,
        externalReference = invoice.invoiceNo,
        createdBy = ps.getIdentifier(src),
        metadata = {
            invoiceNo = invoice.invoiceNo,
            items = invoice.items
        }
    })

    ps.notify(src, '$' .. (invoice.amount or fine) .. ' fine invoice issued successfully', 'success')

    if ps.auditLog then
        local officerName = ps.getPlayerName(src) or 'Unknown Officer'
        ps.auditLog(src, 'fine_issued', 'citizen', citizenId, {
            fine = invoice.amount or fine,
            reportId = reportId,
            officerName = officerName,
            invoiceId = invoice.id,
            invoiceNo = invoice.invoiceNo,
            items = invoice.items,
        })
    end

    return { success = true, message = '$' .. (invoice.amount or fine) .. ' fine invoice issued' }
end)
