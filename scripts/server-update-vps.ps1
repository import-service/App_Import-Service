# На VPS (или по SSH): обновить сервер из git и перезапустить Node
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
git pull origin main
Set-Location (Join-Path $Root 'import_service_server')
npm install --omit=dev
Write-Host 'Перезапустите процесс Node (pm2 restart / systemctl).'
Write-Host 'Проверка: https://157-22-173-7.sslip.io/admin/'
