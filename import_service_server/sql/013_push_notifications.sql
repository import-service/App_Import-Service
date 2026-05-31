CREATE TABLE IF NOT EXISTS user_push_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  org_id BIGINT UNSIGNED NOT NULL,
  token VARCHAR(768) NOT NULL,
  platform ENUM('android', 'ios', 'web') NULL DEFAULT NULL,
  app_version VARCHAR(64) NULL DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  UNIQUE KEY uq_user_push_tokens_token (token),
  KEY idx_user_push_tokens_org (org_id),
  KEY idx_user_push_tokens_deleted (deleted_at),
  CONSTRAINT fk_user_push_tokens_org FOREIGN KEY (org_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
