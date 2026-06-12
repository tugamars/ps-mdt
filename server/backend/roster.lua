
local function getRadioChannel(playerSource)
    if not playerSource then return 0 end
    local channel = 0
    pcall(function()
        channel = Player(playerSource).state.radioChannel or 0
    end)
    return tonumber(channel) or 0
end

local function getCertifications(citizenid)
    EnsureProfileExists(citizenid)

    local profile = MySQL.single.await('SELECT certifications FROM mdt_profiles WHERE citizenid = ?', { citizenid })
    if not profile then
        return {}
    end

    if profile.certifications and profile.certifications ~= '' then
        local ok, decoded = pcall(json.decode, profile.certifications)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end

    return {}
end

local function buildRosterFromQbx()
    local rosterList = {}
    local activeUnits = {}
    local members = {}
    local policeJobs = (Config and Config.PoliceJobs) or { 'police' }
    local qbx = exports['qbx_core']

    for _, jobName in ipairs(policeJobs) do
        local groupMembers = qbx:GetGroupMembers(jobName, 'job') or {}
        for _, member in ipairs(groupMembers) do
            if member.citizenid then
                members[member.citizenid] = true
            end
        end
    end

    for _, player in ipairs(qbx:GetQBPlayers() or {}) do
        local data = player.PlayerData or nil
        if data and data.job then
            local job = data.job
            if IsPoliceJob(job.name, job.type) then
                members[data.citizenid] = true
            end
        end
    end

    for _, row in ipairs(MySQL.query.await(
        ('SELECT %s AS citizenid, %s AS job_raw FROM %s'):format(
            TableMap.Players.rawFields.citizenid, TableMap.Players.rawFields.job,
            TableMap.Players.table
        ), {}) or {}) do
        local job = row.job_raw and json.decode(row.job_raw) or { name = row.job_raw }
        if IsPoliceJob(job.name, job.type) then
            members[row.citizenid] = true
        end
    end

    for citizenid, _ in pairs(members) do
        local onlinePlayer = qbx:GetPlayerByCitizenId(citizenid)
        local player = onlinePlayer or qbx:GetOfflinePlayer(citizenid)
        if player and player.PlayerData then
            local data = player.PlayerData
            local job = data.job or {}
            local callsign = data.metadata and data.metadata.callsign or 'N/A'
            local fullname = data.charinfo and (data.charinfo.firstname .. ' ' .. data.charinfo.lastname) or 'Unknown'
            local rank = job.grade and job.grade.name or 'Officer'
            local department = job.name or 'police'
            local certifications = getCertifications(citizenid)

            local onlineSrc = onlinePlayer and (onlinePlayer.PlayerData and onlinePlayer.PlayerData.source or onlinePlayer.source) or nil
            rosterList[#rosterList + 1] = {
                id = #rosterList + 1,
                citizenid = citizenid,
                callsign = callsign,
                firstName = data.charinfo and data.charinfo.firstname or 'N/A',
                lastName = data.charinfo and data.charinfo.lastname or 'N/A',
                rank = rank,
                department = department,
                status = (onlinePlayer and job.onduty) and 'On Duty' or 'Off Duty',
                certifications = certifications,
                badgeNumber = callsign,
                radioChannel = getRadioChannel(onlineSrc)
            }

            if rosterList[#rosterList].status == 'On Duty' then
                activeUnits[#activeUnits + 1] = {
                    id = rosterList[#rosterList].id,
                    badgeNumber = rosterList[#rosterList].badgeNumber,
                    callsign = rosterList[#rosterList].callsign,
                    firstName = rosterList[#rosterList].firstName,
                    lastName = rosterList[#rosterList].lastName,
                }
            end
        end
    end

    return {
        roster = rosterList,
        activeUnits = activeUnits
    }
end

local function checkDuty(citizenid)
    local player = ps.getPlayerByIdentifier(citizenid)

    if not player then return 'Off Duty' end

    local src = player.source or (player.PlayerData and player.PlayerData.source)
    if not src then return 'Off Duty' end

    if IsPoliceJob(ps.getJobName(src), ps.getJobType(src)) and ps.getJobDuty(src) then
        return 'On Duty'
    end
    return 'Off Duty'
end

ps.registerCallback('ps-mdt:server:getRosterList', function(source)
    --[[
    if GetResourceState('qbx_core') == 'started' and exports['qbx_core'] then
        return buildRosterFromQbx()
    end

    local rosterList = {}
    local activeUnits = {}
    local policeJobs = (Config and Config.PoliceJobs) or { 'police' }
    local jobLookup = {}
    for _, jobName in ipairs(policeJobs) do
        jobLookup[tostring(jobName)] = true
    end
    local jobType = Config and Config.PoliceJobType and tostring(Config.PoliceJobType) or nil

    local employees = {}
    if GetResourceState('ps-multijob') == 'started' and exports['ps-multijob'] then
        for _, jobName in ipairs(policeJobs) do
            local list = exports['ps-multijob']:getEmployees(jobName) or {}
            for _, employee in pairs(list) do
                if employee and employee.citizenid then
                    employees[employee.citizenid] = employee
                end
            end
        end
    end
    --]]

    local jobType = ps.getJobData(source, "type") or "other";

    local jobsTable = ps.getJobTable();

    local rosterPrelim={};

    for k,v in pairs(jobsTable) do
        if(v.type == jobType) then
            local employees = ps.getJobEmployees(k);

            for j, l in ipairs(employees) do
                rosterPrelim[#rosterPrelim+1] = l;
            end
        end
    end

    local rosterList = {};
    local activeUnits = {};

    for k,v in ipairs(rosterPrelim) do
        local citizenid = v.citizenid;
        local callsign = v.callsign or 'N/A';
        local firstName = v.firstName or 'N/A';
        local lastName = v.lastName or 'N/A';
        local rank = v.rank or 'Officer';
        local department = v.department or 'police';
        local status = checkDuty(citizenid);
        local onlinePlayer = ps.getPlayerByIdentifier(citizenid);
        local onlineSrc = onlinePlayer and (onlinePlayer.source or (onlinePlayer.PlayerData and onlinePlayer.PlayerData.source)) or nil;

        rosterList[#rosterList + 1] = {
            id = #rosterList + 1,
            citizenid = citizenid,
            callsign = callsign,
            firstName = firstName,
            lastName = lastName,
            rank = rank,
            department = department,
            status = status,
            certifications = getCertifications(citizenid),
            badgeNumber = callsign,
            radioChannel = getRadioChannel(onlineSrc)
        }

        if status == 'On Duty' then
            activeUnits[#activeUnits + 1] = {
                id = rosterList[#rosterList].id,
                badgeNumber = rosterList[#rosterList].badgeNumber,
                callsign = rosterList[#rosterList].callsign,
                firstName = rosterList[#rosterList].firstName,
                lastName = rosterList[#rosterList].lastName,
            }
        end
    end

    --[[
    local _P = TableMap.Players
    for _, citizen in pairs(MySQL.query.await(
        ('SELECT %s AS citizenid, %s AS firstname, %s AS lastname, %s AS jobname, %s AS jobtype, %s AS job_raw, %s AS metadata FROM %s'):format(
            _P.rawFields.citizenid,
            _P.rawFields.firstname, _P.rawFields.lastname,
            _P.rawFields.job,   -- jobname (plain string for NDCore, or JSON col for QBCore)
            _P.rawFields.job,   -- jobtype (same source; decoded below)
            _P.rawFields.job,   -- job_raw for full JSON decode on QBCore
            _P.rawFields.metadata,
            _P.table
        ), {}) or {}) do
        local citizenid = citizen.citizenid
        -- For QBCore the job_raw column is JSON; for NDCore it's a plain string job name
        local job = {}
        if citizen.job_raw then
            local ok, decoded = pcall(json.decode, citizen.job_raw)
            if ok and type(decoded) == 'table' then
                job = decoded
            else
                -- NDCore: job_raw is a plain string (job name)
                job = { name = citizen.job_raw, type = nil }
            end
        end
        local metadata = citizen.metadata and json.decode(citizen.metadata) or {}
        local jobName = job.name or citizen.jobname or nil
        if type(jobName) == 'string' then jobName = tostring(jobName) end
        local jobType = job.type or nil
        local isPolice = (jobName and jobLookup[jobName]) or (jobType and jobType and tostring(jobType) == jobType)
        if isPolice then
            local employee = employees[citizenid] or {}
            local callsign = metadata.callsign or 'N/A'
            -- firstname/lastname resolved directly from mapping (no charinfo decode needed)
            local firstName = citizen.firstname or 'N/A'
            local lastName = citizen.lastname or 'N/A'
            local rank = job.grade and job.grade.name or employee.grade and ps.getSharedJobGradeData(jobName or 'police', employee.grade, 'name') or 'Officer'
            local status = checkDuty(citizenid)
            local onlinePlayer = ps.getPlayerByIdentifier(citizenid)
            local onlineSrc = onlinePlayer and (onlinePlayer.source or (onlinePlayer.PlayerData and onlinePlayer.PlayerData.source)) or nil
            rosterList[#rosterList + 1] = {
                id = #rosterList + 1,
                citizenid = citizenid,
                callsign = callsign,
                firstName = firstName,
                lastName = lastName,
                rank = rank,
                department = jobName or employee.job or 'police',
                status = status,
                certifications = getCertifications(citizenid),
                badgeNumber = callsign,
                radioChannel = getRadioChannel(onlineSrc)
            }
            if status == 'On Duty' then
                activeUnits[#activeUnits + 1] = {
                    id = rosterList[#rosterList].id,
                    badgeNumber = rosterList[#rosterList].badgeNumber,
                    callsign = rosterList[#rosterList].callsign,
                    firstName = rosterList[#rosterList].firstName,
                    lastName = rosterList[#rosterList].lastName,
                }
            end
        end
    end
    --]]
    return {
        roster = rosterList,
        activeUnits = activeUnits
    }
end)

-- Get available officer tags/certifications (filtered by job type)
ps.registerCallback('ps-mdt:server:getOfficerTags', function(source)
    local src = source
    if not CheckAuth(src) then return {} end

    local jobType = ps.getJobType(src)
    local rows
    if jobType and (jobType == 'leo' or jobType == 'ems') then
        rows = MySQL.query.await([[
            SELECT id, name, color FROM mdt_tags
            WHERE type IN ('officer', 'both')
              AND (job_type = ? OR job_type = 'all' OR job_type IS NULL)
            ORDER BY name ASC
        ]], { jobType })
    else
        rows = MySQL.query.await([[
            SELECT id, name, color FROM mdt_tags
            WHERE type IN ('officer', 'both')
            ORDER BY name ASC
        ]])
    end
    return rows or {}
end)

-- Update officer certifications
ps.registerCallback('ps-mdt:server:updateOfficerCertifications', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'roster_manage_certifications') then
        return { success = false, message = 'No permission to manage certifications' }
    end

    payload = payload or {}
    local citizenid = payload.citizenid
    local certifications = payload.certifications

    if not citizenid or type(certifications) ~= 'table' then
        return { success = false, message = 'Invalid payload' }
    end

    EnsureProfileExists(citizenid)

    local encoded = json.encode(certifications)
    MySQL.update.await('UPDATE mdt_profiles SET certifications = ? WHERE citizenid = ?', { encoded, citizenid })

    return { success = true }
end)

-- Get job grades for a specific department
ps.registerCallback('ps-mdt:server:getJobGrades', function(source, payload)
    local src = source
    if not CheckAuth(src) then return {} end
    if not CheckPermission(src, 'roster_manage_officers') then return {} end

    payload = payload or {}
    local jobName = payload.job or 'police'

    local jobData = ps.getSharedJob(jobName)
    if not jobData or not jobData.grades then return {} end

    local grades = {}
    for gradeKey, gradeValue in pairs(jobData.grades) do
        grades[#grades + 1] = {
            grade = tonumber(gradeKey) or 0,
            name = gradeValue.name or ('Grade ' .. gradeKey),
            isBoss = gradeValue.isboss == true or gradeValue.isBoss == true or gradeValue.boss == true,
        }
    end

    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return grades
end)

-- Promote/demote an officer (change their job grade)
ps.registerCallback('ps-mdt:server:promoteOfficer', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'roster_manage_officers') then
        return { success = false, message = 'No permission to manage officers' }
    end

    payload = payload or {}
    local citizenid = payload.citizenid
    local jobName = payload.job
    local newGrade = tonumber(payload.grade)

    if not citizenid or not jobName or not newGrade then
        return { success = false, message = 'Missing required fields' }
    end

    -- Validate the grade exists
    local gradeData = ps.getSharedJobGrade(jobName, newGrade)
    if not gradeData then
        return { success = false, message = 'Invalid grade for this job' }
    end

    -- Find the target player (must be online for QBCore SetJob)
    local targetPlayer = ps.getPlayerByIdentifier(citizenid)
    if not targetPlayer then
        return { success = false, message = 'Officer must be online to change rank' }
    end

    local targetSrc = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSrc then
        return { success = false, message = 'Could not resolve officer source' }
    end

    -- Don't allow changing your own rank
    if targetSrc == src then
        return { success = false, message = 'You cannot change your own rank' }
    end

    ps.setJob(targetSrc, jobName, newGrade)

    local gradeName = gradeData.name or ('Grade ' .. newGrade)

    if ps.auditLog then
        ps.auditLog(src, 'officer_promoted', 'officers', citizenid, {
            job = jobName,
            grade = newGrade,
            gradeName = gradeName,
        })
    end

    return { success = true, message = 'Officer rank updated to ' .. gradeName }
end)

-- Fire an officer (set their job to unemployed)
ps.registerCallback('ps-mdt:server:fireOfficer', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'roster_manage_officers') then
        return { success = false, message = 'No permission to manage officers' }
    end

    payload = payload or {}
    local citizenid = payload.citizenid

    if not citizenid then
        return { success = false, message = 'Missing citizen ID' }
    end

    local targetPlayer = ps.getPlayerByIdentifier(citizenid)
    if not targetPlayer then
        return { success = false, message = 'Officer must be online to be terminated' }
    end

    local targetSrc = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
    if not targetSrc then
        return { success = false, message = 'Could not resolve officer source' }
    end

    -- Don't allow firing yourself
    if targetSrc == src then
        return { success = false, message = 'You cannot fire yourself' }
    end

    ps.setJob(targetSrc, 'unemployed', 0)

    if ps.auditLog then
        ps.auditLog(src, 'officer_fired', 'officers', citizenid, {})
    end

    return { success = true, message = 'Officer has been terminated' }
end)

-- Update officer callsign (wrapper around existing setCallsign for NUI)
ps.registerCallback('ps-mdt:server:updateOfficerCallsign', function(source, payload)
    local src = source
    if not CheckAuth(src) then return { success = false, message = 'Unauthorized' } end
    if not CheckPermission(src, 'roster_manage_officers') then
        return { success = false, message = 'No permission to manage officers' }
    end

    payload = payload or {}
    local citizenid = payload.citizenid
    local newCallsign = payload.callsign

    if not citizenid or not newCallsign or newCallsign == '' then
        return { success = false, message = 'Missing citizen ID or callsign' }
    end

    -- Use the existing setCallsign callback logic
    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if not ok or not QBCore then
        return { success = false, message = 'Core framework not available' }
    end

    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not Player then
        return { success = false, message = 'Officer must be online to update callsign' }
    end

    Player.Functions.SetMetaData('callsign', newCallsign)

    local resourceName = GetCurrentResourceName()
    TriggerClientEvent(resourceName .. ':client:updateCallsign', Player.PlayerData.source, newCallsign)

    MySQL.update.await('UPDATE mdt_profiles SET callsign = ? WHERE citizenid = ?', { newCallsign, citizenid })

    if ps.auditLog then
        ps.auditLog(src, 'callsign_changed', 'officers', citizenid, { callsign = newCallsign })
    end

    return { success = true, message = 'Callsign updated to ' .. newCallsign }
end)
