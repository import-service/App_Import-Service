UPDATE customs_requests
SET deleted_at = CURRENT_TIMESTAMP(3)
WHERE id = (
  SELECT id_to_delete FROM (
    SELECT id AS id_to_delete
    FROM customs_requests
    WHERE individual_full_name = 'Тестов Тест Тестович'
      AND deleted_at IS NULL
    ORDER BY id DESC
    LIMIT 1
  ) t
);
