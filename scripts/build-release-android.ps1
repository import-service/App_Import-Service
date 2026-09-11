# Release Android APK (+ optional AAB) with a stable Gradle home (never Cursor sandbox cache).
# From monorepo root:
#   .\scripts\build-release-android.ps1
#   .\scripts\build-release-android.ps1 -AlsoAab
#   .\scripts\build-release-android.ps1 -AlsoAab -UploadApk
param(
  [switch]$AlsoAab,
  [switch]$UploadApk,
  [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot 'import_service_app'
$TempDir = 'D:\Temp'

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

  Write-Host 'Building APK (release)...'
  $apkSw = [System.Diagnostics.Stopwatch]::StartNew()
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed: $LASTEXITCODE" }
  $apkSw.Stop()
  Write-Host ("APK done in {0:N1} min" -f $apkSw.Elapsed.TotalMinutes)

  $apkSrc = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-release.apk'
  $apkDst = Join-Path $TempDir "import_service_app_1_$buildNumber.apk"
  Copy-Item -Force $apkSrc $apkDst
  Write-Host "APK -> $apkDst"

  if ($AlsoAab) {
    Write-Host 'Building AAB (release)...'
    $aabSw = [System.Diagnostics.Stopwatch]::StartNew()
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed: $LASTEXITCODE" }
    $aabSw.Stop()
    Write-Host ("AAB done in {0:N1} min" -f $aabSw.Elapsed.TotalMinutes)

    $aabSrc = Join-Path $AppDir 'build\app\outputs\bundle\release\app-release.aab'
    $aabDst = Join-Path $TempDir "import_service_app_1_$buildNumber.aab"
    Copy-Item -Force $aabSrc $aabDst
    Write-Host "AAB -> $aabDst"
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
