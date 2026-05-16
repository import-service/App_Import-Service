#!/usr/bin/env bash
# На VPS в каталоге клона монорепозитория:
#   bash scripts/server-update-vps.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git pull origin main
cd import_service_server
npm install --omit=dev
if command -v pm2 >/dev/null 2>&1; then
  pm2 restart import-service-server 2>/dev/null || pm2 restart all
elif systemctl is-active import-service-server >/dev/null 2>&1; then
  sudo systemctl restart import-service-server
else
  echo "Перезапустите Node вручную (pm2/systemd) из import_service_server"
fi
echo "Готово. Проверка: curl -sI https://157-22-173-7.sslip.io/admin/ | head -1"
