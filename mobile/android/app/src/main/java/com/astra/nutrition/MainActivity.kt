package com.astra.nutrition

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.RowScope
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.CircularProgressIndicator
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { AstraTheme { AstraRoot(remember { AstraState(applicationContext) }) } }
    }
}

class AstraState(context: android.content.Context) {
    val api = ApiClient(context)
    var user by mutableStateOf<AuthUser?>(null)
    var restoring by mutableStateOf(true)
    var busy by mutableStateOf(false)
    var error by mutableStateOf<String?>(null)

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

private suspend fun <T> suspendResult(block: suspend () -> T): Result<T> = try {
    Result.success(block())
} catch (error: Throwable) {
    Result.failure(error)
}

enum class Screen { Overview, Diary, Products, Recipes, More, Progress, Workouts }

@Composable
fun AstraRoot(state: AstraState) {
    LaunchedEffect(Unit) { state.restore() }
    when {
        state.restoring -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        state.user == null -> LoginScreen(state)
        else -> MainScaffold(state)
    }
}

@Composable
fun LoginScreen(state: AstraState) {
    var register by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    Box(Modifier.fillMaxSize().background(AstraTheme.canvas), contentAlignment = Alignment.Center) {
        Card(Modifier.fillMaxWidth().padding(20.dp), shape = RoundedCornerShape(24.dp), colors = CardDefaults.cardColors(Color.White)) {
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
    if (active) Button(onClick, Modifier.weight(1f)) { Text(label) }
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
                Screen.Diary -> DiaryScreen(state)
                Screen.Products -> ProductsScreen(state)
                Screen.Recipes -> RecipesScreen(state)
                Screen.Progress -> ProgressScreen(state)
                Screen.Workouts -> WorkoutsScreen(state)
                Screen.More -> MoreScreen(state) { screen = it }
            }
        }
    }
}

private fun Screen.title() = when (this) { Screen.Overview -> "Обзор"; Screen.Diary -> "Дневник"; Screen.Products -> "Продукты"; Screen.Recipes -> "Рецепты"; Screen.More -> "Ещё"; Screen.Progress -> "Прогресс"; Screen.Workouts -> "Тренировки" }
private fun Screen.icon() = when (this) { Screen.Overview -> Icons.Default.Home; Screen.Diary -> Icons.Default.Restaurant; Screen.Products -> Icons.Default.LocalGroceryStore; Screen.Recipes -> Icons.Default.Book; Screen.More -> Icons.Default.MoreHoriz; Screen.Progress -> Icons.Default.TrendingUp; Screen.Workouts -> Icons.Default.FitnessCenter }

@Composable
private fun Page(title: String, subtitle: String? = null, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().background(AstraTheme.canvas)) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) { Text(title, fontSize = 28.sp, fontWeight = FontWeight.Bold); subtitle?.let { Text(it, color = AstraTheme.muted) } }
        content()
    }
}

@Composable
private fun AstraCard(content: @Composable () -> Unit) {
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(Color.White), elevation = CardDefaults.cardElevation(2.dp)) { content() }
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
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Metric("Одобрено", dashboard.approved.toString(), Color(0xFFFFA726)); Metric("Вес", dashboard.latest?.weight.shown(" кг"), Color(0xFF8E7CFF)) }
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
    AstraCard { Row(Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable { onClick() } else Modifier).padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Fastfood, null, tint = AstraTheme.green); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(recipe.name, fontWeight = FontWeight.Bold); Text("${recipe.category} · ${recipe.protein.shown(" г белка")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text(recipe.kcal.shown(" ккал"), color = AstraTheme.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp) } }
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
private fun Picker(label: String, options: List<String>, onSelect: (String) -> Unit) {
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
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(products.filter { search.isBlank() || it.name.contains(search, true) }, key = { it.id }) { product ->
            AstraCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.green); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(product.name, fontWeight = FontWeight.Bold); Text("${product.category ?: "Без категории"} · ${product.kcal.shown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text("Б ${product.protein.shown(" г")}", color = AstraTheme.blue, fontWeight = FontWeight.Bold, fontSize = 12.sp) } }
        } }
    }
}

@Composable
fun RecipesScreen(state: AstraState) {
    var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }
    var search by rememberSaveable { mutableStateOf("") }
    var selected by remember { mutableStateOf<Recipe?>(null) }
    LaunchedEffect(Unit) { recipes = suspendResult { state.api.recipes() }.getOrDefault(emptyList()) }
    Page("Рецепты", "Собирай рацион из проверенных блюд") {
        OutlinedTextField(search, { search = it }, label = { Text("Найти рецепт") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(recipes.filter { search.isBlank() || it.name.contains(search, true) }, key = { it.id }) { recipe -> RecipeListItem(recipe) { selected = recipe } } }
    }
    selected?.let { RecipeDetailDialog(state, it) { selected = null } }
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
fun ProgressScreen(state: AstraState) {
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
private fun String.toNumber(): Double? = replace(',', '.').toDoubleOrNull()
private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
private fun todayTime() = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())

@Composable
private fun EmptyMessage(title: String, body: String) { Box(Modifier.fillMaxWidth().padding(42.dp), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Default.CalendarMonth, null, tint = AstraTheme.blue, modifier = Modifier.size(40.dp)); Text(title, fontWeight = FontWeight.Bold); Text(body, color = AstraTheme.muted, fontSize = 12.sp) } } }
