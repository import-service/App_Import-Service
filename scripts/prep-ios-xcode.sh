#!/usr/bin/env bash
# Обёртка из корня монорепо → prep iOS/Xcode для МП.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/import_service_app/scripts/prep-ios-xcode.sh" "$@"
