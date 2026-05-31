-- Создайте базу и пользователя в панели ISPmanager, затем выполните этот скрипт
-- в выбранной БД (выберите схему в phpMyAdmin / mysql CLI).

CREATE TABLE IF NOT EXISTS organizations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_1c VARCHAR(255) NOT NULL COMMENT 'Идентификатор организации в 1С',
  login VARCHAR(255) NOT NULL COMMENT 'Логин (email) для входа',
  role ENUM('admin', 'user') NOT NULL DEFAULT 'user' COMMENT 'Роль пользователя',
  password_hash VARCHAR(255) NOT NULL,
  org_type ENUM('ИП', 'ООО') NOT NULL DEFAULT 'ООО' COMMENT 'Тип организации',
  company_name VARCHAR(255) NOT NULL COMMENT 'ФИО для ИП или название для ООО',
  inn VARCHAR(32) NOT NULL COMMENT 'ИНН',
  phone VARCHAR(30) NOT NULL COMMENT 'Телефон',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  UNIQUE KEY uq_organizations_id_1c (id_1c),
  KEY idx_organizations_login_active (login),
  KEY idx_organizations_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS user_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  jti CHAR(36) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  revoked_at DATETIME(3) NULL DEFAULT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_user_sessions_jti (jti),
  KEY idx_user_sessions_user (user_id),
  CONSTRAINT fk_user_sessions_org
    FOREIGN KEY (user_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customs_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  external_1c_id VARCHAR(255) NULL DEFAULT NULL COMMENT 'Идентификатор заявки в 1С (GUID)',
  manager_external_1c_id VARCHAR(255) NULL DEFAULT NULL COMMENT 'Идентификатор менеджера в 1С (GUID)',
  legal_entity_name VARCHAR(255) NOT NULL COMMENT 'Наименование юр. лица / ИП',
  legal_email VARCHAR(255) NOT NULL COMMENT 'Email юр. лица / ИП',
  legal_phone VARCHAR(30) NOT NULL COMMENT 'Телефон юр. лица / ИП',
  individual_full_name VARCHAR(255) NOT NULL COMMENT 'ФИО физ. лица',
  individual_phone VARCHAR(30) NOT NULL COMMENT 'Телефон физ. лица',
  individual_snils VARCHAR(32) NOT NULL COMMENT 'СНИЛС физ. лица',
  owner_full_name VARCHAR(255) NULL DEFAULT NULL COMMENT 'С 1С: владелец/отображаемое ФИО',
  car_make VARCHAR(255) NOT NULL COMMENT 'Марка автомобиля',
  car_model VARCHAR(255) NOT NULL COMMENT 'Модель автомобиля',
  vin VARCHAR(32) NOT NULL COMMENT 'VIN номер',
  has_sunroof TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие люка или панорамной крыши',
  has_all_wheel_drive TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие системы полного привода',
  imported_last_12_months TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Ввозили ли авто в Россию за последние 12 мес',
  owns_other_cars TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие в собственности других авто',
  comment_text TEXT NULL DEFAULT NULL COMMENT 'Комментарий к заявке',
  is_test TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = тестовая заявка (с приложения, для сноса)',
  status ENUM('new', 'in_progress', 'in_transit', 'delivered') NOT NULL DEFAULT 'new',
  engine_spec VARCHAR(255) NULL DEFAULT NULL COMMENT 'Про двигатель (строка с 1С)',
  engine_volume VARCHAR(128) NULL DEFAULT NULL COMMENT 'Объём/ряд (строка с 1С)',
  status_since_date_label VARCHAR(255) NULL DEFAULT NULL COMMENT 'Подпись даты у статуса (строка для UI)',
  status_sub_type VARCHAR(128) NULL DEFAULT NULL COMMENT 'Код подстатуса (чип)',
  finance_items_json JSON NULL DEFAULT NULL COMMENT 'Пошлина, утиль (JSON)',
  vehicle_photo_urls_json JSON NULL DEFAULT NULL COMMENT 'URL фото авто (JSON массив строк)',
  delivered_documents_json JSON NULL DEFAULT NULL COMMENT 'Документы при доставлено (JSON)',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  UNIQUE KEY uq_customs_requests_external_1c_id (external_1c_id),
  KEY idx_customs_requests_status (status),
  KEY idx_customs_requests_is_test (is_test),
  KEY idx_customs_requests_manager_external_1c_id (manager_external_1c_id),
  KEY idx_customs_requests_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS customs_request_files (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  doc_type VARCHAR(64) NOT NULL COMMENT 'Тип документа',
  original_name VARCHAR(255) NOT NULL COMMENT 'Имя файла с клиента',
  stored_name VARCHAR(255) NOT NULL COMMENT 'Имя файла на сервере',
  mime_type VARCHAR(128) NOT NULL,
  file_size_bytes INT UNSIGNED NOT NULL,
  file_url VARCHAR(1024) NOT NULL COMMENT 'Ссылка на файл, которая хранится в БД',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  KEY idx_customs_request_files_request_id (request_id),
  KEY idx_customs_request_files_doc_type (doc_type),
  KEY idx_customs_request_files_deleted_at (deleted_at),
  CONSTRAINT fk_customs_request_files_request
    FOREIGN KEY (request_id) REFERENCES customs_requests (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customs_request_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  author_type ENUM('app_user', 'manager_1c') NOT NULL,
  user_id BIGINT UNSIGNED NULL DEFAULT NULL COMMENT 'organizations.id для сообщений от приложения',
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
  CONSTRAINT fk_crm_org FOREIGN KEY (user_id) REFERENCES organizations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
