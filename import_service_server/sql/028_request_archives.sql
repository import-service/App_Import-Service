-- Архив заявок на физноситель: метаданные выгрузки + пометки на заявке.

ALTER TABLE customs_requests
  ADD COLUMN archived_at DATETIME(3) NULL DEFAULT NULL COMMENT 'Когда выгрузили ZIP на диск' AFTER deleted_at,
  ADD COLUMN archive_id BIGINT UNSIGNED NULL DEFAULT NULL COMMENT 'request_archives.id последней выгрузки' AFTER archived_at,
  ADD COLUMN archived_by_name VARCHAR(255) NULL DEFAULT NULL COMMENT 'ФИО кто архивировал' AFTER archive_id,
  ADD COLUMN archive_location VARCHAR(1000) NULL DEFAULT NULL COMMENT 'Место/путь физносителя' AFTER archived_by_name,
  ADD COLUMN archive_purged_at DATETIME(3) NULL DEFAULT NULL COMMENT 'Когда с сервера сняли файлы после архива' AFTER archive_location;

ALTER TABLE customs_requests
  ADD KEY idx_cr_archived_at (archived_at),
  ADD KEY idx_cr_archive_purged_at (archive_purged_at);

CREATE TABLE IF NOT EXISTS request_archives (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  period_from DATE NOT NULL,
  period_to DATE NOT NULL,
  archived_by_name VARCHAR(255) NOT NULL,
  archive_location VARCHAR(1000) NOT NULL,
  admin_user_id BIGINT UNSIGNED NULL DEFAULT NULL,
  admin_login VARCHAR(255) NULL DEFAULT NULL,
  request_ids_json JSON NOT NULL,
  request_count INT UNSIGNED NOT NULL DEFAULT 0,
  zip_file_name VARCHAR(255) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  KEY idx_ra_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
