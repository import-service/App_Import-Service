-- Тип сделки и дата подстатуса (контракт state 1С).

ALTER TABLE customs_requests
  ADD COLUMN deal_type VARCHAR(32) NULL DEFAULT NULL COMMENT 'bilateral|cash|tripartite|quadripartite' AFTER status_sub_type,
  ADD COLUMN status_sub_type_datetime DATETIME(3) NULL DEFAULT NULL COMMENT 'Дата/время подстатуса из 1С' AFTER deal_type;
