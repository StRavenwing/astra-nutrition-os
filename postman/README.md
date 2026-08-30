# Postman collection for Astra Nutrition OS

## Что входит

- Полная REST-коллекция по всем маршрутам FastAPI проекта.
- Переменные окружения для локального запуска.
- JWT-токен для авторизации (`{{access_token}}`).
- Отдельная группа `Trainer / Coach` с токеном `{{trainer_access_token}}` для новых тренерских маршрутов.
- Примеры запросов для OAuth / MCP.

## Как импортировать

1. Откройте Postman.
2. Нажмите Import.
3. Импортируйте файл `Astra_Nutrition_OS.postman_collection.json`.
4. Импортируйте файл `Astra_Nutrition_OS.postman_environment.json`.
5. Выберите окружение `Astra Nutrition OS Local`.

## Переменные окружения

- `base_url` — основной URL API, по умолчанию `http://127.0.0.1:8787`
- `admin_email` — email администратора из `.env`
- `admin_password` — пароль администратора из `.env`
- `access_token` — JWT для обычного пользователя/админа, заполняется после `POST /api/v1/auth/login`
- `trainer_access_token` — JWT тренера/коуча, заполняется после `POST /api/v1/auth/login` в папке `Trainer / Coach`
- `trainer_email`, `trainer_password` — учетные данные тренера для роли `is_trainer`
- `client_id`, `redirect_uri`, `code_challenge`, `code_verifier`, `oauth_request_id`, `oauth_code`, `refresh_token` — для OAuth/MCP

## Быстрый сценарий

1. Проверьте, что сервер запущен.
2. Выполните `POST /api/v1/auth/login` для обычного пользователя/админа или `POST /api/v1/auth/login (trainer)` в папке `Trainer / Coach`.
3. Убедитесь, что `access_token` или `trainer_access_token` сохранился в переменную окружения.
4. После этого можно запускать остальные запросы, которые требуют авторизацию, включая тренерский раздел.

## Полезные ссылки

- API health: `{{base_url}}/api/health`
- OAuth metadata: `{{base_url}}/.well-known/oauth-authorization-server`
- Protected resource metadata: `{{base_url}}/.well-known/oauth-protected-resource/mcp`
- MCP endpoint: `{{base_url}}/mcp`

## Примечание

Некоторые OAuth-переменные зависят от вашего конкретного client registration и PKCE. Для локального использования заполните их вручную после регистрации клиента.
