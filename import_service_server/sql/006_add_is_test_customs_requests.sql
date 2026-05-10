-- Пометка тестовых заявок (с приложения); массовая очистка: POST /api/integration/customs-requests/purge-test

ALTER TABLE customs_requests
  ADD COLUMN is_test TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = тестовая заявка' AFTER comment_text,
  ADD KEY idx_customs_requests_is_test (is_test);
