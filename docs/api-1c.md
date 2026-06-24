# API для интеграции с 1С

Параллельно: **`api-app.md`** — контракт ответов для мобильного клиента (заявки, чат, camelCase).

Базовый URL (прод):

- `https://157-22-173-7.sslip.io/api`

## Авторизация интеграции

Для методов 1С обязателен заголовок:

- `Authorization: Bearer <INTEGRATION_BEARER_TOKEN>`

## GET /api/customs-requests/files/:storedName

Скачать двоичное содержимое файла по имени из `fileUrl` в заявке (например `/api/customs-requests/files/<uuid>.jpg`). Заголовок такой же, как для остальных методов интеграции: `Authorization: Bearer <INTEGRATION_BEARER_TOKEN>`. Альтернатива — JWT пользователя после входа в приложение.

Ошибки:

- `401 UNAUTHORIZED` (нет заголовка, неверный интеграционный токен или неверный JWT)
- `404 NOT_FOUND`

## POST /api/integration/organizations

Создать или обновить **одну** организацию (upsert по `id_1c`) в таблице `organizations`.

Запрос:

```json
{
  "id_1c": "org-001",
  "login": "mail@org.ru",
  "password": "StrongPass123",
  "role": "user",
  "orgType": "ООО",
  "companyName": "ООО Ромашка",
  "inn": "7701234567",
  "phone": "+79990000000"
}
```

Поля:

- `id_1c` — идентификатор организации в 1С
- `login` — логин для авторизации (email)
- `password` — пароль (на backend хранится как bcrypt hash)
- `role` — `admin` или `user`
- `orgType` — только `ИП` или `ООО`
- `companyName` — ФИО (для `ИП`) или название (для `ООО`)
- `inn`, `phone` — обязательны

Успешный ответ:

```json
{
  "ok": true,
  "item": {
    "id": 10,
    "id_1c": "org-001",
    "login": "mail@org.ru",
    "role": "user",
    "orgType": "ООО",
    "companyName": "ООО Ромашка",
    "inn": "7701234567",
    "phone": "+79990000000",
    "created_at": "2026-04-27T07:00:00.000Z",
    "updated_at": "2026-04-27T07:00:00.000Z",
    "deleted_at": null
  }
}
```

Ошибки:

- `400 VALIDATION_ERROR`
- `401 INVALID_INTEGRATION_TOKEN`
- `500 INTERNAL_ERROR`

## Исходящее создание заявки в 1С (HTTP на стороне 1С)

После `POST /api/customs-requests` (приложение) backend **асинхронно** шлёт на URL из настроек админки (`PUT /api/admin/settings/one-c-request-create`) **тот же JSON**, что принял от клиента, плюс поле `requestId` (внутренний id в нашей БД).

Заголовок со стороны backend:

- `Content-Type: application/json`
- `Authorization: Bearer …` — токен из настроек админки (`PUT /api/admin/settings/one-c-request-create`), если задан.

Тело (camelCase, как в `api-app.md`):

| Поле | Описание |
|------|----------|
| `requestId` | number — id заявки у нас |
| `legalEntityName`, `legalEmail`, `legalPhone`, `legalInn` | данные организации из анкеты |
| `individualFullName`, `individualPhone`, `individualSnils` | … |
| `carMake`, `carModel`, `vin` | … |
| `hasSunroof`, `hasAllWheelDrive`, `importedLast12Months`, `ownsOtherCars` | boolean |
| `commentText` | string \| null |
| `isTest` | boolean |
| `files[]` | `docType`, `fileName`, `mimeType`, `fileUrl` — `fileUrl` при необходимости с `PUBLIC_BASE_URL` (в карточке МП также `previewUrl` для превью) |

**Ответ 1С** (успех, JSON):

```json
{
  "requestId": 123,
  "external1cId": "GUID-REQUEST-1C"
}
```

- `requestId` в ответе **необязателен**; если передан — должен совпадать с id отправленной заявки.
- При успехе backend ставит заявке `on_review` и сохраняет `external1cId`. Переход в `in_progress` — когда в `state` приходит менеджер. Остальные поля 1С передаёт через `POST /api/integration/customs-requests/state`.
- При ошибке HTTP/валидации заявка остаётся в `new`, ставится **`oneCCreatePending`**; автоповтор раз в час; ручной повтор — `POST /api/admin/customs-requests/:id/resend-to-1c` (admin JWT).

