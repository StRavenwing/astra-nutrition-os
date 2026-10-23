# Astra Nutrition OS API

Документация соответствует текущему FastAPI backend в каталоге `backend/routers` и моделям запросов из `backend/schemas.py`.

## Подключение

- Основной base URL продукта: `http://204.168.255.69:8787`
- Локальный base URL для разработки: `http://127.0.0.1:8787`
- Health check: `GET /api/health`
- Интерактивная схема FastAPI: `/docs`
- OpenAPI JSON: `/openapi.json`

Для защищённых REST-методов передавайте JWT:

```http
Authorization: Bearer <access_token>
```

`POST /api/v1/auth/register` и `POST /api/v1/auth/login` доступны без токена. Часть `GET`-методов публична и показывает расширенные/персональные данные, если передать токен.

### Роли

| Роль | Как определяется | Возможности |
|---|---|---|
| Гость | Нет валидного Bearer JWT | Публичные GET и health |
| Пользователь | Валидный JWT | Личные дневник, прогресс, тренировки, обратная связь, рецепты и клиентские `/me/*` |
| Тренер | `is_trainer=true` | Клиенты, клиентские данные, планы, чат, тренерские справочники |
| Admin | `is_admin=true` | Все возможности, общие справочники, статьи и админская обратная связь |

Отдельного endpoint для саморегистрации тренера нет: `POST /api/v1/auth/register` создаёт обычного пользователя (`is_trainer=false`). Для тренерских сценариев нужен заранее созданный аккаунт с `is_trainer=true` или admin-аккаунт.

### Формат ошибок

Ошибки приложения возвращаются в едином формате:

```json
{
  "error": "Описание ошибки",
  "details": null
}
```

`details` обычно присутствует для ошибок валидации `422`. Основные коды: `400` — неверные данные, `401` — нет/невалиден токен, `403` — недостаточно прав, `404` — объект не найден, `409` — конфликт, `413` — файл больше 8 MB, `415` — неподдерживаемый тип файла, `422` — ошибка валидации или КБЖУ не найдены, `503` — OCR недоступен.

## Справочник методов

В колонке «Тело» указано имя модели запроса из раздела «Модели JSON» ниже. `—` означает отсутствие тела.

### Health, auth и dashboard

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/health` | public | — | `200 {"status":"ok"}` |
| POST | `/api/v1/auth/register` | public | `AuthInput` | `201 {access_token, token_type, user}` |
| POST | `/api/v1/auth/login` | public | `AuthInput` | `200 {access_token, token_type, user}` |
| POST | `/api/v1/auth/password-reset/request` | public | `PasswordResetRequestInput` | `200` с результатом отправки кода |
| POST | `/api/v1/auth/password-reset/confirm` | public | `PasswordResetConfirmInput` | `200` с результатом смены пароля |
| POST | `/api/v1/auth/logout` | user | — | `200 {"ok":true}`; logout stateless |
| GET | `/api/v1/auth/me` | user | — | `200 User` |
| GET | `/api/v1/auth/users` | admin | — | `200 User[]` |
| GET | `/api/v1/dashboard` | public / optional JWT | — | `200 Dashboard` |

### Контент

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/categories?kind=recipe` | public / optional JWT | `kind`: `recipe` или `product` | `200 Category[]` |
| POST | `/api/v1/categories` | user | `CategoryInput` | `201 Category` |
| GET | `/api/v1/article-sections` | public / optional JWT | — | `200 ArticleSection[]` |
| POST | `/api/v1/article-sections` | admin | `ArticleSectionInput` | `201 ArticleSection` |
| PUT | `/api/v1/article-sections/{section_id}` | admin | `ArticleSectionInfoInput` | `200 ArticleSection` |
| GET | `/api/v1/articles` | public / optional JWT | — | `200 Article[]` |
| POST | `/api/v1/articles` | admin | `ArticleInput` | `201 Article` |
| PUT | `/api/v1/articles/{article_id}` | admin | `ArticleInput` | `200 Article` |
| PATCH | `/api/v1/articles/{article_id}/flags` | admin | `ArticleFlagsInput` | `200 Article` |
| DELETE | `/api/v1/articles/{article_id}` | admin | — | `200 DeleteResponse` |

