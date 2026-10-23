# Postman для Astra Nutrition OS

В каталоге лежит коллекция со всеми текущими REST-маршрутами FastAPI, OAuth 2.1 + PKCE и MCP endpoint.

## Импорт

1. Запустите backend (`start.bat` или `uvicorn` на порту `8787`).
2. В Postman выберите **Import** и импортируйте `Astra_Nutrition_OS.postman_collection.json`.
3. Создайте/выберите окружение `Astra Nutrition OS Public` и задайте `base_url` при необходимости.
4. Выполните `POST /api/v1/auth/login`. Тест запроса сохранит `access_token` в окружение.
5. Для клиентских и тренерских методов сначала выполните login тренера и вручную сохраните полученный JWT в `trainer_access_token`.

## Переменные окружения

| Переменная | Значение по умолчанию / назначение |
|---|---|
| `base_url` | `http://204.168.255.69:8787` |
| `access_token` | JWT пользователя/admin; сохраняется после login/register |
| `trainer_access_token` | JWT с `is_trainer=true` или admin |
| `mcp_access_token` | OAuth access token для `/mcp` |
| `admin_email`, `admin_password` | Учетные данные из `.env` backend |
| `trainer_email`, `trainer_password` | Учетные данные тренера |
| `product_id`, `recipe_id`, `client_id` и другие `*_id` | ID объектов для path/body примеров; после create часть ID сохраняется автоматически |
| `oauth_client_id`, `redirect_uri`, `code_challenge`, `code_verifier` | Параметры OAuth PKCE; `oauth_client_id` не смешивается с ID клиента Astra |
| `oauth_request_id`, `oauth_code`, `refresh_token` | Промежуточные значения OAuth flow |

Файловые переменные и секреты не зашиты в коллекцию. Значения `admin_password` и `trainer_password` замените на свои перед запуском.

Для локального запуска замените `base_url` на `http://127.0.0.1:8787`.

## Быстрые сценарии

### REST

1. `GET /api/health`.
2. `POST /api/v1/auth/login` — обычный пользователь или admin.
3. `GET /api/v1/auth/me`.
4. Любой публичный GET или личный POST, например `POST /api/v1/progress`.

### Тренер

1. Выполните login тренера и сохраните JWT в `trainer_access_token`.
2. Вызовите `GET /api/v1/clients`.
3. Используйте client ID в запросах раздела `Clients & Trainer`.

Важно: API не содержит саморегистрации тренера. `POST /api/v1/auth/register` создаёт обычного пользователя, поэтому для тренерских runs нужен заранее подготовленный `trainer_email`/`trainer_password` с `is_trainer=true` либо admin.

## Postman runs

Готовые коллекции для запуска через Postman Runner:

| Run | Коллекция | Содержание |
|---|---|---|
| Positive | `Astra_Nutrition_OS_Run_Positive.postman_collection.json` | Health, admin/trainer login, dashboard и позитивные GET |
| Negative | `Astra_Nutrition_OS_Run_Negative.postman_collection.json` | `401`, `403`, `404`, `400`, `422`, невалидные данные и проверка ролей |
| Sequential | `Astra_Nutrition_OS_Run_Sequential.postman_collection.json` | Сквозные цепочки с передачей токенов и ID между запросами |

Для запуска выберите коллекцию, окружение `Astra Nutrition OS Public` и нажмите **Run**. Внутри Sequential порядок запросов менять нельзя.

Sequential включает:

1. `trainer login → register client → add client → open client`;
2. `create product → create recipe → open recipe → edit recipe → delete recipe → delete product`;
3. `create diary entry → open diary → edit → delete`;
4. `create progress → open list → edit → delete`.

Первый flow создаёт отдельного тестового пользователя и связь тренер-клиент; endpoint удаления пользователя в API отсутствует, поэтому этот тестовый пользователь останется в базе.

### OCR этикетки

Откройте `POST /api/v1/products/scan-nutrition-label`, в `form-data` выберите файл в поле `image`. Поддерживаются JPEG, PNG и WebP до 8 MB.

### OAuth / MCP

OAuth-папка содержит последовательность регистрации клиента, authorization code + PKCE, обмена кода на токены и вызов `POST /mcp`. Для реального flow нужно сгенерировать собственные `code_verifier`/`code_challenge`, а после редиректа вручную перенести `oauth_code` и `oauth_request_id` в окружение. Запрос `/oauth/token` автоматически сохраняет `mcp_access_token` и `refresh_token`.

## Синхронизация коллекции

Исходник генератора — `generate_collection.ps1`. После изменения маршрутов или примеров его можно выполнить из корня проекта:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\postman\generate_collection.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\postman\generate_runs.ps1
```

Подробное описание контрактов API находится в [docs/API.md](../docs/API.md).
