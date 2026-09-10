package com.astra.nutrition

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Fastfood
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalGroceryStore
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.geometry.Offset
import androidx.compose.foundation.layout.RowScope
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.CircularProgressIndicator
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.time.LocalDate
import org.json.JSONObject

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val state = remember { AstraState(applicationContext) }
            AstraTheme(darkTheme = state.darkTheme) { AstraRoot(state) }
        }
    }
}

class AstraState(context: android.content.Context) {
    private val preferences = context.getSharedPreferences("astra_preferences", android.content.Context.MODE_PRIVATE)
    val api = ApiClient(context)
    var user by mutableStateOf<AuthUser?>(null)
    var restoring by mutableStateOf(true)
    var busy by mutableStateOf(false)
    var error by mutableStateOf<String?>(null)
    var darkTheme by mutableStateOf(preferences.getBoolean("dark_theme", true))

    fun toggleTheme(value: Boolean) {
        darkTheme = value
        preferences.edit().putBoolean("dark_theme", value).apply()
    }

    suspend fun restore() {
        if (api.token != null) suspendResult { user = api.me() }.onFailure { api.token = null }
        restoring = false
    }

    suspend fun authenticate(email: String, password: String, register: Boolean): Boolean {
        busy = true; error = null
        val result = suspendResult { api.login(email, password, register) }
        busy = false
        result.onSuccess { api.token = it.token; user = it.user }.onFailure { error = it.message ?: "Не удалось войти" }
        return result.isSuccess
    }
}

suspend fun <T> suspendResult(block: suspend () -> T): Result<T> = try {
    Result.success(block())
} catch (error: Throwable) {
    Result.failure(error)
}

enum class Screen { Overview, Diary, Products, Recipes, More, Progress, Workouts, Trainer, Information, Catalog }

@Composable
fun AstraRoot(state: AstraState) {
    LaunchedEffect(Unit) { state.restore() }
    when {
        state.restoring -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        state.user == null -> LoginScreen(state)
        else -> MobileScaffold(state)
    }
}

@Composable
fun LoginScreen(state: AstraState) {
    var register by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background), contentAlignment = Alignment.Center) {
        Card(Modifier.fillMaxWidth().padding(20.dp), shape = RoundedCornerShape(24.dp), colors = CardDefaults.cardColors(MaterialTheme.colorScheme.surface)) {
            Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Restaurant, null, tint = AstraTheme.green, modifier = Modifier.size(40.dp))
                    Spacer(Modifier.width(10.dp))
                    Column { Text("Astra Nutrition OS", fontSize = 22.sp, fontWeight = FontWeight.Bold); Text("PERSONAL WORKSPACE", style = MaterialTheme.typography.labelSmall, color = AstraTheme.muted) }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ChoiceButton("Вход", !register) { register = false }
                    ChoiceButton("Регистрация", register) { register = true }
                }
                OutlinedTextField(email, { email = it }, label = { Text("Email") }, singleLine = true, modifier = Modifier.fillMaxWidth(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email))
                OutlinedTextField(password, { password = it }, label = { Text("Пароль") }, singleLine = true, modifier = Modifier.fillMaxWidth(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password))
                state.error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
                Button(onClick = { scope.launch { state.authenticate(email, password, register) } }, enabled = !state.busy && email.isNotBlank() && password.length >= 8, modifier = Modifier.fillMaxWidth()) {
                    if (state.busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text(if (register) "Создать аккаунт" else "Войти")
                }
            }
        }
    }
}

@Composable
private fun RowScope.ChoiceButton(label: String, active: Boolean, onClick: () -> Unit) {
    if (active) OutlinedButton(onClick, Modifier.weight(1f), colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue)) { Text(label) }
    else OutlinedButton(onClick, Modifier.weight(1f)) { Text(label) }
}

@Composable
fun MainScaffold(state: AstraState) {
    var screen by remember { mutableStateOf(Screen.Overview) }
    val bottom = listOf(Screen.Overview, Screen.Diary, Screen.Products, Screen.Recipes, Screen.More)
    Scaffold(bottomBar = {
        NavigationBar {
            for (item in bottom) {
                NavigationBarItem(selected = screen == item, onClick = { screen = item }, icon = { Icon(item.icon(), null) }, label = { Text(item.title()) })
            }
        }
    }) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when (screen) {
                Screen.Overview -> DashboardScreen(state)
                Screen.Diary -> DiaryCalendarScreen(state)
                Screen.Products -> ProductsScreen(state)
                Screen.Recipes -> RecipesScreen(state)
                Screen.Progress -> ProgressScreen(state)
                Screen.Workouts -> WorkoutsScreen(state)
                Screen.More -> MoreScreen(state) { screen = it }
                else -> MoreScreen(state) { screen = it }
            }
        }
    }
}

private fun Screen.title() = when (this) { Screen.Overview -> "Обзор"; Screen.Diary -> "Дневник"; Screen.Products -> "Продукты"; Screen.Recipes -> "Рецепты"; Screen.More -> "Ещё"; Screen.Progress -> "Прогресс"; Screen.Workouts -> "Тренировки"; else -> "Раздел" }
private fun Screen.icon() = when (this) { Screen.Overview -> Icons.Default.Home; Screen.Diary -> Icons.Default.Restaurant; Screen.Products -> Icons.Default.LocalGroceryStore; Screen.Recipes -> Icons.Default.Book; Screen.More -> Icons.Default.MoreHoriz; Screen.Progress -> Icons.Default.TrendingUp; Screen.Workouts -> Icons.Default.FitnessCenter; else -> Icons.Default.MoreHoriz }

@Composable
private fun Page(title: String, subtitle: String? = null, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) { Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold); subtitle?.let { Text(it, color = AstraTheme.muted) } }
        content()
    }
}

@Composable
private fun AstraCard(content: @Composable () -> Unit) {
    Card(Modifier.fillMaxWidth().border(1.dp, AstraTheme.line, RoundedCornerShape(16.dp)), shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(MaterialTheme.colorScheme.surface), elevation = CardDefaults.cardElevation(1.dp)) { content() }
}

