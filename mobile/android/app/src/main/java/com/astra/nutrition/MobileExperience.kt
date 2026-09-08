package com.astra.nutrition

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocalGroceryStore
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Person2
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun MobileScaffold(state: AstraState) {
    var screen by rememberSaveable { mutableStateOf(Screen.Overview) }
    val bottom = listOf(Screen.Overview, Screen.Diary, Screen.Workouts, Screen.Trainer, Screen.Information, Screen.More)
    Scaffold(bottomBar = {
        NavigationBar { bottom.forEach { item -> NavigationBarItem(selected = screen == item, onClick = { screen = item }, icon = { Icon(item.mobileIcon(), null) }, label = { Text(item.mobileTitle()) }) } }
    }) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when (screen) {
                Screen.Overview -> MobileDashboard(state) { screen = it }
                Screen.Diary -> DiaryScreen(state)
                Screen.Workouts -> MobileWorkoutsScreen(state)
                Screen.Trainer -> TrainerScreen(state)
                Screen.Information -> InformationScreen(state)
                Screen.Catalog -> CatalogScreen(state)
                Screen.Progress -> ProgressScreen(state)
                Screen.Products -> ProductsScreen(state)
                Screen.Recipes -> RecipesScreen(state)
                Screen.More -> MobileMoreScreen(state) { screen = it }
            }
        }
    }
}

private fun Screen.mobileTitle() = when (this) {
    Screen.Overview -> "Обзор"; Screen.Diary -> "Дневник"; Screen.Workouts -> "Тренировки"; Screen.Trainer -> "Тренер"; Screen.Information -> "Инфо"; Screen.More -> "Ещё"; else -> "Раздел"
}
private fun Screen.mobileIcon() = when (this) {
    Screen.Overview -> Icons.Default.Home; Screen.Diary -> Icons.Default.LocalGroceryStore; Screen.Workouts -> Icons.Default.FitnessCenter; Screen.Trainer -> Icons.Default.Person; Screen.Information -> Icons.Default.Info; else -> Icons.Default.MoreHoriz
}

@Composable
private fun MobileCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Card(modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(MaterialTheme.colorScheme.surface), elevation = CardDefaults.cardElevation(2.dp)) { content() }
}

