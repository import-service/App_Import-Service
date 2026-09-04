# Fast Android run for import_service_app (agent + local).
# Do NOT pipe flutter through Tee-Object. Do NOT kill Gradle mid-build.
#
# From monorepo root:
#   .\scripts\app-run-android.ps1
#   .\scripts\app-run-android.ps1 -NoPub
#   .\scripts\app-run-android.ps1 -WarmGradle
#   .\scripts\app-run-android.ps1 -ShowVersion
#   .\scripts\app-run-android.ps1 -Device 97c277d3

param(
  [string]$Device = '',
  [switch]$NoPub,
  [switch]$WarmGradle,
  [switch]$ShowVersion,
  [switch]$LogcatAppUpdate,
  [int]$LogcatSeconds = 90
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$AppDir = Join-Path $RepoRoot 'import_service_app'
$PackageId = 'com.importservice.app'
$Adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { $Adb = 'adb' }

function Get-FlutterDeviceId([string]$Preferred) {
  if ($Preferred) { return $Preferred }
  $json = & flutter devices --machine 2>$null
  if (-not $json) { throw 'flutter devices --machine returned empty' }
  $devices = $json | ConvertFrom-Json
  $android = @($devices | Where-Object {
      $_.id -and ($_.targetPlatform -like 'android*' -or $_.targetPlatform -eq 'android-arm64')
    })
  if ($android.Count -lt 1) {
    throw 'No Android device connected. Enable USB debugging.'
  }
  return [string]$android[0].id
}

Push-Location $AppDir
try {
  if ($ShowVersion) {
    $id = Get-FlutterDeviceId $Device
    Write-Host "Device: $id"
    & $Adb -s $id shell dumpsys package $PackageId |
      Select-String -Pattern 'versionName=|versionCode=' |
      ForEach-Object { $_.Line.Trim() }
    return
  }

  if ($LogcatAppUpdate) {
    $id = Get-FlutterDeviceId $Device
    Write-Host "logcat AppUpdate on $id for ${LogcatSeconds}s"
    & $Adb -s $id logcat -c
    $deadline = (Get-Date).AddSeconds($LogcatSeconds)
    & $Adb -s $id logcat -v time flutter:I '*:S' | ForEach-Object {
      if ($_ -match 'AppUpdate|store-versions|updateNeeded') {
        Write-Host $_
      }
      if ((Get-Date) -gt $deadline) { break }
    }
    return
  }

  if ($WarmGradle) {
    Write-Host 'Warm Gradle: flutter build apk --debug'
    flutter build apk --debug
    Write-Host 'Done. Next: .\scripts\app-run-android.ps1 -NoPub'
    return
  }

  $id = Get-FlutterDeviceId $Device
  Write-Host "flutter run -d $id $(if ($NoPub) { '--no-pub' } else { '' })"
  Write-Host 'Watch console for [AppUpdate]. Check install: -ShowVersion'

  if ($NoPub) {
    flutter run -d $id --no-pub
  } else {
    flutter run -d $id
  }
} finally {
  Pop-Location
}
