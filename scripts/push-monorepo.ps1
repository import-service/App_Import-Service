#requires -Version 5.1
<#
.SYNOPSIS
    Коммит и push всего монорепозитория Import Service на origin (ветка main).

.DESCRIPTION
    Запускать из любого места. Корень репозитория определяется по расположению скрипта.

.PARAMETER Message
    Текст коммита на русском. Если не указан — используется сообщение по умолчанию.

.EXAMPLE
    .\scripts\push-monorepo.ps1 -Message "Исправление API таможенных заявок"
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$Message = "Обновление монорепозитория Import Service"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $RepoRoot

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    Write-Error "Не найден каталог .git в $RepoRoot. Выполните git init и настройте remote."
}

$null = git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Текущий каталог не является Git-репозиторием."
}

git add -A
$changes = git status --porcelain
if (-not $changes) {
    Write-Host "Нет изменений для коммита."
    exit 0
}

git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Error "git commit завершился с ошибкой."
}

$branch = git rev-parse --abbrev-ref HEAD
git push -u origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Error "git push завершился с ошибкой. Проверьте доступ к GitHub и ветку."
}

Write-Host "Готово: отправлено в origin ($branch)."
