-- Миграция для таблиц заявок на таможенное оформление авто и файлов.

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
  car_make VARCHAR(255) NOT NULL COMMENT 'Марка автомобиля',
  car_model VARCHAR(255) NOT NULL COMMENT 'Модель автомобиля',
  vin VARCHAR(32) NOT NULL COMMENT 'VIN номер',
  has_sunroof TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие люка или панорамной крыши',
  has_all_wheel_drive TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие системы полного привода',
  imported_last_12_months TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Ввозили ли авто в Россию за последние 12 мес',
  owns_other_cars TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Наличие в собственности других авто',
  comment_text TEXT NULL DEFAULT NULL COMMENT 'Комментарий к заявке',
  status ENUM('new', 'in_progress', 'in_transit', 'delivered') NOT NULL DEFAULT 'new',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  UNIQUE KEY uq_customs_requests_external_1c_id (external_1c_id),
  KEY idx_customs_requests_status (status),
  KEY idx_customs_requests_manager_external_1c_id (manager_external_1c_id),
  KEY idx_customs_requests_deleted_at (deleted_at)
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
