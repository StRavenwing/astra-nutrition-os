$ErrorActionPreference = "Stop"

$collectionPath = Join-Path (Get-Location) "postman\Astra_Nutrition_OS.postman_collection.json"
$baseUrl = "{{base_url}}"

$variables = @(
    @{ key = "base_url"; value = "http://204.168.255.69:8787" },
    @{ key = "access_token"; value = "" },
    @{ key = "trainer_access_token"; value = "" },
    @{ key = "mcp_access_token"; value = "" },
    @{ key = "admin_email"; value = "admin@example.com" },
    @{ key = "admin_password"; value = "Password123!" },
    @{ key = "trainer_email"; value = "trainer@example.com" },
    @{ key = "trainer_password"; value = "TrainerPassword123!" },
    @{ key = "user_email"; value = "user@example.com" },
    @{ key = "user_password"; value = "Password123!" },
    @{ key = "reset_email"; value = "user@example.com" },
    @{ key = "reset_code"; value = "000000" },
    @{ key = "account_name"; value = "Postman Account User" },
    @{ key = "account_email"; value = "user@example.com" },
    @{ key = "account_phone"; value = "+1234567890" },
    @{ key = "account_current_password"; value = "Password123!" },
    @{ key = "account_new_password"; value = "NewPassword123!" },
    @{ key = "email_verification_code"; value = "000000" },
    @{ key = "client_id"; value = "1" },
    @{ key = "product_id"; value = "1" },
    @{ key = "recipe_id"; value = "1" },
    @{ key = "article_id"; value = "1" },
    @{ key = "section_id"; value = "1" },
    @{ key = "entry_id"; value = "1" },
    @{ key = "progress_id"; value = "1" },
    @{ key = "exercise_id"; value = "1" },
    @{ key = "variant_id"; value = "1" },
    @{ key = "equipment_id"; value = "1" },
    @{ key = "complex_id"; value = "1" },
    @{ key = "log_id"; value = "1" },
    @{ key = "plan_id"; value = "1" },
    @{ key = "task_id"; value = "1" },
    @{ key = "message_id"; value = "1" },
    @{ key = "redirect_uri"; value = "https://example.com/callback" },
    @{ key = "oauth_client_id"; value = "" },
    @{ key = "code_challenge"; value = "replace-with-base64url-sha256" },
    @{ key = "code_verifier"; value = "replace-with-pkce-verifier" },
    @{ key = "oauth_request_id"; value = "" },
    @{ key = "oauth_code"; value = "" },
    @{ key = "refresh_token"; value = "" }
)

$folderDescriptions = [ordered]@{
    "Health" = "Проверка доступности API."
    "Authentication" = "Регистрация, JWT-сессия и восстановление пароля."
    "Personal Account" = "Профиль пользователя, пароль, аватар и подтверждение email."
    "Dashboard" = "Сводные показатели главного экрана."
    "Content" = "Категории, разделы статей и статьи."
    "Products" = "Продукты, меры и распознавание этикетки."
    "Recipes" = "Рецепты, ингредиенты, модерация и отправка на проверку."
    "Diary" = "Дневник питания."
    "Progress" = "Замеры и целевые показатели."
    "Workouts" = "Упражнения, оборудование, комплексы, журнал и планы тренировок."
    "Clients & Trainer" = "Связка тренер-клиент, чаты, задачи, шаринг и клиентские данные."
    "Feedback" = "Обратная связь пользователя и ответы администратора."
    "OAuth / MCP" = "OAuth 2.1 + PKCE и Streamable HTTP MCP."
}

$folders = [ordered]@{}
foreach ($folderName in $folderDescriptions.Keys) {
    $folders[$folderName] = [ordered]@{
        name = $folderName
        description = $folderDescriptions[$folderName]
        item = @()
    }
}

function New-Url([string]$path, [array]$query) {
    $cleanPath = $path.TrimStart("/")
    $raw = "$baseUrl/$cleanPath"
    if ($query.Count -gt 0) {
        $raw += "?" + (($query | ForEach-Object { "$($_.key)=$($_.value)" }) -join "&")
    }
    $url = [ordered]@{
        raw = $raw
        host = @($baseUrl)
        path = @($cleanPath -split "/")
    }
    if ($query.Count -gt 0) { $url.query = @($query) }
    return $url
}

function New-CaptureTest([string]$variable) {
    return @(
        "try {",
        "  const payload = pm.response.json();",
        "  const item = Array.isArray(payload) ? payload[0] : payload;",
        "  if (item && item.id !== undefined) pm.environment.set(`"$variable`", String(item.id));",
        "} catch (error) {}"
    )
}

function New-TokenTest([string]$variable) {
    return @(
        "pm.test(`"Successful response`", function () {",
        "  pm.expect(pm.response.code).to.be.within(200, 299);",
        "});",
        "try {",
        "  const payload = pm.response.json();",
        "  if (payload.access_token) pm.environment.set(`"$variable`", payload.access_token);",
        "} catch (error) {}"
    )
}

function New-CaptureClientTest {
    return @(
        "try {",
        "  const payload = pm.response.json();",
        "  if (payload.client_id) pm.environment.set(`"oauth_client_id`", payload.client_id);",
        "} catch (error) {}"
    )
}