@Composable
fun <T> MobileItemGrid(values: List<T>, modifier: Modifier = Modifier, content: @Composable (T) -> Unit) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        values.chunked(2).forEach { rowValues ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                rowValues.forEach { value -> Box(Modifier.weight(1f)) { content(value) } }
                if (rowValues.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun RowScope.Metric(label: String, value: String, color: Color) {
    Column(Modifier.weight(1f).background(color.copy(alpha = .12f), RoundedCornerShape(14.dp)).padding(12.dp)) { Text(label.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AstraTheme.muted); Spacer(Modifier.height(5.dp)); Text(value, fontSize = 19.sp, fontWeight = FontWeight.Bold) }
}

@Composable
fun DashboardScreen(state: AstraState) {
    var data by remember { mutableStateOf<Dashboard?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { data = state.api.dashboard() }.onFailure { error = it.message } }
    Page("Обзор", "Твоя система питания и движения") {
        if (data == null && error == null) Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        data?.let { dashboard ->
            Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Продукты", dashboard.products.toString(), AstraTheme.blue); Metric("Рецепты", dashboard.recipes.toString(), AstraTheme.green) }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Одобрено", dashboard.approved.toString(), AstraTheme.blue); Metric("Вес", dashboard.latest?.weight.shown(" кг"), AstraTheme.blue) }
                dashboard.latest?.let { latest ->
                    AstraCard { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { Text("Последний замер", fontWeight = FontWeight.Bold); Text(latest.date, color = AstraTheme.muted); Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Талия", latest.waist.shown(" см"), AstraTheme.green); Metric("ИМТ", latest.bmi.shown(), AstraTheme.blue) } } }
                }
                Text("Рецепты с высоким белком", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                for (recipe in dashboard.top) { RecipeListItem(recipe) }
            }
        }
    }
}

@Composable
private fun RecipeListItem(recipe: Recipe, onClick: (() -> Unit)? = null) {
    AstraCard {
        Column(Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable { onClick() } else Modifier).padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Icon(Icons.Default.Fastfood, null, tint = AstraTheme.green)
            Text(recipe.name, fontWeight = FontWeight.Bold, maxLines = 3)
            Text(recipe.category, color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
            Text("Б ${recipe.protein.shown(" г")} · ${recipe.kcal.shown(" ккал")}", color = AstraTheme.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
    }
}

@Composable
private fun MobileProductCard(product: Product) {
    AstraCard {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.green)
            Text(product.name, fontWeight = FontWeight.Bold, maxLines = 3)
            Text(product.category ?: "Без категории", color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
            Text("Б ${product.protein.shown(" г")} · ${product.kcal.shown(" ккал")}", color = AstraTheme.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
    }
}

@Composable
fun DiaryScreen(state: AstraState) {
    var entries by remember { mutableStateOf<List<DiaryEntry>>(emptyList()) }
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }
    var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }
    var showAdd by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    suspend fun load() { suspendResult { entries = state.api.diary(); products = state.api.products(); recipes = state.api.recipes(); error = null }.onFailure { error = it.message } }
    LaunchedEffect(Unit) { load() }
    Page("Дневник", "Фиксируй питание без лишних шагов") {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.End) { Button({ showAdd = true }) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(4.dp)); Text("Добавить") } }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        if (entries.isEmpty() && error == null) EmptyMessage("Записей пока нет", "Добавь первый продукт или рецепт.")
        else LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(entries, key = { it.id }) { entry ->
            AstraCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(if (entry.itemType == "product") Icons.Default.LocalGroceryStore else Icons.Default.Restaurant, null, tint = AstraTheme.green); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(entry.name ?: "Без названия", fontWeight = FontWeight.Bold); Text("${entry.meal ?: "Приём пищи"} · ${entry.kcal.shown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp) }; IconButton({ stateErrorDelete(state, entry.id) { load() } }) { Icon(Icons.Default.Delete, "Удалить") } } }
        } }
    }
    if (showAdd) AddDiaryDialog(products, recipes, { date, meal, product, recipe, amount -> loadAndClose(state, date, meal, product, recipe, amount) { showAdd = false } }, { showAdd = false })
}

private fun stateErrorDelete(state: AstraState, id: Int, onDone: suspend () -> Unit) { kotlinx.coroutines.MainScope().launch { suspendResult { state.api.deleteDiary(id); onDone() } } }
private fun loadAndClose(state: AstraState, date: String, meal: String, product: Product?, recipe: Recipe?, amount: Double, close: () -> Unit) { kotlinx.coroutines.MainScope().launch { suspendResult { state.api.addDiary(date, meal, product?.id, recipe?.id, amount); close() } } }