@Composable
private fun MobileMetric(label: String, value: String, tint: Color, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).background(tint.copy(alpha = .12f), RoundedCornerShape(14.dp)).padding(13.dp)) {
        Text(label, fontSize = 11.sp, color = AstraTheme.muted, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(5.dp)); Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun MobileDashboard(state: AstraState, onNavigate: (Screen) -> Unit) {
    var data by remember { mutableStateOf<Dashboard?>(null) }; var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { data = state.api.dashboard() }.onFailure { error = it.message } }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).verticalScroll(rememberScrollState())) {
        Column(Modifier.padding(16.dp)) { Text("Обзор", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Фитнес, питание и контроль прогресса", color = AstraTheme.muted) }
        if (data == null && error == null) Text("Загрузка…", Modifier.padding(16.dp), color = AstraTheme.muted)
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        data?.let { dashboard ->
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Box(Modifier.weight(1f)) { MobileMetric("Продукты", dashboard.products.toString(), AstraTheme.blue) { onNavigate(Screen.Catalog) } }; Box(Modifier.weight(1f)) { MobileMetric("Рецепты", dashboard.recipes.toString(), AstraTheme.green) { onNavigate(Screen.Catalog) } } }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Box(Modifier.weight(1f)) { MobileMetric("Одобренные рецепты", dashboard.approved.toString(), Color(0xFFFFA726)) { onNavigate(Screen.Catalog) } }; Box(Modifier.weight(1f)) { MobileMetric("Вес", dashboard.latest?.weight.shown(" кг"), Color(0xFF8E7CFF)) { onNavigate(Screen.Progress) } } }
                Text("«Одобренные рецепты» — рецепты, прошедшие модерацию и доступные для дневника питания.", fontSize = 12.sp, color = AstraTheme.muted)
                dashboard.latest?.let { latest -> MobileCard(Modifier.clickable { onNavigate(Screen.Progress) }) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) { Text("Последний замер", fontWeight = FontWeight.Bold); Text("${latest.date} · Вес ${latest.weight.shown(" кг")} · Талия ${latest.waist.shown(" см")}", color = AstraTheme.muted) } } }
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Рецепты с высоким белком", fontSize = 18.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.weight(1f)); TextButton({ onNavigate(Screen.Catalog) }) { Text("Каталог") } }
                dashboard.top.forEach { recipe -> MobileRecipeRow(recipe) { onNavigate(Screen.Catalog) } }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun MobileRecipeRow(recipe: Recipe, onClick: () -> Unit) {
    MobileCard(Modifier.clickable(onClick = onClick)) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Book, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(recipe.name, fontWeight = FontWeight.Bold); Text("${recipe.category} · ${recipe.protein.shown(" г белка")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text(recipe.kcal.shown(" ккал"), color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold) } }
}

@Composable
fun MobileMoreScreen(state: AstraState, onNavigate: (Screen) -> Unit) {
    var showApi by remember { mutableStateOf(false) }; var apiUrl by remember { mutableStateOf(state.api.baseUrl) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Ещё", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Каталоги, информация и настройки", color = AstraTheme.muted) }
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { MobileCard { Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) { Text("Тёмная тема", Modifier.weight(1f)); androidx.compose.material3.Switch(checked = state.darkTheme, onCheckedChange = state::toggleTheme) } } }
            item { MobileCard(Modifier.clickable { onNavigate(Screen.Catalog) }) { androidx.compose.material3.ListItem(headlineContent = { Text("Продукты и рецепты") }, supportingContent = { Text("Каталог с категориями как в веб-версии") }, leadingContent = { Icon(Icons.Default.Book, null) }) } }
            item { MobileCard(Modifier.clickable { onNavigate(Screen.Information) }) { androidx.compose.material3.ListItem(headlineContent = { Text("Статьи и информация") }, leadingContent = { Icon(Icons.Default.Info, null) }) } }
            item { MobileCard(Modifier.clickable { onNavigate(Screen.Progress) }) { androidx.compose.material3.ListItem(headlineContent = { Text("Замеры и цели") }, leadingContent = { Icon(Icons.Default.TrendingUp, null) }) } }
            item { MobileCard(Modifier.clickable { onNavigate(Screen.Trainer) }) { androidx.compose.material3.ListItem(headlineContent = { Text("Чат с тренером") }, leadingContent = { Icon(Icons.Default.Person, null) }) } }
            item { MobileCard { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) { Text(state.user?.email ?: "—", fontWeight = FontWeight.Bold); OutlinedButton({ showApi = true }) { Text("Адрес API") }; TextButton({ kotlinx.coroutines.MainScope().launch { state.api.logout(); state.user = null } }) { Text("Выйти") } } } }
        }
    }
    if (showApi) AlertDialog(onDismissRequest = { showApi = false }, title = { Text("Адрес API") }, text = { OutlinedTextField(apiUrl, { apiUrl = it }, label = { Text("https://astra.example.com/api/v1") }, singleLine = true) }, confirmButton = { Button({ state.api.baseUrl = apiUrl; showApi = false }) { Text("Сохранить") } }, dismissButton = { TextButton({ showApi = false }) { Text("Отмена") } })
}

