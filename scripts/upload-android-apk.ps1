# Upload Android APK to prod and publish manifest (versionCode = buildNumber).
# From monorepo root:
#   .\scripts\upload-android-apk.ps1 -ApkPath D:\Temp\import_service_app_1_34.apk -VersionCode 34 -VersionName 1.0.34
param(
  [Parameter(Mandatory = $true)][string]$ApkPath,
  [Parameter(Mandatory = $true)][int]$VersionCode,
  [string]$VersionName = ''
)

$ErrorActionPreference = 'Stop'
$SshHost = 'root@157.22.173.7'
$RemoteRoot = '/var/www/www-root/data/www/157-22-173-7.sslip.io'
$RemoteApkDir = "$RemoteRoot/uploads/app-releases"
$RemoteApk = "$RemoteApkDir/import-service-latest.apk"
$SshOpts = @('-o', 'ConnectTimeout=45', '-o', 'StrictHostKeyChecking=accept-new')

if (-not (Test-Path -LiteralPath $ApkPath)) {
  Write-Error "APK not found: $ApkPath"
}

$localHash = (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Local sha256=$localHash"

Write-Host 'Ensure remote dir...'
& ssh @SshOpts $SshHost "mkdir -p '$RemoteApkDir'"
if ($LASTEXITCODE -ne 0) { throw "ssh mkdir failed: $LASTEXITCODE" }

Write-Host "SCP -> $RemoteApk"
& scp @SshOpts $ApkPath "${SshHost}:${RemoteApk}"
if ($LASTEXITCODE -ne 0) {
  throw "scp failed: $LASTEXITCODE (do NOT publish old remote APK)"
}

$vnArg = if ($VersionName) { " --versionName $VersionName" } else { '' }
$cmd = "cd '$RemoteRoot' && node scripts/publish-android-apk.js --file '$RemoteApk' --versionCode $VersionCode$vnArg"
Write-Host 'Publish manifest...'
& ssh @SshOpts $SshHost $cmd
if ($LASTEXITCODE -ne 0) { throw "publish-android-apk failed: $LASTEXITCODE" }

Write-Host 'Check public manifest:'
$manifestJson = curl.exe -sS 'https://157-22-173-7.sslip.io/api/app/android-apk'
Write-Host $manifestJson
if ($manifestJson -notmatch [regex]::Escape($localHash)) {
  throw "Remote sha256 does not match local APK ($localHash)"
}

$localSize = (Get-Item -LiteralPath $ApkPath).Length
$head = curl.exe -sSI 'https://157-22-173-7.sslip.io/api/app/android-apk/download'
$contentLengthLine = ($head | Select-String -Pattern '(?i)^Content-Length:\s*(\d+)' | Select-Object -First 1)
if (-not $contentLengthLine) {
  throw 'Download response missing Content-Length'
}
$remoteSize = [int64]$contentLengthLine.Matches[0].Groups[1].Value
Write-Host "Size check local=$localSize remote=$remoteSize"
if ($remoteSize -ne $localSize) {
  throw "Remote Content-Length $remoteSize != local $localSize (broken upload?)"
}
Write-Host 'UPLOAD_OK'
