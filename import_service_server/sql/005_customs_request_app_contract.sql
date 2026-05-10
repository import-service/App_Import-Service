-- Поля UI/1С по контракту мобильного приложения (список/деталка заявки).

ALTER TABLE customs_requests
  ADD COLUMN owner_full_name VARCHAR(255) NULL DEFAULT NULL COMMENT 'С 1С: владелец/отображаемое ФИО' AFTER individual_snils,
  ADD COLUMN engine_spec VARCHAR(255) NULL DEFAULT NULL COMMENT 'Про двигатель (строка с 1С)' AFTER status,
  ADD COLUMN engine_volume VARCHAR(128) NULL DEFAULT NULL COMMENT 'Объём/ряд (строка с 1С)' AFTER engine_spec,
  ADD COLUMN status_since_date_label VARCHAR(255) NULL DEFAULT NULL COMMENT 'Подпись даты у статуса (строка для UI)' AFTER engine_volume,
  ADD COLUMN status_sub_type VARCHAR(128) NULL DEFAULT NULL COMMENT 'Код подстатуса (чип): in_transit_loading, …' AFTER status_since_date_label,
  ADD COLUMN finance_items_json JSON NULL DEFAULT NULL COMMENT 'Пошлина, утиль и т.д.' AFTER status_sub_type,
  ADD COLUMN vehicle_photo_urls_json JSON NULL DEFAULT NULL COMMENT 'URL фото авто (1С+сервер)' AFTER finance_items_json,
  ADD COLUMN delivered_documents_json JSON NULL DEFAULT NULL COMMENT 'СБКТС, ЭПТС, …' AFTER vehicle_photo_urls_json;
