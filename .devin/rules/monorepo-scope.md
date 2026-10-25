---
description: Монорепо Import Service — один агент, общая концепция, границы по задаче
trigger: always_on
---

# Монорепо `import_servis`

## Один агент

Пользователь работает с **одним агентом** на весь монорепо (app + server + admin + docs).

Открывать **`import_servis.code-workspace`** или корень `D:\Projects\import_servis` — иначе корневые `.devin/rules/` не подхватятся.

См. **`import-platform-workspace.md`**, **`feature-delivery-workflow.md`**.

## Общая концепция (обязательно)

**`.devin/rules/project-concept.md`** — архитектура, статусы, документы, 1С.  
**`docs/request-lifecycle.md`** — жизненный цикл заявки.

## Каталоги

| Путь | Назначение |
|------|------------|
| `import_service_server/` | Node API, деплой |
| `import_service_app/` | Flutter МП |
| `import_service_admin/` | Flutter web админка |
| `docs/` | Markdown-спеки |

## Границы

- Не менять файлы **вне scope задачи**.
- End-to-end фича (API + МП + админка) — **одна сессия, один агент**, порядок в `feature-delivery-workflow.md`.
- Фокус пакета: `agent-server.md`, `agent-mobile-app.md`, `agent-admin-web.md` (по globs).

## Запрещено

- Открывать только подпапку и ожидать, что видны все правила монорепо.
- Дублировать канон API в коде без синхронизации с `docs/`.
