-- Оценка клиента по заявке (1–5) + опциональный комментарий.
ALTER TABLE customs_requests
  ADD COLUMN client_rating TINYINT UNSIGNED NULL DEFAULT NULL
    COMMENT 'Оценка клиента 1..5, один раз' AFTER comment_text,
  ADD COLUMN client_rating_comment VARCHAR(500) NULL DEFAULT NULL
    COMMENT 'Пожелания при оценке <=3' AFTER client_rating,
  ADD COLUMN client_rated_at DATETIME(3) NULL DEFAULT NULL
    COMMENT 'Когда поставлена оценка' AFTER client_rating_comment;

ALTER TABLE customs_requests
  ADD KEY idx_customs_requests_client_rating (client_rating),
  ADD KEY idx_customs_requests_client_rated_at (client_rated_at);