@Composable
fun CatalogScreen(state: AstraState) {
    var mode by rememberSaveable { mutableStateOf(0) }; var search by rememberSaveable { mutableStateOf("") }; var category by rememberSaveable { mutableStateOf("Все") }
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }; var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }; var productCategories by remember { mutableStateOf<List<ContentCategory>>(emptyList()) }; var recipeCategories by remember { mutableStateOf<List<ContentCategory>>(emptyList()) }; var selected by remember { mutableStateOf<Recipe?>(null) }
    LaunchedEffect(Unit) { products = suspendResult { state.api.products() }.getOrDefault(emptyList()); recipes = suspendResult { state.api.recipes() }.getOrDefault(emptyList()); productCategories = suspendResult { state.api.categories("product") }.getOrDefault(emptyList()); recipeCategories = suspendResult { state.api.categories("recipe") }.getOrDefault(emptyList()) }
    val categories = if (mode == 0) productCategories.map { it.name } else recipeCategories.map { it.name }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Каталог", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Структура разделов веб-версии", color = AstraTheme.muted) }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) { if (mode == 0) Button({ mode = 0 }) { Text("Продукты") } else OutlinedButton({ mode = 0; category = "Все" }) { Text("Продукты") }; if (mode == 1) Button({ mode = 1 }) { Text("Рецепты") } else OutlinedButton({ mode = 1; category = "Все" }) { Text("Рецепты") } }
        OutlinedTextField(search, { search = it }, label = { Text("Поиск") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(16.dp))
        Picker("Категория: $category", listOf("Все") + categories) { category = it }
        if (mode == 0) LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(products.filter { (search.isBlank() || it.name.contains(search, true)) && (category == "Все" || it.category == category) }, key = { it.id }) { product -> MobileCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(product.name, fontWeight = FontWeight.Bold); Text("${product.category ?: "Без категории"} · ${product.kcal.shown(" ккал")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text("Б ${product.protein.shown(" г")}", fontSize = 12.sp, fontWeight = FontWeight.Bold) } } } }
        else LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(recipes.filter { (search.isBlank() || it.name.contains(search, true)) && (category == "Все" || it.category == category) }, key = { it.id }) { recipe -> MobileRecipeRow(recipe) { selected = recipe } } }
    }
    selected?.let { MobileRecipeDialog(state, it) { selected = null } }
}

@Composable
private fun MobileRecipeDialog(state: AstraState, recipe: Recipe, onDismiss: () -> Unit) {
    var detail by remember { mutableStateOf<RecipeDetail?>(null) }; LaunchedEffect(recipe.id) { detail = suspendResult { state.api.recipe(recipe.id) }.getOrNull() }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(recipe.name) }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text("${recipe.kcal.shown(" ккал")} · Б ${recipe.protein.shown(" г")} · Ж ${recipe.fat.shown(" г")} · У ${recipe.carbs.shown(" г")}", color = AstraTheme.muted); Text("Ингредиенты", fontWeight = FontWeight.Bold); detail?.ingredients?.forEach { Text("${it.name} — ${it.quantity.shown()} ${it.unit ?: ""}") } } }, confirmButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

@Composable
fun ClientTrainerScreen(state: AstraState) {
    var chat by remember { mutableStateOf<TrainerChatResponse?>(null) }; var draft by remember { mutableStateOf("") }; var error by remember { mutableStateOf<String?>(null) }; val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) { suspendResult { state.api.myTrainerChat() }.onSuccess { chat = it }.onFailure { error = it.message } }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Тренер", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Обратная связь и рекомендации", color = AstraTheme.muted) }
        when { chat == null && error == null -> Text("Загрузка…", Modifier.padding(16.dp)); error != null -> Text(error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)); chat?.trainer == null -> EmptyMessage("Тренер пока не назначен", "После подключения тренера здесь появится чат.")
            else -> { val current = chat!!; Text("${current.trainer!!.name} · ${current.trainer!!.email}", Modifier.padding(horizontal = 16.dp), fontWeight = FontWeight.Bold); LazyColumn(Modifier.weight(1f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(current.messages, key = { it.id }) { message -> Row(Modifier.fillMaxWidth(), horizontalArrangement = if (message.senderId == state.user?.id) Arrangement.End else Arrangement.Start) { Text(message.message, Modifier.background(if (message.senderId == state.user?.id) AstraTheme.blue.copy(alpha = .16f) else MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(14.dp)).padding(12.dp)) } } }; Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Bottom) { OutlinedTextField(draft, { draft = it }, label = { Text("Сообщение тренеру") }, modifier = Modifier.weight(1f)); IconButton({ val text = draft.trim(); if (text.isNotEmpty()) { draft = ""; scope.launch { suspendResult { state.api.sendMyTrainerChat(text) }.onSuccess { message -> chat = current.copy(messages = current.messages + message) }.onFailure { error = it.message } } } }) { Icon(Icons.Default.Send, "Отправить") } } }
        }
    }
}

@Composable
fun TrainerScreen(state: AstraState) {
    if (state.user?.isAdmin == true || state.user?.isTrainer == true) TrainerWorkspaceFullScreen(state) else ClientTrainerScreen(state)
}

