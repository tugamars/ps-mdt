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
end)
