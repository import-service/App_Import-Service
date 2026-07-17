# Контракт файлов (Import Service)

**Статус:** действующий для сервера, 1С, МП.
## Принцип

| Канал | Назначение |
|-------|------------|
| **`POST /api/customs-requests/upload`** | Все файлы (1С и МП) |
| **`POST /api/integration/customs-requests/state`** | Только метаданные заявки (без файлов) |
| **URL обновления файлов** (сервер → 1С) | Файлы, загруженные из МП (`oneCRequestUpdateUrl` или create + `/files`) |
| **`GET /api/customs-requests/:id`** | Карточка с единым массивом **`files[]`** |

Push в МП: **метаданные** — после `state`; **файлы** — после завершения батча upload (`uploadIndex === uploadTotal`), тип `request_files_update`, поле `changedDocTypes`.

---

## Upload (multipart)

### 1С

| Поле | Обяз. | Описание |
|------|-------|----------|
| `external1cId` | да | Id заявки в 1С |
| `docType` | да | Код документа |
| `file` | да | Файл |
| `uploadIndex` | да | Номер в пачке, с 1 |
| `uploadTotal` | да | Размер пачки (1 для одного файла) |

### МП

| Поле | Обяз. | Описание |
|------|-------|----------|
| `requestId` | да | Id заявки на сервере |
| `docType` | да | Код документа |
| `file` | да | Файл |
| `uploadIndex` | да | С 1 |
| `uploadTotal` | да | Задаёт МП (11 обязательных + опционально `add_doc1`, `add_doc2`) |

**Auth:** 1С — `INTEGRATION_BEARER_TOKEN`, МП — `accessToken`.

**Лимиты:** фото/PDF/документы — **25 МБ**; видео/аудио — **100 МБ** (по `docType` и mime).

**Ответ:**

```json
{
  "ok": true,
  "batchComplete": true,
  "file": {
    "docType": "contract_original",
    "fileName": "contract-export.pdf",
    "mimeType": "application/pdf",
    "fileSizeBytes": 12345,
    "fileUrl": "/api/customs-requests/files/GUID__contract_original.pdf",
    "previewUrl": "/api/customs-requests/files/GUID__car_front_photo_preview.jpg",
    "replaced": false
  }
}
```

**`fileName`:** человекочитаемое имя с расширением в `files[]` и ответе upload; в 1С уходит в create/update. Multipart: имя из поля `file`; JSON 1С: поле `fileName`.

В `files[]` также: `sourceFileName`, `sourceMimeType` (как пришло в upload до детекта), `uploadSource` (`integration`|`user`|`demo`), `storedName`.

**Имя на диске:** `{external1cId}__{docType}.{ext}` (до GUID — `r{requestId}__{docType}.{ext}`). Re-upload перезаписывает по той же паре. Для фото дополнительно `{key}__{docType}_preview.jpg`.

**Архивы RAR/ZIP при upload:** сервер **разворачивает** архив и сохраняет **все** картинки/PDF внутри как отдельные файлы (до 50). Для слота `X` файлы получают `docType` `X_1`, `X_2`, … (если внутри один файл — остаётся `X`). Сам архив не хранится. У всех развёрнутых файлов `sourceFileName` = имя архива — по нему МП показывает их списком по номерам, а админка группирует их в один вход с каруселью. Office ZIP (docx и т.п.) не распаковывается.

**`fileUrl` vs `previewUrl`:** полный файл и JPEG-превью (~1200px) для списков МП. 1С в create/update по-прежнему получает только **`fileUrl`**.

**Хранение:** бинарники на сервере (`uploads/customs-requests/`). Автоудаление только заявок **`closed`** старше **6 месяцев** (настраивается в админке). Ручное удаление — админка.

**Несколько файлов одного типа:** `transit_archive_photo_1`, `transit_archive_photo_2`, …

### После последнего файла батча

| Источник | Действие сервера |
|----------|------------------|
| 1С | Push в МП (`request_files_update`, `changedDocTypes`) |
| МП, заявка `new` | Create в 1С → `external1cId` → переименование файлов → update URL в 1С; при ошибке — `oneCCreatePending`, автоповтор раз в час |
| МП, заявка с `external1cId` | Update в 1С только изменённые `docType`; при ошибке — `oneCUpdatePending`, автоповтор раз в час |

---

## State (1С → сервер), только метаданные

```json
{
  "external1cId": "GUID",
  "status": "in_progress",
  "statusSubType": "manager_execution",
  "statusSubTypeDateTime": "2026-05-27T10:00:00+03:00",
  "dealType": "tripartite",
  "ownerFullName": "…",
  "carMake": "TOYOTA",
  "carModel": "Camry",
  "vin": "…",
  "engineSpec": "…",
  "engineVolume": "…",
  "advancePayment": "830998.00",
  "actualPayment": "750000.00",
  "managerExternal1cId": "GUID",
  "managerFullName": "…"
}
```

**Суммы:** строка/число в рублях. В ответе API: `advancePayment`, `actualPayment`, `refundAmount` (строки; `refundAmount` считает сервер).

**Порядок 1С:** N×`upload` → при смене статуса/менеджера/сумм — `state`.

---

## Создание заявки из МП

1. `POST /api/customs-requests` — только поля формы, **без** `files[]`.
2. N×`upload` с `requestId`, `uploadIndex`, `uploadTotal`.
3. После `uploadTotal/uploadTotal` — сервер создаёт заявку в 1С, получает `external1cId`, переименовывает файлы.

---

## Особые docType

| docType | 1С → МП (upload) | МП → 1С |
|---------|------------------|---------|
| Обычные (`contract`, `kuts`, …) | да | `*_sign` |
| `funds_transfer_application`, `passport_notarized_copy` | нет | только `*_sign` |
| Квитанции, фото, ЭПТС | да, как файл с `docType` | чеки `*_receipt` |

Переподпись: 1С re-upload оригинала + `state` с `signature_revision_required`; клиент upload нового `*_sign`.

---

## Push (МП)

| type | Когда |
|------|--------|
| `request_update` | После `state` |
| `request_files_update` | После батча upload от 1С |
| `new_message` | Чат |

Для `request_files_update`: в `data` — `changedDocTypes` (через запятую). МП делает `GET /customs-requests/:id` и обновляет UI.
