# API для приложения

Базовый URL (прод):

- `https://157-22-173-7.sslip.io/api`

## Авторизация

### GET /api/version

Проверка версии и имени backend.

Успех:

```json
{ "name": "import-service-server", "version": "0.1.1", "timestamp": "2026-04-27T09:00:00.000Z" }
```

### POST /api/auth/login

Вход по логину и паролю. Логин — **email организации**.

Запрос:

```json
{ "login": "admin@gmail.com", "password": "123456" }
```

Успех:

```json
{
  "accessToken": "sample_access_token_value",
  "tokenType": "Bearer",
  "expiresAt": "2026-05-27T09:00:00.000Z",
  "role": "admin"
}
```

Ошибки:

- `401 INVALID_CREDENTIALS`

### POST /api/auth/logout

Выход из текущей сессии.

Успех:

```json
{ "ok": true }
```

Ошибки:

- `401 UNAUTHORIZED`
- `401 SESSION_REVOKED_OR_EXPIRED`

### GET /api/auth/me

Профиль текущей организации (без password hash).

Успех:

```json
{
  "id": 5,
  "id_1c": "org-001",
  "login": "mail@org.ru",
  "role": "user",
  "orgType": "ООО",
  "companyName": "ООО Ромашка",
  "inn": "7701234567",
  "phone": "+79990000000",
  "created_at": "2026-04-27T09:00:00.000Z",
  "updated_at": "2026-04-27T09:00:00.000Z",
  "deleted_at": null
}
```

Ошибки:

- `401 UNAUTHORIZED`
- `401 USER_NOT_FOUND`

## Заявки на таможенное оформление

Статусы:

- `new`
- `in_progress`
- `in_transit`
- `delivered`

Контракт ответа (camelCase), см. также **`docs/contract-files-v2.md`**:

- `id` (string)
- `ownerFullName`
- `legalEntityName`, `legalEmail`, `legalPhone`, **`legalInn`** (ИНН ЮЛ/ИП из анкеты; алиас в ответе `inn`)
- `carMake`, `carModel`, `vin`
- `status`, `statusSubType`, `statusSubTypeDateTime`
- `engineSpec`, `engineVolume`
- `advancePayment`, `actualPayment`, `refundAmount` — **строки** (рубли); `refundAmount` считает сервер
- `external1cId`, `managerExternal1cId`, `managerFullName`
- `files[]` — **все** документы (квитанции, фото, ЭПТС — только здесь)
  - элемент: `docType`, **`fileName`** (с расширением, для отображения и 1С), `mimeType`, `fileSizeBytes`, **`fileUrl`** (полный файл), **`previewUrl`** (JPEG-превью для фото в списках МП; `null` для PDF/видео без poster)
  - дополнительно (для отладки / админки): **`sourceFileName`**, **`sourceMimeType`** — как пришло в upload до нормализации; **`uploadSource`**: `integration` | `user` | `demo`; **`storedName`** — имя на диске

### POST /api/customs-requests

Создать заявку (**без** `files` в теле). Файлы — отдельно через `upload`.

Запрос (сокращенно):

```json
{
  "legalEntityName": "ООО Вектор",
  "legalEmail": "mail@example.com",
  "legalPhone": "+79990000000",
  "legalInn": "7707083893",
  "individualFullName": "Иванов Иван Иванович",
  "individualPhone": "+79991112233",
  "individualSnils": "123-456-789 00",
  "carMake": "Toyota",
  "carModel": "Crown",
  "vin": "VIN12345678901234"
}
```

МП может отправить **`legalInn`** и/или **`inn`** с одним значением (10 или 12 цифр). Это **поле анкеты**, не путать с `docType: "inn"` — скан ИНН в `files[]` при upload.

Далее N× `upload` (см. ниже). Обязательные `docType` — при upload, не в теле create:

- `passport_front`, `passport_registration`, `inn`, `snils`, `invoice`, **`contract_original`**, `payment_check`
- `car_nameplate_photo`, `car_mileage_photo`, `car_front_photo`, `car_back_photo`

Успех create: `201`, `status: new`, `files: []`, в теле **`legalInn`** (и алиас `inn`).

На последнем upload сервер создаёт заявку в 1С → `on_review`, `external1cId`. Менеджер и суммы — из 1С через `state`. Ошибка create в 1С — статус остаётся `new`; повтор из админки.

Ошибки:

- `400 VALIDATION_ERROR`
- `401 UNAUTHORIZED`
- `500 INTERNAL_ERROR`

### GET /api/customs-requests

Список заявок **только своей организации** (JWT `sub` = `organizations.id`).

Query:

