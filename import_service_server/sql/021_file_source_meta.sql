-- Сырые метаданные файла с upload (1С / МП) до нормализации mime/имени

ALTER TABLE customs_request_files
  ADD COLUMN source_file_name VARCHAR(255) NULL DEFAULT NULL
    COMMENT 'Имя файла как пришло в upload (fileName / multipart)' AFTER original_name,
  ADD COLUMN source_mime_type VARCHAR(128) NULL DEFAULT NULL
    COMMENT 'mimeType как пришёл в upload (до детекта)' AFTER source_file_name,
  ADD COLUMN upload_source VARCHAR(32) NULL DEFAULT NULL
    COMMENT 'integration | user | demo' AFTER source_mime_type;
