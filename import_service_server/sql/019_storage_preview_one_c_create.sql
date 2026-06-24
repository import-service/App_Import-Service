-- Превью файлов, флаги create в 1С, хранение и алерты исходящей синхронизации

ALTER TABLE customs_request_files
  ADD COLUMN preview_stored_name VARCHAR(255) NULL DEFAULT NULL
    COMMENT 'Имя превью на диске (JPEG)' AFTER stored_name,
  ADD COLUMN preview_url VARCHAR(1024) NULL DEFAULT NULL
    COMMENT 'URL превью для списков/карточек МП' AFTER file_url;

ALTER TABLE customs_requests
  ADD COLUMN one_c_create_pending TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '1 = create в 1С не удался, нужен повтор' AFTER one_c_update_last_attempt_at,
  ADD COLUMN one_c_create_last_error_json JSON NULL DEFAULT NULL
    COMMENT 'Детали последней ошибки create в 1С' AFTER one_c_create_pending,
  ADD COLUMN one_c_create_last_attempt_at DATETIME(3) NULL DEFAULT NULL
    AFTER one_c_create_last_error_json,
  ADD COLUMN one_c_create_first_failed_at DATETIME(3) NULL DEFAULT NULL
    COMMENT 'Первая неудача create (для «часов в очереди»)' AFTER one_c_create_last_attempt_at,
  ADD COLUMN one_c_update_first_failed_at DATETIME(3) NULL DEFAULT NULL
    COMMENT 'Первая неудача update' AFTER one_c_create_first_failed_at;

ALTER TABLE app_settings
  ADD COLUMN retention_months TINYINT UNSIGNED NOT NULL DEFAULT 6
    COMMENT 'Автоудаление closed-заявок старше N месяцев' AFTER one_c_request_update_bearer_token,
  ADD COLUMN one_c_outbound_alert_last_at DATETIME(3) NULL DEFAULT NULL
    COMMENT 'Когда последний раз фиксировали суточный алерт исходящих' AFTER retention_months;

CREATE TABLE IF NOT EXISTS one_c_outbound_daily_alerts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  alert_date DATE NOT NULL,
  payload_json JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE KEY uq_one_c_outbound_daily_alerts_date (alert_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
