# Devin Rules — Flutter шаблон

Файлы в `.devin/rules/` подхватываются Devin CLI для этого репозитория (`trigger` frontmatter: `always_on` / `glob` / `model_decision`).

**Исходный шаблон (DigitalSquare):** `D:\Projects\_my_template\digitalsquare` — тот же каркас и дух правил; этот репо развивается от него, при синхронизации правок можно сверяться с путём выше. Шаблон пока хранит правила в `.cursor/rules/` (`.mdc`).

## Зафиксированный стек
**Clean Architecture (классические слои)** + **flutter_bloc** + **GetIt** + **go_router** + **Dio**. Другие стеки в этих правилах не рассматриваются.

## Правила
| Файл | Описание |
|------|----------|
| `agent-workflow.md` | Агент **может и должен** запускать команды терминала (`flutter analyze`, `dart test`, `git` и т.д.) для проверки и диагностики |
| `architecture.md` | Слои `data` / `domain` / `presentation`, репозитории, use cases |
| `flutter-best-practices.md` | Стиль, импорты, без кодогена; версии — из `pubspec.yaml` |
| `bloc-state-management.md` | BLoC/Cubit + `sl`, **без** `BlocProvider`; без ChangeNotifier в фичах |
| `dependency-injection.md` | GetIt (`sl`), `initDependencies`, **без** GetX |
| `feature-trace-logs.md` | `AppLog.trace` + `tag` на новой фиче, **удалить** после «ок» |
| `pitfalls-and-regression-guards.md` | Типовые баги: async/сессия/роутер, `Stack`+`shrink`, `PageView`+`ListView` |
| `routing.md` | GoRouter |
| `api-client.md` | Dio, ошибки, data sources |
| `logging.md` | `AppLog`, easylogger, что логировать |
| `app-context-map.md` | Карта проекта для агента: тема, модели, ключевые виджеты, черновики |
| `presentation-widgets.md` | Один виджет на файл; обновлять `app-context-map.md` при новых UI |

## Skills
| Каталог | Назначение |
|---------|------------|
| `skills/mp-server-sync-contract-filename-preview/` | Playbook: довести МП до контракта сервера (contract_original, fileName, previewUrl) |
| `skills/preview-url-photo-video/` | Playbook: поддержка previewUrl для фото/видео |

## Версии зависимостей
Версии пакетов фиксируй **только в `pubspec.yaml`**. Правила и README не должны дублировать номера версий, чтобы не устаревать.

## Рабочий процесс фичи
1. **План** (чат): учесть rules и спеки, наметить файлы и слои.
2. **Реализация**: правки по плану и `.devin/rules/` — только после «делай»/«утверждаю» (корневое `approve-before-any-action.md`).
3. **Проверка**: агент запускает `flutter analyze` / `dart analyze` (и при необходимости тесты) **сам** через терминал — см. `agent-workflow.md`.