@Composable
fun TrainerWorkspaceFullScreen(state: AstraState) {
    var section by rememberSaveable { mutableStateOf(0) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }; var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }; var history by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }; var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }; var complexes by remember { mutableStateOf<List<WorkoutComplex>>(emptyList()) }; var equipment by remember { mutableStateOf<List<WorkoutEquipment>>(emptyList()) }; var error by remember { mutableStateOf<String?>(null) }
    var selectedClient by remember { mutableStateOf<ClientSummary?>(null) }; var selectedExercise by remember { mutableStateOf<Exercise?>(null) }; var selectedComplex by remember { mutableStateOf<WorkoutComplex?>(null) }; var selectedEquipment by remember { mutableStateOf<WorkoutEquipment?>(null) }; var selectedPlan by remember { mutableStateOf<WorkoutPlan?>(null) }; var selectedWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    val planned = plans.filter { it.status == "planned" }; val machines = equipment.filter { it.kind == "machine" }; val freeEquipment = equipment.filter { it.kind != "machine" }
    suspend fun load() { suspendResult { state.api.clients() }.onSuccess { clients = it }; suspendResult { state.api.plans() }.onSuccess { plans = it }; suspendResult { state.api.workouts() }.onSuccess { history = it }; suspendResult { state.api.exercises() }.onSuccess { exercises = it }; suspendResult { state.api.workoutComplexes() }.onSuccess { complexes = it }; suspendResult { state.api.workoutEquipment() }.onSuccess { equipment = it }.onFailure { error = it.message } }
    LaunchedEffect(Unit) { load() }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        if (section == 0) Column(Modifier.padding(16.dp)) { Text("Тренерский workspace", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text(if (state.user?.isAdmin == true) "Администратор: полный доступ к инструментам тренера" else "Клиенты, тренировки и справочники", color = AstraTheme.muted) }
        else Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) { TextButton({ section = 0 }) { Text("‹ Разделы") }; Spacer(Modifier.weight(1f)); Text(listOf("", "Клиенты", "Планы тренировок", "История тренировок", "Упражнения", "Комплексы", "Тренажёры", "Инвентарь")[section], fontWeight = FontWeight.Bold) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        if (section == 0) {
            LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("Клиенты", clients.size, AstraTheme.blue) { section = 1 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Планы", planned.size, AstraTheme.green) { section = 2 } } } }
                item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("История", history.size, Color(0xFF8E7CFF)) { section = 3 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Упражнения", exercises.size, Color(0xFFFFA726)) { section = 4 } } } }
                item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("Комплексы", complexes.size, AstraTheme.blue) { section = 5 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Тренажёры", machines.size, AstraTheme.green) { section = 6 } } } }
                item { MobileTrainerTile("Инвентарь", freeEquipment.size, Color(0xFFB56A16)) { section = 7 } }
                item { Text("Все плитки открывают соответствующие разделы, а карточки элементов — подробности.", color = AstraTheme.muted, fontSize = 12.sp) }
            }
        } else when (section) {
            1 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(clients, key = { it.id }) { client -> MobileCard(Modifier.clickable { selectedClient = client }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Person, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(client.name, fontWeight = FontWeight.Bold); Text(client.email, color = AstraTheme.muted, fontSize = 12.sp); client.nextWorkout?.let { Text("Ближайшая тренировка: ${it.scheduledAt}", color = AstraTheme.green, fontSize = 11.sp) } }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } } } }
            2 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(planned, key = { it.id }) { plan -> MobileCard(Modifier.clickable { selectedPlan = plan }) { Column(Modifier.padding(14.dp)) { Text(plan.scheduledAt, fontWeight = FontWeight.Bold); Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            3 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(history, key = { it.id }) { workout -> MobileCard(Modifier.clickable { selectedWorkout = workout }) { Column(Modifier.padding(14.dp)) { Text(workout.name, fontWeight = FontWeight.Bold); Text("${workout.date} · ${workout.sets.shown(" подходов")} × ${workout.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            4 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(exercises, key = { it.id }) { exercise -> MobileCard(Modifier.clickable { selectedExercise = exercise }) { Column(Modifier.padding(14.dp)) { Text(exercise.name, fontWeight = FontWeight.Bold); Text("${exercise.muscleGroup ?: "Другое"} · ${exercise.defaultSets.shown(" подхода")} × ${exercise.defaultReps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            5 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(complexes, key = { it.id }) { complex -> MobileCard(Modifier.clickable { selectedComplex = complex }) { Column(Modifier.padding(14.dp)) { Text(complex.name, fontWeight = FontWeight.Bold); Text("${complex.items.size} упражнений", color = AstraTheme.muted, fontSize = 12.sp); complex.comment?.let { Text(it, fontSize = 12.sp) } } } } }
            6 -> TrainerEquipmentList(machines, selectedEquipment = { selectedEquipment = it })
            else -> TrainerEquipmentList(freeEquipment, selectedEquipment = { selectedEquipment = it })
        }
    }
    selectedClient?.let { TrainerClientChatScreen(state, it) { selectedClient = null } }
    selectedExercise?.let { exercise -> AlertDialog(onDismissRequest = { selectedExercise = null }, title = { Text(exercise.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(exercise.muscleGroup ?: "Другое", color = AstraTheme.muted); Text("Единица: ${exercise.unit ?: "—"}"); Text("Подходы: ${exercise.defaultSets.shown()}"); Text("Повторения: ${exercise.defaultReps.shown()}") } }, confirmButton = { TextButton({ selectedExercise = null }) { Text("Закрыть") } }) }
    selectedComplex?.let { complex -> AlertDialog(onDismissRequest = { selectedComplex = null }, title = { Text(complex.name) }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(5.dp)) { complex.comment?.let { Text(it) }; Text("Упражнения", fontWeight = FontWeight.Bold); complex.items.forEach { Text("${it.name} · ${it.sets.shown(" подхода")} · ${it.durationMinutes.shown(" мин")}") } } }, confirmButton = { TextButton({ selectedComplex = null }) { Text("Закрыть") } }) }
    selectedEquipment?.let { item -> AlertDialog(onDismissRequest = { selectedEquipment = null }, title = { Text(item.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted); item.description?.let { Text(it) } } }, confirmButton = { TextButton({ selectedEquipment = null }) { Text("Закрыть") } }) }
    selectedPlan?.let { plan -> AlertDialog(onDismissRequest = { selectedPlan = null }, title = { Text("План ${plan.scheduledAt}") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(5.dp)) { Text(plan.status, color = AstraTheme.muted); plan.items.forEach { Text("${it.name ?: "Упражнение"} · ${it.sets.shown(" подхода")} · ${it.duration.shown(" мин")}") } } }, confirmButton = { TextButton({ selectedPlan = null }) { Text("Закрыть") } }) }
    selectedWorkout?.let { workout -> AlertDialog(onDismissRequest = { selectedWorkout = null }, title = { Text(workout.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(5.dp)) { Text(workout.date); Text("Подходы: ${workout.sets.shown()}"); Text("Повторения: ${workout.reps.shown()}"); Text("Вес: ${workout.weight.shown(" кг")}"); workout.comment?.let { Text(it) } } }, confirmButton = { TextButton({ selectedWorkout = null }) { Text("Закрыть") } }) }
}

@Composable
private fun MobileTrainerTile(title: String, count: Int, tint: Color, onClick: () -> Unit) { MobileCard(Modifier.clickable(onClick = onClick)) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(title, color = tint, fontWeight = FontWeight.Bold); Text(count.toString(), fontSize = 22.sp, fontWeight = FontWeight.Bold); Text("Открыть раздел ›", color = AstraTheme.muted, fontSize = 11.sp) } } }

