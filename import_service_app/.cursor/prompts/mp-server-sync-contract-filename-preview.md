# Промпт: синхронизация МП с сервером (contract_original, fileName, previewUrl)

Скопируй блок ниже в агент каталога `import_service_app/` (Composer, Agent mode).

```text
Задача: довести import_service_app до актуального контракта API сервера (прод: https://157-22-173-7.sslip.io).

Документация (обязательно прочитать):
- D:\Projects\import_servis\docs\catalog-reference.md — docType, contract_original vs contract
- D:\Projects\import_servis\docs\api-app.md — files[], upload, лимиты
- D:\Projects\import_servis\docs\contract-files-v2.md — батч upload, fileName
- D:\Projects\import_servis\docs\mp-file-preview-migration.md — previewUrl
- https://157-22-173-7.sslip.io/docs/ — вкладки «API приложения», «Справочники»

Что уже на сервере (не дублировать на бэкенде):
- previewUrl + fileUrl в files[] и ответе POST /api/customs-requests/upload
- Лимиты: фото/PDF/документы 25 МБ, видео/аудио 100 МБ
- contract_original — обязательный docType при создании заявки (contract — только пакет на подпись от 1С)
- files[].fileName — человекочитаемое имя с расширением (.pdf, .jpg, …)
- DELETE /api/customs-requests/:id из МП → 403 (удаление только админка)
- oneCCreatePending / oneCUpdatePending — информативные поля в DTO (бейджи опционально)

Частично уже сделано в МП (проверить и допилить, не переписывать с нуля):
- lib/domain/entities/customs_request_file.dart — previewUrl, fileName
- lib/data/models/customs_request_upload_result.dart — previewUrl
- lib/presentation/helpers/request_file_preview_helper.dart
- lib/core/utils/request_file_upload_validation.dart — лимиты размера
- lib/data/datasources/remote/customs_requests_remote_data_source.dart — парсинг upload

=== 1. contract_original (критично) ===

Сервер: customsCatalog.js
- requiredOnCreate: contract_original (НЕ contract)
- contract — category signing, оригинал из 1С в пакете на подпись

МП — lib/domain/entities/customs_doc_type.dart:
- Добавить enum value: contractOriginal('contract_original')
- requiredOnCreate: заменить contract на contractOriginal
- creationTypes: contractOriginal вместо contract в обязательных
- signingBaseTypes: contract остаётся (пакет на подпись)
- fromApiCode: поддержать contract_original

Пройти grep по проекту:
- docType: 'contract' при создании заявки → contract_original
- CustomsDocType.contract в формах create/upload → contractOriginal
- uploadTotal: пересчитать если завязан на список обязательных типов
- doc_type_labels / JsonStrings: подпись «Контракт экспортёра» для contract_original; contract — «Контракт (на подпись)»
- default_cars_seed.dart: в демо-заявке на create — docType contract_original

Обратная совместимость GET:
- Старые заявки могут иметь files[] с docType contract на этапе create — показывать в секции «Документы при создании», не ломать UI

=== 2. fileName с расширением ===

Сервер отдаёт fileName в:
- GET /api/customs-requests/:id → files[].fileName
- POST /api/customs-requests/upload → file.fileName

МП:
- После upload сохранять fileName из ответа (customs_requests_remote_data_source, репозиторий)
- В UI строк файлов: показывать fileName если есть (car_request_detail_page уже частично)
- При локальном upload передавать осмысленное имя в multipart filename (basename с расширением)
- Не показывать технические storedName (r12__passport_front.jpg) — isTechnicalRequestFileName

=== 3. previewUrl (доработка UI) ===

- Миниатюры фото: requestFileThumbnailUrl → previewUrl ?? fileUrl
- Видео transit_archive_video: не грузить fileUrl в Image.network; иконка play если previewUrl null
- Полный просмотр/скачивание/share: всегда fileUrl
- Проверить: car_request_detail_page, request_detail_files_sections, request_photo_row_field, карусель

=== 4. Валидация upload ===

request_file_upload_validation.dart:
- 25 МБ — фото, PDF, docType без video/audio
- 100 МБ — transit_archive_video, audio docType
- SnackBar на русском при превышении

=== 5. Убрать/скрыть ===

- UI удаления заявки пользователем (если есть) — сервер вернёт 403
- Не менять applicationId, не коммитить/push без явной просьбы

=== 6. Проверка ===

- flutter analyze без новых ошибок
- Сценарий create: upload contract_original с правильным docType в multipart
- Карточка: files[] с contract_original и позже contract + contract_sign в разных секциях
- fileName отображается с расширением (.pdf, .jpg)

Критерии готовности:
- Create upload использует contract_original
- contract в signing-секции — только из пакета 1С
- fileName из API в списках файлов
- Превью фото через previewUrl, полный файл через fileUrl
- Лимиты 25/100 МБ до отправки
```