- `limit`, `offset`
- `status`

### GET /api/customs-requests/:id

Деталка заявки (+ `files`).

### PATCH /api/customs-requests/:id

Обновить поля анкеты (без полей 1С и без смены статуса). Поддерживается **`legalInn`** / **`inn`** (10 или 12 цифр).

### DELETE /api/customs-requests/:id

**Отключено для МП** — ответ `403 FORBIDDEN`. Удаление заявки и файлов с диска — только из **админки** (`DELETE /api/admin/customs-requests/:id`).

### POST /api/customs-requests/upload

Multipart: `requestId`, `docType`, `file`, `uploadIndex`, `uploadTotal`.

**Лимиты размера:** фото/PDF/документы — **25 МБ**; видео и аудио (`transit_archive_video`, mime `video/*` / `audio/*`) — **100 МБ**.

Ответ:

```json
{
  "ok": true,
  "batchComplete": false,
  "file": {
    "docType": "passport_front",
    "fileName": "passport-front.jpg",
    "mimeType": "image/jpeg",
    "fileSizeBytes": 12345,
    "fileUrl": "/api/customs-requests/files/r12__passport_front.jpg",
    "previewUrl": "/api/customs-requests/files/r12__passport_front_preview.jpg",
    "replaced": false
  }
}
```

- **`fileUrl`** — скачивание, PDF-viewer, видео.
- **`previewUrl`** — миниатюры в МП (меньше трафика); для фото генерируется на сервере.

После каждого upload (или когда `batchComplete: true`) — **GET /api/customs-requests/:id** для актуальных URL.

Push `request_files_update` — после upload от 1С; в `data.changedDocTypes` — список docType.

## Push-уведомления (FCM)

Регистрация токена: `POST /api/push/register` (см. код `src/routes/push.js`).

После push — **GET /api/customs-requests/:id** (или обновление списка) для актуальных данных.

### `request_update` (смена статуса / state от 1С)

Поле `data` (все значения — строки):

| Ключ | Описание |
|------|----------|
| `type` | `request_update` |
| `requestId` | id заявки |
| `external1cId` | id в 1С |
| `status` | новый верхний статус |
| `statusSubType` | подстатус (может быть пустым) |
| `previousStatus` | **только** если верхний `status` реально сменился |
| `changeSummary` | готовая строка для UI списка (RU, до ~120 символов) |

Примеры `changeSummary`:

- `Статус: В пути → Доставлено`
- `Требуется подпись документов` (`signature_revision_required`)
- `Обновлён подстатус: Отправлены первичные документы`

Если `changeSummary` пуст — МП собирает текст из `status` / `previousStatus` / `statusSubType`.

### `request_files_update` (новые файлы от 1С)

| Ключ | Описание |
|------|----------|
| `type` | `request_files_update` |
| `requestId`, `external1cId` | … |
| `changedDocTypes` | через запятую, напр. `contract,kuts` |
| `changeSummary` | напр. `Новые документы: contract, kuts` |

### `new_message` (чат)

| Ключ | Описание |
|------|----------|
| `type` | `new_message` |
| `requestId`, `external1cId`, `messageId` | … |

### DELETE /api/customs-requests/:id/files/:fileId

Мягко удалить файл заявки.

### GET /api/customs-requests/files/:storedName

Скачать файл по ссылке.

Авторизация: `Authorization: Bearer <accessToken>` (пользователь приложения), JWT админки (`aud: admin`) **или** интеграционный токен 1С — `Authorization: Bearer <INTEGRATION_BEARER_TOKEN>`.

Ищется по `stored_name` **или** `preview_stored_name` (миниатюра JPEG для списков).

## Чат по заявке

Чат доступен только после появления `external1cId`.

Ограничения:

- `text` до 2000 символов
- вложения только ссылками (`fileUrl`)

### GET /api/customs-requests/:id/messages

История сообщений.

Query:

- `limit` (default 50, max 200)
- `beforeId`

Ошибка:

- `409 CHAT_NOT_AVAILABLE`

### POST /api/customs-requests/:id/messages

Отправить сообщение пользователем.

### POST /api/customs-requests/:id/messages/read

Прочитанность входящих сообщений 1С у пользователя.

## Realtime (WSS)

Прод:

- `wss://157-22-173-7.sslip.io/ws/<requestId>/?token=<accessToken>`

Локально/напрямую:

- `ws://<host>:3010/ws/<requestId>/?token=<accessToken>`

## API веб-админки

Отдельная сессия (JWT с `aud: "admin"`), **не** смешивается с `POST /api/auth/login` организаций.

### POST /api/admin/auth/login

