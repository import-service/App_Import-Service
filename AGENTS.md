# Import Service — монорепо (один агент)

## ПРАВИЛО №1 (важнее всего)

**`.devin/rules/approve-before-any-action.md`**

Пока пользователь не утвердил план («делай» / «ок» / «да») — **запрещены любые tool calls** (SSH, логи, код, деплой, «быстро проверить»). Сначала: разъяснить → план → «Утверждаешь?» → ждать. Вопрос («почему?», «что ответить?») = только текст.

---

## Как открыть проект

**`import_servis.code-workspace`** в корне репозитория — или папка `D:\Projects\import_servis`.

Не открывать только `import_service_app` / `import_service_server` — иначе не подхватятся корневые правила.

## Один агент

Пользователь общается с **одним агентом** на app + server + admin + docs.  
Subagent/Task — только после утверждённого плана в этом чате.

## Корневые правила (trigger: always_on)

| Файл | Назначение |
|------|------------|
| `approve-before-any-action.md` | **№1** — план + утверждение **до** любых тулов |
| `customer-literal-ui-fidelity.md` | Делать 1:1 по словам/скрину заказчика и пользователя (не подменять UI) |
| `one-app-version-store-and-debug.md` | Один `pubspec` version для debug и стора; не откатывать ниже опубликованной |
| `import-platform-workspace.md` | Структура монорепо, порядок end-to-end |
| `feature-delivery-workflow.md` | План → утверждение → код (фичи) |
| `agent-docs-keep-fresh.md` | После фичи/UI — обновлять агентские `.md` (карта флоу МП) |
| `agent-invariants-never-break.md` | commit/push/релиз только по просьбе |
| `agent-does-setup-never-user-chores.md` | Агент сам: analyze, деплой, setup (**после** утверждения задачи) |
| `mandatory-verify-after-code-changes.md` | analyze перед «готово» |
| `project-concept.md` | МП ↔ сервер ↔ 1С (+ роли МП: клиент / СВХ) |
| `monorepo-scope.md` | Границы по задаче, не по «трём агентам» |

## Пакетные правила

| Пакет | Каталог |
|-------|---------|
| МП | `import_service_app/.devin/rules/` |
| Сервер | `import_service_server/.devin/rules/` |
| Админка | `import_service_admin/.devin/rules/` |

Фокус по globs: `agent-mobile-app.md`, `agent-server.md`, `agent-admin-web.md`.

## Канон документации

| Документ | Когда читать |
|----------|--------------|
| `docs/request-lifecycle.md` | Заявки, статусы, upload |
| `docs/api-app.md`, `docs/api-1c.md` | HTTP API |
| `docs/catalog-reference.md` | docType, statusSubType |
| `import_service_app/.devin/rules/app-runtime-architecture.md` | Runtime МП (клиент + СВХ, APK, кэш) |
| `.devin/rules/agent-docs-keep-fresh.md` | После фичи — обновлять agent `.md` |

**Прод:** https://app.import-service.su/docs

## Деплой

- Сервер: `scripts/deploy-server-vps.ps1` — агент сам после правок API
- SSL/LE на VPS: `import_service_server/.devin/rules/server-deploy-vps.md` (§ SSL) + `scripts/setup-ssl-autorenew.sh`; канон для новых VPS — шаблон `fastify-api` (`ssl-letsencrypt-vps.mdc`)
- APK/IPA: только по явной просьбе — `import_service_app/.devin/rules/release-apk-handoff.md`

## Git

Один репозиторий, push из корня. Commit/push — только по просьбе пользователя.
