---
description: Import Service монорепо — один git, один агент, app/server/admin/docs
trigger: always_on
---

# Import Service platform (монорепо)

Один git в корне. Workspace: **`import_servis.code-workspace`** (открывать корнем, не только `import_service_app`).

## Папки

| Имя в workspace | Путь | Стек |
|-----------------|------|------|
| `platform` | `.` | workspace, `.devin/rules`, `scripts/` |
| `server` | `import_service_server/` | Node API, деплой VPS |
| `app` | `import_service_app/` | Flutter МП |
| `admin` | `import_service_admin/` | Flutter web админка |
| `docs` | `docs/` | Markdown-спеки (канон API, ТЗ, каталоги) |

Не менять файлы **вне scope задачи**. End-to-end фича — правки в нескольких пакетах **разрешены** в одной сессии.

## Git

- **Один** `git push` из корня `import_servis`
- Remote: `https://github.com/import-service/App_Import-Service`

## Порядок end-to-end фичи

См. **`feature-delivery-workflow.md`**: план → вопросы → **утверждение пользователем** → код → verify → следующий подэтап.

1. `docs/` + `server/` — контракт API (`docs/api-app.md`, `api-1c.md`)
2. `app/` / `admin/` — UI
3. Пользователь общается с **одним агентом**; subagent/Task — на усмотрение исполнителя

## Документация для агента

После любой фичи/UI — синхронизировать agent `.md` (`agent-docs-keep-fresh.md`).

### Канон продукта и API

| Документ | Назначение |
|----------|------------|
| `.devin/rules/project-concept.md` | МП ↔ сервер ↔ 1С, статусы, docType, роли МП |
| `import_service_app/.devin/rules/app-runtime-architecture.md` | Флоу МП (клиент + СВХ, APK, кэш) |
| `docs/request-lifecycle.md` | Жизненный цикл заявки |
| `docs/api-app.md`, `docs/api-1c.md` | HTTP-контракты |
| `docs/catalog-reference.md` | Коды docType, statusSubType, dealType |
| https://app.import-service.su/docs | HTML на проде (люди/1С) |

### Пакетные rules

| Пакет | Каталог |
|-------|---------|
| МП | `import_service_app/.devin/rules/` |
| Сервер | `import_service_server/.devin/rules/` |
| Админка | `import_service_admin/.devin/rules/` |

Фокус пакета: `agent-mobile-app.md`, `agent-server.md`, `agent-admin-web.md` (globs по папке).

## Прод

- API: `https://app.import-service.su/api`
- Деплой сервера: `scripts/deploy-server-vps.ps1` — см. `import_service_server/.devin/rules/server-deploy-vps.md`
