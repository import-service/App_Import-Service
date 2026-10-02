-- Серверная копия ZIP архива (24 ч на скачивание) + детали для истории.

ALTER TABLE request_archives
  ADD COLUMN zip_server_path VARCHAR(1000) NULL DEFAULT NULL COMMENT 'Относительный путь от ARCHIVE_ZIP_ROOT' AFTER zip_file_name,
  ADD COLUMN zip_sha256 CHAR(64) NULL DEFAULT NULL AFTER zip_server_path,
  ADD COLUMN zip_size_bytes BIGINT UNSIGNED NULL DEFAULT NULL AFTER zip_sha256,
  ADD COLUMN zip_expires_at DATETIME(3) NULL DEFAULT NULL AFTER zip_size_bytes,
  ADD COLUMN zip_deleted_at DATETIME(3) NULL DEFAULT NULL AFTER zip_expires_at,
  ADD COLUMN manifest_detail_json JSON NULL DEFAULT NULL COMMENT 'organizations/requests для UI истории' AFTER zip_deleted_at;

ALTER TABLE request_archives
  ADD KEY idx_ra_zip_expires (zip_expires_at);