@Composable
fun AddDiaryDialog(products: List<Product>, recipes: List<Recipe>, onSave: (String, String, Product?, Recipe?, Double) -> Unit, onDismiss: () -> Unit) {
    var productMode by remember { mutableStateOf(true) }
    var date by remember { mutableStateOf(today()) }
    var meal by remember { mutableStateOf("Завтрак") }
    var amount by remember { mutableStateOf("1") }
    var product by remember { mutableStateOf(products.firstOrNull()) }
    var recipe by remember { mutableStateOf(recipes.firstOrNull()) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("В дневник") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { ChoiceButton("Продукт", productMode) { productMode = true }; ChoiceButton("Рецепт", !productMode) { productMode = false } }
            OutlinedTextField(date, { date = it }, label = { Text("Дата YYYY-MM-DD") }, singleLine = true)
            Picker("Приём: $meal", listOf("Завтрак", "Обед", "Ужин", "Перекус", "Напиток", "Десерт")) { meal = it }
            if (productMode) Picker("Продукт: ${product?.name ?: "—"}", products.map { it.name }) { product = products.firstOrNull { p -> p.name == it } }
            else Picker("Рецепт: ${recipe?.name ?: "—"}", recipes.map { it.name }) { recipe = recipes.firstOrNull { r -> r.name == it } }
            OutlinedTextField(amount, { amount = it }, label = { Text(if (productMode) "Количество, г" else "Порций") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
        }
    }, confirmButton = { Button({ onSave(date, meal, if (productMode) product else null, if (productMode) null else recipe, amount.toDoubleOrNull() ?: 1.0) }) { Text("Добавить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
fun Picker(label: String, options: List<String>, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton({ expanded = true }, Modifier.fillMaxWidth()) { Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, Modifier.weight(1f)); Text("⌄") } }
        DropdownMenu(expanded, { expanded = false }) { for (option in options) { DropdownMenuItem({ Text(option) }, { expanded = false; onSelect(option) }) } }
    }
}

@Composable
fun ProductsScreen(state: AstraState) {
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }
    var search by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { products = state.api.products() }.onFailure { error = it.message } }
    Page("Продукты", "Каталог с пищевой ценностью") {
        OutlinedTextField(search, { search = it }, label = { Text("Найти продукт") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        MobileItemGrid(products.filter { search.isBlank() || it.name.contains(search, true) }, modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) { product ->
            MobileProductCard(product)
        } }
    }

@Composable
fun RecipesScreen(state: AstraState) {
    var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }
    var search by rememberSaveable { mutableStateOf("") }
    var selected by remember { mutableStateOf<Recipe?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { recipes = suspendResult { state.api.recipes() }.getOrDefault(emptyList()) }
    selected?.let { recipe ->
        MobileRecipeDetailScreen(
            state = state,
            recipe = recipe,
            onBack = { selected = null },
            onShare = {
                scope.launch {
                    suspendResult { state.api.shareToTrainer("recipe", recipe.id) }
                        .onFailure { error = it.message }
                }
            },
            canEdit = false,
            canShareToTrainer = state.user?.isAdmin != true && state.user?.isTrainer != true,
            canShareToClient = false
        )
    } ?: Page("Рецепты", "Собирай рацион из проверенных блюд") {
        OutlinedTextField(search, { search = it }, label = { Text("Найти рецепт") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
        error?.let { Text(it, color = androidx.compose.material3.MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        MobileItemGrid(recipes.filter { search.isBlank() || it.name.contains(search, true) }, modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) { recipe -> RecipeListItem(recipe) { selected = recipe } }
    }
}

@Composable
private fun RecipeDetailDialog(state: AstraState, recipe: Recipe, onDismiss: () -> Unit) {
    var detail by remember { mutableStateOf<RecipeDetail?>(null) }
    LaunchedEffect(recipe.id) { detail = suspendResult { state.api.recipe(recipe.id) }.getOrNull() }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(recipe.name) }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("${recipe.kcal.shown(" ккал")} · Б ${recipe.protein.shown(" г")} · Ж ${recipe.fat.shown(" г")} · У ${recipe.carbs.shown(" г")}", color = AstraTheme.muted)
            Divider()
            Text("Ингредиенты", fontWeight = FontWeight.Bold)
            if (detail == null) CircularProgressIndicator(Modifier.size(22.dp))
            else for (ingredient in detail!!.ingredients) Text("${ingredient.name} — ${ingredient.quantity.shown()} ${ingredient.unit ?: ""}")
        }
    }, confirmButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

@Composable
fun MoreScreen(state: AstraState, onNavigate: (Screen) -> Unit) {
    var showAPI by remember { mutableStateOf(false) }
    var apiURL by remember { mutableStateOf(state.api.baseUrl) }
    Page("Ещё", "Профиль и дополнительные разделы") {
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { AstraCard { ListItem(headlineContent = { Text("Замеры и цели") }, leadingContent = { Icon(Icons.Default.TrendingUp, null) }, modifier = Modifier.clickable { onNavigate(Screen.Progress) }) } }
            item { AstraCard { ListItem(headlineContent = { Text("Журнал тренировок") }, leadingContent = { Icon(Icons.Default.FitnessCenter, null) }, modifier = Modifier.clickable { onNavigate(Screen.Workouts) }) } }
            item { AstraCard { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { Text(state.user?.email ?: "—", fontWeight = FontWeight.Bold); Text("Настройки", color = AstraTheme.muted); OutlinedButton({ showAPI = true }) { Icon(Icons.Default.Settings, null); Spacer(Modifier.width(6.dp)); Text("Адрес API") }; TextButton({ kotlinx.coroutines.MainScope().launch { state.api.logout(); state.user = null } }) { Icon(Icons.Default.ArrowBack, null); Spacer(Modifier.width(6.dp)); Text("Выйти") } } } }
        }
    }
    if (showAPI) AlertDialog(onDismissRequest = { showAPI = false }, title = { Text("Адрес API") }, text = { OutlinedTextField(apiURL, { apiURL = it }, label = { Text("https://astra.example.com/api/v1") }, singleLine = true) }, confirmButton = { Button({ state.api.baseUrl = apiURL; showAPI = false }) { Text("Сохранить") } }, dismissButton = { TextButton({ showAPI = false }) { Text("Отмена") } })
}

@Composable
fun LegacyProgressScreen(state: AstraState) {
    var entries by remember { mutableStateOf<List<ProgressEntry>>(emptyList()) }
    var showAdd by remember { mutableStateOf(false) }
    suspend fun load() { entries = suspendResult { state.api.progress() }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { load() }
    Page("Прогресс", "Измерения и динамика тела") {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.End) { Button({ showAdd = true }) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(4.dp)); Text("Новый замер") } }
        if (entries.isEmpty()) EmptyMessage("Замеров пока нет", "Добавь первый показатель.")
        else LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(entries, key = { it.id }) { item -> AstraCard { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) { Text(item.date, fontWeight = FontWeight.Bold); Text("Вес ${item.weight.shown(" кг")} · Талия ${item.waist.shown(" см")} · ИМТ ${item.bmi.shown()}", color = AstraTheme.muted); item.comment?.let { Text(it, fontSize = 12.sp) } } } } }
    }
    if (showAdd) AddProgressDialog({ date, weight, waist, wellbeing, comment -> kotlinx.coroutines.MainScope().launch { state.api.addProgress(date, weight, waist, wellbeing, comment); load(); showAdd = false } }, { showAdd = false })
}

