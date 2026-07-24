-- Тип заявителя: физическое лицо (наряду с ИП и ООО)

ALTER TABLE organizations
  MODIFY COLUMN org_type ENUM('ИП', 'ООО', 'Физическое лицо') NOT NULL DEFAULT 'ООО'
    COMMENT 'Тип организации / заявителя';
