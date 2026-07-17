# Import Service — монорепо (один агент Cursor)

## Как открыть проект

**`import_servis.code-workspace`** в корне репозитория — или папка `D:\Projects\import_servis`.

Не открывать только `import_service_app` / `import_service_server` — иначе не подхватятся корневые правила.

## Один агент

Пользователь общается с **одним агентом** на app + server + admin + docs.  
Subagent/Task — на усмотрение исполнителя.

## Корневые правила (alwaysApply)

| Файл | Назначение |
|------|------------|
| `import-platform-workspace.mdc` | Структура монорепо, порядок end-to-end |
| `feature-delivery-workflow.mdc` | План → утверждение → код |
| `agent-invariants-never-break.mdc` | commit/push/релиз только по просьбе |
| `agent-does-setup-never-user-chores.mdc` | Агент сам: analyze, деплой, setup |
| `mandatory-verify-after-code-changes.mdc` | analyze перед «готово» |
| `project-concept.mdc` | МП ↔ сервер ↔ 1С |
| `monorepo-scope.mdc` | Границы по задаче, не по «трём агентам» |

## Пакетные правила

| Пакет | Каталог |
|-------|---------|
| МП | `import_service_app/.cursor/rules/` |
| Сервер | `import_service_server/.cursor/rules/` |
| Админка | `import_service_admin/.cursor/rules/` |

Фокус по globs: `agent-mobile-app.mdc`, `agent-server.mdc`, `agent-admin-web.mdc`.

## Канон документации

| Документ | Когда читать |
|----------|--------------|
| `docs/request-lifecycle.md` | Заявки, статусы, upload |
| `docs/api-app.md`, `docs/api-1c.md` | HTTP API |
| `docs/catalog-reference.md` | docType, statusSubType |
| `import_service_app/.cursor/rules/app-runtime-architecture.mdc` | Runtime МП |

**Прод:** https://157-22-173-7.sslip.io/docs

## Деплой

- Сервер: `scripts/deploy-server-vps.ps1` — агент сам после правок API
- SSL/LE на VPS: `import_service_server/.cursor/rules/server-deploy-vps.mdc` (§ SSL) + `scripts/setup-ssl-autorenew.sh`; канон для новых VPS — шаблон `fastify-api` (`ssl-letsencrypt-vps.mdc`)
- APK/IPA: только по явной просьбе — `import_service_app/.cursor/rules/release-apk-handoff.mdc`

## Git

Один репозиторий, push из корня. Commit/push — только по просьбе пользователя.
