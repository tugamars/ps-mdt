-- Lightweight schema upgrades for existing ps-mdt installations.
-- Older MariaDB versions do not support ADD COLUMN IF NOT EXISTS.
local function columnExists(tableName, columnName)
    return (MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?]],
        { tableName, columnName }) or 0) > 0
end

CreateThread(function()
    if not columnExists('mdt_profiles', 'officer_phone') then
        MySQL.query.await('ALTER TABLE `mdt_profiles` ADD COLUMN `officer_phone` varchar(50) NULL AFTER `certifications`')
    end
    if not columnExists('mdt_profiles', 'officer_email') then
        MySQL.query.await('ALTER TABLE `mdt_profiles` ADD COLUMN `officer_email` varchar(120) NULL AFTER `officer_phone`')
    end

    -- Warrant requests were originally report/citizen-only. Keep existing MDT
    -- databases compatible with the standalone warrant workflow.
    if not columnExists('mdt_warrant_requests', 'warrant_type') then
        MySQL.query.await("ALTER TABLE `mdt_warrant_requests` ADD COLUMN `warrant_type` enum('arrest','search','bench') NOT NULL DEFAULT 'arrest' AFTER `id`")
    end
    if not columnExists('mdt_warrant_requests', 'target_text') then
        MySQL.query.await("ALTER TABLE `mdt_warrant_requests` ADD COLUMN `target_text` varchar(255) NOT NULL DEFAULT '' AFTER `citizen_name`")
    end
    if not columnExists('mdt_warrant_requests', 'executed_by') then
        MySQL.query.await('ALTER TABLE `mdt_warrant_requests` ADD COLUMN `executed_by` varchar(50) DEFAULT NULL AFTER `reviewed_at`')
    end
    if not columnExists('mdt_warrant_requests', 'executed_by_name') then
        MySQL.query.await('ALTER TABLE `mdt_warrant_requests` ADD COLUMN `executed_by_name` varchar(100) DEFAULT NULL AFTER `executed_by`')
    end
    if not columnExists('mdt_warrant_requests', 'executed_at') then
        MySQL.query.await('ALTER TABLE `mdt_warrant_requests` ADD COLUMN `executed_at` timestamp NULL DEFAULT NULL AFTER `executed_by_name`')
    end
    MySQL.query.await("ALTER TABLE `mdt_warrant_requests` MODIFY COLUMN `status` enum('pending','approved','executed','denied') NOT NULL DEFAULT 'pending'")
end)
