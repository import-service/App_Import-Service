-- Перевод модели авторизации: users -> organizations (по одной записи от 1С).
-- Поля организации: id_1c, login(email), password, role, orgType, companyName, inn, phone.

CREATE TABLE IF NOT EXISTS organizations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_1c VARCHAR(255) NOT NULL COMMENT 'Идентификатор организации в 1С',
  login VARCHAR(255) NOT NULL COMMENT 'Логин (email) для входа',
  role ENUM('admin', 'user') NOT NULL DEFAULT 'user',
  password_hash VARCHAR(255) NOT NULL,
  org_type ENUM('ИП', 'ООО') NOT NULL DEFAULT 'ООО',
  company_name VARCHAR(255) NOT NULL COMMENT 'ФИО для ИП или название для ООО',
  inn VARCHAR(32) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL DEFAULT NULL,
  UNIQUE KEY uq_organizations_id_1c (id_1c),
  KEY idx_organizations_login_active (login),
  KEY idx_organizations_deleted_at (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Миграция данных из старой таблицы users (если она существует).
SET @users_exists := (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
);

SET @copy_sql := IF(
  @users_exists > 0,
  'INSERT INTO organizations (id, id_1c, login, role, password_hash, org_type, company_name, inn, phone, created_at, updated_at, deleted_at)
   SELECT id,
          COALESCE(external_1c_id, CONCAT("legacy-", id)),
          login,
          COALESCE(role, "user"),
          password_hash,
          "ООО",
          login,
          "",
          "",
          created_at,
          updated_at,
          deleted_at
   FROM users
   ON DUPLICATE KEY UPDATE
     login=VALUES(login),
     role=VALUES(role),
     password_hash=VALUES(password_hash),
     updated_at=VALUES(updated_at),
     deleted_at=VALUES(deleted_at)',
  'SELECT 1'
);
PREPARE stmt_copy FROM @copy_sql;
EXECUTE stmt_copy;
DEALLOCATE PREPARE stmt_copy;

-- user_sessions: привязка к organizations
SET @fk_user_sessions_exists := (
  SELECT COUNT(*)
  FROM information_schema.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND CONSTRAINT_NAME = 'fk_user_sessions_user'
    AND TABLE_NAME = 'user_sessions'
);
SET @drop_fk_user_sessions_sql := IF(
  @fk_user_sessions_exists > 0,
  'ALTER TABLE user_sessions DROP FOREIGN KEY fk_user_sessions_user',
  'SELECT 1'
);
PREPARE stmt_drop_us_fk FROM @drop_fk_user_sessions_sql;
EXECUTE stmt_drop_us_fk;
DEALLOCATE PREPARE stmt_drop_us_fk;

SET @add_fk_user_sessions_sql := (
  SELECT IF(
    EXISTS(
      SELECT 1
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_sessions'
    ),
    'ALTER TABLE user_sessions ADD CONSTRAINT fk_user_sessions_org FOREIGN KEY (user_id) REFERENCES organizations (id) ON DELETE CASCADE',
    'SELECT 1'
  )
);
PREPARE stmt_add_us_fk FROM @add_fk_user_sessions_sql;
EXECUTE stmt_add_us_fk;
DEALLOCATE PREPARE stmt_add_us_fk;

-- customs_request_messages: чтобы связь автора сообщений шла на organizations
SET @fk_crm_user_exists := (
  SELECT COUNT(*)
  FROM information_schema.REFERENTIAL_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND CONSTRAINT_NAME = 'fk_crm_user'
    AND TABLE_NAME = 'customs_request_messages'
);
SET @drop_fk_crm_sql := IF(
  @fk_crm_user_exists > 0,
  'ALTER TABLE customs_request_messages DROP FOREIGN KEY fk_crm_user',
  'SELECT 1'
);
PREPARE stmt_drop_crm_fk FROM @drop_fk_crm_sql;
EXECUTE stmt_drop_crm_fk;
DEALLOCATE PREPARE stmt_drop_crm_fk;

SET @add_fk_crm_sql := (
  SELECT IF(
    EXISTS(
      SELECT 1
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'customs_request_messages'
    ),
    'ALTER TABLE customs_request_messages ADD CONSTRAINT fk_crm_org FOREIGN KEY (user_id) REFERENCES organizations (id) ON DELETE SET NULL',
    'SELECT 1'
  )
);
PREPARE stmt_add_crm_fk FROM @add_fk_crm_sql;
EXECUTE stmt_add_crm_fk;
DEALLOCATE PREPARE stmt_add_crm_fk;