Этот URL **только** для создания заявки в 1С, не для чата и не для `state`.

## POST /api/integration/customs-requests/state

**Назначение:** 1С передаёт на наш backend изменения по заявке (статус, подстатус, тип сделки, менеджер, суммы, ссылки).  
**Направление:** 1С → `https://157-22-173-7.sslip.io/api/integration/customs-requests/state` (команда 1С реализует HTTP-клиент; URL фиксированный).

Заголовок: `Authorization: Bearer <INTEGRATION_BEARER_TOKEN>`

Тело: JSON, **частичное обновление** (только изменённые поля). Обязательно: `external1cId`.

### Справочник `status` (верхний уровень)

| Код | Когда |
|-----|--------|
| `new` | На нашей стороне до ответа 1С на создание (1С обычно не шлёт) |
| `on_review` | Есть `external1cId`, менеджера ещё нет |
| `in_progress` | Назначен менеджер; **здесь же передаётся `dealType`** |
| `in_transit` | Транзит / СВХ |
| `delivered` | Этапы после прибытия |
| `closed` | Заявка закрыта |
| `cancelled` | Отменена |

### Справочник `dealType` (тип сделки, enum)

Задаётся **менеджером один раз** при переводе заявки в работу (`in_progress`). Определяет состав первичного пакета на подпись.

| Код | Название | Документы пакета (`docType`) |
|-----|----------|------------------------------|
| `bilateral` | Двухсторонняя сделка | `recycling_fee_calc`, `kuts`, `explanatory_note`, `customs_rep_agreement`, `funds_transfer_application`, `passport_notarized_copy`, `contract` |
| `cash` | Наличный расчёт | Как `bilateral`, **без** `funds_transfer_application`; + `receipt`, `additional_agreement` |
| `tripartite` | Трёхсторонняя сделка | Как `bilateral` + `tripartite_agreement` |
| `quadripartite` | Четырёхсторонняя сделка | Как `bilateral` + `quadripartite_agreement` |

**Не выгружаются из 1С в МП** (клиент загружает только подпись `*_sign`): `funds_transfer_application`, `passport_notarized_copy`.

`funds_transfer_application` — **«Заявление на перевод»** (перевод остатков средств после растаможивания), не перевоз автомобиля.

### Справочник `statusSubType` (подстатус)

1С передаёт **машинный код** (не произвольный текст). Полная таблица код ↔ подпись из 1С: **[catalog-reference.md](catalog-reference.md)**.

| Группа 1С | Коды (примеры) | Рекомендуемый `status` |
|-----------|----------------|------------------------|
| На проверке | `draft` | `on_review` |
| В работе | `manager_execution`, `primary_documents_sent`, `originals_partial_no_transit`, `originals_complete_no_transit` | `in_progress` |
| В пути | `originals_missing_transit`, `originals_partial_transit`, `originals_complete_transit` | `in_transit` |
| Доставлено | `svh_*`, `ptd_*`, `sent_to_lab`, `issued_to_client` | `delivered` |
| Закрытие | `request_closed` | `closed` |

**Переподпись** (неверная подпись/печать): `signature_revision_required` — клиент загружает новые `*_sign`.

**Алиас:** `manager_assigned` → `manager_execution`.

### Подпись: два файла на позицию

| Версия | `docType` | Кто кладёт |
|--------|-----------|------------|
| Оригинал | `contract` (без суффикса) | 1С → сервер → МП (скачать) |
| Подписанный | `contract_sign` (суффикс `_sign`) | МП → сервер → 1С |

То же для каждого документа пакета: `kuts` / `kuts_sign`, `customs_rep_agreement` / `customs_rep_agreement_sign`, и т.д.

### Загрузка файлов (1С и МП): `upload`

`POST /api/customs-requests/upload`:

- **МП** — `multipart/form-data`: `requestId`, `docType`, `file`, `uploadIndex`, `uploadTotal`.
- **1С** — **`application/json` + base64** (рекомендуется): `external1cId`, `docType`, `fileBase64`, `uploadIndex`, `uploadTotal`, опционально `mimeType`, `fileName`. Auth: только `INTEGRATION_BEARER_TOKEN`.