function New-McpTokenTest {
    return @(
        "try {",
        "  const payload = pm.response.json();",
        "  if (payload.access_token) pm.environment.set(`"mcp_access_token`", payload.access_token);",
        "  if (payload.refresh_token) pm.environment.set(`"refresh_token`", payload.refresh_token);",
        "} catch (error) {}"
    )
}

function Add-Request {
    param(
        [string]$Folder,
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string]$Token = "",
        [object]$Body = $null,
        [string]$Description = "",
        [array]$Query = @(),
        [string]$CaptureId = "",
        [switch]$CaptureOAuthClient,
        [switch]$SaveMcpTokens,
        [string]$SaveToken = "",
        [switch]$FormData,
        [array]$FormFields = @(),
        [array]$ExtraHeaders = @()
    )

    $headers = @($ExtraHeaders)
    $request = [ordered]@{
        method = $Method
        header = @()
        url = New-Url $Path $Query
    }

    if ($FormData) {
        $request.body = [ordered]@{ mode = "formdata"; formdata = @($FormFields) }
    } elseif ($FormFields.Count -gt 0) {
        $request.body = [ordered]@{ mode = "urlencoded"; urlencoded = @($FormFields) }
    } elseif ($null -ne $Body) {
        $request.body = [ordered]@{
            mode = "raw"
            raw = ($Body | ConvertTo-Json -Depth 20)
            options = [ordered]@{ raw = [ordered]@{ language = "json" } }
        }
        $headers += @{ key = "Content-Type"; value = "application/json" }
    }

    if ($Token) {
        $request.auth = [ordered]@{
            type = "bearer"
            bearer = @(@{ key = "token"; value = "{{${Token}}}"; type = "string" })
        }
    }
    if ($Description) { $request.description = $Description }
    $request.header = @($headers)

    $item = [ordered]@{
        name = $Name
        request = $request
        response = @()
    }
    $tests = @()
    if ($SaveToken) { $tests += New-TokenTest $SaveToken }
    if ($CaptureId) { $tests += New-CaptureTest $CaptureId }
    if ($CaptureOAuthClient) { $tests += New-CaptureClientTest }
    if ($SaveMcpTokens) { $tests += New-McpTokenTest }
    if ($tests.Count -gt 0) {
        $item.event = @(@{
            listen = "test"
            script = @{ type = "text/javascript"; exec = @($tests) }
        })
    }
    $folders[$Folder].item += $item
}

function Set-BodyField([object]$Body, [string]$Key, [object]$Value) {
    $copy = [ordered]@{}
    foreach ($property in $Body.GetEnumerator()) { $copy[$property.Key] = $property.Value }
    $copy[$Key] = $Value
    return $copy
}

$authNote = "Bearer JWT. Для admin/trainer-методов используйте соответствующую роль. Публичные GET допускают запрос без токена."

# Health
Add-Request "Health" "GET /api/health" "GET" "/api/health" -Description "Публичная проверка доступности сервера."

# Authentication
Add-Request "Authentication" "POST /api/v1/auth/register" "POST" "/api/v1/auth/register" -Body @{ email = "new.user@example.com"; password = "Password123!" } -Description "Создаёт пользователя и возвращает JWT." -SaveToken "access_token"
Add-Request "Authentication" "POST /api/v1/auth/login" "POST" "/api/v1/auth/login" -Body @{ email = "{{admin_email}}"; password = "{{admin_password}}" } -Description "Вход admin/user; сохраняет access_token." -SaveToken "access_token"
Add-Request "Authentication" "POST /api/v1/auth/login (trainer)" "POST" "/api/v1/auth/login" -Body @{ email = "{{trainer_email}}"; password = "{{trainer_password}}" } -Description "Вход тренера; сохраняет trainer_access_token." -SaveToken "trainer_access_token"
Add-Request "Authentication" "POST /api/v1/auth/password-reset/request" "POST" "/api/v1/auth/password-reset/request" -Body @{ email = "{{reset_email}}" } -Description "Запрашивает код восстановления пароля."
Add-Request "Authentication" "POST /api/v1/auth/password-reset/confirm" "POST" "/api/v1/auth/password-reset/confirm" -Body @{ email = "{{reset_email}}"; code = "{{reset_code}}"; password = "NewPassword123!" } -Description "Подтверждает код восстановления; code — 6 цифр."
Add-Request "Authentication" "POST /api/v1/auth/logout" "POST" "/api/v1/auth/logout" -Token "access_token" -Description "$authNote Logout stateless."
Add-Request "Authentication" "GET /api/v1/auth/me" "GET" "/api/v1/auth/me" -Token "access_token" -Description "Возвращает текущего пользователя."
Add-Request "Authentication" "GET /api/v1/auth/users (admin)" "GET" "/api/v1/auth/users" -Token "access_token" -Description "Список пользователей; требуется admin."

