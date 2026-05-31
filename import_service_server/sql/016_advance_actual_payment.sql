-- Аванс и фактический платёж таможни (из 1С через state).
ALTER TABLE customs_requests
  ADD COLUMN advance_payment_json JSON NULL DEFAULT NULL COMMENT 'Аванс клиента: { amount, currency }' AFTER finance_items_json,
  ADD COLUMN actual_payment_json JSON NULL DEFAULT NULL COMMENT 'Фактический платёж на день таможни: { amount, currency }' AFTER advance_payment_json;
