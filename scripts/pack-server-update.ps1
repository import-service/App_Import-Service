# Build import-service-update.tgz for VPS deploy.
# Run from repo root: .\scripts\pack-server-update.ps1
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ServerDir = Join-Path $RepoRoot 'import_service_server'
$OutFile = Join-Path $ServerDir 'import-service-update.tgz'

if (-not (Test-Path (Join-Path $ServerDir 'src\app.js'))) {
  Write-Error "import_service_server not found"
}

$required = @(
  'src\routes\adminWeb.js',
  'web\index.html',
  'src\routes\docs.js'
)
foreach ($rel in $required) {
  if (-not (Test-Path (Join-Path $ServerDir $rel))) {
    Write-Error "Missing: import_service_server\$rel"
  }
}

Push-Location $ServerDir
try {
  if (Test-Path $OutFile) {
    Remove-Item $OutFile -Force
  }
  & tar -czf $OutFile package.json package-lock.json sql src web
  if ($LASTEXITCODE -ne 0) {
    throw "tar failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

$sizeKb = [math]::Round((Get-Item $OutFile).Length / 1KB, 1)
Write-Host "OK: $OutFile ($sizeKb KB)"
Write-Host "Upload to VPS, extract (keep .env), npm install --omit=dev, restart Node."