# Personal Account
$accountProfileBody = @{ name = "{{account_name}}"; email = "{{account_email}}"; phone = "{{account_phone}}"; avatar = $null }
$accountPasswordBody = @{ current_password = "{{account_current_password}}"; new_password = "{{account_new_password}}"; confirm_password = "{{account_new_password}}" }
Add-Request "Personal Account" "GET /api/v1/auth/me" "GET" "/api/v1/auth/me" -Token "access_token" -Description "Возвращает профиль текущего пользователя с phone, avatar и email_verified."
Add-Request "Personal Account" "PUT /api/v1/auth/me/profile" "PUT" "/api/v1/auth/me/profile" -Token "access_token" -Body $accountProfileBody -Description "Обновляет имя, email, телефон и аватар текущего пользователя. Для аватара передавайте data URL изображения."
Add-Request "Personal Account" "POST /api/v1/auth/me/password" "POST" "/api/v1/auth/me/password" -Token "access_token" -Body $accountPasswordBody -Description "Меняет пароль после проверки старого пароля."
Add-Request "Personal Account" "POST /api/v1/auth/me/email-verification/request" "POST" "/api/v1/auth/me/email-verification/request" -Token "access_token" -Description "Отправляет код подтверждения на email. Требует настроенный SMTP; для admin возвращает, что email уже подтверждён."
Add-Request "Personal Account" "POST /api/v1/auth/me/email-verification/confirm" "POST" "/api/v1/auth/me/email-verification/confirm" -Token "access_token" -Body @{ code = "{{email_verification_code}}" } -Description "Подтверждает email шестизначным кодом из письма."

# Dashboard
Add-Request "Dashboard" "GET /api/v1/dashboard" "GET" "/api/v1/dashboard" -Description "KPI dashboard; с JWT latest относится к текущему пользователю."

# Content
Add-Request "Content" "GET /api/v1/categories" "GET" "/api/v1/categories" -Query @(@{ key = "kind"; value = "recipe"; description = "recipe или product" }) -Description "Список категорий. kind обязателен."
Add-Request "Content" "POST /api/v1/categories" "POST" "/api/v1/categories" -Token "access_token" -Body @{ kind = "recipe"; name = "Breakfast"; collection = "local" } -Description "Создаёт категорию; common только для admin." -CaptureId "category_id"
Add-Request "Content" "GET /api/v1/article-sections" "GET" "/api/v1/article-sections" -Description "Список разделов статей."
Add-Request "Content" "POST /api/v1/article-sections" "POST" "/api/v1/article-sections" -Token "access_token" -Body @{ name = "Nutrition" } -Description "Создаёт раздел статей; требуется admin." -CaptureId "section_id"
Add-Request "Content" "PUT /api/v1/article-sections/{section_id}" "PUT" "/api/v1/article-sections/{{section_id}}" -Token "access_token" -Body @{ description = "Практические материалы по питанию" } -Description "Обновляет описание раздела; требуется admin."
Add-Request "Content" "GET /api/v1/articles" "GET" "/api/v1/articles" -Description "Список статей; admin также видит скрытые."
$articleBody = @{ section_id = "{{section_id}}"; title = "Как собрать сбалансированный завтрак"; body = "Текст статьи"; tags = $null; links = @(@{ title = "Источник"; url = "https://example.com/source" }); photos = @(); video = $null }
Add-Request "Content" "POST /api/v1/articles" "POST" "/api/v1/articles" -Token "access_token" -Body $articleBody -Description "Создаёт статью; требуется admin." -CaptureId "article_id"
Add-Request "Content" "PUT /api/v1/articles/{article_id}" "PUT" "/api/v1/articles/{{article_id}}" -Token "access_token" -Body (Set-BodyField $articleBody "title" "Как собрать сбалансированный завтрак — обновление") -Description "Полностью обновляет статью; требуется admin."
Add-Request "Content" "PATCH /api/v1/articles/{article_id}/flags" "PATCH" "/api/v1/articles/{{article_id}}/flags" -Token "access_token" -Body @{ is_pinned = $true; is_hidden = $false } -Description "Обновляет флаги статьи; требуется admin."
Add-Request "Content" "DELETE /api/v1/articles/{article_id}" "DELETE" "/api/v1/articles/{{article_id}}" -Token "access_token" -Description "Удаляет статью; требуется admin."