```json
{ "login": "admin", "password": "123456" }
```

Успех:

```json
{
  "accessToken": "…",
  "tokenType": "Bearer",
  "expiresAt": "2026-06-15T09:00:00.000Z",
  "login": "admin"
}
```

Ошибки: `401 INVALID_CREDENTIALS`.

Пользователь по умолчанию создаётся миграцией `sql/009_admin_panel_and_one_c_create.sql` (пароль сменить на проде).

### POST /api/admin/auth/logout

Заголовок: `Authorization: Bearer <admin accessToken>`.

### GET /api/admin/auth/me

Профиль администратора: `id`, `login`, `createdAt`.

### GET /api/admin/users

Список учётных записей админ-панели (без паролей). Требуется admin JWT.

Query: `limit` (1–200, по умолчанию 50), `offset`.

Успех: `{ "items": [{ "id", "login", "createdAt" }], "total", "limit", "offset" }`.

### POST /api/admin/users

Создать администратора. Требуется admin JWT.

Тело: `{ "login": "manager", "password": "******" }` (пароль ≥ 6 символов).

Успех: `201`, `{ "item": { "id", "login", "createdAt" } }`.

Ошибки: `409 LOGIN_ALREADY_EXISTS`, `400 VALIDATION_ERROR`.

### DELETE /api/admin/users/:id

Удалить администратора. Нельзя удалить себя или последнего администратора.

### GET /api/admin/organizations

Список организаций, зарегистрированных из 1С (`POST /api/integration/organizations`). **Только просмотр**, пароли не отдаются.

Заголовок: `Authorization: Bearer <admin accessToken>`.

Query:

| Параметр | Описание |
|----------|----------|
| `limit` | 1–200, по умолчанию 50 |
| `offset` | смещение, по умолчанию 0 |
| `q` | поиск по login, companyName, inn, id_1c, phone (подстрока) |
| `includeDeleted` | `true` / `1` — включить мягко удалённые |

Успех:

