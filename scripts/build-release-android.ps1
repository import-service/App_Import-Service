# Release Android APK (+ optional store AAB/APK) with a stable Gradle home (never Cursor sandbox cache).
# From monorepo root:
#   .\scripts\build-release-android.ps1
#   .\scripts\build-release-android.ps1 -UploadApk
#   .\scripts\build-release-android.ps1 -AlsoStoreAab
#   .\scripts\build-release-android.ps1 -AlsoStoreAab -AlsoStoreApk
#
# Flavors:
#   server — APK на наш сервер (REQUEST_INSTALL_PACKAGES + самоустановка)
#   store  — Play / RuStore (без REQUEST_INSTALL_PACKAGES)
param(
  [switch]$AlsoStoreAab,
  [switch]$AlsoStoreApk,
  [switch]$UploadApk,
  [switch]$SkipPubGet,
  # Устарело: раньше -AlsoAab. Теперь store AAB = -AlsoStoreAab.
  [switch]$AlsoAab
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot 'import_service_app'
$TempDir = 'D:\Temp'

if ($AlsoAab) {
  Write-Warning '-AlsoAab устарел → используем -AlsoStoreAab (flavor store)'
  $AlsoStoreAab = $true
}

# CRITICAL: never use Cursor sandbox Gradle cache (...\Temp\cursor-sandbox-cache\...).
$stableGradleHome = Join-Path $env:USERPROFILE '.gradle'
if (-not [string]::IsNullOrWhiteSpace($env:GRADLE_USER_HOME)) {
  $current = [string]$env:GRADLE_USER_HOME
  if ($current -match 'cursor-sandbox-cache') {
    Write-Warning "GRADLE_USER_HOME was sandbox cache: $current - override to $stableGradleHome"
    $env:GRADLE_USER_HOME = $stableGradleHome
  }
} else {
  $env:GRADLE_USER_HOME = $stableGradleHome
}

if ($env:GRADLE_USER_HOME -match 'cursor-sandbox-cache') {
  throw "Refusing build: GRADLE_USER_HOME still in cursor-sandbox-cache ($($env:GRADLE_USER_HOME))"
}

New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

Write-Host "GRADLE_USER_HOME=$($env:GRADLE_USER_HOME)"

$pubspec = Get-Content (Join-Path $AppDir 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+(\d+)\s*$') {
  throw 'Cannot parse version from pubspec.yaml (expected x.y.z+build)'
}
$versionName = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$buildNumber = [int]$Matches[4]
Write-Host "Version $versionName+$buildNumber"

Push-Location $AppDir
try {
  $gradlew = Join-Path $AppDir 'android\gradlew.bat'
  if (Test-Path $gradlew) {
    Write-Host 'Stopping Gradle daemons...'
    & $gradlew --stop 2>$null | Out-Null
  }

  if (-not $SkipPubGet) {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed: $LASTEXITCODE" }
  }

  Write-Host 'Building server APK (release, flavor=server)...'
  $apkSw = [System.Diagnostics.Stopwatch]::StartNew()
  flutter build apk --release --flavor server --dart-define=APP_DISTRIBUTION=server
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk (server) failed: $LASTEXITCODE" }
  $apkSw.Stop()
  Write-Host ("Server APK done in {0:N1} min" -f $apkSw.Elapsed.TotalMinutes)

  $apkSrcCandidates = @(
    (Join-Path $AppDir 'build\app\outputs\flutter-apk\app-server-release.apk'),
    (Join-Path $AppDir 'build\app\outputs\apk\server\release\app-server-release.apk')
  )
  $apkSrc = $apkSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $apkSrc) {
    throw "Server APK not found. Tried: $($apkSrcCandidates -join ', ')"
  }
  $apkDst = Join-Path $TempDir "import_service_app_1_$buildNumber.apk"
  Copy-Item -Force $apkSrc $apkDst
  Write-Host "Server APK -> $apkDst"

  if ($AlsoStoreAab) {
    Write-Host 'Building store AAB (release, flavor=store)...'
    $aabSw = [System.Diagnostics.Stopwatch]::StartNew()
    flutter build appbundle --release --flavor store --dart-define=APP_DISTRIBUTION=store
    if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle (store) failed: $LASTEXITCODE" }
    $aabSw.Stop()
    Write-Host ("Store AAB done in {0:N1} min" -f $aabSw.Elapsed.TotalMinutes)

    $aabSrcCandidates = @(
      (Join-Path $AppDir 'build\app\outputs\bundle\storeRelease\app-store-release.aab'),
      (Join-Path $AppDir 'build\app\outputs\bundle\storeRelease\app.aab')
    )
    $aabSrc = $aabSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $aabSrc) {
      throw "Store AAB not found. Tried: $($aabSrcCandidates -join ', ')"
    }
    $aabDst = Join-Path $TempDir "import_service_app_1_$buildNumber.aab"
    Copy-Item -Force $aabSrc $aabDst
    Write-Host "Store AAB -> $aabDst"
  }

  if ($AlsoStoreApk) {
    Write-Host 'Building store APK (release, flavor=store)...'
    $storeApkSw = [System.Diagnostics.Stopwatch]::StartNew()
    flutter build apk --release --flavor store --dart-define=APP_DISTRIBUTION=store
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk (store) failed: $LASTEXITCODE" }
    $storeApkSw.Stop()
    Write-Host ("Store APK done in {0:N1} min" -f $storeApkSw.Elapsed.TotalMinutes)

    $storeApkSrcCandidates = @(
      (Join-Path $AppDir 'build\app\outputs\flutter-apk\app-store-release.apk'),
      (Join-Path $AppDir 'build\app\outputs\apk\store\release\app-store-release.apk')
    )
    $storeApkSrc = $storeApkSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $storeApkSrc) {
      throw "Store APK not found. Tried: $($storeApkSrcCandidates -join ', ')"
    }
    $storeApkDst = Join-Path $TempDir "import_service_app_store_1_$buildNumber.apk"
    Copy-Item -Force $storeApkSrc $storeApkDst
    Write-Host "Store APK -> $storeApkDst"
  }

  if ($UploadApk) {
    $upload = Join-Path $RepoRoot 'scripts\upload-android-apk.ps1'
    & $upload -ApkPath $apkDst -VersionCode $buildNumber -VersionName $versionName
    if ($LASTEXITCODE -ne 0) { throw "upload-android-apk failed: $LASTEXITCODE" }
  }

  Write-Host 'ALL_OK'
} finally {
  Pop-Location
}
