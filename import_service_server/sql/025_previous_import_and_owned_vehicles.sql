-- Даты предыдущего ввоза и список авто в собственности (для пояснения в 1С).
ALTER TABLE customs_requests
  ADD COLUMN previous_import_dates JSON NULL DEFAULT NULL
    COMMENT 'Даты ввоза авто за 12 мес. JSON-массив YYYY-MM-DD'
    AFTER owns_other_cars,
  ADD COLUMN owned_vehicles JSON NULL DEFAULT NULL
    COMMENT 'Авто в собственности: JSON [{name, year}]'
    AFTER previous_import_dates;
