-- Клиентские ошибки МП (мини-Sentry): хранение ~14 дней, purge в backgroundJobs.
CREATE TABLE IF NOT EXISTS client_errors (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  organization_id INT UNSIGNED NULL DEFAULT NULL,
  login VARCHAR(128) NULL DEFAULT NULL,
  role VARCHAR(32) NULL DEFAULT NULL,
  platform VARCHAR(32) NULL DEFAULT NULL,
  app_version VARCHAR(64) NULL DEFAULT NULL,
  build_number VARCHAR(32) NULL DEFAULT NULL,
  tag VARCHAR(64) NULL DEFAULT NULL,
  message VARCHAR(1024) NOT NULL,
  stack_text MEDIUMTEXT NULL,
  fatal TINYINT(1) NOT NULL DEFAULT 0,
  device_info VARCHAR(256) NULL DEFAULT NULL,
  fingerprint CHAR(40) NULL DEFAULT NULL,
  KEY idx_client_errors_created (created_at),
  KEY idx_client_errors_org_created (organization_id, created_at),
  KEY idx_client_errors_fingerprint_created (fingerprint, created_at)
);
