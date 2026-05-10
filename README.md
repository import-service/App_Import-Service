# Import Service — монорепозиторий

Единый репозиторий для мобильного приложения, серверной части и админ-панели.

## Структура

| Каталог | Описание |
|--------|----------|
| `import_service_app` | Мобильное приложение (Flutter) |
| `import_service_server` | Backend (Node.js) |
| `import_service_admin` | Админка (Flutter Web) |

## Публикация изменений на GitHub

Из корня `import_servis`:

```powershell
.\scripts\push-monorepo.ps1 -Message "Краткое описание изменений"
```

Сообщения коммитов — на русском. Подробнее см. `.cursor/rules` внутри каждого проекта.
