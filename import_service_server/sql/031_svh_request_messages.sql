-- Чат СВХ-менеджер ↔ клиент по заявке (отдельно от чата 1С).

CREATE TABLE IF NOT EXISTS svh_request_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  svh_manager_id BIGINT UNSIGNED NOT NULL COMMENT 'organizations.id с role=svh_manager',
  author_type ENUM('svh_manager', 'app_user') NOT NULL,
  author_org_id BIGINT UNSIGNED NULL DEFAULT NULL COMMENT 'organizations.id автора',
  client_message_id CHAR(36) NULL DEFAULT NULL COMMENT 'UUID исходящего (идемпотентность)',
  text_content VARCHAR(2000) NOT NULL,
  attachments_json JSON NULL DEFAULT NULL COMMENT 'массив { fileUrl, mimeType, fileName }',
  read_by_client_at DATETIME(3) NULL DEFAULT NULL,
  read_by_svh_at DATETIME(3) NULL DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  KEY idx_svh_msg_request (request_id),
  KEY idx_svh_msg_manager (svh_manager_id),
  KEY idx_svh_msg_request_manager (request_id, svh_manager_id),
  KEY idx_svh_msg_created (created_at),
  KEY idx_svh_msg_deleted (deleted_at),
  UNIQUE KEY uq_svh_client_message (client_message_id),
  CONSTRAINT fk_svh_msg_request FOREIGN KEY (request_id) REFERENCES customs_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_svh_msg_manager FOREIGN KEY (svh_manager_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_svh_msg_author FOREIGN KEY (author_org_id) REFERENCES organizations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