# Products
Add-Request "Products" "GET /api/v1/products" "GET" "/api/v1/products" -Description "Список продуктов с measures."
Add-Request "Products" "GET /api/v1/product-measures" "GET" "/api/v1/product-measures" -Description "Плоский справочник мер продуктов."
$productBody = @{ name = "Oats"; category = "Breakfast"; unit = "g"; package_price_rsd = 250; package_size = 500; price_per_100_or_unit_rsd = 50; kcal = 370; protein_g = 13; fat_g = 7; carbs_g = 62; data_status = "Confirmed"; note = $null; measures = @(@{ measure_name = "tbsp"; base_quantity = 10 }) }
Add-Request "Products" "POST /api/v1/products" "POST" "/api/v1/products" -Token "access_token" -Body $productBody -Description "Создаёт продукт; требуется admin." -CaptureId "product_id"
Add-Request "Products" "POST /api/v1/products/scan-nutrition-label" "POST" "/api/v1/products/scan-nutrition-label" -Token "access_token" -FormData -FormFields @(@{ key = "image"; type = "file"; src = "" }) -Description "JPEG/PNG/WebP, до 8 MB; требуется admin."
Add-Request "Products" "PUT /api/v1/products/{product_id}" "PUT" "/api/v1/products/{{product_id}}" -Token "access_token" -Body (Set-BodyField $productBody "name" "Oats updated") -Description "Обновляет продукт; требуется admin."
Add-Request "Products" "DELETE /api/v1/products/{product_id}" "DELETE" "/api/v1/products/{{product_id}}" -Token "access_token" -Description "Удаляет продукт; требуется admin."

# Recipes
Add-Request "Recipes" "GET /api/v1/recipes" "GET" "/api/v1/recipes" -Description "Список общих и локальных рецептов."
Add-Request "Recipes" "GET /api/v1/recipes/{recipe_id}" "GET" "/api/v1/recipes/{{recipe_id}}" -Description "Карточка рецепта и ingredients."
$recipeBody = @{ category = "Breakfast"; name = "Oatmeal"; subcategory = $null; version = "1.0"; status = "Draft"; servings = 1; yield_g = 300; tags = "breakfast"; is_ready = $false; needs_garnish = $false; manual_price_per_serving_rsd = $null; manual_kcal_per_serving = $null; manual_protein_per_serving_g = $null; manual_fat_per_serving_g = $null; manual_carbs_per_serving_g = $null; ingredients = @(@{ product_id = "{{product_id}}"; quantity = 80; unit = "g"; measurement_name = $null; measurement_quantity = $null; portion_description = $null }) }
Add-Request "Recipes" "POST /api/v1/recipes" "POST" "/api/v1/recipes" -Token "access_token" -Body $recipeBody -Description "Создаёт локальный или общий рецепт." -CaptureId "recipe_id"
Add-Request "Recipes" "PUT /api/v1/recipes/{recipe_id}" "PUT" "/api/v1/recipes/{{recipe_id}}" -Token "access_token" -Body (Set-BodyField $recipeBody "name" "Oatmeal updated") -Description "Обновляет рецепт."
Add-Request "Recipes" "DELETE /api/v1/recipes/{recipe_id}" "DELETE" "/api/v1/recipes/{{recipe_id}}" -Token "access_token" -Description "Удаляет рецепт и связанные дневниковые записи."
Add-Request "Recipes" "POST /api/v1/recipes/{recipe_id}/submission-request" "POST" "/api/v1/recipes/{{recipe_id}}/submission-request" -Token "access_token" -Description "Отправляет рецепт на модерацию."
Add-Request "Recipes" "DELETE /api/v1/recipes/{recipe_id}/submission-request" "DELETE" "/api/v1/recipes/{{recipe_id}}/submission-request" -Token "access_token" -Description "Отменяет заявку на модерацию."
Add-Request "Recipes" "POST /api/v1/recipes/{recipe_id}/moderation" "POST" "/api/v1/recipes/{{recipe_id}}/moderation" -Token "access_token" -Body @{ action = "accept"; note = "Проверено" } -Description "Модерация: action accept, reject или revision; требуется admin."

# Diary
$diaryBody = @{ entry_date = "2026-10-13"; meal_type = "breakfast"; recipe_id = "{{recipe_id}}"; servings = 1; quantity = $null; measurement_name = $null; measurement_quantity = $null; comment = "После тренировки" }
Add-Request "Diary" "GET /api/v1/diary" "GET" "/api/v1/diary" -Description "Дневник пользователя; GET допускает гостя."
Add-Request "Diary" "POST /api/v1/diary" "POST" "/api/v1/diary" -Token "access_token" -Body $diaryBody -Description "Добавляет одну запись; поддерживается batch items." -CaptureId "entry_id"
Add-Request "Diary" "PUT /api/v1/diary/{entry_id}" "PUT" "/api/v1/diary/{{entry_id}}" -Token "access_token" -Body (Set-BodyField $diaryBody "entry_date" "2026-10-14") -Description "Обновляет запись дневника."
Add-Request "Diary" "DELETE /api/v1/diary/{entry_id}" "DELETE" "/api/v1/diary/{{entry_id}}" -Token "access_token" -Description "Удаляет запись дневника."

