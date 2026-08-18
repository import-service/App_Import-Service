-- Системные сообщения чата (не менеджер и не клиент).
ALTER TABLE customs_request_messages
  MODIFY COLUMN author_type ENUM('app_user', 'manager_1c', 'system') NOT NULL;
