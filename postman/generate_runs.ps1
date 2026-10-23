$ErrorActionPreference = "Stop"

$postmanRoot = Join-Path (Get-Location) "postman"
$baseUrl = "{{base_url}}"

function New-Url([string]$path, [array]$query = @()) {
    $cleanPath = $path.TrimStart("/")
    $raw = "$baseUrl/$cleanPath"
    if ($query.Count -gt 0) {
        $raw += "?" + (($query | ForEach-Object { "$($_.key)=$($_.value)" }) -join "&")
    }
    $url = [ordered]@{ raw = $raw; host = @($baseUrl); path = @($cleanPath -split "/") }
    if ($query.Count -gt 0) { $url.query = @($query) }
    return $url
}

function New-StatusTest([int]$status) {
    return @(
        "pm.test(`"HTTP status is $status`", function () {",
        "  pm.response.to.have.status($status);",
        "});"
    )
}

function New-CaptureTokenTest([string]$variable) {
    return @(
        "try {",
        "  const payload = pm.response.json();",
        "  if (payload.access_token) pm.collectionVariables.set(`"$variable`", payload.access_token);",
        "} catch (error) {}"
    )
}

function New-CaptureIdTest([string]$variable) {
    return @(
        "try {",
        "  const payload = pm.response.json();",
        "  const item = Array.isArray(payload) ? payload[0] : payload;",
        "  if (item && item.id !== undefined) pm.collectionVariables.set(`"$variable`", String(item.id));",
        "} catch (error) {}"
    )
}

function New-SeedScript {
    return @(
        "const suffix = Date.now().toString();",
        "pm.collectionVariables.set('run_suffix', suffix);",
        "pm.collectionVariables.set('run_client_email', 'postman-run-client-' + suffix + '@example.com');",
        "pm.collectionVariables.set('run_product_name', 'Postman run product ' + suffix);",
        "pm.collectionVariables.set('run_recipe_name', 'Postman run recipe ' + suffix);"
    )
}

function New-JsonBody([object]$body) {
    return [ordered]@{
        mode = "raw"
        raw = ($body | ConvertTo-Json -Depth 20)
        options = [ordered]@{ raw = [ordered]@{ language = "json" } }
    }
}

function Set-BodyField([object]$Body, [string]$Key, [object]$Value) {
    $copy = [ordered]@{}
    foreach ($property in $Body.GetEnumerator()) { $copy[$property.Key] = $property.Value }
    $copy[$Key] = $Value
    return $copy
}

function Add-Request {
    param(
        [object]$Collection,
        [string]$Folder,
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string]$Token = "",
        [object]$Body = $null,
        [array]$Query = @(),
        [int]$Expected = 200,
        [array]$Test = @(),
        [array]$PreRequest = @(),
        [array]$ExtraHeaders = @(),
        [switch]$FormData
    )
    $headers = @($ExtraHeaders)
    $request = [ordered]@{ method = $Method; header = @(); url = New-Url $Path $Query }
    if ($FormData) {
        $request.body = [ordered]@{ mode = "formdata"; formdata = @(@{ key = "image"; type = "file"; src = "" }) }
    } elseif ($null -ne $Body) {
        $request.body = New-JsonBody $Body
        $headers += @{ key = "Content-Type"; value = "application/json" }
    }
    if ($Token) {
        $request.auth = [ordered]@{ type = "bearer"; bearer = @(@{ key = "token"; value = "{{${Token}}}"; type = "string" }) }
    }
    $request.header = @($headers)
    $item = [ordered]@{ name = $Name; request = $request; response = @() }
    $tests = @(New-StatusTest $Expected) + @($Test)
    $item.event = @(@{ listen = "test"; script = @{ type = "text/javascript"; exec = @($tests) } })
    if ($PreRequest.Count -gt 0) {
        $item.event += @(@{ listen = "prerequest"; script = @{ type = "text/javascript"; exec = @($PreRequest) } })
    }
    $Collection.folders[$Folder].item += $item
}

function New-RunCollection([string]$name, [string]$description, [string]$fileName, [array]$folderNames, [array]$variables) {
    $folders = [ordered]@{}
    foreach ($folderName in $folderNames) {
        $folders[$folderName] = [ordered]@{ name = $folderName; item = @() }
    }
    $collection = [ordered]@{
        info = [ordered]@{
            _postman_id = [guid]::NewGuid().ToString()
            name = $name
            description = $description
            schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        }
        item = @($folders.Values)
        variable = @($variables | ForEach-Object { [ordered]@{ key = $_.key; value = $_.value; type = "string" } })
    }
    $collection.folders = $folders
    return $collection
}

function Save-RunCollection([object]$collection, [string]$fileName) {
    $output = [ordered]@{
        info = $collection.info
        item = @($collection.folders.Values)
        variable = $collection.variable
    }
    $output | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $postmanRoot $fileName) -Encoding UTF8
}

$commonVariables = @(
    @{ key = "base_url"; value = "http://204.168.255.69:8787" },
    @{ key = "admin_email"; value = "admin@example.com" },
    @{ key = "admin_password"; value = "Password123!" },
    @{ key = "trainer_email"; value = "trainer@example.com" },
    @{ key = "trainer_password"; value = "TrainerPassword123!" },
    @{ key = "run_client_email"; value = "" },
    @{ key = "run_client_password"; value = "Password123!" },
    @{ key = "run_client_token"; value = "" },
    @{ key = "admin_token"; value = "" },
    @{ key = "trainer_token"; value = "" },
    @{ key = "run_suffix"; value = "" },
    @{ key = "run_product_name"; value = "" },
    @{ key = "run_recipe_name"; value = "" },
    @{ key = "flow_client_id"; value = "" },
    @{ key = "flow_product_id"; value = "" },
    @{ key = "flow_recipe_id"; value = "" },
    @{ key = "flow_entry_id"; value = "" },
    @{ key = "flow_progress_id"; value = "" }
)

# Positive smoke run
$positive = New-RunCollection "Astra Nutrition OS — Positive run" "Позитивный smoke-run: доступность, авторизация, публичные GET и роли." "Astra_Nutrition_OS_Run_Positive.postman_collection.json" @("Smoke", "Admin", "Trainer") $commonVariables
Add-Request $positive "Smoke" "GET /api/health" "GET" "/api/health" -Expected 200
Add-Request $positive "Admin" "POST /api/v1/auth/login (admin)" "POST" "/api/v1/auth/login" -Body @{ email = "{{admin_email}}"; password = "{{admin_password}}" } -Expected 200 -Test (New-CaptureTokenTest "admin_token")
Add-Request $positive "Admin" "GET /api/v1/auth/me" "GET" "/api/v1/auth/me" -Token "admin_token" -Expected 200
Add-Request $positive "Admin" "GET /api/v1/dashboard" "GET" "/api/v1/dashboard" -Token "admin_token" -Expected 200
Add-Request $positive "Admin" "GET /api/v1/products" "GET" "/api/v1/products" -Token "admin_token" -Expected 200
Add-Request $positive "Admin" "GET /api/v1/recipes" "GET" "/api/v1/recipes" -Token "admin_token" -Expected 200
Add-Request $positive "Admin" "GET /api/v1/articles" "GET" "/api/v1/articles" -Token "admin_token" -Expected 200
Add-Request $positive "Admin" "GET /api/v1/categories" "GET" "/api/v1/categories" -Query @(@{ key = "kind"; value = "recipe" }) -Token "admin_token" -Expected 200
Add-Request $positive "Trainer" "POST /api/v1/auth/login (trainer)" "POST" "/api/v1/auth/login" -Body @{ email = "{{trainer_email}}"; password = "{{trainer_password}}" } -Expected 200 -Test (New-CaptureTokenTest "trainer_token")
Add-Request $positive "Trainer" "GET /api/v1/clients" "GET" "/api/v1/clients" -Token "trainer_token" -Expected 200
Add-Request $positive "Trainer" "GET /api/v1/exercises" "GET" "/api/v1/exercises" -Token "trainer_token" -Expected 200

# Negative run
$negative = New-RunCollection "Astra Nutrition OS — Negative run" "Негативные сценарии: 401/403/404/400/422 и проверка ролей." "Astra_Nutrition_OS_Run_Negative.postman_collection.json" @("Unauthorized", "Validation", "Forbidden", "Not found") $commonVariables
Add-Request $negative "Unauthorized" "GET /api/v1/auth/me without token" "GET" "/api/v1/auth/me" -Expected 401
Add-Request $negative "Unauthorized" "POST /api/v1/auth/login with wrong password" "POST" "/api/v1/auth/login" -Body @{ email = "{{admin_email}}"; password = "wrong-password" } -Expected 401
Add-Request $negative "Validation" "POST /api/v1/auth/register invalid email" "POST" "/api/v1/auth/register" -Body @{ email = "not-an-email"; password = "Password123!" } -Expected 400
Add-Request $negative "Validation" "POST /api/v1/auth/register short password" "POST" "/api/v1/auth/register" -Body @{ email = "invalid-password@example.com"; password = "short" } -Expected 400
Add-Request $negative "Validation" "POST /api/v1/auth/register ordinary user for role checks" "POST" "/api/v1/auth/register" -Body @{ email = "{{run_client_email}}"; password = "{{run_client_password}}" } -Expected 201 -PreRequest (New-SeedScript) -Test (New-CaptureTokenTest "run_client_token")
Add-Request $negative "Forbidden" "GET /api/v1/clients with ordinary user" "GET" "/api/v1/clients" -Token "run_client_token" -Expected 403
Add-Request $negative "Forbidden" "POST /api/v1/products with ordinary user" "POST" "/api/v1/products" -Token "run_client_token" -Body @{ name = "Should be forbidden" } -Expected 403
Add-Request $negative "Validation" "POST /api/v1/auth/login (admin for validation)" "POST" "/api/v1/auth/login" -Body @{ email = "{{admin_email}}"; password = "{{admin_password}}" } -Expected 200 -Test (New-CaptureTokenTest "admin_token")
Add-Request $negative "Validation" "POST /api/v1/products missing required name" "POST" "/api/v1/products" -Token "admin_token" -Body @{ category = "invalid" } -Expected 422
Add-Request $negative "Validation" "GET /api/v1/categories with unknown kind" "GET" "/api/v1/categories" -Token "admin_token" -Query @(@{ key = "kind"; value = "unknown" }) -Expected 400
Add-Request $negative "Validation" "POST /api/v1/recipes/{recipe_id}/moderation invalid action" "POST" "/api/v1/recipes/1/moderation" -Token "admin_token" -Body @{ action = "approve"; note = "Invalid action" } -Expected 400
Add-Request $negative "Validation" "GET /api/v1/clients/{client_id}/tasks without week_start" "GET" "/api/v1/clients/1/tasks" -Token "admin_token" -Expected 422
Add-Request $negative "Not found" "GET /api/v1/recipes/{recipe_id} unknown ID" "GET" "/api/v1/recipes/999999999" -Token "admin_token" -Expected 404
Add-Request $negative "Not found" "DELETE /api/v1/products/{product_id} unknown ID" "DELETE" "/api/v1/products/999999999" -Token "admin_token" -Expected 404
# Sequential flows
$sequential = New-RunCollection "Astra Nutrition OS — Sequential flows" "Сквозные сценарии с передачей токенов и ID между запросами." "Astra_Nutrition_OS_Run_Sequential.postman_collection.json" @("Flow 1 — Client", "Flow 2 — Recipe CRUD", "Flow 3 — Diary CRUD", "Flow 4 — Progress CRUD") $commonVariables

# Flow 1: configured trainer login -> register client -> add client -> open client.
Add-Request $sequential "Flow 1 — Client" "01 Register disposable client" "POST" "/api/v1/auth/register" -Body @{ email = "{{run_client_email}}"; password = "{{run_client_password}}" } -Expected 201 -PreRequest (New-SeedScript) -Test (New-CaptureTokenTest "run_client_token")
Add-Request $sequential "Flow 1 — Client" "02 Login configured trainer" "POST" "/api/v1/auth/login" -Body @{ email = "{{trainer_email}}"; password = "{{trainer_password}}" } -Expected 200 -Test (New-CaptureTokenTest "trainer_token")
Add-Request $sequential "Flow 1 — Client" "03 Add client to trainer" "POST" "/api/v1/clients" -Token "trainer_token" -Body @{ email = "{{run_client_email}}" } -Expected 201 -Test (New-CaptureIdTest "flow_client_id")
Add-Request $sequential "Flow 1 — Client" "04 Open client" "GET" "/api/v1/clients/{{flow_client_id}}" -Token "trainer_token" -Expected 200

# Flow 2: create product -> create/open/edit/delete recipe -> delete product.
$flowProduct = @{ name = "{{run_product_name}}"; category = "Postman run"; unit = "g"; kcal = 370; protein_g = 13; fat_g = 7; carbs_g = 62; data_status = "Confirmed"; measures = @() }
$flowRecipe = @{ category = "Breakfast"; name = "{{run_recipe_name}}"; servings = 1; yield_g = 300; ingredients = @(@{ product_id = "{{flow_product_id}}"; quantity = 80; unit = "g" }) }
Add-Request $sequential "Flow 2 — Recipe CRUD" "01 Login admin" "POST" "/api/v1/auth/login" -Body @{ email = "{{admin_email}}"; password = "{{admin_password}}" } -Expected 200 -Test (New-CaptureTokenTest "admin_token")
Add-Request $sequential "Flow 2 — Recipe CRUD" "02 Create product" "POST" "/api/v1/products" -Token "admin_token" -Body $flowProduct -Expected 201 -Test (New-CaptureIdTest "flow_product_id")
Add-Request $sequential "Flow 2 — Recipe CRUD" "03 Create recipe" "POST" "/api/v1/recipes" -Token "admin_token" -Body $flowRecipe -Expected 201 -Test (New-CaptureIdTest "flow_recipe_id")
Add-Request $sequential "Flow 2 — Recipe CRUD" "04 Open recipe" "GET" "/api/v1/recipes/{{flow_recipe_id}}" -Token "admin_token" -Expected 200
Add-Request $sequential "Flow 2 — Recipe CRUD" "05 Edit recipe" "PUT" "/api/v1/recipes/{{flow_recipe_id}}" -Token "admin_token" -Body (Set-BodyField $flowRecipe "name" "{{run_recipe_name}} edited") -Expected 200
Add-Request $sequential "Flow 2 — Recipe CRUD" "06 Delete recipe" "DELETE" "/api/v1/recipes/{{flow_recipe_id}}" -Token "admin_token" -Expected 200
Add-Request $sequential "Flow 2 — Recipe CRUD" "07 Delete product" "DELETE" "/api/v1/products/{{flow_product_id}}" -Token "admin_token" -Expected 200

# Flow 3: create/open/edit/delete diary entry using a custom dish.
$diaryBody = @{ entry_date = "2026-10-13"; meal_type = "lunch"; custom_dish = @{ name = "Postman run dish"; kcal = 500; protein_g = 30; fat_g = 15; carbs_g = 55 }; servings = 1; comment = "Sequential run" }
Add-Request $sequential "Flow 3 — Diary CRUD" "01 Create diary entry" "POST" "/api/v1/diary" -Token "run_client_token" -Body $diaryBody -Expected 201 -Test (New-CaptureIdTest "flow_entry_id")
Add-Request $sequential "Flow 3 — Diary CRUD" "02 Open diary" "GET" "/api/v1/diary" -Token "run_client_token" -Expected 200
Add-Request $sequential "Flow 3 — Diary CRUD" "03 Edit diary entry" "PUT" "/api/v1/diary/{{flow_entry_id}}" -Token "run_client_token" -Body (Set-BodyField $diaryBody "comment" "Edited by sequential run") -Expected 200
Add-Request $sequential "Flow 3 — Diary CRUD" "04 Delete diary entry" "DELETE" "/api/v1/diary/{{flow_entry_id}}" -Token "run_client_token" -Expected 200

# Flow 4: create/open/edit/delete progress entry.
$progressBody = @{ measured_at = "2026-10-13"; weight_kg = 72; height_cm = 175; kcal_target = 2200; protein_target_g = 140; fat_target_g = 70; carbs_target_g = 240 }
Add-Request $sequential "Flow 4 — Progress CRUD" "01 Create progress" "POST" "/api/v1/progress" -Token "run_client_token" -Body $progressBody -Expected 201 -Test (New-CaptureIdTest "flow_progress_id")
Add-Request $sequential "Flow 4 — Progress CRUD" "02 Open progress list" "GET" "/api/v1/progress" -Token "run_client_token" -Expected 200
Add-Request $sequential "Flow 4 — Progress CRUD" "03 Edit progress" "PUT" "/api/v1/progress/{{flow_progress_id}}" -Token "run_client_token" -Body (Set-BodyField $progressBody "weight_kg" 71.5) -Expected 200
Add-Request $sequential "Flow 4 — Progress CRUD" "04 Delete progress" "DELETE" "/api/v1/progress/{{flow_progress_id}}" -Token "run_client_token" -Expected 200

Save-RunCollection $positive "Astra_Nutrition_OS_Run_Positive.postman_collection.json"
Save-RunCollection $negative "Astra_Nutrition_OS_Run_Negative.postman_collection.json"
Save-RunCollection $sequential "Astra_Nutrition_OS_Run_Sequential.postman_collection.json"
Write-Output "Generated Postman run collections in $postmanRoot"
