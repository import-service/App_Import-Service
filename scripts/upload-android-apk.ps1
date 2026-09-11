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

if (-not (Test-Path -LiteralPath $ApkPath)) {
  Write-Error "APK not found: $ApkPath"
}

Write-Host "Ensure remote dir…"
ssh $SshHost "mkdir -p '$RemoteApkDir'"

Write-Host "SCP -> $RemoteApk"
scp -o StrictHostKeyChecking=accept-new $ApkPath "${SshHost}:${RemoteApk}"

$vnArg = if ($VersionName) { " --versionName $($VersionName)" } else { '' }
$cmd = "cd '$RemoteRoot' && node scripts/publish-android-apk.js --file '$RemoteApk' --versionCode $VersionCode$vnArg"
Write-Host "Publish manifest…"
ssh $SshHost $cmd

Write-Host "Check public manifest:"
curl.exe -sS "https://157-22-173-7.sslip.io/api/app/android-apk"
Write-Host ""
