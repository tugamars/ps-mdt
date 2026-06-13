-- ============================================================
-- TABLE MAP  –  ps-mdt database schema mapping
-- ============================================================
-- Edit FRAMEWORK to match your server's active framework.
-- Supported values: 'ndcore' | 'qbcore' | 'qbx' | 'esx'
-- ============================================================

local FRAMEWORK = 'ndcore'

-- ----------------------------------------------------------------
-- SCHEMA DEFINITIONS
-- Each `fields` entry is a full SQL expression (with table alias).
-- It is used verbatim inside SELECT and WHERE clauses.
-- Each `rawFields` entry is just the bare column name (no alias),
-- used in UPDATE SET, INSERT, and un-aliased WHERE clauses.
-- ----------------------------------------------------------------

local schemas = {

    -- ── NDCore ──────────────────────────────────────────────────
    -- Table  : characters
    -- Columns: character_id, first_name, last_name, gender,
    --          dob, phone_number, job, data
    ndcore = {
        Players = {
            table   = 'characters',
            alias   = 'p',
            joinKey = 'character_id',   -- joined with mdt_profiles.citizenid
            fields  = {
                citizenid   = 'p.character_id',
                firstname   = 'p.first_name',
                lastname    = 'p.last_name',
                gender      = 'p.gender',
                dateofbirth = 'p.dob',
                phone       = 'p.phone_number',
                joblabel    = 'p.job',          -- plain string in NDCore
                jobname     = 'p.job',
                jobgrade    = 'NULL',
                jobtype     = 'NULL',
                metadata    = 'p.data',
                job_raw     = 'p.job',
                fingerprint = "JSON_UNQUOTE(JSON_EXTRACT(p.data, '$.fingerprint'))",
                charinfo    = 'NULL',
                profilePic = "JSON_UNQUOTE(JSON_EXTRACT(p.data, '$.picture'))",
            },
            rawFields = {
                citizenid = 'character_id',
                firstname = 'first_name',
                lastname  = 'last_name',
                metadata  = 'data',
                charinfo  = nil,
                job       = 'job',
            },
        },
    },

    -- ── QBCore / QBX ────────────────────────────────────────────
    -- Table  : players
    -- Columns: citizenid, charinfo (JSON), job (JSON), metadata (JSON)
    qbcore = {
        Players = {
            table   = 'players',
            alias   = 'p',
            joinKey = 'citizenid',
            fields  = {
                citizenid   = 'p.citizenid',
                firstname   = "JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname'))",
                lastname    = "JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))",
                gender      = "JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.gender'))",
                dateofbirth = "JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.birthdate'))",
                phone       = "JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.phone'))",
                joblabel    = "JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.label'))",
                jobname     = "JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.name'))",
                jobgrade    = "JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.grade.name'))",
                jobtype     = "JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.type'))",
                metadata    = 'p.metadata',
                job_raw     = 'p.job',
                fingerprint = "JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.fingerprint'))",
                charinfo    = 'p.charinfo',
            },
            rawFields = {
                citizenid = 'citizenid',
                firstname = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))",
                lastname  = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))",
                metadata  = 'metadata',
                charinfo  = 'charinfo',
                job       = 'job',
            },
        },
    },
}

-- QBX is identical to QBCore; ESX typically matches too
schemas.qbx = schemas.qbcore
schemas.esx = schemas.qbcore

