-- Журнал попыток входа в МП (успех и провал), просмотр в админке «Входы».
-- Retention 30 дней — purge в backgroundJobs.
CREATE TABLE IF NOT EXISTS auth_attempts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  login VARCHAR(255) NOT NULL,
  organization_id BIGINT UNSIGNED NULL DEFAULT NULL,
  success TINYINT(1) NOT NULL DEFAULT 0,
  error_code VARCHAR(64) NULL DEFAULT NULL,
  ip VARCHAR(64) NULL DEFAULT NULL,
  user_agent VARCHAR(255) NULL DEFAULT NULL,
  INDEX idx_auth_attempts_created_at (created_at),
  INDEX idx_auth_attempts_login (login),
  INDEX idx_auth_attempts_org (organization_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
