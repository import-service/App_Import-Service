-- Отслеживание пачки upload (uploadIndex/uploadTotal) до sync MP↔1С.
CREATE TABLE IF NOT EXISTS customs_request_upload_batch (
  request_id BIGINT UNSIGNED NOT NULL,
  upload_total SMALLINT UNSIGNED NOT NULL,
  source VARCHAR(16) NOT NULL COMMENT 'integration | user',
  indices_json JSON NOT NULL COMMENT '{"1":"contract","2":"kuts"}',
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
