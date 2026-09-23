-- Несколько интерфейсных ролей у одной organization (клиент / СВХ / декларант).
-- primary `role` остаётся для JWT и старых клиентов; `roles` JSON — полный набор.
ALTER TABLE organizations
  MODIFY COLUMN role ENUM('admin', 'user', 'svh_manager', 'declarant_manager')
    NOT NULL DEFAULT 'user';

ALTER TABLE organizations
  ADD COLUMN roles JSON NULL
    COMMENT 'JSON-массив ролей: user, svh_manager, declarant_manager, admin'
    AFTER role;

UPDATE organizations
SET roles = JSON_ARRAY(role)
WHERE roles IS NULL AND role IS NOT NULL AND role <> '';

UPDATE organizations
SET roles = JSON_ARRAY('user')
WHERE roles IS NULL;
