-- Очередь исходящих update в 1С (повтор из админки).

ALTER TABLE customs_requests
  ADD COLUMN one_c_update_pending TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '1 = последний update в 1С не доставлен' AFTER deal_type,
  ADD COLUMN one_c_update_last_error_json JSON NULL DEFAULT NULL
    COMMENT 'Детали последней ошибки update в 1С' AFTER one_c_update_pending,
  ADD COLUMN one_c_update_last_attempt_at DATETIME(3) NULL DEFAULT NULL
    COMMENT 'Время последней попытки update в 1С' AFTER one_c_update_last_error_json;
