---
description: Фокус МП — import_service_app (в рамках одного агента монорепо)
trigger: glob
globs: import_service_app/**
---

# Пакет: `import_service_app`

**Сначала:** `.devin/rules/project-concept.md`, `docs/request-lifecycle.md`, `import_service_app/.devin/rules/app-runtime-architecture.md`.

После фичи/UI в МП — обновить `app-runtime-architecture.md` + `app-context-map.md` (корневое `agent-docs-keep-fresh.md`).

## Зона ответственности

- `import_service_app/` — UI, Cubit, роутер, push, файлы заявки, роли клиент / `svh_manager`.
- End-to-end задачи: правки app **вместе** с server/docs по утверждённому плану.

## Спеки

- `docs/api-app.md` — API приложения
- `docs/catalog-reference.md` — docType, statusSubType, dealType
- https://157-22-173-7.sslip.io/docs → вкладка **ТЗ**

## Фокус МП (кратко)

- Роли: клиент → `/home`; СВХ → `/svh-home` (`session_role.dart`)
- Create (клиент): `POST /customs-requests` без files → N×upload
- 11 обязательных docType при создании — project-concept §7
- Demo только по кнопке на логине (не СВХ)
- SnackBar: `AppFeedbackService`; i18n: `assets/i18n/*.json`

## Пакетные rules

`import_service_app/.devin/rules/` — architecture, bloc, pitfalls, app-context-map, release-apk и др.

## Проверки

`flutter analyze` по задаче. Commit/push — только по просьбе пользователя.
