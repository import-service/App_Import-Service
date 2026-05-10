-- Сообщения чата по заявке (таможенное оформление).

CREATE TABLE IF NOT EXISTS customs_request_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  author_type ENUM('app_user', 'manager_1c') NOT NULL,
  user_id BIGINT UNSIGNED NULL DEFAULT NULL COMMENT 'users.id для сообщений от приложения',
  direction ENUM('to_1c', 'from_1c') NOT NULL,
  client_message_id CHAR(36) NULL DEFAULT NULL COMMENT 'UUID исходящего сообщения (идемпотентность)',
  message_1c_id VARCHAR(255) NULL DEFAULT NULL COMMENT 'Уникальный id сообщения в 1С (для входящих)',
  text_content VARCHAR(2000) NOT NULL,
  attachments_json JSON NULL DEFAULT NULL COMMENT 'массив { fileUrl, mimeType, fileName }',
  delivery_status ENUM('pending', 'delivered', 'failed') NULL DEFAULT NULL COMMENT 'только для to_1c',
  delivered_to_1c_at DATETIME(3) NULL DEFAULT NULL,
  last_1c_error VARCHAR(1000) NULL DEFAULT NULL,
  read_by_user_at DATETIME(3) NULL DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  KEY idx_crm_request_id (request_id),
  KEY idx_crm_user_id (user_id),
  KEY idx_crm_direction (direction),
  KEY idx_crm_created (created_at),
  KEY idx_crm_deleted (deleted_at),
  UNIQUE KEY uq_crm_client_message (client_message_id),
  UNIQUE KEY uq_crm_message_1c (message_1c_id),
  CONSTRAINT fk_crm_request FOREIGN KEY (request_id) REFERENCES customs_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
