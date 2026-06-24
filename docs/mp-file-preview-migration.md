# МП: previewUrl и лимиты файлов (миграция моделей)

Дата: 2026-05-29. Сервер: `import_service_server` после миграции `019_storage_preview_one_c_create.sql`.

## Что изменилось в API

### `files[]` в заявке (`GET /api/customs-requests/:id`, список в админке)

Каждый элемент:

| Поле | Тип | Описание |
|------|-----|----------|
| `fileUrl` | string | **Полный** файл (скачивание, PDF-viewer, видео) |
| `previewUrl` | string \| null | **Превью** JPEG (~1200px) для фото; для видео — poster (когда сервер добавит), иначе `null` |

Ответ upload (`POST /api/customs-requests/upload`) в `file` тоже содержит `previewUrl`.

### Лимиты размера

| Тип | Лимит |
|-----|-------|
| Фото, PDF, документы | **25 МБ** |
| Видео, аудио (`transit_archive_video`, mime `video/*`, `audio/*`) | **100 МБ** |

При превышении: `400 VALIDATION_ERROR` с текстом «файл больше N МБ».

### Исходящая синхронизация 1С (для справки)

В DTO заявки: `oneCCreatePending`, `oneCCreateHoursPending`, `oneCUpdatePending`, `oneCUpdateHoursPending`, `oneCOutboundStaleOver24h`. Автоповтор раз в час на сервере.

---

## Изменения в Flutter (import_service_app)

### 1. Модель `CustomsRequestFile`

```dart
final String? previewUrl;

String? get displayImageUrl {
  final p = previewUrl?.trim();
  if (p != null && p.isNotEmpty) return p;
  return fileUrl?.trim();
}
```

`fromJson`: читать `previewUrl` / `preview_url`.

### 2. Превью в UI

- **Списки, миниатюры 64×64, карусель превью** → `displayImageUrl` / `requestFileThumbnailUrl(file)`
- **Скачивание, Share, полноэкранное фото, PDF, видео** → `fileUrl` / `requestFileFullUrl(file)`

Уже сделано в репозитории:

- `lib/domain/entities/customs_request_file.dart`
- `lib/presentation/helpers/request_file_preview_helper.dart`
- `lib/presentation/pages/car_request_detail_page.dart` (миниатюра)

Проверить остальные `Image.network` по файлам заявки — везде для превью использовать `displayImageUrl`, не `fileUrl`.

### 3. Валидация до upload (рекомендуется)

Перед `POST /upload`:

- фото/PDF: `<= 25 * 1024 * 1024`
- видео/аудио: `<= 100 * 1024 * 1024`

Показывать SnackBar на русском до отправки.

### 4. Удаление заявки

`DELETE /api/customs-requests/:id` из МП **отключён** (`403`). Удаление только в админке.

---

## Чеклист для разработчика МП

- [ ] `CustomsRequestFile.previewUrl` в модели и `fromJson`
- [ ] Превью в списках через `previewUrl ?? fileUrl`
- [ ] Скачивание только через `fileUrl`
- [ ] Лимиты 25/100 МБ на клиенте
- [ ] Убрать UI удаления заявки из МП (если был)

Промпт для агента МП (copy-paste): `import_service_app/.cursor/prompts/preview-url-photo-video.md`

Документация API: https://157-22-173-7.sslip.io/docs/integration и `/docs` (карточки upload, files[]).