@Composable
private fun AddProgressDialog(onSave: (String, Double?, Double?, Double?, String?) -> Unit, onDismiss: () -> Unit) {
    var date by remember { mutableStateOf(today()) }; var weight by remember { mutableStateOf("") }; var waist by remember { mutableStateOf("") }; var wellbeing by remember { mutableStateOf("") }; var comment by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Новый замер") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedTextField(date, { date = it }, label = { Text("Дата YYYY-MM-DD") }, singleLine = true); NumberField("Вес, кг", weight) { weight = it }; NumberField("Талия, см", waist) { waist = it }; NumberField("Самочувствие 1–5", wellbeing) { wellbeing = it }; OutlinedTextField(comment, { comment = it }, label = { Text("Комментарий") }, modifier = Modifier.fillMaxWidth()) } }, confirmButton = { Button({ onSave(date, weight.toNumber(), waist.toNumber(), wellbeing.toNumber(), comment.takeIf { it.isNotBlank() }) }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
fun ProgressScreen(state: AstraState) {
    var entries by remember { mutableStateOf<List<ProgressEntry>>(emptyList()) }
    var selected by remember { mutableStateOf<ProgressEntry?>(null) }
    var showAdd by remember { mutableStateOf(false) }
    var selectedPeriod by rememberSaveable { mutableStateOf("Месяц") }
    val scope = rememberCoroutineScope()
    suspend fun load() { entries = suspendResult { state.api.progress() }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { load() }
    val periodDays = when (selectedPeriod) {
        "Неделя" -> 7
        "3 месяца" -> 90
        "Год" -> 365
        else -> 30
    }
    val anchorDate = entries.mapNotNull { progressDate(it.date) }.maxOrNull() ?: LocalDate.now()
    val periodStart = anchorDate.minusDays((periodDays - 1).toLong())
    val periodEntries = entries.filter { entry ->
        progressDate(entry.date)?.let { date -> !date.isBefore(periodStart) && !date.isAfter(anchorDate) } == true
    }
    val chartEntries = periodEntries.filter { it.weight != null }.sortedBy { progressDate(it.date) ?: LocalDate.MIN }.takeLast(30)

    selected?.let { item ->
        ProgressDetailScreen(
            state = state,
            entry = item,
            onBack = { selected = null },
            onChanged = { scope.launch { load(); selected = null } }
        )
    } ?: Page("Прогресс", "Измерения, которые помогают увидеть динамику") {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("Неделя", "Месяц", "3 месяца", "Год").forEach { label ->
                    OutlinedButton(
                        onClick = { selectedPeriod = label },
                        modifier = Modifier.weight(1f).height(40.dp),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 2.dp),
                        colors = if (selectedPeriod == label) androidx.compose.material3.ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue) else androidx.compose.material3.ButtonDefaults.outlinedButtonColors()
                    ) { Text(label, fontSize = 10.sp, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis) }
                }
            }
            val latest = entries.firstOrNull()
            AstraCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("ДИНАМИКА ВЕСА", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue)
                            Text("Последние $periodDays дней", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        }
                        Text("${chartEntries.size} замеров", fontSize = 11.sp, color = AstraTheme.muted)
                    }
                    if (chartEntries.isEmpty()) {
                        Text("Добавьте несколько замеров, чтобы увидеть динамику веса.", color = AstraTheme.muted, fontSize = 12.sp, modifier = Modifier.padding(vertical = 26.dp))
                    } else {
                        ProgressLineChart(chartEntries.mapNotNull { it.weight })
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(chartEntries.firstOrNull()?.date.orEmpty(), fontSize = 10.sp, color = AstraTheme.muted)
                            Text(chartEntries.lastOrNull()?.date.orEmpty(), fontSize = 10.sp, color = AstraTheme.muted)
                        }
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { ProgressMetric("Вес", latest?.weight.shown(" кг"), AstraTheme.blue) }
                Box(Modifier.weight(1f)) { ProgressMetric("ИМТ", latest?.bmi.shown(), AstraTheme.blue) }
                Box(Modifier.weight(1f)) { ProgressMetric("Талия", latest?.waist.shown(" см"), AstraTheme.blue) }
            }
            AstraCard {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Последние $periodDays дней", fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                        Text("${periodEntries.size} всего", fontSize = 11.sp, color = AstraTheme.muted)
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        (0 until 16).forEach { index ->
                            val filled = index < periodEntries.size.coerceAtMost(16)
                            Box(Modifier.weight(1f).height(14.dp).background(if (filled) AstraTheme.blue else AstraTheme.line, RoundedCornerShape(4.dp)))
                        }
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { ProgressMetric("Калории", averageProgress(periodEntries.map { it.kcalTarget }).shown(" ккал"), AstraTheme.blue) }
                Box(Modifier.weight(1f)) { ProgressMetric("Белок", averageProgress(periodEntries.map { it.proteinTarget }).shown(" г"), AstraTheme.blue) }
                Box(Modifier.weight(1f)) { ProgressMetric("Самочувствие", averageProgress(periodEntries.map { it.wellbeing }).shown(" / 5"), AstraTheme.blue) }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("ИСТОРИЯ ЗАМЕРОВ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue)
                    Text("Открывайте карточку, чтобы посмотреть детали", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                }
                OutlinedButton({ showAdd = true }) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(4.dp)); Text("Добавить") }
            }
            if (entries.isEmpty()) {
                EmptyMessage("Замеров пока нет", "Добавь первый показатель.")
            } else {
                entries.chunked(2).forEach { pair ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        pair.forEach { item -> Box(Modifier.weight(1f)) { ProgressTile(item) { selected = item } } }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
            AstraCard {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("ПОДСКАЗКА", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue)
                    Text("Добавляйте замеры примерно в одно и то же время", fontWeight = FontWeight.Bold)
                    Text("Так динамика веса и объёмов будет сравниваться точнее.", color = AstraTheme.muted, fontSize = 12.sp)
                }
            }
        }
    }
    if (showAdd) ProgressEditorDialog(null, { body -> scope.launch { suspendResult { state.api.createProgress(body) }; load(); showAdd = false } }, { showAdd = false })
}

private fun progressDate(value: String): LocalDate? = runCatching {
    LocalDate.parse(value.take(10))
}.getOrNull()

private fun averageProgress(values: Iterable<Double?>): Double? {
    val numbers = values.mapNotNull { it }.toList()
    return numbers.takeIf { it.isNotEmpty() }?.average()
}

@Composable
private fun ProgressLineChart(values: List<Double>) {
    Canvas(Modifier.fillMaxWidth().height(132.dp)) {
        if (values.isEmpty()) return@Canvas

        val minValue = (values.minOrNull() ?: 0.0) - 1.0
        val maxValue = (values.maxOrNull() ?: minValue) + 1.0
        val range = (maxValue - minValue).coerceAtLeast(1.0)
        val points = values.mapIndexed { index, value ->
            val x = if (values.size == 1) size.width / 2f else size.width * index / values.lastIndex.toFloat()
            val y = size.height - size.height * ((value - minValue) / range).toFloat()
            Offset(x, y)
        }
        val gridColor = MaterialTheme.colorScheme.onSurface.copy(alpha = .12f)
        listOf(0f, .5f, 1f).forEach { fraction ->
            val y = size.height * fraction
            drawLine(gridColor, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
        }

        val area = Path().apply {
            moveTo(points.first().x, size.height)
            points.forEach { lineTo(it.x, it.y) }
            lineTo(points.last().x, size.height)
            close()
        }
        drawPath(area, AstraTheme.blue.copy(alpha = .10f))

        val line = Path().apply {
            moveTo(points.first().x, points.first().y)
            points.drop(1).forEach { lineTo(it.x, it.y) }
        }
        drawPath(
            line,
            AstraTheme.blue,
            style = Stroke(width = 4f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        )
        drawCircle(AstraTheme.blue, radius = 6f, center = points.last())
    }
}

@Composable
private fun ProgressMetric(label: String, value: String, color: Color) {
    Column(Modifier.fillMaxWidth().background(color.copy(alpha = .12f), RoundedCornerShape(14.dp)).padding(10.dp)) {
        Text(label.uppercase(), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = AstraTheme.muted)
        Spacer(Modifier.height(4.dp))
        Text(value, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}

@Composable
private fun ProgressTile(item: ProgressEntry, onOpen: () -> Unit) {
    AstraCard {
        Column(Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(12.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(item.date, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text("ЗАМЕР", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue)
            }
            Divider()
            Text("Вес", fontSize = 11.sp, color = AstraTheme.muted)
            Text(item.weight.shown(" кг"), fontSize = 19.sp, fontWeight = FontWeight.Bold)
            Text("Талия ${item.waist.shown(" см")}", fontSize = 11.sp, color = AstraTheme.muted)
            Text("ИМТ ${item.bmi.shown()} · Самочувствие ${item.wellbeing.shown(" / 5")}", fontSize = 11.sp, color = AstraTheme.muted)
            Button(onClick = onOpen, modifier = Modifier.fillMaxWidth()) { Text("Открыть") }
        }
    }
}

@Composable
private fun ProgressDetailScreen(state: AstraState, entry: ProgressEntry, onBack: () -> Unit, onChanged: () -> Unit) {
    var showEditor by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    var showShare by remember { mutableStateOf(false) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    var hasTrainer by remember { mutableStateOf(false) }
    var actionMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val canManage = state.user?.isAdmin == true || state.user?.isTrainer == true
    LaunchedEffect(canManage) { if (!canManage) hasTrainer = suspendResult { state.api.myTrainerChat() }.getOrNull()?.trainer != null }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Назад") }
            Column(Modifier.weight(1f)) { Text("Замер", fontSize = 20.sp, fontWeight = FontWeight.Bold); Text(entry.date, color = AstraTheme.muted, fontSize = 12.sp) }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            AstraCard {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("ТЕКУЩИЕ ПОКАЗАТЕЛИ", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue)
                    Text(entry.weight.shown(" кг"), fontSize = 38.sp, fontWeight = FontWeight.Bold)
                    Text("Вес на дату замера", color = AstraTheme.muted, fontSize = 12.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(Modifier.weight(1f)) { ProgressMetric("Цель", entry.desiredWeight.shown(" кг"), AstraTheme.blue) }
                        Box(Modifier.weight(1f)) { ProgressMetric("ИМТ", entry.bmi.shown(), AstraTheme.blue) }
                    }
                }
            }
            AstraCard {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    Text("Подробности", fontWeight = FontWeight.Bold)
                    ProgressDetailRow("Талия", entry.waist.shown(" см")); ProgressDetailRow("Грудь", entry.chest.shown(" см")); ProgressDetailRow("Бёдра", entry.hips.shown(" см")); ProgressDetailRow("Рост", entry.height.shown(" см")); ProgressDetailRow("Процент жира", entry.bodyFat.shown(" %")); ProgressDetailRow("Мышечная масса", entry.muscleMass.shown(" кг")); ProgressDetailRow("Калорийность", entry.kcalTarget.shown(" ккал")); ProgressDetailRow("Белок", entry.proteinTarget.shown(" г")); ProgressDetailRow("Жиры", entry.fatTarget.shown(" г")); ProgressDetailRow("Углеводы", entry.carbsTarget.shown(" г")); ProgressDetailRow("Сон", entry.sleep.shown(" / 5")); ProgressDetailRow("Самочувствие", entry.wellbeing.shown(" / 5"))
                    entry.comment?.takeIf { it.isNotBlank() }?.let { Text(it, color = AstraTheme.muted, fontSize = 12.sp) }
                }
            }
            AstraCard {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ showEditor = true }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Edit, null); Spacer(Modifier.width(6.dp)); Text("Редактировать") }
                    if (canManage) OutlinedButton({ scope.launch { clients = suspendResult { state.api.clients() }.getOrDefault(emptyList()); showShare = true } }, modifier = Modifier.fillMaxWidth()) { Text("Отправить клиенту") }
                    if (!canManage && hasTrainer) OutlinedButton({ scope.launch { suspendResult { state.api.shareToTrainer("progress", entry.id) }; actionMessage = "Отправлено тренеру" } }, modifier = Modifier.fillMaxWidth()) { Text("Отправить тренеру") }
                    TextButton({ showDelete = true }, modifier = Modifier.fillMaxWidth()) { Text("Удалить замер", color = AstraTheme.danger) }
                    actionMessage?.let { Text(it, color = AstraTheme.green, fontSize = 12.sp) }
                }
            }
        }
    }
    if (showEditor) ProgressEditorDialog(entry, { body -> scope.launch { suspendResult { state.api.updateProgress(entry.id, body) }; showEditor = false; onChanged() } }, { showEditor = false })
    if (showShare) ShareToClientDialog(clients, { clientId -> scope.launch { suspendResult { state.api.shareToClient(clientId, "progress", entry.id) }; showShare = false; actionMessage = "Отправлено клиенту" } }, { showShare = false })
    if (showDelete) AlertDialog(onDismissRequest = { showDelete = false }, title = { Text("Удалить замер?") }, text = { Text("Это действие нельзя отменить.") }, confirmButton = { TextButton({ scope.launch { suspendResult { state.api.deleteProgress(entry.id) }; showDelete = false; onChanged() } }) { Text("Удалить", color = AstraTheme.danger) } }, dismissButton = { TextButton({ showDelete = false }) { Text("Отмена") } })
}

