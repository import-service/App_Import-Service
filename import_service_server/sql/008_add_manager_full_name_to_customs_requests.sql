-- ФИО менеджера из 1С для отображения клиенту в приложении.
-- Идемпотентно: повторный запуск не падает, если колонка уже есть.

SET @exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'customs_requests'
    AND COLUMN_NAME = 'manager_full_name'
);
SET @sql := IF(
  @exists = 0,
  'ALTER TABLE customs_requests ADD COLUMN manager_full_name VARCHAR(255) NULL DEFAULT NULL AFTER manager_external_1c_id',
  'SELECT 1'
);
PREPARE stmt_mgr_full_name FROM @sql;
EXECUTE stmt_mgr_full_name;
DEALLOCATE PREPARE stmt_mgr_full_name;
