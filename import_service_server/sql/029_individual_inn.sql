-- ИНН физлица («кому везут») — всегда 12 цифр, отдельно от legal_inn ЮЛ/ИП.
ALTER TABLE customs_requests
  ADD COLUMN individual_inn VARCHAR(12) NULL DEFAULT NULL
    COMMENT 'ИНН физлица получателя (12 цифр)'
    AFTER individual_snils;
