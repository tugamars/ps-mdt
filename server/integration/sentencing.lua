local function getOfficerJobName(source)
    local job = ps.getJob(source)
    local jobName = job and job.name or nil

    if not jobName and job and job.id then
        jobName = job.id
    end

    jobName = tostring(jobName or 'police')
    return jobName:gsub('^business_', '')
end

local function getDueAt(days)
    return os.date('!%Y-%m-%d %H:%M:%S', os.time() + ((days or 7) * 86400))
end

local function buildFineInvoiceItems(reportId, citizenId, payloadCharges, fallbackFine)
    local chargeLines = {}
    local total = 0

    local function addChargeLine(description, quantity, unitPrice)
        quantity = math.max(1, tonumber(quantity) or 1)
        unitPrice = math.max(0, tonumber(unitPrice) or 0)
        if unitPrice <= 0 then return end

        chargeLines[#chargeLines + 1] = {
            description = tostring(description or 'MDT Fine'),
            quantity = quantity,
            unitPrice = unitPrice,
            total = quantity * unitPrice
        }
        total = total + (quantity * unitPrice)
    end

    if type(payloadCharges) == 'table' then
        for _, charge in ipairs(payloadCharges) do
            if charge and (not charge.citizenid or charge.citizenid == citizenId) then
                addChargeLine(charge.charge, charge.count, charge.fine)
            end
        end
    end

    if #chargeLines == 0 and reportId then
        local rows = MySQL.query.await([[
            SELECT charge, count, fine
            FROM mdt_reports_charges
            WHERE reportid = ? AND citizenid = ?
        ]], { reportId, citizenId })

        for _, charge in ipairs(rows or {}) do
            addChargeLine(charge.charge, charge.count, charge.fine)
        end
    end

    if #chargeLines == 0 then
        addChargeLine('MDT Fine', 1, fallbackFine)
    end

    local targetTotal = math.max(0, tonumber(fallbackFine) or total)
    if targetTotal > 0 and total > 0 and targetTotal ~= total then
        local scaledItems = {}
        local assignedTotal = 0

        for i, line in ipairs(chargeLines) do
            local lineTotal
            if i == #chargeLines then
                lineTotal = math.max(0, targetTotal - assignedTotal)
            else
                lineTotal = math.floor((line.total / total) * targetTotal + 0.5)
                assignedTotal = assignedTotal + lineTotal
            end

            local description = line.description
            if line.quantity > 1 then
                description = ('%s x%s'):format(description, line.quantity)
            end

            scaledItems[#scaledItems + 1] = {
                description = description,
                quantity = 1,
                unit_price = lineTotal
            }
        end

        return scaledItems, targetTotal
    end

    local items = {}
    for _, line in ipairs(chargeLines) do
        items[#items + 1] = {
            description = line.description,
            quantity = line.quantity,
            unit_price = line.unitPrice
        }
    end

    return items, total
end

SentencingIntegration = SentencingIntegration or {}

function SentencingIntegration.IssueFine(source, payload)
    payload = payload or {}
    local items, total = buildFineInvoiceItems(payload.reportId, payload.citizenId, payload.charges, payload.fine)

    if total <= 0 then
        return {
            success = false,
            message = 'No charge fines found for this invoice'
        }
    end

    local result = exports.bs_core:CreateInvoice(source, {
        fromType = 'business',
        fromId = getOfficerJobName(source),
        toType = 'personal',
        toId = payload.citizenId,
        items = items,
        notes = payload.notes,
        reference = payload.reference,
        dueAt = getDueAt(7)
    })

    if result and result.ok then
        return {
            success = true,
            id = result.id,
            invoiceNo = result.invoice_no,
            status = result.status or 'pending',
            amount = total,
            items = items
        }
    end

    return {
        success = false,
        message = result and result.reason or 'Invoice failed'
    }
end

function SentencingIntegration.SendToJail(source, payload)
    return {
        success = true
    }
end

RegisterNetEvent('bs_core:updateInvoiceStatus', function(id, status, paidAt)
    if not id then return end

    MySQL.update.await([[
        UPDATE mdt_sentencing_actions
        SET status = ?, paid_at = ?
        WHERE action = 'fine' AND external_id = ?
    ]], {
        tostring(status or 'unknown'),
        paidAt,
        tostring(id)
    })
end)