@Composable
private fun TrainerEquipmentList(items: List<WorkoutEquipment>, selectedEquipment: (WorkoutEquipment) -> Unit) { LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(items, key = { it.id }) { item -> MobileCard(Modifier.clickable { selectedEquipment(item) }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(item.name, fontWeight = FontWeight.Bold); Text(item.description ?: if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted, fontSize = 12.sp) }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } } } } }

@Composable
fun TrainerWorkspaceScreen(state: AstraState) {
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }; var selected by remember { mutableStateOf<ClientSummary?>(null) }; var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { state.api.clients() }.onSuccess { clients = it }.onFailure { error = it.message } }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Тренер", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text(if (state.user?.isAdmin == true) "Администраторский доступ: все тренерские инструменты" else "Клиенты, планы и чат", color = AstraTheme.muted) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        if (clients.isEmpty() && error == null) EmptyMessage("Клиентов пока нет", "Добавьте клиента в веб-версии или назначьте ему этого тренера.")
        else LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(clients, key = { it.id }) { client -> MobileCard(Modifier.clickable { selected = client }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Person, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(client.name, fontWeight = FontWeight.Bold); Text(client.email, color = AstraTheme.muted, fontSize = 12.sp); client.nextWorkout?.let { Text("Ближайшая тренировка: ${it.scheduledAt}", color = AstraTheme.green, fontSize = 11.sp) } }; if (client.unreadMessages > 0) Text(client.unreadMessages.toString(), color = Color(0xFFB56A16), fontWeight = FontWeight.Bold) } } } }
    }
    selected?.let { TrainerClientChatScreen(state, it) { selected = null } }
}