# Progress
$progressBody = @{ measured_at = "2026-10-13"; weight_kg = 72; desired_weight_kg = 68; height_cm = 175; bmi = 23.5; body_fat_pct = $null; fat_mass_kg = $null; muscle_pct = $null; muscle_mass_kg = $null; kcal_target = 2200; protein_target_g = 140; fat_target_g = 70; carbs_target_g = 240; waist_cm = $null; chest_cm = $null; hips_cm = $null; sleep_score = 8; wellbeing_score = 8; comment = "Стартовый замер" }
Add-Request "Progress" "GET /api/v1/progress" "GET" "/api/v1/progress" -Description "Список замеров."
Add-Request "Progress" "POST /api/v1/progress" "POST" "/api/v1/progress" -Token "access_token" -Body $progressBody -Description "Создаёт замер." -CaptureId "progress_id"
Add-Request "Progress" "PUT /api/v1/progress/{entry_id}" "PUT" "/api/v1/progress/{{progress_id}}" -Token "access_token" -Body (Set-BodyField $progressBody "weight_kg" 71.5) -Description "Обновляет замер."
Add-Request "Progress" "DELETE /api/v1/progress/{entry_id}" "DELETE" "/api/v1/progress/{{progress_id}}" -Token "access_token" -Description "Удаляет замер."

# Workouts
$exerciseBody = @{ name = "Goblet squat"; muscle_group = "legs"; default_unit = "kg"; default_sets = 3; default_reps = 12; target_rir = "0-2"; note = $null; description = "Техника выполнения"; photos = @(); video = $null; variants = @(@{ name = "Dumbbell"; machine = $null; equipment = "dumbbell"; description = $null; technique = $null; tips = $null }) }
Add-Request "Workouts" "GET /api/v1/exercises" "GET" "/api/v1/exercises" -Description "Список упражнений."
Add-Request "Workouts" "POST /api/v1/exercises" "POST" "/api/v1/exercises" -Token "trainer_access_token" -Body $exerciseBody -Description "Создаёт упражнение; trainer/admin." -CaptureId "exercise_id"
Add-Request "Workouts" "PUT /api/v1/exercises/{exercise_id}" "PUT" "/api/v1/exercises/{{exercise_id}}" -Token "trainer_access_token" -Body (Set-BodyField $exerciseBody "name" "Goblet squat updated") -Description "Обновляет упражнение; trainer/admin."
Add-Request "Workouts" "DELETE /api/v1/exercises/{exercise_id}" "DELETE" "/api/v1/exercises/{{exercise_id}}" -Token "trainer_access_token" -Description "Удаляет упражнение; trainer/admin."
$equipmentBody = @{ kind = "free_weight"; name = "Dumbbells"; description = "Набор гантелей"; photo = $null }
Add-Request "Workouts" "GET /api/v1/workout-equipment" "GET" "/api/v1/workout-equipment" -Description "Список оборудования."
Add-Request "Workouts" "POST /api/v1/workout-equipment" "POST" "/api/v1/workout-equipment" -Token "trainer_access_token" -Body $equipmentBody -Description "Создаёт оборудование; trainer/admin." -CaptureId "equipment_id"
Add-Request "Workouts" "PUT /api/v1/workout-equipment/{equipment_id}" "PUT" "/api/v1/workout-equipment/{{equipment_id}}" -Token "trainer_access_token" -Body (Set-BodyField $equipmentBody "name" "Dumbbells updated") -Description "Обновляет оборудование; trainer/admin."
Add-Request "Workouts" "DELETE /api/v1/workout-equipment/{equipment_id}" "DELETE" "/api/v1/workout-equipment/{{equipment_id}}" -Token "trainer_access_token" -Description "Удаляет оборудование; trainer/admin."
$planItem = @{ exercise_id = "{{exercise_id}}"; variant_id = "{{variant_id}}"; working_weight = 20; sets = 3; duration_minutes = $null; speed_kmh = $null }
$complexBody = @{ name = "Leg day"; comment = "Базовый комплекс"; photos = @(); video = $null; items = @($planItem) }
Add-Request "Workouts" "GET /api/v1/workout-complexes" "GET" "/api/v1/workout-complexes" -Description "Список комплексов."
Add-Request "Workouts" "POST /api/v1/workout-complexes" "POST" "/api/v1/workout-complexes" -Token "trainer_access_token" -Body $complexBody -Description "Создаёт комплекс; trainer/admin." -CaptureId "complex_id"
Add-Request "Workouts" "PUT /api/v1/workout-complexes/{complex_id}" "PUT" "/api/v1/workout-complexes/{{complex_id}}" -Token "trainer_access_token" -Body (Set-BodyField $complexBody "name" "Leg day updated") -Description "Обновляет комплекс; trainer/admin."
$workoutBody = @{ performed_at = "2026-10-13T18:00:00+03:00"; exercise_id = "{{exercise_id}}"; exercise_name = $null; muscle_group = $null; unit = "kg"; working_weight = 20; sets = 3; reps = 12; rir = "1"; machine_location = $null; comment = $null }
Add-Request "Workouts" "GET /api/v1/workouts" "GET" "/api/v1/workouts" -Description "Журнал выполненных тренировок."
Add-Request "Workouts" "POST /api/v1/workouts" "POST" "/api/v1/workouts" -Token "access_token" -Body $workoutBody -Description "Добавляет запись тренировки." -CaptureId "log_id"
Add-Request "Workouts" "PUT /api/v1/workouts/{log_id}" "PUT" "/api/v1/workouts/{{log_id}}" -Token "access_token" -Body (Set-BodyField $workoutBody "reps" 10) -Description "Обновляет запись тренировки."
Add-Request "Workouts" "DELETE /api/v1/workouts/{log_id}" "DELETE" "/api/v1/workouts/{{log_id}}" -Token "access_token" -Description "Удаляет запись тренировки."
$workoutPlanBody = @{ name = "Monday strength"; scheduled_at = "2026-10-19T18:00:00+03:00"; duration_minutes = 60; items = @($planItem) }
Add-Request "Workouts" "GET /api/v1/workout-plans" "GET" "/api/v1/workout-plans" -Description "Список планов тренировок."
Add-Request "Workouts" "POST /api/v1/workout-plans" "POST" "/api/v1/workout-plans" -Token "access_token" -Body $workoutPlanBody -Description "Создаёт план для текущего пользователя." -CaptureId "plan_id"
Add-Request "Workouts" "PUT /api/v1/workout-plans/{plan_id}" "PUT" "/api/v1/workout-plans/{{plan_id}}" -Token "access_token" -Body (Set-BodyField $workoutPlanBody "name" "Monday strength updated") -Description "Обновляет план."
Add-Request "Workouts" "POST /api/v1/workout-plans/{plan_id}/complete" "POST" "/api/v1/workout-plans/{{plan_id}}/complete" -Token "access_token" -Description "Помечает план выполненным."
Add-Request "Workouts" "POST /api/v1/workout-plans/{plan_id}/cancel" "POST" "/api/v1/workout-plans/{{plan_id}}/cancel" -Token "access_token" -Description "Отменяет план."
Add-Request "Workouts" "DELETE /api/v1/workout-plans/{plan_id}" "DELETE" "/api/v1/workout-plans/{{plan_id}}" -Token "access_token" -Description "Удаляет план."

