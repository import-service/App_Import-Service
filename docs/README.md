# Документация API Import Service

Публичные спецификации (Markdown), общие для мобильного клиента, бэкенда и 1С:

| Файл | Содержание |
|------|------------|
| **[request-lifecycle.md](request-lifecycle.md)** | **Единый эталон жизненного цикла заявки** (статусы, этапы, upload, push, МП, demo) |
| [TZ-zayavka-mp-server-1c.md](TZ-zayavka-mp-server-1c.md) | Полное ТЗ (детали, история) |
| [api-app.md](api-app.md) | API приложения: авторизация, таможенные заявки, чат, WSS, деплой веб-админки |
| [api-1c.md](api-1c.md) | Интеграция 1С: `organizations`, `state`, upload, чат |
| [contract-files-v2.md](contract-files-v2.md) | Контракт файлов (upload + батч, state) |
| [catalog-reference.md](catalog-reference.md) | **Справочники:** `statusSubType`, все `docType`, `dealType` |

**Базовый URL (прод):** `https://157-22-173-7.sslip.io/api`  
Краткий HTML-обзор эндпоинтов и вкладка **ТЗ**: `https://157-22-173-7.sslip.io/docs`

Правила Cursor для агентов монорепо: `.cursor/rules/` в корне `import_servis` (границы: сервер / МП / админка).  
Веб-админка (Flutter Web): `https://157-22-173-7.sslip.io/admin/` — сборка и выкладка в [api-app.md § Веб-админка](api-app.md#веб-админка-деплой).
