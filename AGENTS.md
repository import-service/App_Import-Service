# Import Service — монорепо

Перед работой откройте корень репозитория **`D:\Projects\import_servis`** в Cursor (не только подпапку `import_service_server`), чтобы подхватывались правила из **`.cursor/rules/`**.

## Главный документ для всех агентов

**`.cursor/rules/project-concept.mdc`** — общая концепция (МП ↔ сервер ↔ 1С): статусы, документы, этапы, границы агентов.  
Подключён с `alwaysApply: true` — агент должен сверяться с ним при любой задаче по заявкам.

## Дополнительно по роли

| Файл | Для кого |
|------|----------|
| `agent-server.mdc` | Backend |
| `agent-mobile-app.mdc` | Flutter МП |
| `agent-admin-web.mdc` | Flutter админка |
| `monorepo-scope.mdc` | Границы каталогов |

## Markdown-спеки

- `docs/TZ-zayavka-mp-server-1c.md` — полное ТЗ  
- `docs/api-app.md`, `docs/api-1c.md`  
- https://157-22-173-7.sslip.io/docs — вкладка **ТЗ**
