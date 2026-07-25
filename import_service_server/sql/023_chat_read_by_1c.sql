-- Прочитанность сообщений клиента менеджером в 1С (WSS/HTTP read).
ALTER TABLE customs_request_messages
  ADD COLUMN read_by_1c_at DATETIME(3) NULL DEFAULT NULL
  AFTER read_by_user_at;