# Clients & Trainer
Add-Request "Clients & Trainer" "GET /api/v1/clients" "GET" "/api/v1/clients" -Token "trainer_access_token" -Description "Список клиентов; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients" "POST" "/api/v1/clients" -Token "trainer_access_token" -Body @{ email = "client@example.com" } -Description "Назначает существующего пользователя клиентом; trainer/admin." -CaptureId "client_id"
Add-Request "Clients & Trainer" "POST /api/v1/clients/shares" "POST" "/api/v1/clients/shares" -Token "trainer_access_token" -Body @{ client_id = "{{client_id}}"; item_type = "recipe"; item_id = "{{recipe_id}}" } -Description "Отправляет материал клиенту; trainer/admin."
Add-Request "Clients & Trainer" "GET /api/v1/clients/me/chat" "GET" "/api/v1/clients/me/chat" -Token "access_token" -Description "Чат текущего клиента с тренером."
Add-Request "Clients & Trainer" "GET /api/v1/clients/me/trainer" "GET" "/api/v1/clients/me/trainer" -Token "access_token" -Description "Тренер текущего клиента."
Add-Request "Clients & Trainer" "POST /api/v1/clients/me/chat" "POST" "/api/v1/clients/me/chat" -Token "access_token" -Body @{ message = "Здравствуйте! Есть вопрос по плану." } -Description "Сообщение клиента тренеру."
Add-Request "Clients & Trainer" "GET /api/v1/clients/me/shared-items/{item_type}/{item_id}" "GET" "/api/v1/clients/me/shared-items/recipe/{{recipe_id}}" -Token "access_token" -Description "Материал, которым поделился тренер."
Add-Request "Clients & Trainer" "POST /api/v1/clients/me/shares" "POST" "/api/v1/clients/me/shares" -Token "access_token" -Body @{ item_type = "progress"; item_id = "{{progress_id}}" } -Description "Отправляет материал тренеру."
Add-Request "Clients & Trainer" "GET /api/v1/clients/{client_id}" "GET" "/api/v1/clients/{{client_id}}" -Token "trainer_access_token" -Description "Карточка клиента; trainer/admin."
Add-Request "Clients & Trainer" "GET /api/v1/clients/{client_id}/shared-items/{item_type}/{item_id}" "GET" "/api/v1/clients/{{client_id}}/shared-items/recipe/{{recipe_id}}" -Token "trainer_access_token" -Description "Материал клиента; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients/{client_id}/diary" "POST" "/api/v1/clients/{{client_id}}/diary" -Token "trainer_access_token" -Body $diaryBody -Description "Добавляет запись дневника клиента; trainer/admin."
Add-Request "Clients & Trainer" "GET /api/v1/clients/{client_id}/diary" "GET" "/api/v1/clients/{{client_id}}/diary" -Token "trainer_access_token" -Description "Дневник клиента; trainer/admin."
Add-Request "Clients & Trainer" "DELETE /api/v1/clients/{client_id}/diary/{entry_id}" "DELETE" "/api/v1/clients/{{client_id}}/diary/{{entry_id}}" -Token "trainer_access_token" -Description "Удаляет запись дневника клиента; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients/{client_id}/workout-plans" "POST" "/api/v1/clients/{{client_id}}/workout-plans" -Token "trainer_access_token" -Body $workoutPlanBody -Description "Назначает план клиенту; trainer/admin."
Add-Request "Clients & Trainer" "PUT /api/v1/clients/{client_id}/workout-plans/{plan_id}" "PUT" "/api/v1/clients/{{client_id}}/workout-plans/{{plan_id}}" -Token "trainer_access_token" -Body $workoutPlanBody -Description "Обновляет план клиента; trainer/admin."
Add-Request "Clients & Trainer" "PUT /api/v1/clients/{client_id}/nutrition-targets" "PUT" "/api/v1/clients/{{client_id}}/nutrition-targets" -Token "trainer_access_token" -Body @{ kcal_target = 2200; protein_target_g = 140; fat_target_g = 70; carbs_target_g = 240 } -Description "Обновляет цели питания клиента; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients/{client_id}/progress" "POST" "/api/v1/clients/{{client_id}}/progress" -Token "trainer_access_token" -Body $progressBody -Description "Добавляет прогресс клиента; trainer/admin."
Add-Request "Clients & Trainer" "PUT /api/v1/clients/{client_id}/progress/{entry_id}" "PUT" "/api/v1/clients/{{client_id}}/progress/{{progress_id}}" -Token "trainer_access_token" -Body $progressBody -Description "Обновляет прогресс клиента; trainer/admin."
Add-Request "Clients & Trainer" "GET /api/v1/clients/{client_id}/tasks" "GET" "/api/v1/clients/{{client_id}}/tasks" -Token "trainer_access_token" -Query @(@{ key = "week_start"; value = "2026-10-12"; description = "YYYY-MM-DD" }) -Description "Задачи клиента за неделю; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients/{client_id}/tasks" "POST" "/api/v1/clients/{{client_id}}/tasks" -Token "trainer_access_token" -Body @{ week_start = "2026-10-12"; title = "Заполнить дневник"; description = "Все приёмы пищи"; due_date = "2026-10-18" } -Description "Создаёт задачу; trainer/admin." -CaptureId "task_id"
Add-Request "Clients & Trainer" "PUT /api/v1/clients/{client_id}/tasks/{task_id}" "PUT" "/api/v1/clients/{{client_id}}/tasks/{{task_id}}" -Token "trainer_access_token" -Body @{ status = "done" } -Description "Статус задачи open/done; trainer/admin."
Add-Request "Clients & Trainer" "GET /api/v1/clients/{client_id}/chat" "GET" "/api/v1/clients/{{client_id}}/chat" -Token "trainer_access_token" -Description "Чат с клиентом; trainer/admin."
Add-Request "Clients & Trainer" "POST /api/v1/clients/{client_id}/chat" "POST" "/api/v1/clients/{{client_id}}/chat" -Token "trainer_access_token" -Body @{ message = "Не забудьте про тренировку в понедельник." } -Description "Сообщение клиенту; trainer/admin."

