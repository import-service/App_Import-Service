# Сборка import_service_admin и копирование в import_service_server/public/admin
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$adminDir = Join-Path $RepoRoot 'import_service_admin'
$serverWebDir = Join-Path $RepoRoot 'import_service_server\web'
$buildDir = Join-Path $adminDir 'build\web'

Write-Host "flutter build web --base-href=/admin/ --dart-define=API_BASE_URL=/api/" -ForegroundColor Cyan
Push-Location $adminDir
try {
  flutter build web --base-href=/admin/ --dart-define=API_BASE_URL=/api/
} finally {
  Pop-Location
}

if (-not (Test-Path (Join-Path $buildDir 'index.html'))) {
  throw "Нет $buildDir\index.html после сборки"
}

if (-not (Test-Path $serverWebDir)) {
  New-Item -ItemType Directory -Path $serverWebDir -Force | Out-Null
}

Write-Host "Копирование в $serverWebDir" -ForegroundColor Cyan
Get-ChildItem -Path $serverWebDir -Force |
  Where-Object { $_.Name -ne 'index.html' } |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Copy-Item -Path (Join-Path $buildDir '*') -Destination $serverWebDir -Recurse -Force

Write-Host "Done. Run deploy-server-vps.ps1, then open https://157-22-173-7.sslip.io/admin/" -ForegroundColor Green