Статья принимает до 6 фотографий. `tags` пересчитываются backend на основе заголовка и текста. `links` можно передать как массив URL, массив объектов `{title,url}` или строку.

### Продукты

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/products` | public | — | `200 Product[]` с `measures` |
| GET | `/api/v1/product-measures` | public | — | `200 ProductMeasure[]` |
| POST | `/api/v1/products` | admin | `ProductInput` | `201 Product` |
| POST | `/api/v1/products/scan-nutrition-label` | admin | `multipart/form-data`, поле `image` | `200 ProductNutritionScanResult` |
| PUT | `/api/v1/products/{product_id}` | admin | `ProductInput` | `200 Product` |
| DELETE | `/api/v1/products/{product_id}` | admin | — | `200 DeleteResponse` |

Для OCR допускаются `image/jpeg`, `image/png`, `image/webp`; размер файла не более 8 MB.

### Рецепты

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/recipes` | public / optional JWT | — | `200 RecipeSummary[]` |
| GET | `/api/v1/recipes/{recipe_id}` | public / optional JWT | — | `200 {recipe, ingredients}` |
| POST | `/api/v1/recipes` | user | `RecipeInput` | `201 RecipeSummary` |
| PUT | `/api/v1/recipes/{recipe_id}` | user | `RecipeInput` | `200 RecipeSummary` |
| DELETE | `/api/v1/recipes/{recipe_id}` | user | — | `200 {deleted,id,deleted_diary_entries}` |
| POST | `/api/v1/recipes/{recipe_id}/submission-request` | user | — | `200 RecipeSummary` |
| DELETE | `/api/v1/recipes/{recipe_id}/submission-request` | user | — | `200 RecipeSummary` |
| POST | `/api/v1/recipes/{recipe_id}/moderation` | admin | `RecipeModerationInput` | `200 RecipeSummary` |

Ингредиент может ссылаться на `product_id` или вложенный `recipe_id`. Для обычного продукта обычно достаточно `product_id`, `quantity` и `unit`. Для модерации `action` принимает `accept`, `reject` или `revision`.

### Дневник питания

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/diary` | public / optional JWT | — | `200 DiaryEntry[]` |
| POST | `/api/v1/diary` | user | `DiaryCreateInput` | `201 DiaryEntry[]` |
| PUT | `/api/v1/diary/{entry_id}` | user | `DiaryUpdateInput` | `200 DiaryEntry` |
| DELETE | `/api/v1/diary/{entry_id}` | user | — | `200 DeleteResponse` |

`POST /diary` поддерживает два варианта: одну запись в полях верхнего уровня или пакет `{entry_date, items:[...]}`. Элемент может содержать `recipe_id`, `product_id` или `custom_dish`.

### Прогресс

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/progress` | public / optional JWT | — | `200 ProgressEntry[]` |
| POST | `/api/v1/progress` | user | `ProgressInput` | `201 ProgressEntry` |
| PUT | `/api/v1/progress/{entry_id}` | user | `ProgressInput` | `200 ProgressEntry` |
| DELETE | `/api/v1/progress/{entry_id}` | user | — | `200 DeleteResponse` |