@Composable
private fun ProgressDetailRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text(label, color = AstraTheme.muted, fontSize = 12.sp); Text(value, fontWeight = FontWeight.Bold, fontSize = 12.sp) }
}

@Composable
private fun ProgressEditorDialog(existing: ProgressEntry?, onSave: (JSONObject) -> Unit, onDismiss: () -> Unit) {
    var date by remember(existing?.id) { mutableStateOf(existing?.date ?: today()) }
    var weight by remember(existing?.id) { mutableStateOf(existing?.weight?.toString().orEmpty()) }
    var desired by remember(existing?.id) { mutableStateOf(existing?.desiredWeight?.toString().orEmpty()) }
    var height by remember(existing?.id) { mutableStateOf(existing?.height?.toString().orEmpty()) }
    var bodyFat by remember(existing?.id) { mutableStateOf(existing?.bodyFat?.toString().orEmpty()) }
    var muscle by remember(existing?.id) { mutableStateOf(existing?.muscleMass?.toString().orEmpty()) }
    var kcal by remember(existing?.id) { mutableStateOf(existing?.kcalTarget?.toString().orEmpty()) }
    var protein by remember(existing?.id) { mutableStateOf(existing?.proteinTarget?.toString().orEmpty()) }
    var fat by remember(existing?.id) { mutableStateOf(existing?.fatTarget?.toString().orEmpty()) }
    var carbs by remember(existing?.id) { mutableStateOf(existing?.carbsTarget?.toString().orEmpty()) }
    var waist by remember(existing?.id) { mutableStateOf(existing?.waist?.toString().orEmpty()) }
    var chest by remember(existing?.id) { mutableStateOf(existing?.chest?.toString().orEmpty()) }
    var hips by remember(existing?.id) { mutableStateOf(existing?.hips?.toString().orEmpty()) }
    var sleep by remember(existing?.id) { mutableStateOf(existing?.sleep?.toString().orEmpty()) }
    var wellbeing by remember(existing?.id) { mutableStateOf(existing?.wellbeing?.toString().orEmpty()) }
    var comment by remember(existing?.id) { mutableStateOf(existing?.comment.orEmpty()) }
    fun body(): JSONObject = JSONObject().put("measured_at", date).putProgressValue("weight_kg", weight).putProgressValue("desired_weight_kg", desired).putProgressValue("height_cm", height).putProgressValue("body_fat_pct", bodyFat).putProgressValue("muscle_mass_kg", muscle).putProgressValue("kcal_target", kcal).putProgressValue("protein_target_g", protein).putProgressValue("fat_target_g", fat).putProgressValue("carbs_target_g", carbs).putProgressValue("waist_cm", waist).putProgressValue("chest_cm", chest).putProgressValue("hips_cm", hips).putProgressValue("sleep_score", sleep).putProgressValue("wellbeing_score", wellbeing).put("comment", comment.takeIf { it.isNotBlank() } ?: JSONObject.NULL)
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новый замер" else "Редактировать замер") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { OutlinedTextField(date, { date = it }, label = { Text("Дата YYYY-MM-DD") }, singleLine = true); NumberField("Вес, кг", weight) { weight = it }; NumberField("Желаемый вес, кг", desired) { desired = it }; NumberField("Рост, см", height) { height = it }; NumberField("Талия, см", waist) { waist = it }; NumberField("Грудь, см", chest) { chest = it }; NumberField("Бёдра, см", hips) { hips = it }; NumberField("Процент жира", bodyFat) { bodyFat = it }; NumberField("Мышечная масса, кг", muscle) { muscle = it }; NumberField("Калорийность", kcal) { kcal = it }; NumberField("Белок, г", protein) { protein = it }; NumberField("Жиры, г", fat) { fat = it }; NumberField("Углеводы, г", carbs) { carbs = it }; NumberField("Сон, 1–5", sleep) { sleep = it }; NumberField("Самочувствие, 1–5", wellbeing) { wellbeing = it }; OutlinedTextField(comment, { comment = it }, label = { Text("Комментарий") }, modifier = Modifier.fillMaxWidth()) } }, confirmButton = { Button({ onSave(body()) }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

private fun JSONObject.putProgressValue(key: String, value: String): JSONObject = put(key, value.toNumber() ?: JSONObject.NULL)

@Composable
fun WorkoutsScreen(state: AstraState) {
    var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }; var logs by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }; var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }; var showAdd by remember { mutableStateOf(false) }
    suspend fun load() { plans = suspendResult { state.api.plans() }.getOrDefault(emptyList()); logs = suspendResult { state.api.workouts() }.getOrDefault(emptyList()); exercises = suspendResult { state.api.exercises() }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { load() }
    Page("Тренировки", "Планы и журнал нагрузки") {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.End) { Button({ showAdd = true }) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(4.dp)); Text("Записать") } }
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (plans.isNotEmpty()) item { Text("Планы", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            items(plans, key = { "plan${it.id}" }) { plan -> AstraCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(plan.scheduledAt, fontWeight = FontWeight.Bold); Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp) }; if (plan.status == "planned") IconButton({ kotlinx.coroutines.MainScope().launch { state.api.completePlan(plan.id); load() } }) { Icon(Icons.Default.Check, "Готово") } } } }
            item { Text("Журнал", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            items(logs, key = { "log${it.id}" }) { log -> AstraCard { Column(Modifier.padding(14.dp)) { Text(log.name, fontWeight = FontWeight.Bold); Text("${log.date} · ${log.sets.shown(" подходов")} × ${log.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } }
        }
    }
    if (showAdd) AddWorkoutDialog(exercises, { date, exercise, weight, sets, reps, rir -> kotlinx.coroutines.MainScope().launch { state.api.addWorkout(date, exercise.id, weight, sets, reps, rir); load(); showAdd = false } }, { showAdd = false })
}

@Composable
private fun AddWorkoutDialog(exercises: List<Exercise>, onSave: (String, Exercise, Double?, Double?, Double?, String?) -> Unit, onDismiss: () -> Unit) {
    var date by remember { mutableStateOf(todayTime()) }; var exercise by remember { mutableStateOf(exercises.firstOrNull()) }; var weight by remember { mutableStateOf("") }; var sets by remember { mutableStateOf("") }; var reps by remember { mutableStateOf("") }; var rir by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Записать тренировку") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Picker("Упражнение: ${exercise?.name ?: "—"}", exercises.map { it.name }) { exercise = exercises.firstOrNull { e -> e.name == it } }; OutlinedTextField(date, { date = it }, label = { Text("Дата и время") }, singleLine = true); NumberField("Вес", weight) { weight = it }; NumberField("Подходы", sets) { sets = it }; NumberField("Повторения", reps) { reps = it }; OutlinedTextField(rir, { rir = it }, label = { Text("RIR") }, singleLine = true) } }, confirmButton = { Button({ exercise?.let { onSave(date, it, weight.toNumber(), sets.toNumber(), reps.toNumber(), rir.takeIf { value -> value.isNotBlank() }) } }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
private fun NumberField(label: String, value: String, onValueChange: (String) -> Unit) = OutlinedTextField(value, onValueChange, label = { Text(label) }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
fun String.toNumber(): Double? = replace(',', '.').toDoubleOrNull()
private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
fun todayTime() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())

@Composable
fun EmptyMessage(title: String, body: String) { Box(Modifier.fillMaxWidth().padding(42.dp), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Default.CalendarMonth, null, tint = AstraTheme.blue, modifier = Modifier.size(40.dp)); Text(title, fontWeight = FontWeight.Bold); Text(body, color = AstraTheme.muted, fontSize = 12.sp) } } }

private val androidMealOrder = listOf("Завтрак", "Обед", "Ужин", "Перекус", "Напиток", "Десерт")
private data class AndroidDiaryTotals(val kcal: Double, val protein: Double, val fat: Double, val carbs: Double, val cost: Double)
private fun diaryTotalsAndroid(items: List<DiaryEntry>) = AndroidDiaryTotals(items.sumOf { it.kcal ?: 0.0 }, items.sumOf { it.protein ?: 0.0 }, items.sumOf { it.fat ?: 0.0 }, items.sumOf { it.carbs ?: 0.0 }, items.sumOf { it.cost ?: 0.0 })
private fun Double?.diaryShown(suffix: String = ""): String { val value = this ?: 0.0; return if (value % 1.0 == 0.0) "${value.toInt()}$suffix" else "${"%.1f".format(Locale.US, value)}$suffix" }
private fun daysInMonthAndroid(year: Int, month: Int): Int = Calendar.getInstance().apply { set(year, month, 1) }.getActualMaximum(Calendar.DAY_OF_MONTH)
private fun firstDayOffsetAndroid(year: Int, month: Int): Int = ((Calendar.getInstance().apply { set(year, month, 1) }.get(Calendar.DAY_OF_WEEK) + 5) % 7)
private fun shiftMonthAndroid(value: String, delta: Int): String { val parts = value.split('-').map { it.toInt() }; val calendar = Calendar.getInstance().apply { set(parts[0], parts[1] - 1, 1); add(Calendar.MONTH, delta) }; return "%04d-%02d".format(Locale.US, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH) + 1) }
private fun monthLabelAndroid(value: String): String { val parts = value.split('-').map { it.toInt() }; return SimpleDateFormat("LLLL yyyy", Locale("ru")).format(Calendar.getInstance().apply { set(parts[0], parts[1] - 1, 1) }.time).replaceFirstChar { it.titlecase(Locale("ru")) } }

@Composable
fun DiaryCalendarScreen(state: AstraState) {
    var entries by remember { mutableStateOf<List<DiaryEntry>>(emptyList()) }
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }
    var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }
    var month by rememberSaveable { mutableStateOf(today().take(7)) }
    var editingDate by rememberSaveable { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    suspend fun load() { suspendResult { entries = state.api.diary(); products = state.api.products(); recipes = state.api.recipes(); error = null }.onFailure { error = it.message } }
    LaunchedEffect(Unit) { load() }
    val date = editingDate
    if (date != null) DiaryDayEditorScreen(state, date, entries.filter { it.date == date }, products, recipes, { editingDate = null }, { load() })
    else Page("Дневник", "Food Calendar · питание по дням") {
        val todayEntries = entries.filter { it.date == today() }
        val todayTotals = diaryTotalsAndroid(todayEntries)
        val parts = month.split('-').map { it.toIntOrNull() ?: 1 }
        val year = parts.getOrElse(0) { Calendar.getInstance().get(Calendar.YEAR) }
        val monthIndex = parts.getOrElse(1) { 1 } - 1
        val days = daysInMonthAndroid(year, monthIndex)
        val offset = firstDayOffsetAndroid(year, monthIndex)
        val filledDays = entries.filter { it.date.startsWith(month) }.map { it.date }.toSet().size
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { AstraCard { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("FOOD CALENDAR", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AstraTheme.green); Text("Сегодня · ${today()}", fontSize = 20.sp, fontWeight = FontWeight.Bold) }; Button({ editingDate = today() }) { Text("Сегодня") } }; Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Metric("Заполнено дней", filledDays.toString(), AstraTheme.green); Metric("Ккал", todayTotals.kcal.diaryShown(), AstraTheme.blue); Metric("Белок", todayTotals.protein.diaryShown(" г"), AstraTheme.green) }; Text("${todayEntries.size} записей · ${todayTotals.fat.diaryShown(" г жиров")} · ${todayTotals.carbs.diaryShown(" г углеводов")}", color = AstraTheme.muted, fontSize = 12.sp) } } }
            item { AstraCard { Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("ТЕКУЩИЙ ДЕНЬ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AstraTheme.blue); Text("Питание по приёмам", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; TextButton({ editingDate = today() }) { Text("Изменить") } }; if (todayEntries.isEmpty()) Text("Записей пока нет — откройте день и добавьте блюдо или продукт.", color = AstraTheme.muted) else for (meal in androidMealOrder) { val mealEntries = todayEntries.filter { it.meal == meal }; if (mealEntries.isNotEmpty()) Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) { Text(meal.take(1), modifier = Modifier.size(30.dp).background(AstraTheme.green.copy(alpha = .14f), RoundedCornerShape(10.dp)).padding(7.dp), color = AstraTheme.green, fontWeight = FontWeight.Bold); Column(Modifier.weight(1f).padding(horizontal = 10.dp)) { Text(meal, fontWeight = FontWeight.Bold); Text(mealEntries.joinToString(" · ") { it.name ?: "Без названия" }, color = AstraTheme.muted, fontSize = 12.sp) }; Text(diaryTotalsAndroid(mealEntries).kcal.diaryShown(" ккал"), color = AstraTheme.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp) } } } } }
            item { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("КАЛЕНДАРЬ ПИТАНИЯ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AstraTheme.green); Text("Нажмите на день для редактирования", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; TextButton({ month = shiftMonthAndroid(month, -1) }) { Text("‹") }; TextButton({ month = today().take(7) }) { Text("Сегодня") }; TextButton({ month = shiftMonthAndroid(month, 1) }) { Text("›") } } }
            item { AstraCard { Column(Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(monthLabelAndroid(month), fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp)); Row(Modifier.fillMaxWidth()) { listOf("Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс").forEach { Text(it, Modifier.weight(1f).padding(5.dp), fontSize = 11.sp, color = AstraTheme.muted, fontWeight = FontWeight.Bold) } }; for (row in 0 until ((offset + days + 6) / 7)) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) { for (column in 0..6) { val day = row * 7 + column - offset + 1; if (day !in 1..days) Spacer(Modifier.weight(1f).height(72.dp)) else { val dayDate = "%04d-%02d-%02d".format(Locale.US, year, monthIndex + 1, day); val dayItems = entries.filter { it.date == dayDate }; val isToday = dayDate == today(); Button({ editingDate = dayDate }, Modifier.weight(1f).height(72.dp), shape = RoundedCornerShape(12.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(5.dp), colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = if (isToday) AstraTheme.green.copy(alpha = .18f) else MaterialTheme.colorScheme.surface, contentColor = MaterialTheme.colorScheme.onSurface)) { Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.Start) { Text(day.toString(), fontWeight = FontWeight.Bold, color = if (isToday) AstraTheme.green else MaterialTheme.colorScheme.onSurface); Text(if (dayItems.isEmpty()) "Нет записей" else "${dayItems.size} · ${diaryTotalsAndroid(dayItems).kcal.diaryShown(" ккал")}", fontSize = 9.sp, color = AstraTheme.muted, maxLines = 2) } } } } } } } }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

@Composable
private fun DiaryDayEditorScreen(state: AstraState, date: String, entries: List<DiaryEntry>, products: List<Product>, recipes: List<Recipe>, onBack: () -> Unit, onChanged: suspend () -> Unit) {
    var editorEntry by remember { mutableStateOf<DiaryEntry?>(null) }
    var editorOpen by remember { mutableStateOf(false) }
    var pickerOpen by remember { mutableStateOf(false) }
    var presetProduct by remember { mutableStateOf<Product?>(null) }
    var presetRecipe by remember { mutableStateOf<Recipe?>(null) }
    var presetCustom by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Page("День · $date", "Редактирование дневника") {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) { OutlinedButton(onBack) { Icon(Icons.Default.ArrowBack, null); Spacer(Modifier.width(5.dp)); Text("Назад") }; Spacer(Modifier.weight(1f)); Button({ pickerOpen = true }) { Icon(Icons.Default.Add, null); Spacer(Modifier.width(4.dp)); Text("Добавить") } }
        val totals = diaryTotalsAndroid(entries)
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) { item { AstraCard { Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) { Metric("Записей", entries.size.toString(), AstraTheme.green); Metric("Ккал", totals.kcal.diaryShown(), AstraTheme.blue); Metric("Белок", totals.protein.diaryShown(" г"), AstraTheme.green) } } }; if (entries.isEmpty()) item { EmptyMessage("В этот день записей пока нет", "Добавьте блюдо, ингредиент или новое блюдо.") }; items(entries, key = { it.id }) { entry -> AstraCard { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Icon(if (entry.itemType == "product") Icons.Default.LocalGroceryStore else Icons.Default.Restaurant, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(entry.name ?: "Без названия", fontWeight = FontWeight.Bold); Text("${entry.meal ?: "Приём пищи"} · ${entry.kcal.diaryShown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp) }; IconButton({ editorEntry = entry; editorOpen = true }) { Icon(Icons.Default.Edit, "Редактировать") }; IconButton({ scope.launch { suspendResult { state.api.deleteDiary(entry.id); onChanged() } } }) { Icon(Icons.Default.Delete, "Удалить") } }; Text("${if (entry.itemType == "product") "Количество: ${entry.measurementQuantity ?: entry.quantity ?: 0.0} ${entry.measurementName ?: entry.unit ?: "г"}" else "Порций: ${entry.servings ?: 1.0}"}${entry.comment?.let { " · $it" } ?: ""}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
    }
    if (pickerOpen) DiaryFoodPickerScreen(products, recipes, { pickerOpen = false }, { presetProduct = null; presetRecipe = null; presetCustom = true; pickerOpen = false; editorEntry = null; editorOpen = true }) { product, recipe -> presetProduct = product; presetRecipe = recipe; presetCustom = false; pickerOpen = false; editorEntry = null; editorOpen = true }
    if (editorOpen) DiaryEntryEditorDialog(products, recipes, date, editorEntry, presetProduct, presetRecipe, presetCustom, { editorOpen = false }) { id, body -> scope.launch { suspendResult { if (id == null) state.api.addDiary(body) else state.api.updateDiary(id, body); onChanged() }; editorOpen = false } }
}

@Composable
private fun DiaryFoodPickerScreen(products: List<Product>, recipes: List<Recipe>, onBack: () -> Unit, onCustom: () -> Unit, onSelect: (Product?, Recipe?) -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    var tab by rememberSaveable { mutableStateOf("Блюда") }
    val filteredRecipes = recipes.filter { search.isBlank() || it.name.contains(search, true) }
    val filteredProducts = products.filter { search.isBlank() || it.name.contains(search, true) }
    Page("Добавить в дневник", "Выберите блюдо или продукт") {
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(search, { search = it }, modifier = Modifier.fillMaxWidth(), singleLine = true, shape = RoundedCornerShape(24.dp), label = { Text("Поиск") }, leadingIcon = { Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.blue) })
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Блюда", "Продукты", "Новое", "Все").forEach { item ->
                    if (tab == item) OutlinedButton({ tab = item }, Modifier.weight(1f), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp), colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue)) { Text(item, fontSize = 11.sp, maxLines = 1) }
                    else OutlinedButton({ if (item == "Новое") onCustom() else tab = item }, Modifier.weight(1f), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp)) { Text(item, fontSize = 11.sp, maxLines = 1) }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("Выберите запись", fontSize = 18.sp, fontWeight = FontWeight.Bold); Text("Нажмите на карточку, чтобы указать количество", color = AstraTheme.muted, fontSize = 12.sp) }; TextButton(onBack) { Text("Отмена") } }
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (tab == "Блюда" || tab == "Все") MobileItemGrid(filteredRecipes) { recipe ->
                        AstraCard { Column(Modifier.fillMaxWidth().clickable { onSelect(null, recipe) }.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon(Icons.Default.Restaurant, null, tint = AstraTheme.blue)
                            Text(recipe.name, fontWeight = FontWeight.Bold, maxLines = 3)
                            Text("${recipe.category} · ${recipe.kcal.shown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
                            Text("Б ${recipe.protein.shown(" г")}", color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        } }
                    }
                    if (tab == "Продукты" || tab == "Все") MobileItemGrid(filteredProducts) { product ->
                        AstraCard { Column(Modifier.fillMaxWidth().clickable { onSelect(product, null) }.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.blue)
                            Text(product.name, fontWeight = FontWeight.Bold, maxLines = 3)
                            Text("${product.category ?: "Без категории"} · ${product.kcal.shown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
                            Text("Б ${product.protein.shown(" г")}", color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        } }
                    }
            }
        }
    }
}