**Лимиты:** фото/PDF — **25 МБ**; видео/аудио — **100 МБ** (после декодирования base64 для JSON).

Auth: 1С — `INTEGRATION_BEARER_TOKEN`, МП — `accessToken`.

Ответ:

```json
{
  "ok": true,
  "batchComplete": true,
  "file": {
    "docType": "contract",
    "mimeType": "application/pdf",
    "fileSizeBytes": 12345,
    "fileUrl": "/api/customs-requests/files/GUID__contract.pdf",
    "previewUrl": null,
    "replaced": false
  }
}
```

Для фото `previewUrl` — URL JPEG-превью; 1С в исходящих update использует только `fileUrl`.

**После `uploadIndex === uploadTotal`:**

| Источник | Действие сервера |
|----------|------------------|
| 1С | Push в МП (`request_files_update`, `changedDocTypes`) |
| МП, заявка `new` | Create в 1С → `external1cId` → переименование файлов |
| МП, есть `external1cId` | Update в 1С с изменёнными `docType` |

**Метаданные** (статус, менеджер, суммы) — отдельно `POST /api/integration/customs-requests/state`.

Подробнее: **`docs/contract-files-v2.md`**.

### Поля тела `state` (метаданные заявки)

| Поле | Тип | Описание |
|------|-----|----------|
| `external1cId` | string | **Обязательно** |
| `status` | string | См. enum выше |
| `statusSubType` | string | Подстатус 1С |
| `statusSubTypeDateTime` | string | ISO-8601 |
| `dealType` | string | `bilateral` \| `cash` \| `tripartite` \| `quadripartite` |
| `ownerFullName` | string | Владелец в карточке |
| `carMake`, `carModel`, `vin` | string | Авто |
| `engineSpec`, `engineVolume` | string | Двигатель |
| `advancePayment` | string/number | Аванс, рубли |
| `actualPayment` | string/number | Факт, рубли |
| `managerExternal1cId` | string | GUID менеджера |
| `managerFullName` | string | ФИО для МП |

Частичное обновление: передаются только изменившиеся поля. Файлы в `state` **не** передаются — только через `upload`.

### Upload (1С)

`POST /api/customs-requests/upload` — multipart: `external1cId`, `docType`, `file`, `uploadIndex`, `uploadTotal` (см. contract-files-v2.md).

Пример запроса (назначение менеджера + тип сделки):

```json
{
  "external1cId": "GUID-REQUEST-1C",
  "status": "in_progress",
  "dealType": "tripartite",
  "statusSubType": "manager_execution",
  "statusSubTypeDateTime": "2026-05-27T10:00:00+03:00",
  "managerExternal1cId": "GUID-MANAGER-1C",
  "managerFullName": "Иванов Иван Иванович"
}
```

Пример возврата на переподпись:

```json
{
  "external1cId": "GUID-REQUEST-1C",
  "statusSubType": "signature_revision_required",
  "statusSubTypeDateTime": "2026-05-28T14:30:00+03:00"
}
```

Успех:

```json
{ "ok": true, "item": { "id": "123", "status": "in_progress", "dealType": "tripartite", "files": [] } }
```

Ошибки: `400 VALIDATION_ERROR` (пустой body полей, нет `external1cId`), `401`, `404` (заявка с таким `external1cId` не найдена).

**Ответ сервера (`item`):** полная карточка для МП, включая `advancePayment`, `actualPayment` и вычисленное **`refundAmount`** (`advance − actual`, только в ответе — 1С не шлёт).

## Исходящий update файлов в 1С

Сервер вызывает **отдельный** HTTP-роут 1С после загрузок из МП (подписи, чеки и т.д.).

**Настройки админки:** `GET/PUT /api/admin/settings/one-c-request-create`

| Поле | Назначение |
|------|------------|
| `oneCRequestCreateUrl` | Создание заявки в 1С |
| `oneCRequestUpdateUrl` | Обновление файлов (опционально) |
| `oneCRequestCreateBearerToken` | Bearer для обоих вызовов |

