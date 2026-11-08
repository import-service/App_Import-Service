# 2026-11-08 — черновики не теряются, ИНН не блокирует, organizationId1c + uploadedAt для 1С

**Статус:** done — задеплоено на прод, live-тест пройден, тестовые данные удалены.

## Live-тест на проде (2026-11-08)

- `POST /api/integration/organizations` с `inn: "123456789"` (9 цифр) → `200`, `warnings: ["INVALID_INN_IGNORED"]`, в БД `inn` пустой.
- Прямой `UPDATE inn='123456789'` в БД + `POST /api/customs-requests` (JWT) → `201`, заявка создана, `legalInn: null` — некорректный ИНН профиля не блокирует.
- Payload create в 1С: `organizationId1c` = `id_1c` организации, `files[].uploadedAt` — ISO UTC из `customs_request_files.created_at`; у файлов из тела create — время сервера.
- Тестовая организация, её заявка, сессии и `auth_attempts` удалены; временные файлы убраны.

## Цитата заказчика (дословно)

> Завёл из 1С организацию с ИНН 123456789 (9 цифр) — заявка не отправляется.
> ИНН по бизнес-логике необязательный.
> Ключ для 1С должен быть id_1c (не меняется никогда).
> В files[] нужна дата загрузки файла (для чеков — дата выгрузки чека).
> Черновики заявки в приложении стираются при выходе и входе.

## Факты (проверено)

- `resolveLegalInnForCreate` бросал `VALIDATION_ERROR` на ИНН профиля не 10/12 цифр — блокировал create.
- Upsert организации принимал любой `inn` без проверки длины.
- В payload create в 1С ключ организации был внутренний `organizationId` — нужен стабильный `id_1c`.
- В `files[]` не было даты загрузки; в БД `customs_request_files.created_at` — момент получения файла сервером.
- `RequestDraftCubit().clearAll()` вызывался при logout и login, `prefs.clear()` стирал ключ черновиков — черновики терялись.

## Сделано

- Сервер: некорректный ИНН профиля (не 10/12 цифр) игнорируется — warn в лог, заявка создаётся, в 1С `legalInn/inn: null`.
- Сервер: upsert организации — некорректный `inn` не сохраняется, ответ с `warnings: ["INVALID_INN_IGNORED"]`, факт пишется в `integration_logs`.
- Сервер: в payload create для 1С добавлен `organizationId1c` (= `organizations.id_1c`, стабильный ключ). `organizationId`/`organizationLogin` оставлены без изменений.
- Сервер: в каждый исходящий файл для 1С добавлен `uploadedAt` (ISO 8601 UTC): create из тела и из БД, update файлов, resend, ответ upload. Рядом — `createdAt` с тем же значением (дубль для удобства парсеров 1С).
- МП: черновики привязаны к `userId` сессии (ключ `request_drafts_v1:<userId>`), не стираются при выходе/входе и `prefs.clear()`; старые черновики мигрируют на первого вошедшего пользователя; демо чистит только демо-бакет.
- Доки: `api-1c.md` (таблица create, `inn`, `organizationId1c`, `uploadedAt`, warnings, пример JSON), `api.html`, `api-app.md`, `request-lifecycle.md`, agent-доки МП.

## На будущее

- `organizationId` в create для 1С помечен устаревшим — после перехода 1С на `organizationId1c` можно убрать отдельной задачей.
- Черновики анонимного бакета (`anon`) видны только демо-сессии.
