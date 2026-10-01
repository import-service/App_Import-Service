-- Источник скана версии (itunes_lookup / google_play_api / rustore_public_api …)
ALTER TABLE store_version_latest
  ADD COLUMN scan_source VARCHAR(64) NULL DEFAULT NULL AFTER error_message;

ALTER TABLE store_version_scan_log
  ADD COLUMN scan_source VARCHAR(64) NULL DEFAULT NULL AFTER error_message;
