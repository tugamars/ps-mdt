SET @officer_phone_exists = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'mdt_profiles' AND column_name = 'officer_phone');
SET @officer_phone_sql = IF(@officer_phone_exists = 0,
  'ALTER TABLE `mdt_profiles` ADD COLUMN `officer_phone` varchar(50) NULL AFTER `certifications`',
  'SELECT 1');
PREPARE officer_phone_migration FROM @officer_phone_sql;
EXECUTE officer_phone_migration;
DEALLOCATE PREPARE officer_phone_migration;

SET @officer_email_exists = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'mdt_profiles' AND column_name = 'officer_email');
SET @officer_email_sql = IF(@officer_email_exists = 0,
  'ALTER TABLE `mdt_profiles` ADD COLUMN `officer_email` varchar(120) NULL AFTER `officer_phone`',
  'SELECT 1');
PREPARE officer_email_migration FROM @officer_email_sql;
EXECUTE officer_email_migration;
DEALLOCATE PREPARE officer_email_migration;
