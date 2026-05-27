# Full prod deploy: pack -> scp -> extract -> npm -> pm2 restart -> curl check
# Run from repo root: .\scripts\deploy-server-vps.ps1
param(
  [string]$SshHost = 'root@157.22.173.7',
  [string]$RemoteDir = '/var/www/www-root/data/www/157-22-173-7.sslip.io',
  [string]$Pm2Name = 'import-service',
  [string]$CheckUrl = 'https://157-22-173-7.sslip.io/admin/'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

& "$PSScriptRoot\pack-server-update.ps1"
$tgz = Join-Path $RepoRoot 'import_service_server\import-service-update.tgz'
$remoteTgz = '/tmp/import-service-update.tgz'

Write-Host "SCP -> ${SshHost}:${remoteTgz}" -ForegroundColor Cyan
& scp -o BatchMode=yes $tgz "${SshHost}:${remoteTgz}"

$remoteCmd = "set -e && cd '$RemoteDir' && tar -xzf '$remoteTgz' && npm install --omit=dev && pm2 restart '$Pm2Name' && sleep 2 && curl -sS -o /dev/null -w 'admin_http=%{http_code} content_type=%{content_type}\n' '$CheckUrl'"

Write-Host "SSH deploy on $SshHost" -ForegroundColor Cyan
& ssh -o BatchMode=yes $SshHost $remoteCmd

Write-Host "Local check:" -ForegroundColor Cyan
try {
  $r = Invoke-WebRequest -Uri $CheckUrl -UseBasicParsing
  Write-Host "OK $($r.StatusCode) $($r.Headers['Content-Type'])" -ForegroundColor Green
} catch {
  Write-Error "Check failed: $($_.Exception.Message)"
}