```json
{
  "items": [
    {
      "id": 10,
      "id_1c": "org-001",
      "login": "mail@org.ru",
      "role": "user",
      "orgType": "ООО",
      "companyName": "ООО Ромашка",
      "inn": "7701234567",
      "phone": "+79990000000",
      "createdAt": "2026-04-27T07:00:00.000Z",
      "updatedAt": "2026-04-27T07:00:00.000Z",
      "deletedAt": null
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

Ошибки: `401 UNAUTHORIZED`.

### GET /api/admin/organizations/:id

Карточка одной организации (те же поля, что в элементе `items` списка). Ошибки: `400`, `401`, `404 NOT_FOUND`.

### GET /api/admin/settings/one-c-request-create

Текущие настройки **исходящих** вызовов в 1С: создание заявки и обновление файлов.

```json
{
  "oneCRequestCreateUrl": "https://1c.example/hs/MobileAppIntegration/customs-requests",
  "oneCRequestUpdateUrl": "https://1c.example/hs/MobileAppIntegration/customs-requests/files",
  "oneCRequestUpdateUrlEffective": "https://1c.example/hs/MobileAppIntegration/customs-requests/files",
  "oneCRequestCreateBearerToken": "secret-token",
  "oneCRequestCreateBearerTokenMasked": "…abcd",
  "hasBearerToken": true,
  "updatedAt": "2026-05-16T12:00:00.000Z"
}
```

`oneCRequestUpdateUrlEffective` — фактический URL update (явный или create + `/files`).

Полный `oneCRequestCreateBearerToken` отдаётся только в этом GET под admin JWT (для подстановки в форму). Маска `oneCRequestCreateBearerTokenMasked` сохранена для совместимости.

### PUT /api/admin/settings/one-c-request-create

Задать URL и Bearer-токен. Bearer общий для создания и обновления файлов.

```json
{
  "oneCRequestCreateUrl": "https://1c.example/hs/MobileAppIntegration/customs-requests",
  "oneCRequestUpdateUrl": "https://1c.example/hs/MobileAppIntegration/customs-requests/files",
  "oneCRequestCreateBearerToken": "secret-token"
}
```

- `oneCRequestCreateUrl` — обязательно, только `http`/`https`.
- `oneCRequestUpdateUrl` — опционально; если пусто, сервер использует `oneCRequestCreateUrl` + `/files`.
- `oneCRequestCreateBearerToken` — опционально в теле: если не передан или пустая строка, на сервере остаётся ранее сохранённый токен; при первой настройке (токена ещё нет) — обязателен. Повторная отправка того же значения принимается. В админке поле токена обязательно к заполнению; при открытии страницы значение подставляется из GET.

### GET /api/admin/customs-requests

Список заявок для админки. Сортировка: сначала **`new`**, затем с **`oneCUpdatePending: true`**, затем по убыванию `id`.

### GET /api/admin/customs-requests/:id

Деталка заявки для админки (полный camelCase-контракт, включая `files[]`).

В каждом элементе: **`oneCUpdatePending`** (boolean) — последний исходящий update в 1С не доставлен (нужна кнопка повтора).

Query: `limit` (1–200, по умолчанию 50), `offset`, `status`.

Успех: `{ "items": [...], "total", "limit", "offset" }` — элементы в том же camelCase-контракте, что и `GET /api/customs-requests`.

### POST /api/admin/customs-requests/:id/resend-to-1c

Повторная отправка заявки в 1С, если после создания осталась в **`new`** и ещё нет `external1cId`. Требуется admin JWT.

Успех: `ok`, `oneC`, `item` (заявка после возможного перевода в `in_progress`).

Ошибки:

- `404 NOT_FOUND`
- `409 CONFLICT` — не `new` или уже есть `external1cId`
- `502 ONE_C_CREATE_FAILED` — в теле поле `oneC`: `httpStatus`, `responseBody` (ответ 1С или фрагмент), `oneCMessage`, `code`
- `503 ONE_C_URL_NOT_CONFIGURED`

При успехе в `oneC` также есть `response` — тело успешного ответа 1С (в debug админка пишет его в консоль, фильтр `1C`, из ответа `POST …/resend-to-1c`).

### POST /api/admin/customs-requests/:id/resend-update-to-1c

Повторная отправка **последнего снимка заявки** в 1С (update), если после изменений с нашей стороны 1С не ответила. Требуется admin JWT.

Условия:

- есть `external1cId`;
- `oneCUpdatePending === true`.

Тело запроса: `{}`. Отправляется полный payload (как в исходящем update: зеркало `state` + `requestId` + `files`).

Успех: `ok`, `oneC`, `item` (с `oneCUpdatePending: false`).

Ошибки:

- `404 NOT_FOUND`
- `409 CONFLICT` — нет `external1cId` или нет неотправленных изменений
- `502 ONE_C_UPDATE_FAILED` — в теле `oneC` (как у create)
- `503 ONE_C_URL_NOT_CONFIGURED`

Флаг `oneCUpdatePending` выставляется при неудачной доставке update после загрузки файлов из МП (`POST /api/customs-requests/:id/files`). Входящий `state` от 1С **не** инициирует исходящий update (нет эха).

## Веб-админка (деплой)

Панель `import_service_admin` (Flutter Web) отдаётся **тем же Node-сервером**, что и API, как статика.

| | |
|---|---|
| URL (прод) | `https://157-22-173-7.sslip.io/admin/` |
| Редирект | `GET /admin` → `/admin/` |
| Каталог на сервере | `import_service_server/web/` (содержимое `build/web/`) |
| Переменная окружения | `ADMIN_WEB_ROOT` — другой путь (относительно `cwd` процесса Node или абсолютный) |

Неизвестные пути под `/admin/` (кроме существующих файлов) отдают `index.html` (SPA).

**Локальная разработка** (`flutter run -d chrome`): по умолчанию API — полный URL прод-сервера; origin страницы — `http://localhost:*`. На API включён CORS для `localhost` / `127.0.0.1` (см. `CORS_ORIGINS` в `.env` сервера). Прод-админка на том же хосте, что и `/api/`, CORS не требует.

### Сборка и выкладка

**Обязательно** base href `/admin/`:

```bash
cd import_service_admin
flutter build web --base-href=/admin/
```

Скопировать **всё** из `build/web/` в `import_service_server/web/` на машине, где крутится API.

Из корня монорепозитория (Windows):

```powershell
.\scripts\deploy-admin-web.ps1
```

Скрипт выполняет `flutter build web --base-href=/admin/` и копирует артефакты в `web/`.

После копирования файлов — **перезапуск** процесса Node (`npm start`, pm2 и т.д.).

Артефакты билда в git не коммитятся; в репозитории закоммичена заглушка `web/index.html`.

### Проверка

1. `GET https://157-22-173-7.sslip.io/admin/` — HTML (не 503).
2. В DevTools → Network: `main.dart.js`, `flutter_bootstrap.js` грузятся с префикса `/admin/`, не с `/`.

503 с текстом про отсутствие `index.html` — каталог пуст или билд не скопирован.

### Nginx (если перед Node)

Как для `/docs`: проксировать `/admin` на тот же upstream, что API. Иначе запросы не дойдут до Fastify.