**URL обновления файлов:**

1. Если задан `oneCRequestUpdateUrl` — используется он.
2. Иначе к `oneCRequestCreateUrl` добавляется суффикс **`/files`**.

Пример: create `https://1c.example/hs/MobileAppIntegration/customs-requests` → update `…/customs-requests/files`.

На стороне 1С — **два отдельных роута**: создание заявки и приём файлов, без смешивания в одном обработчике.

### Тело запроса (сервер → 1С)

```json
{
  "requestId": 123,
  "external1cId": "GUID-REQUEST-1C",
  "files": [
    {
      "docType": "contract_sign",
      "fileName": "contract_sign.pdf",
      "mimeType": "application/pdf",
      "fileUrl": "https://157-22-173-7.sslip.io/api/customs-requests/files/GUID__contract_sign.pdf"
    }
  ]
}
```

- `files[]` — только **новые или изменённые** файлы от клиента (подписи, чеки, доп. документы).
- Статусы и суммы 1С получает **входящим** `state` (1С → сервер), не через update.

Минимально: `external1cId` + непустой `files[]`.

## POST /api/integration/customs-requests/purge-test

**Жёсткое удаление** из БД всех заявок с флагом теста (`is_test = 1`), помеченных с приложения (`isTest: true` в `POST /api/customs-requests`).

- Заголовок: `Authorization: Bearer <INTEGRATION_BEARER_TOKEN>`
- Тело: **не** требуется

Успех:

```json
{ "ok": true, "deletedRows": 12 }
```

Каскадно удаляются связанные файлы/сообщения (FK). Файлы на диске в `uploads/` по старым путям при необходимости подчистить отдельно, если важен объём.

Ошибки: `401` — неверный Bearer.

## Справочник `docType` (все типы файлов заявки)

Полный перечень с этапами и матрицей по `dealType`: **[catalog-reference.md](catalog-reference.md)**.

Кратко:

- **Создание:** `passport_front`, `passport_registration`, `inn`, `snils`, `invoice`, **`contract_original`**, `payment_check`, `car_nameplate_photo`, `car_mileage_photo`, `car_front_photo`, `car_back_photo`; опционально `add_doc1`, `add_doc2`. Пакет на подпись — отдельный **`contract`**.
- **Подпись:** оригинал `docType` + подпись `docType_sign` (см. пакет по `dealType` выше).
- **Оплаты:** `payment_recycling_fee`, `payment_recycling_fee_receipt`, `payment_customs_duty`, `payment_customs_duty_receipt`.
- **Итог:** `epts`, `sbkts`.
- **Архив транзита:** `transit_archive_photo_1`, …, `transit_archive_video`.

Полные таблицы: `docs/catalog-reference.md`, вкладка **Справочники** на `/docs`.

## POST /api/integration/customs-request-messages

Сообщение от менеджера/1С в чат по заявке. Дедупликация по `message1cId` (уникальный id сообщения в 1С).

Запрос:

```json
{
  "external1cId": "GUID-REQUEST-1C",
  "message1cId": "GUID-MSG-1C-0001",
  "text": "Добрый день! Уточните, пожалуйста, VIN",
  "sender1cId": "u-manager-001",
  "senderName": "Иванов И.И.",
  "attachments": [
    {
      "fileUrl": "https://example.com/a.pdf",
      "fileName": "a.pdf",
      "mimeType": "application/pdf"
    }
  ]
}
```

Успешный ответ:

```json
{
  "ok": true,
  "id": 9001,
  "requestId": 123,
  "message": {
    "id": 9001,
    "message_1c_id": "GUID-MSG-1C-0001"
  }
}
```

Ошибки:

- `400 VALIDATION_ERROR`
- `401 INVALID_INTEGRATION_TOKEN`
- `404 NOT_FOUND` - заявка с `external1cId` не найдена

## Правила интеграции организаций

- Один вызов = одна организация (upsert по `id_1c`).
- Логин (`login`) используется приложением для входа (email).
- Пароль в БД хранится только в виде bcrypt hash.
- Поддерживается поле `role` (`admin`/`user`), по умолчанию `user`.
- Каждый вызов сохраняется в `integration_logs` (статус и метрики).
