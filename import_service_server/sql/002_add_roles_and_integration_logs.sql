-- Миграция для уже развёрнутой БД:
-- 1) Добавляет роль пользователю (admin/user), по умолчанию user.
-- 2) Создаёт таблицу журнала интеграций с 1С.

ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS role ENUM('admin', 'user') NOT NULL DEFAULT 'user' AFTER login;

CREATE TABLE IF NOT EXISTS integration_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  request_id CHAR(36) NOT NULL,
  source VARCHAR(64) NOT NULL DEFAULT '1c',
  endpoint VARCHAR(255) NOT NULL,
  status ENUM('success', 'error') NOT NULL,
  http_code SMALLINT UNSIGNED NOT NULL,
  rows_received INT UNSIGNED NOT NULL DEFAULT 0,
  rows_unique INT UNSIGNED NOT NULL DEFAULT 0,
  rows_upserted INT UNSIGNED NOT NULL DEFAULT 0,
  rows_soft_deleted INT UNSIGNED NOT NULL DEFAULT 0,
  error_message VARCHAR(500) NULL DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_integration_logs_request_id (request_id),
  KEY idx_integration_logs_created_at (created_at),
  KEY idx_integration_logs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
