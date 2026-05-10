# Cursor Rules — Flutter шаблон

Файлы в `.cursor/rules/` подхватываются Cursor для этого репозитория.

**Исходный шаблон (DigitalSquare):** `D:\Projects\_my_template\digitalsquare` — тот же каркас и дух правил; этот репо развивается от него, при синхронизации правок можно сверяться с путём выше.

## Зафиксированный стек
**Clean Architecture (классические слои)** + **flutter_bloc** + **GetIt** + **go_router** + **Dio**. Другие стеки в этих правилах не рассматриваются.

## Правила
| Файл | Описание |
|------|----------|
| `agent-workflow.mdc` | Агент **может и должен** запускать команды терминала (`flutter analyze`, `dart test`, `git` и т.д.) для проверки и диагностики |
| `architecture.mdc` | Слои `data` / `domain` / `presentation`, репозитории, use cases |
| `flutter-best-practices.mdc` | Стиль, импорты, без кодогена; версии — из `pubspec.yaml` |
| `bloc-state-management.mdc` | BLoC/Cubit + `sl`, **без** `BlocProvider`; без ChangeNotifier в фичах |
| `dependency-injection.mdc` | GetIt (`sl`), `initDependencies`, **без** GetX |
| `feature-trace-logs.mdc` | `AppLog.trace` + `tag` на новой фиче, **удалить** после «ок» |
| `pitfalls-and-regression-guards.mdc` | Типовые баги: async/сессия/роутер, `Stack`+`shrink`, `PageView`+`ListView` |
| `routing.mdc` | GoRouter |
| `api-client.mdc` | Dio, ошибки, data sources |
| `logging.mdc` | `AppLog`, easylogger, что логировать |
| `app-context-map.mdc` | Карта проекта для агента: тема, модели, ключевые виджеты, черновики |
| `presentation-widgets.mdc` | Один виджет на файл; обновлять `app-context-map.mdc` при новых UI |

## Использование как шаблона
1. Скопируй проект целиком (в т.ч. `lib/`, `android/`, `ios/`, `.cursor/`).
2. Пройди [чеклист после копирования](../docs/template_checklist.md) (`docs/template_checklist.md`).
3. В **`pubspec.yaml`** задай **`name:`** — имя пакета для импортов `package:<name>/...`; при смене имени сделай поиск по старому имени в `lib/`.
4. В `lib/` уже разложен **каркас папок** под классические слои (`.gitkeep`, чтобы Git не терял пустые каталоги). Код добавляй по мере фич — см. `architecture.mdc`.
5. Опционально: `docs/project-specs.md` и в чате `@docs/project-specs.md`.

## Версии зависимостей
Версии пакетов фиксируй **только в `pubspec.yaml`**. Правила и README не должны дублировать номера версий, чтобы не устаревать.

## Горячие клавиши Cursor
| Действие | macOS | Windows / Linux |
|----------|--------|-----------------|
| Чат | `Cmd+L` | `Ctrl+L` |
| Редактировать выделение | `Cmd+K` | `Ctrl+K` |
| Composer / агент | `Cmd+I` | `Ctrl+I` |

## Ссылки в чате (`@`)
- `@AGENTS.md` — краткий контекст стека и ссылки на правила (удобно агенту)
- `@.cursor/rules/` — все правила проекта
- `@codebase` — поиск по коду
- `@docs/template_checklist.md` — чеклист после копирования шаблона
- `@docs/project-specs.md` — черновик спецификации продукта (заполни под проект)

Файл **`.cursorignore`** (в корне) ограничивает индексацию `build/`, `.dart_tool/` и т.п.

## Рабочий процесс фичи
1. **План** (чат): учесть rules и спеки, наметить файлы и слои.
2. **Реализация** (Composer): правки по плану и `.cursor/rules/`.
3. **Проверка**: агент запускает `flutter analyze` / `dart analyze` (и при необходимости тесты) **сам** через терминал — см. `agent-workflow.mdc`.

## Терминал и агент
В шаблоне зафиксировано: ИИ-агент **не обязан** ограничиваться подсказками «выполните команду» — допустимо и ожидаемо **самостоятельно** вызывать CLI для анализа, сборки и отладки. Подробности в **`agent-workflow.mdc`** (`alwaysApply: true`).