# Feedback
Add-Request "Feedback" "GET /api/v1/feedback/unread-count" "GET" "/api/v1/feedback/unread-count" -Token "access_token" -Description "Непрочитанные обращения; admin."
Add-Request "Feedback" "GET /api/v1/feedback" "GET" "/api/v1/feedback" -Token "access_token" -Description "Все обращения; admin."
Add-Request "Feedback" "GET /api/v1/feedback/mine" "GET" "/api/v1/feedback/mine" -Token "access_token" -Description "Обращения текущего пользователя."
Add-Request "Feedback" "POST /api/v1/feedback" "POST" "/api/v1/feedback" -Token "access_token" -Body @{ message = "Предложение по улучшению приложения" } -Description "Создаёт обращение; 1–500 символов." -CaptureId "message_id"
Add-Request "Feedback" "POST /api/v1/feedback/{message_id}/read" "POST" "/api/v1/feedback/{{message_id}}/read" -Token "access_token" -Description "Помечает обращение прочитанным; admin."
Add-Request "Feedback" "POST /api/v1/feedback/{message_id}/reply" "POST" "/api/v1/feedback/{{message_id}}/reply" -Token "access_token" -Body @{ reply = "Спасибо за обратную связь!" } -Description "Отвечает на обращение; admin."

# OAuth / MCP
Add-Request "OAuth / MCP" "GET /.well-known/oauth-authorization-server" "GET" "/.well-known/oauth-authorization-server" -Description "OAuth authorization-server metadata."
Add-Request "OAuth / MCP" "GET /.well-known/oauth-protected-resource/mcp" "GET" "/.well-known/oauth-protected-resource/mcp" -Description "Protected resource metadata для /mcp."
Add-Request "OAuth / MCP" "POST /oauth/register" "POST" "/oauth/register" -Body @{ client_name = "Postman Test Client"; redirect_uris = @("{{redirect_uri}}"); grant_types = @("authorization_code", "refresh_token"); response_types = @("code"); token_endpoint_auth_method = "client_secret_post" } -Description "Dynamic client registration." -CaptureOAuthClient
Add-Request "OAuth / MCP" "GET /oauth/authorize" "GET" "/oauth/authorize" -Query @(
    @{ key = "client_id"; value = "{{oauth_client_id}}" },
    @{ key = "redirect_uri"; value = "{{redirect_uri}}" },
    @{ key = "response_type"; value = "code" },
    @{ key = "code_challenge"; value = "{{code_challenge}}" },
    @{ key = "code_challenge_method"; value = "S256" },
    @{ key = "scope"; value = "recipes:read recipes:write" }
) -Description "Authorization code + PKCE start."
Add-Request "OAuth / MCP" "GET /oauth/login" "GET" "/oauth/login" -Query @(@{ key = "request"; value = "{{oauth_request_id}}" }) -Description "HTML login form for pending OAuth request."
Add-Request "OAuth / MCP" "POST /oauth/login" "POST" "/oauth/login" -FormFields @(
    @{ key = "request"; value = "{{oauth_request_id}}" },
    @{ key = "email"; value = "{{admin_email}}" },
    @{ key = "password"; value = "{{admin_password}}" }
) -Description "OAuth login form; application/x-www-form-urlencoded."
Add-Request "OAuth / MCP" "POST /oauth/token" "POST" "/oauth/token" -FormFields @(
    @{ key = "grant_type"; value = "authorization_code" },
    @{ key = "code"; value = "{{oauth_code}}" },
    @{ key = "redirect_uri"; value = "{{redirect_uri}}" },
    @{ key = "client_id"; value = "{{oauth_client_id}}" },
    @{ key = "code_verifier"; value = "{{code_verifier}}" }
) -Description "Обменивает authorization code на токены." -SaveMcpTokens
Add-Request "OAuth / MCP" "POST /oauth/revoke" "POST" "/oauth/revoke" -FormFields @(
    @{ key = "token"; value = "{{refresh_token}}" },
    @{ key = "token_type_hint"; value = "refresh_token" }
) -Description "Отзывает refresh token."
Add-Request "OAuth / MCP" "POST /mcp" "POST" "/mcp" -Token "mcp_access_token" -Body @{ jsonrpc = "2.0"; id = 1; method = "tools/list"; params = @{} } -ExtraHeaders @(@{ key = "Accept"; value = "application/json, text/event-stream" }) -Description "Streamable HTTP MCP endpoint; требует OAuth access token."

