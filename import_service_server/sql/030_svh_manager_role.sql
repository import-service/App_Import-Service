-- Роль менеджера СВХ (склад): вход в МП, все заявки, upload фото/доков без правки анкеты.
ALTER TABLE organizations
  MODIFY COLUMN role ENUM('admin', 'user', 'svh_manager') NOT NULL DEFAULT 'user';