-- ================================================================
-- ACTIVE MAPS  (read by all server/*.lua and server/backend/*.lua)
-- ================================================================

TableMap = {}

local _schema = schemas[FRAMEWORK] or schemas.qbcore

--- Players / Characters table map
TableMap.Players = _schema.Players

--- player_vehicles table map
TableMap.Vehicles = {
    table  = 'tgmsna_registered_vehicles',
    alias  = 'pv',
    fields = {
        id          = 'pv.id',
        citizenid   = 'pv.character_id',
        plate       = 'pv.plate',
        vehicle     = 'pv.vehicle',
        state       = 'pv.state',
        brand        = 'pv.brand',
        model      = 'pv.model',
        color       = 'pv.color',
        information = 'pv.mdt_vehicle_information',
        points      = 'pv.mdt_vehicle_points',
        status      = 'pv.mdt_vehicle_status',
        stolen      = 'pv.mdt_vehicle_stolen',
        boloactive  = 'pv.mdt_vehicle_boloactive',
        image       = 'pv.mdt_vehicle_image',
        stateRegistered = 'pv.state',
        vinNumber = 'pv.vin',
    },
    rawFields = {
        id          = 'id',
        citizenid   = 'character_id',
        plate       = 'plate',
        vehicle     = 'CONCAT(brand, " ", model)',
        state       = 'state',
        fuel        = '""',
        engine      = '""',
        body        = '""',
        information = 'mdt_vehicle_information',
        points      = 'mdt_vehicle_points',
        status      = 'mdt_vehicle_status',
        stolen      = 'mdt_vehicle_stolen',
        boloactive  = 'mdt_vehicle_boloactive',
        image       = 'mdt_vehicle_image',
        vinNumber = 'vin',
    },
}

--- properties table map
TableMap.Properties = {
    table  = 'properties',
    alias  = 'pr',
    fields = {
        owner       = 'CAST(pr.owner_citizenid as UNSIGNED)',
        apartment   = 'pr.apartment',
        street      = 'pr.street',
        property_id = 'pr.property_id',
        region = 'region',
        coords = 'door_data',
        keyholders = 'has_access'
    },
    rawFields = {
        owner       = 'CAST(owner_citizenid as UNSIGNED)',
        apartment   = 'apartment',
        street      = 'street',
        property_id = 'property_id',
        region = 'region',
        coords = 'door_data',
        keyholders = 'has_access'
    },
}

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

--- Build a "expr AS fieldKey" string for use in a SELECT list.
---@param tblMap table  e.g. TableMap.Players
---@param fieldKey string  logical field name (e.g. 'firstname')
---@return string
local function selExpr(tblMap, fieldKey)
    local expr = tblMap.fields[fieldKey]
    if not expr or expr == 'NULL' then
        return 'NULL AS ' .. fieldKey
    end
    return expr .. ' AS ' .. fieldKey
end

--- Build a comma-separated SELECT list.
---@param tblMap    table   e.g. TableMap.Players
---@param fieldKeys table   ordered list of logical field names
---@return string
function TableMap.buildSelect(tblMap, fieldKeys)
    local parts = {}
    for _, key in ipairs(fieldKeys) do
        parts[#parts + 1] = selExpr(tblMap, key)
    end
    return table.concat(parts, ',\n        ')
end

--- Return the raw SQL expression for a field (for WHERE / LOWER() / CONCAT()).
---@param tblMap  table
---@param fieldKey string
---@return string
function TableMap.field(tblMap, fieldKey)
    return tblMap.fields[fieldKey] or 'NULL'
end

--- Return the JOIN ON condition linking the players table to an mdt table.
--- e.g.  "p.character_id = mp.citizenid COLLATE utf8mb4_general_ci"
---@param mdtAlias string  alias used for the mdt table (default 'mp')
---@return string
function TableMap.joinCondition(mdtAlias)
    local P = TableMap.Players
    mdtAlias = mdtAlias or 'mp'
    return P.alias .. '.' .. P.joinKey
        .. ' = ' .. mdtAlias .. '.citizenid COLLATE utf8mb4_general_ci'
end

--- Return just the player-side join expression ("p.character_id" / "p.citizenid").
---@return string
function TableMap.playerJoinExpr()
    local P = TableMap.Players
    return P.alias .. '.' .. P.joinKey
end

--- Return a CONCAT(...) expression for building a full name from mapped fields.
---@return string  SQL CONCAT expression using mapped firstname/lastname fields
function TableMap.fullNameConcat()
    local P = TableMap.Players
    return "CONCAT(" .. P.fields.firstname .. ", ' ', " .. P.fields.lastname .. ")"
end

-- ================================================================
-- JOBS HELPER
-- ================================================================
