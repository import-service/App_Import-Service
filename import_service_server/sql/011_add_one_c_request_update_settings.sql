-- Совместимо со старыми MySQL: без ADD COLUMN IF NOT EXISTS.
SET @db := DATABASE();

SET @has_url := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'app_settings' AND COLUMN_NAME = 'one_c_request_update_url'
);
SET @has_token := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'app_settings' AND COLUMN_NAME = 'one_c_request_update_bearer_token'
);

SET @sql1 := IF(@has_url = 0,
  'ALTER TABLE app_settings ADD COLUMN one_c_request_update_url VARCHAR(2048) NULL DEFAULT NULL COMMENT ''POST обновления заявки в 1С''',
  'SELECT 1'
);
PREPARE stmt1 FROM @sql1;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

SET @sql2 := IF(@has_token = 0,
  'ALTER TABLE app_settings ADD COLUMN one_c_request_update_bearer_token VARCHAR(512) NULL DEFAULT NULL COMMENT ''Bearer к URL обновления заявки''',
  'SELECT 1'
);
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