@Composable
private fun TrainerClientChatScreen(state: AstraState, client: ClientSummary, onDismiss: () -> Unit) {
    var messages by remember { mutableStateOf<List<TrainerChatMessage>>(emptyList()) }; var draft by remember { mutableStateOf("") }; val scope = rememberCoroutineScope(); var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(client.id) { suspendResult { state.api.clientChat(client.id) }.onSuccess { messages = it }.onFailure { error = it.message } }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Чат: ${client.name}") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { error?.let { Text(it, color = MaterialTheme.colorScheme.error) }; messages.forEach { message -> Text("${message.senderName}: ${message.message}", Modifier.background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(10.dp)).padding(9.dp)) }; OutlinedTextField(draft, { draft = it }, label = { Text("Сообщение клиенту") }, modifier = Modifier.fillMaxWidth()) } }, confirmButton = { Button({ val text = draft.trim(); if (text.isNotEmpty()) { draft = ""; scope.launch { suspendResult { state.api.sendClientChat(client.id, text) }.onSuccess { messages = messages + it }.onFailure { error = it.message } } } }) { Icon(Icons.Default.Send, null); Spacer(Modifier.width(5.dp)); Text("Отправить") } }, dismissButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

@Composable
fun InformationScreen(state: AstraState) {
    var sections by remember { mutableStateOf<List<ArticleSection>>(emptyList()) }; var articles by remember { mutableStateOf<List<Article>>(emptyList()) }; var selectedSection by remember { mutableStateOf<Int?>(null) }; var search by rememberSaveable { mutableStateOf("") }; var selected by remember { mutableStateOf<Article?>(null) }; var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { Pair(state.api.articleSections(), state.api.articles()) }.onSuccess { sections = it.first; articles = it.second }.onFailure { error = it.message } }
    val filtered = articles.filter { (selectedSection == null || it.sectionId == selectedSection) && (search.isBlank() || it.title.contains(search, true) || it.body.stripHtml().contains(search, true) || (it.tags ?: "").contains(search, true)) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Информация", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Питание, тренировки и полезные материалы", color = AstraTheme.muted) }
        OutlinedTextField(search, { search = it }, label = { Text("Найти статью") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) { OutlinedButton({ selectedSection = null }) { Text("Все") }; sections.forEach { section -> OutlinedButton({ selectedSection = section.id }) { Text(section.name) } } }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(filtered, key = { it.id }) { article -> MobileCard(Modifier.clickable { selected = article }) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(article.sectionName, color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold); Text(article.title, fontWeight = FontWeight.Bold); Text(article.body.stripHtml(), color = AstraTheme.muted, maxLines = 3) } } } }
    }
    selected?.let { ArticleDialog(it) { selected = null } }
}

@Composable
private fun ArticleDialog(article: Article, onDismiss: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text(article.title) }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) { Text(article.sectionName, color = AstraTheme.blue, fontWeight = FontWeight.Bold); Text(article.body.stripHtml()); article.tags?.let { Text(it, color = AstraTheme.muted, fontSize = 12.sp) } } }, confirmButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

private fun String.stripHtml(): String = replace(Regex("<[^>]+>"), " ").replace("&nbsp;", " ").replace(Regex("\\s+"), " ").trim()

