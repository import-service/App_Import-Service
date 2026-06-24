# Промпт: previewUrl для фото и видео в МП

Скопируй блок ниже в агент каталога `import_service_app/` (Composer, Agent mode).

```text
Задача: довести поддержку previewUrl в мобильном приложении import_service_app.

Контекст API (уже на проде):
- В files[] заявки и в ответе POST /api/customs-requests/upload каждый файл содержит:
  - fileUrl — полный файл (скачивание, PDF-viewer, воспроизведение видео)
  - previewUrl — JPEG-превью (~1200px) для фото; для видео пока может быть null (poster на сервере — следующий этап)
- Лимиты upload: фото/PDF/документы 25 МБ, видео/аудио 100 МБ
- DELETE /api/customs-requests/:id из МП возвращает 403 — убрать UI удаления заявки, если есть

Документация:
- D:\Projects\import_servis\docs\mp-file-preview-migration.md
- https://157-22-173-7.sslip.io/docs/ (карточки upload, files[])

Частично уже сделано (не дублировать, проверить и допилить):
- lib/domain/entities/customs_request_file.dart — previewUrl, displayImageUrl
- lib/presentation/helpers/request_file_preview_helper.dart — requestFileThumbnailUrl, requestFileFullUrl
- lib/presentation/pages/car_request_detail_page.dart — миниатюра 64×64 через requestFileThumbnailUrl

Что нужно сделать:

1) Модель и парсинг
- CustomsRequestFile: поле previewUrl (fromJson previewUrl / preview_url)
- CustomsRequestUploadResult (если есть): previewUrl из ответа upload
- Локальный кэш/репозиторий после upload: сохранять previewUrl вместе с fileUrl
- default_cars_seed / моки: для фото добавить previewUrl (можно тот же URL в демо)

2) Хелперы (request_file_preview_helper.dart)
- isRequestFileVideo(file) — mime video/* или docType transit_archive_video / *_video
- requestFileThumbnailUrl(file):
  - фото: previewUrl ?? fileUrl
  - видео: previewUrl если есть (poster), иначе null (показать иконку play, не грузить полное видео в Image.network)
- requestFileFullUrl(file) — всегда fileUrl (скачивание, плеер, share, PDF)

3) UI — везде разделить превью и полный файл
Пройти grep по Image.network и fileUrl в lib/presentation/:
- Списки файлов, миниатюры, карусель превью → requestFileThumbnailUrl / displayImageUrl
- Открытие файла, downloadAuthenticatedRequestFile, share, полноэкранное фото, video player → requestFileFullUrl / fileUrl
Файлы для проверки:
- car_request_detail_page.dart (карусель _openImageCarousel — превью в сетке, полный при зуме)
- request_detail_files_sections.dart, request_detail_photo_urls_row.dart
- request_photo_row_field.dart
- widgets/requests/* по файлам заявки

4) Видео (transit_archive_video)
- В строке файла: если isRequestFileVideo и нет previewUrl — Container с иконкой Icons.videocam / play_circle
- По тапу — открыть/скачать по fileUrl (как сейчас для видео)
- Когда сервер начнёт отдавать previewUrl для видео (poster) — автоматически показывать Image.network(previewUrl) без смены контракта

5) Валидация размера до upload
- Перед multipart upload: max 25 МБ для фото/PDF, 100 МБ для video/audio docType
- SnackBar на русском при превышении (AppFeedbackService / AppSnackBars проекта)

6) Проверка
- flutter analyze без новых ошибок
- Не менять applicationId, не коммитить без просьбы пользователя

Критерии готовности:
- Все миниатюры фото грузят previewUrl (меньше трафика)
- Видео не тянет 100 МБ в Image.network для превью
- Скачивание и просмотр всегда по fileUrl
- upload response учитывает previewUrl
```