@Composable
private fun DiaryEntryEditorDialog(products: List<Product>, recipes: List<Recipe>, initialDate: String, entry: DiaryEntry?, presetProduct: Product? = null, presetRecipe: Recipe? = null, presetCustom: Boolean = false, onDismiss: () -> Unit, onSave: (Int?, JSONObject) -> Unit) {
    var kind by remember(entry?.id) { mutableStateOf(if (entry?.itemType == "product") 0 else 1) }; var date by remember(entry?.id) { mutableStateOf(entry?.date ?: initialDate) }; var meal by remember(entry?.id) { mutableStateOf(entry?.meal ?: androidMealOrder.first()) }; var product by remember(entry?.id) { mutableStateOf(products.firstOrNull { it.id == entry?.productId } ?: products.firstOrNull()) }; var recipe by remember(entry?.id) { mutableStateOf(recipes.firstOrNull { it.id == entry?.recipeId } ?: recipes.firstOrNull()) }; var amount by remember(entry?.id) { mutableStateOf((entry?.measurementQuantity ?: entry?.quantity ?: entry?.servings ?: 1.0).toString()) }; var unit by remember(entry?.id) { mutableStateOf(entry?.measurementName ?: entry?.unit ?: product?.unit ?: "г") }; var comment by remember(entry?.id) { mutableStateOf(entry?.comment ?: "") }
    LaunchedEffect(presetProduct?.id, presetRecipe?.id, presetCustom) { if (entry == null) { if (presetCustom) kind = 2; presetProduct?.let { product = it; unit = it.unit ?: unit; kind = 0 }; presetRecipe?.let { recipe = it; kind = 1 } } }
    var customName by remember(entry?.id) { mutableStateOf("") }; var customKcal by remember(entry?.id) { mutableStateOf("") }; var customProtein by remember(entry?.id) { mutableStateOf("") }; var customFat by remember(entry?.id) { mutableStateOf("") }; var customCarbs by remember(entry?.id) { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (entry == null) "Добавить запись" else "Редактировать запись") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) { Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { ChoiceButton("Продукт", kind == 0) { kind = 0 }; ChoiceButton("Блюдо", kind == 1) { kind = 1 }; ChoiceButton("Новое блюдо", kind == 2) { kind = 2 } }; OutlinedTextField(date, { date = it }, label = { Text("Дата YYYY-MM-DD") }, singleLine = true); Picker("Приём: $meal", androidMealOrder) { meal = it }; if (kind == 0) { Picker("Продукт: ${product?.name ?: "—"}", products.map { it.name }) { product = products.firstOrNull { p -> p.name == it }; unit = product?.unit ?: "г" }; OutlinedTextField(amount, { amount = it }, label = { Text("Количество") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)); OutlinedTextField(unit, { unit = it }, label = { Text("Единица") }, singleLine = true) } else if (kind == 1) { Picker("Блюдо: ${recipe?.name ?: "—"}", recipes.map { it.name }) { recipe = recipes.firstOrNull { r -> r.name == it } }; OutlinedTextField(amount, { amount = it }, label = { Text("Порций") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) } else { OutlinedTextField(customName, { customName = it }, label = { Text("Название блюда") }, singleLine = true); OutlinedTextField(customKcal, { customKcal = it }, label = { Text("Ккал") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)); OutlinedTextField(customProtein, { customProtein = it }, label = { Text("Белки, г") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)); OutlinedTextField(customFat, { customFat = it }, label = { Text("Жиры, г") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)); OutlinedTextField(customCarbs, { customCarbs = it }, label = { Text("Углеводы, г") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)); OutlinedTextField(amount, { amount = it }, label = { Text("Порций") }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal)) }; OutlinedTextField(comment, { comment = it }, label = { Text("Комментарий") }, modifier = Modifier.fillMaxWidth()) } }, confirmButton = { Button({ val body = JSONObject().put("entry_date", date).put("meal_type", meal).put("servings", if (kind == 0) 1.0 else amount.toNumber() ?: 1.0).put("comment", comment.ifBlank { JSONObject.NULL }); when (kind) { 0 -> body.put("product_id", product?.id).put("quantity", amount.toNumber() ?: 1.0).put("measurement_quantity", amount.toNumber() ?: 1.0).put("measurement_name", unit); 1 -> body.put("recipe_id", recipe?.id); else -> body.put("custom_dish", JSONObject().put("name", customName).put("kcal", customKcal.toNumber() ?: 0.0).put("protein_g", customProtein.toNumber() ?: 0.0).put("fat_g", customFat.toNumber() ?: 0.0).put("carbs_g", customCarbs.toNumber() ?: 0.0)) }; onSave(entry?.id, body) }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}
