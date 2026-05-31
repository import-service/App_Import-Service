-- ИНН юрлица/ИП из анкеты (не docType inn — скан в files[]).
ALTER TABLE customs_requests
  ADD COLUMN legal_inn VARCHAR(12) NULL DEFAULT NULL
    COMMENT 'ИНН ЮЛ/ИП из анкеты'
    AFTER legal_phone;
