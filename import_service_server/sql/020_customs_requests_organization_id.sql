-- Привязка заявки к организации (organizations.id) — изоляция списка в МП.

ALTER TABLE customs_requests
  ADD COLUMN organization_id BIGINT UNSIGNED NULL DEFAULT NULL
    COMMENT 'organizations.id — кто создал заявку из МП'
    AFTER id,
  ADD KEY idx_customs_requests_organization_id (organization_id),
  ADD CONSTRAINT fk_customs_requests_org
    FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL;

-- Старые заявки: привязка по ИНН + email входа (если совпадают).
UPDATE customs_requests cr
INNER JOIN organizations o
  ON REPLACE(o.inn, ' ', '') = REPLACE(cr.legal_inn, ' ', '')
 AND LOWER(TRIM(o.login)) = LOWER(TRIM(cr.legal_email))
 AND o.deleted_at IS NULL
SET cr.organization_id = o.id
WHERE cr.organization_id IS NULL;