@Composable
fun MobileWorkoutsScreen(state: AstraState) {
    var section by rememberSaveable { mutableStateOf(0) }; var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }; var logs by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }; var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }; var complexes by remember { mutableStateOf<List<WorkoutComplex>>(emptyList()) }; var equipment by remember { mutableStateOf<List<WorkoutEquipment>>(emptyList()) }; var showAdd by remember { mutableStateOf(false) }
    suspend fun load() { plans = suspendResult { state.api.plans() }.getOrDefault(emptyList()); logs = suspendResult { state.api.workouts() }.getOrDefault(emptyList()); exercises = suspendResult { state.api.exercises() }.getOrDefault(emptyList()); complexes = suspendResult { state.api.workoutComplexes() }.getOrDefault(emptyList()); equipment = suspendResult { state.api.workoutEquipment() }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { load() }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Тренировки", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Планы, журнал, упражнения и инвентарь", color = AstraTheme.muted) }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf("Журнал", "Упражнения", "Комплексы", "Инвентарь").forEachIndexed { index, title -> if (section == index) Button({ section = index }) { Text(title) } else OutlinedButton({ section = index }) { Text(title) } } }
        if (section == 0) Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.End) { Button({ showAdd = true }) { Text("Записать") } }
        when (section) {
            0 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { if (plans.isNotEmpty()) item { Text("Планы", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; items(plans, key = { "p${it.id}" }) { plan -> MobileCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(plan.scheduledAt, fontWeight = FontWeight.Bold); Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp) }; if (plan.status == "planned") TextButton({ kotlinx.coroutines.MainScope().launch { state.api.completePlan(plan.id); load() } }) { Text("Готово") } } } }; item { Text("Журнал", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; items(logs, key = { "l${it.id}" }) { log -> MobileCard { Column(Modifier.padding(14.dp)) { Text(log.name, fontWeight = FontWeight.Bold); Text("${log.date} · ${log.sets.shown(" подходов")} × ${log.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            1 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(exercises, key = { it.id }) { exercise -> MobileCard { Column(Modifier.padding(14.dp)) { Text(exercise.name, fontWeight = FontWeight.Bold); Text("${exercise.muscleGroup ?: "Другое"} · ${exercise.defaultSets.shown(" подхода")} × ${exercise.defaultReps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            2 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(complexes, key = { it.id }) { complex -> MobileCard { Column(Modifier.padding(14.dp)) { Text(complex.name, fontWeight = FontWeight.Bold); Text("${complex.items.size} упражнений", color = AstraTheme.muted, fontSize = 12.sp); complex.comment?.let { Text(it, fontSize = 12.sp) } } } } }
            else -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(equipment, key = { it.id }) { item -> MobileCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column { Text(item.name, fontWeight = FontWeight.Bold); Text(if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted, fontSize = 12.sp); item.description?.let { Text(it, fontSize = 12.sp) } } } } } }
        }
    }
    if (showAdd) MobileAddWorkoutDialog(exercises, { date, exercise, weight, sets, reps, rir -> kotlinx.coroutines.MainScope().launch { state.api.addWorkout(date, exercise.id, weight, sets, reps, rir); load(); showAdd = false } }, { showAdd = false })
}

@Composable
private fun MobileAddWorkoutDialog(exercises: List<Exercise>, onSave: (String, Exercise, Double?, Double?, Double?, String?) -> Unit, onDismiss: () -> Unit) {
    var date by remember { mutableStateOf(todayTime()) }; var exercise by remember { mutableStateOf(exercises.firstOrNull()) }; var weight by remember { mutableStateOf("") }; var sets by remember { mutableStateOf("") }; var reps by remember { mutableStateOf("") }; var rir by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Записать тренировку") }, text = { Column(verticalArrangement = Arrangement.spacedBy(7.dp)) { Picker("Упражнение: ${exercise?.name ?: "—"}", exercises.map { it.name }) { exercise = exercises.firstOrNull { item -> item.name == it } }; OutlinedTextField(date, { date = it }, label = { Text("Дата и время") }, singleLine = true); OutlinedTextField(weight, { weight = it }, label = { Text("Вес") }, singleLine = true); OutlinedTextField(sets, { sets = it }, label = { Text("Подходы") }, singleLine = true); OutlinedTextField(reps, { reps = it }, label = { Text("Повторения") }, singleLine = true); OutlinedTextField(rir, { rir = it }, label = { Text("RIR") }, singleLine = true) } }, confirmButton = { Button({ exercise?.let { onSave(date, it, weight.toNumber(), sets.toNumber(), reps.toNumber(), rir.takeIf { it.isNotBlank() }) } }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}