$collection = [ordered]@{
    info = [ordered]@{
        _postman_id = "6ee5d4a2-46f4-46c8-a595-9f06bd9d0d0e"
        name = "Astra Nutrition OS API"
        description = "Полная коллекция текущих REST, OAuth и MCP маршрутов Astra Nutrition OS. Синхронизирована с backend/routers и backend/schemas.py."
        schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    }
    item = @($folders.Values)
    variable = @($variables | ForEach-Object { [ordered]@{ key = $_.key; value = $_.value; type = "string" } })
}

$collection | ConvertTo-Json -Depth 30 | Set-Content -Path $collectionPath -Encoding UTF8
$requestCount = ($folders.Values | ForEach-Object { $_.item.Count } | Measure-Object -Sum).Sum
Write-Output "Generated $requestCount requests in $collectionPath"

$personalAccountCollectionPath = Join-Path (Get-Location) "postman\Astra_Nutrition_OS_Personal_Account.postman_collection.json"
$personalAccountCollection = [ordered]@{
    info = [ordered]@{
        _postman_id = "b73b6821-714d-4da3-8cdd-cab120261023"
        name = "Astra Nutrition OS — Personal Account API"
        description = "REST-запросы личного кабинета: профиль, аватар, пароль и подтверждение email."
        schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    }
    item = @($folders["Authentication"], $folders["Personal Account"])
    variable = @($variables | ForEach-Object { [ordered]@{ key = $_.key; value = $_.value; type = "string" } })
}
$personalAccountCollection | ConvertTo-Json -Depth 30 | Set-Content -Path $personalAccountCollectionPath -Encoding UTF8
Write-Output "Generated personal account collection in $personalAccountCollectionPath"
