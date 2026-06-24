# Справочники заявки (1С ↔ сервер ↔ МП)

Источник кодов на сервере: `import_service_server/src/constants/customsCatalog.js`.  
Файлы везде — `POST /api/customs-requests/upload` + единый массив `files[]` в карточке.

---

## Подстатусы (`statusSubType`)

Передаются в `POST /api/integration/customs-requests/state`.

### На проверке → `on_review`

| Код | Название в 1С |
|-----|----------------|
| `draft` | Черновик |

### В работе → `in_progress`

| Код | Название в 1С |
|-----|----------------|
| `manager_execution` | На исполнении у менеджера |
| `primary_documents_sent` | Отправлены первичные документы |
| `originals_partial_no_transit` | Получены оригиналы (не все документы), нет транзита |
| `originals_complete_no_transit` | Получены оригиналы (все документы), нет транзита |
| `signature_revision_required` | Требуется переподпись документов |

### В пути → `in_transit`

| Код | Названение в 1С |
|-----|----------------|
| `originals_missing_transit` | Оригиналы отсутствуют, есть транзит |
| `originals_partial_transit` | Получены оригиналы (не все документы), есть транзит |
| `originals_complete_transit` | Получены оригиналы (все документы), есть транзит |

### Доставлено → `delivered` / `closed`

| Код | Название в 1С | status |
|-----|----------------|--------|
| `svh_no_originals_no_recycling` | Авто на СВХ, оригиналы отсутствуют, нет утиля | `delivered` |
| `svh_partial_docs_no_recycling` | Авто на СВХ, не все документы, нет утиля | `delivered` |
| `svh_no_originals_recycling` | Авто на СВХ, оригиналы отсутствуют, есть утиль | `delivered` |
| `svh_partial_docs_recycling` | Авто на СВХ, не все документы, есть утиль | `delivered` |
| `svh_all_docs_no_recycling` | Авто на СВХ, все документы, нет утиля | `delivered` |
| `svh_all_docs_recycling` | Авто на СВХ, все документы, есть утиль | `delivered` |
| `ptd_submitted` | Подана ПТД | `delivered` |
| `ptd_submitted_paid` | Подана ПТД с оплатой | `delivered` |
| `ptd_release` | Выпуск ПТД | `delivered` |
| `sent_to_lab` | Направлено в лабораторию | `delivered` |
| `issued_to_client` | Выдано клиенту | `delivered` |
| `request_closed` | Заявка закрыта | `closed` |

**Алиас подстатуса:** `manager_assigned` → `manager_execution`.

---

## Типы документов (`docType`)

### 1. Создание заявки (МП → upload)

Обязательные при первичной подаче (`uploadTotal` включает все обязательные `docType`).

| docType | Что это | Обязательно |
|---------|---------|:-----------:|
| `passport_front` | Фото паспорта: лицевая сторона | Да |
| `passport_registration` | Фото паспорта: страница с пропиской | Да |
| `inn` | Фото/скан ИНН | Да |
| `snils` | Фото/скан СНИЛС | Да |
| `invoice` | Инвойс на автомобиль | Да |
| `contract_original` | Контракт экспортёра (оригинал при создании) | Да |
| `payment_check` | Чек/подтверждение оплаты за авто | Да |
| `car_nameplate_photo` | Фото шильдика / VIN-таблички | Да |
| `car_mileage_photo` | Фото пробега (одометр) | Да |
| `car_front_photo` | Фото автомобиля спереди | Да |
| `car_back_photo` | Фото автомобиля сзади | Да |
| `add_doc1` | Дополнительный документ №1 | Нет |
| `add_doc2` | Дополнительный документ №2 | Нет |

---

### 2. Пакет на подпись (1С → upload оригинал; МП → upload `*_sign`)

Состав зависит от `dealType`. Для каждой позиции — **два** `docType`: оригинал и `{docType}_sign`.

| docType | Что это | bilateral | cash | tripartite | quadripartite | Оригинал из 1С в МП |
|---------|---------|:---------:|:----:|:----------:|:-------------:|:-------------------:|
| `recycling_fee_calc` | Расчёт утилизационного сбора | ✓ | ✓ | ✓ | ✓ | Да |
| `kuts` | КУТС | ✓ | ✓ | ✓ | ✓ | Да |
| `explanatory_note` | Пояснительная записка | ✓ | ✓ | ✓ | ✓ | Да |
| `customs_rep_agreement` | Договор таможенного представителя | ✓ | ✓ | ✓ | ✓ | Да |
| `contract` | Контракт (пакет на подпись от менеджера; отдельно от `contract_original` при создании) | ✓ | ✓ | ✓ | ✓ | Да |
| `funds_transfer_application` | Заявление на перевод остатков после растаможивания | ✓ | — | ✓ | ✓ | **Нет** (только `*_sign` с МП) |
| `passport_notarized_copy` | Паспорт, нотариальная копия | ✓ | ✓ | ✓ | ✓ | **Нет** (только `*_sign` с МП) |
| `receipt` | Расписка | — | ✓ | — | — | Да |
| `additional_agreement` | Дополнительное соглашение | — | ✓ | — | — | Да |
| `tripartite_agreement` | Трёхсторонний договор | — | — | ✓ | — | Да |
| `quadripartite_agreement` | Четырёхсторонний договор | — | — | — | ✓ | Да |

**Подпись клиента:** для каждого оригинала из таблицы (кроме строк «только *_sign») — `docType_sign`, например `contract_sign`, `kuts_sign`.

---

### 3. Оплаты (upload)

| docType | Что это | Кто upload | Кто видит в МП |
|---------|---------|------------|----------------|
| `payment_recycling_fee` | Квитанция утилизационного сбора | 1С | МП (скачать) |
| `payment_recycling_fee_receipt` | Чек об оплате утилизационного сбора | МП | 1С (через update) |
| `payment_customs_duty` | Квитанция госпошлины | 1С | МП (скачать) |
| `payment_customs_duty_receipt` | Чек об оплате госпошлины | МП | 1С (через update) |

---

### 4. Архив перед транзитом (1С → upload, только скачивание в МП)

| docType | Что это | Обязательно |
|---------|---------|:-----------:|
| `transit_archive_photo_1` | Фото состояния авто №1 | По процессу 1С |
| `transit_archive_photo_2` | Фото №2 | Нет |
| `transit_archive_photo_3` | … | Нет |
| `transit_archive_video` | Видео перед транзитом | По процессу 1С |

При нескольких фото: `transit_archive_photo_1`, `transit_archive_photo_2`, … (суффикс `_1`, `_2`).

---

### 5. Итоговые документы (1С → upload, только скачивание в МП)

| docType | Что это |
|---------|---------|
| `epts` | ЭПТС |
| `sbkts` | СБКТС |

---

## Тип сделки (`dealType`)

| Код | Название |
|-----|----------|
| `bilateral` | Двухсторонняя сделка |
| `cash` | Наличный расчёт |
| `tripartite` | Трёхсторонняя сделка |
| `quadripartite` | Четырёхсторонняя сделка |

Задаётся **один раз** в `state` при переводе в `in_progress`.

---

## Правило `_sign`

| Версия | docType | Источник |
|--------|---------|----------|
| Оригинал | `contract`, `kuts`, … | 1С → upload |
| Подписанный | `contract_sign`, `kuts_sign`, … | МП → upload → update в 1С |

Re-upload по тому же `docType` перезаписывает файл. При браке подписи: `state.statusSubType = signature_revision_required`, клиент загружает новый `*_sign`.