### Тренировки

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/exercises` | public | — | `200 Exercise[]` |
| POST | `/api/v1/exercises` | trainer/admin | `ExerciseInput` | `201 Exercise` |
| PUT | `/api/v1/exercises/{exercise_id}` | trainer/admin | `ExerciseInput` | `200 Exercise` |
| DELETE | `/api/v1/exercises/{exercise_id}` | trainer/admin | — | `200 DeleteResponse` |
| GET | `/api/v1/workout-equipment` | public | — | `200 WorkoutEquipment[]` |
| POST | `/api/v1/workout-equipment` | trainer/admin | `WorkoutEquipmentInput` | `201 WorkoutEquipment` |
| PUT | `/api/v1/workout-equipment/{equipment_id}` | trainer/admin | `WorkoutEquipmentInput` | `200 WorkoutEquipment` |
| DELETE | `/api/v1/workout-equipment/{equipment_id}` | trainer/admin | — | `200 DeleteResponse` |
| GET | `/api/v1/workout-complexes` | public | — | `200 WorkoutComplex[]` |
| POST | `/api/v1/workout-complexes` | trainer/admin | `WorkoutComplexInput` | `201 WorkoutComplex` |
| PUT | `/api/v1/workout-complexes/{complex_id}` | trainer/admin | `WorkoutComplexInput` | `200 WorkoutComplex` |
| GET | `/api/v1/workouts` | public / optional JWT | — | `200 WorkoutLog[]` |
| POST | `/api/v1/workouts` | user | `WorkoutInput` | `201 WorkoutLog` |
| PUT | `/api/v1/workouts/{log_id}` | user | `WorkoutInput` | `200 WorkoutLog` |
| DELETE | `/api/v1/workouts/{log_id}` | user | — | `200 DeleteResponse` |
| GET | `/api/v1/workout-plans` | public / optional JWT | — | `200 WorkoutPlan[]` |
| POST | `/api/v1/workout-plans` | user | `WorkoutPlanInput` | `201 WorkoutPlan` |
| PUT | `/api/v1/workout-plans/{plan_id}` | user | `WorkoutPlanInput` | `200 WorkoutPlan` |
| POST | `/api/v1/workout-plans/{plan_id}/complete` | user | — | `200 WorkoutPlan` |
| POST | `/api/v1/workout-plans/{plan_id}/cancel` | user | — | `200 WorkoutPlan` |
| DELETE | `/api/v1/workout-plans/{plan_id}` | user | — | `200 DeleteResponse` |

### Клиенты и тренер

Все маршруты ниже с `/clients/{client_id}` требуют роль trainer/admin. Маршруты `/clients/me/*` требуют обычный JWT и работают с текущим пользователем-клиентом.

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/clients` | trainer/admin | — | `200 Client[]` |
| POST | `/api/v1/clients` | trainer/admin | `ClientCreateInput` | `201 Client` |
| POST | `/api/v1/clients/shares` | trainer/admin | `ShareItemInput` | `201 SharedItem` |
| GET | `/api/v1/clients/me/chat` | user | — | `200 Chat` |
| GET | `/api/v1/clients/me/trainer` | user | — | `200 Trainer` |
| POST | `/api/v1/clients/me/chat` | user | `TrainerChatMessageInput` | `201 ChatMessage` |
| GET | `/api/v1/clients/me/shared-items/{item_type}/{item_id}` | user | — | `200 {type,id,name,data}` |
| POST | `/api/v1/clients/me/shares` | user | `ClientShareItemInput` | `201 SharedItem` |
| GET | `/api/v1/clients/{client_id}` | trainer/admin | — | `200 ClientDetail` |
| GET | `/api/v1/clients/{client_id}/shared-items/{item_type}/{item_id}` | trainer/admin | — | `200 {type,id,name,data}` |
| POST | `/api/v1/clients/{client_id}/diary` | trainer/admin | `DiaryCreateInput` | `201 DiaryEntry[]` |
| GET | `/api/v1/clients/{client_id}/diary` | trainer/admin | — | `200 DiaryEntry[]` |
| DELETE | `/api/v1/clients/{client_id}/diary/{entry_id}` | trainer/admin | — | `200 DeleteResponse` |
| POST | `/api/v1/clients/{client_id}/workout-plans` | trainer/admin | `WorkoutPlanInput` | `201 WorkoutPlan` |
| PUT | `/api/v1/clients/{client_id}/workout-plans/{plan_id}` | trainer/admin | `WorkoutPlanInput` | `200 WorkoutPlan` |
| PUT | `/api/v1/clients/{client_id}/nutrition-targets` | trainer/admin | `ClientNutritionTargetsInput` | `200 ProgressEntry` |
| POST | `/api/v1/clients/{client_id}/progress` | trainer/admin | `ProgressInput` | `201 ProgressEntry` |
| PUT | `/api/v1/clients/{client_id}/progress/{entry_id}` | trainer/admin | `ProgressInput` | `200 ProgressEntry` |
| GET | `/api/v1/clients/{client_id}/tasks?week_start=YYYY-MM-DD` | trainer/admin | query `week_start` обязателен | `200 TrainerTask[]` |
| POST | `/api/v1/clients/{client_id}/tasks` | trainer/admin | `TrainerTaskInput` | `201 TrainerTask` |
| PUT | `/api/v1/clients/{client_id}/tasks/{task_id}` | trainer/admin | `TrainerTaskStatusInput` | `200 TrainerTask` |
| GET | `/api/v1/clients/{client_id}/chat` | trainer/admin | — | `200 ChatMessage[]` |
| POST | `/api/v1/clients/{client_id}/chat` | trainer/admin | `TrainerChatMessageInput` | `201 ChatMessage` |

`item_type` принимает одно из значений: `recipe`, `product`, `article`, `exercise`, `progress`, `workout_complex`, `workout_equipment`.

### Обратная связь

| Метод | Endpoint | Доступ | Тело / параметры | Успешный ответ |
|---|---|---|---|---|
| GET | `/api/v1/feedback/unread-count` | admin | — | `200 {count}` |
| GET | `/api/v1/feedback` | admin | — | `200 Feedback[]` |
| GET | `/api/v1/feedback/mine` | user | — | `200 Feedback[]` |
| POST | `/api/v1/feedback` | user | `FeedbackInput` | `201 Feedback` |
| POST | `/api/v1/feedback/{message_id}/read` | admin | — | `200 {ok:true}` |
| POST | `/api/v1/feedback/{message_id}/reply` | admin | `FeedbackReplyInput` | `200 Feedback` |

## OAuth 2.1 и MCP

| Метод | Endpoint | Доступ | Назначение |
|---|---|---|---|
| GET | `/.well-known/oauth-authorization-server` | public | Metadata authorization server |
| GET | `/.well-known/oauth-protected-resource/mcp` | public | Metadata защищённого `/mcp` |
| POST | `/oauth/register` | public | Dynamic client registration |
| GET | `/oauth/authorize` | public | Authorization code + PKCE; после проверки перенаправляет на форму входа |
| GET | `/oauth/login?request=...` | public | HTML-форма авторизации |
| POST | `/oauth/login` | public | Form login: `request`, `email`, `password` |
| POST | `/oauth/token` | public | Form exchange: `grant_type`, `code`, `redirect_uri`, `client_id`, `code_verifier` |
| POST | `/oauth/revoke` | public | Form revoke: `token`, `token_type_hint` |
| POST | `/mcp` | OAuth Bearer | JSON-RPC Streamable HTTP; например `tools/list` |

Для MCP используйте `Accept: application/json, text/event-stream`. Полный OAuth flow требует зарегистрировать client, сгенерировать PKCE verifier/challenge и сохранить полученный authorization code.

## Модели JSON

Типы `Any` ниже специально оставлены гибкими: backend принимает числа/строки и приводит их к формату, используемому SQLite-сервисами.

### Auth и контент

```text
// AuthInput
{"email":"user@example.com","password":"Password123!"}

// PasswordResetRequestInput
{"email":"user@example.com"}

// PasswordResetConfirmInput
{"email":"user@example.com","code":"123456","password":"NewPassword123!"}

// CategoryInput
{"kind":"recipe","name":"Breakfast","collection":"local"}

// ArticleSectionInput / ArticleSectionInfoInput
{"name":"Nutrition"}
{"description":"Практические материалы"}

// ArticleFlagsInput
{"is_pinned":true,"is_hidden":false}
```

```jsonc
// ArticleInput
{
  "section_id": 1,
  "title": "Заголовок",
  "body": "Текст статьи",
  "tags": null,
  "links": [{"title":"Источник","url":"https://example.com"}],
  "photos": [],
  "video": null
}
```

### Продукты и рецепты

```jsonc
// ProductInput
{
  "name":"Oats",
  "category":"Breakfast",
  "unit":"g",
  "package_price_rsd":250,
  "package_size":500,
  "price_per_100_or_unit_rsd":50,
  "kcal":370,
  "protein_g":13,
  "fat_g":7,
  "carbs_g":62,
  "data_status":"Confirmed",
  "note":null,
  "measures":[{"measure_name":"tbsp","base_quantity":10}]
}
```

```jsonc
// RecipeInput
{
  "category":"Breakfast",
  "name":"Oatmeal",
  "subcategory":null,
  "version":"1.0",
  "status":"Draft",
  "servings":1,
  "yield_g":300,
  "tags":"breakfast",
  "is_ready":false,
  "needs_garnish":false,
  "manual_price_per_serving_rsd":null,
  "manual_kcal_per_serving":null,
  "manual_protein_per_serving_g":null,
  "manual_fat_per_serving_g":null,
  "manual_carbs_per_serving_g":null,
  "ingredients":[{"product_id":1,"quantity":80,"unit":"g","measurement_name":null,"measurement_quantity":null,"portion_description":null}]
}
```

### Дневник, прогресс и тренировки

```jsonc
// DiaryCreateInput — одна запись
{
  "entry_date":"2026-10-13",
  "meal_type":"breakfast",
  "recipe_id":1,
  "servings":1,
  "quantity":null,
  "measurement_name":null,
  "measurement_quantity":null,
  "comment":"После тренировки"
}
```

```jsonc
// ProgressInput — measured_at обязателен, остальные поля optional
{
  "measured_at":"2026-10-13",
  "weight_kg":72,
  "desired_weight_kg":68,
  "height_cm":175,
  "bmi":23.5,
  "body_fat_pct":null,
  "fat_mass_kg":null,
  "muscle_pct":null,
  "muscle_mass_kg":null,
  "kcal_target":2200,
  "protein_target_g":140,
  "fat_target_g":70,
  "carbs_target_g":240,
  "waist_cm":null,
  "chest_cm":null,
  "hips_cm":null,
  "sleep_score":8,
  "wellbeing_score":8,
  "comment":"Стартовый замер"
}
```

```text
// WorkoutInput
{"performed_at":"2026-10-13T18:00:00+03:00","exercise_id":1,"exercise_name":null,"muscle_group":null,"unit":"kg","working_weight":20,"sets":3,"reps":12,"rir":"1","machine_location":null,"comment":null}

// WorkoutPlanInput
{"name":"Monday strength","scheduled_at":"2026-10-19T18:00:00+03:00","duration_minutes":60,"items":[{"exercise_id":1,"variant_id":1,"working_weight":20,"sets":3,"duration_minutes":null,"speed_kmh":null}]}
```

### Клиенты и feedback

```text
// ClientCreateInput
{"email":"client@example.com"}

// ClientNutritionTargetsInput
{"kcal_target":2200,"protein_target_g":140,"fat_target_g":70,"carbs_target_g":240}

// TrainerTaskInput / TrainerTaskStatusInput
{"week_start":"2026-10-12","title":"Заполнить дневник","description":"Все приёмы пищи","due_date":"2026-10-18"}
{"status":"done"}

// ShareItemInput / ClientShareItemInput
{"client_id":1,"item_type":"recipe","item_id":1}
{"item_type":"progress","item_id":1}

// TrainerChatMessageInput / FeedbackInput / FeedbackReplyInput
{"message":"Здравствуйте! Есть вопрос по плану."}
{"message":"Предложение по улучшению приложения"}
{"reply":"Спасибо за обратную связь!"}
```

## Postman

Готовая коллекция: [Astra_Nutrition_OS.postman_collection.json](../postman/Astra_Nutrition_OS.postman_collection.json).

Коллекции для Postman Runner:

- [Positive](../postman/Astra_Nutrition_OS_Run_Positive.postman_collection.json)
- [Negative](../postman/Astra_Nutrition_OS_Run_Negative.postman_collection.json)
- [Sequential flows](../postman/Astra_Nutrition_OS_Run_Sequential.postman_collection.json)

Инструкция по импорту, окружение и быстрый сценарий: [postman/README.md](../postman/README.md).
