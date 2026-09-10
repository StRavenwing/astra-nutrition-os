package com.astra.nutrition

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocalGroceryStore
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Person2
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
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
    val canManage = state.user?.isAdmin == true || state.user?.isTrainer == true
    val bottom = buildList {
        add(Screen.Overview)
        if (canManage) add(Screen.Trainer)
        add(Screen.Diary)
        add(Screen.Workouts)
        add(Screen.Products)
        add(Screen.Recipes)
        add(Screen.Information)
        add(Screen.More)
    }
    Scaffold(bottomBar = {
        Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface).horizontalScroll(rememberScrollState()).padding(horizontal = 8.dp, vertical = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            bottom.forEach { item ->
                val selected = screen == item
                Column(Modifier.width(78.dp).clip(RoundedCornerShape(12.dp)).clickable { screen = item }.background(if (selected) AstraTheme.blue.copy(alpha = .12f) else Color.Transparent).padding(horizontal = 6.dp, vertical = 5.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Icon(item.mobileIcon(), null, tint = if (selected) AstraTheme.blue else AstraTheme.muted, modifier = Modifier.size(19.dp))
                    Text(item.mobileTitle(), color = if (selected) AstraTheme.blue else AstraTheme.muted, fontSize = 10.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal, maxLines = 1)
                }
            }
        }
    }) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when (screen) {
                Screen.Overview -> MobileDashboard(state) { screen = it }
                Screen.Diary -> DiaryCalendarScreen(state)
                Screen.Workouts -> MobileWorkoutsDashboardScreen(state)
                Screen.Trainer -> TrainerScreen(state)
                Screen.Information -> InformationScreen(state)
                Screen.Catalog -> CatalogScreen(state)
                Screen.Progress -> ProgressScreen(state)
                Screen.Products -> ProductsScreen(state)
                Screen.Recipes -> RecipesScreen(state)
                Screen.More -> MobileProfileReferenceScreen(state) { screen = it }
            }
        }
    }
}

private fun Screen.mobileTitle() = when (this) {
    Screen.Overview -> "Обзор"; Screen.Diary -> "Дневник"; Screen.Workouts -> "Тренировки"; Screen.Trainer -> "Клиенты"; Screen.Products -> "Продукты"; Screen.Recipes -> "Рецепты"; Screen.Information -> "Инфо"; Screen.More -> "Профиль"; else -> "Раздел"
}
private fun Screen.mobileIcon() = when (this) {
    Screen.Overview -> Icons.Default.Home; Screen.Diary -> Icons.Default.Restaurant; Screen.Workouts -> Icons.Default.FitnessCenter; Screen.Trainer -> Icons.Default.Person; Screen.Products -> Icons.Default.LocalGroceryStore; Screen.Recipes -> Icons.Default.Book; Screen.Information -> Icons.Default.Info; Screen.More -> Icons.Default.Person; else -> Icons.Default.MoreHoriz
}

@Composable
private fun MobileCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Card(modifier.fillMaxWidth().border(1.dp, AstraTheme.line, RoundedCornerShape(16.dp)), shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(MaterialTheme.colorScheme.surface), elevation = CardDefaults.cardElevation(1.dp)) { content() }
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
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { Box(Modifier.weight(1f)) { MobileMetric("Продукты", dashboard.products.toString(), AstraTheme.blue) { onNavigate(Screen.Catalog) } }; Box(Modifier.weight(1f)) { MobileMetric("Рецепты", dashboard.recipes.toString(), AstraTheme.green) { onNavigate(Screen.Catalog) } } }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { Box(Modifier.weight(1f)) { MobileMetric("Одобренные рецепты", dashboard.approved.toString(), AstraTheme.blue) { onNavigate(Screen.Catalog) } }; Box(Modifier.weight(1f)) { MobileMetric("Вес", dashboard.latest?.weight.shown(" кг"), AstraTheme.blue) { onNavigate(Screen.Progress) } } }
                Text("«Одобренные рецепты» — рецепты, прошедшие модерацию и доступные для дневника питания.", fontSize = 12.sp, color = AstraTheme.muted)
                dashboard.latest?.let { latest -> MobileCard(Modifier.clickable { onNavigate(Screen.Progress) }) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) { Text("Последний замер", fontWeight = FontWeight.Bold); Text("${latest.date} · Вес ${latest.weight.shown(" кг")} · Талия ${latest.waist.shown(" см")}", color = AstraTheme.muted) } } }
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Рецепты с высоким белком", fontSize = 18.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.weight(1f)); TextButton({ onNavigate(Screen.Catalog) }) { Text("Каталог") } }
                MobileItemGrid(dashboard.top) { recipe -> MobileRecipeRow(recipe) { onNavigate(Screen.Catalog) } }
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun MobileRecipeRow(recipe: Recipe, onClick: () -> Unit) {
    MobileCard(Modifier.clickable(onClick = onClick)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Icon(Icons.Default.Book, null, tint = AstraTheme.green)
            Text(recipe.name, fontWeight = FontWeight.Bold, maxLines = 3)
            Text(recipe.category, color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
            Text("Б ${recipe.protein.shown(" г")} · ${recipe.kcal.shown(" ккал")}", color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun CatalogFoodCard(name: String, category: String, kcal: Double?, protein: Double?, fat: Double?, carbs: Double?, onClick: (() -> Unit)? = null) {
    val cardModifier = if (onClick == null) Modifier else Modifier.clickable(onClick = onClick)
    MobileCard(cardModifier.heightIn(min = 168.dp)) {
        Column(Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(category, color = AstraTheme.muted, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Text(name, fontSize = 18.sp, lineHeight = 21.sp, fontWeight = FontWeight.Bold, maxLines = 3)
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CatalogMacro("ККАЛ", kcal.shown())
                CatalogMacro("Б", protein.shown(" г"))
                CatalogMacro("Ж", fat.shown(" г"))
                CatalogMacro("У", carbs.shown(" г"))
            }
        }
    }
}

@Composable
private fun RowScope.CatalogMacro(label: String, value: String) {
    Column(Modifier.weight(1f)) {
        Text(label, color = AstraTheme.muted, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
        Text(value, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}

@Composable
private fun LegacyMobileProfileReferenceScreen(state: AstraState, onNavigate: (Screen) -> Unit) {
    var progress by remember { mutableStateOf<List<ProgressEntry>>(emptyList()) }
    var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }
    var showSettings by remember { mutableStateOf(false) }
    var showApi by remember { mutableStateOf(false) }
    var apiUrl by remember { mutableStateOf(state.api.baseUrl) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val user = state.user
    val initial = (user?.name ?: "A").firstOrNull()?.uppercase() ?: "A"
    val latest = progress.firstOrNull()

    suspend fun load() {
        suspendResult { Pair(state.api.progress(), state.api.plans()) }
            .onSuccess { progress = it.first; plans = it.second; error = null }
            .onFailure { error = it.message }
    }

    LaunchedEffect(Unit) { load() }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        LazyColumn(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                Column(Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(77.dp).background(AstraTheme.blue, RoundedCornerShape(50.dp)).border(3.dp, AstraTheme.blue, RoundedCornerShape(50.dp)), contentAlignment = Alignment.Center) {
                        Text(initial, color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(user?.name ?: "Пользователь", fontSize = 21.sp, fontWeight = FontWeight.Bold)
                    Text(user?.email ?: "—", color = AstraTheme.muted, fontSize = 13.sp)
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
                        Text("Замеры и цели", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        MobileProfileMetric("Вес", latest?.weight.shown(" кг"))
                        MobileProfileMetric("Калории", latest?.kcalTarget.shown(" ккал в день"))
                        MobileProfileMetric("Тренировки", if (plans.none { it.status == "planned" }) "Нет планов" else "${plans.count { it.status == "planned" }} запланировано")
                    }
                }
            }
            item { MobileProfileReferenceRow("Замеры и цели") { onNavigate(Screen.Progress) } }
            item { MobileProfileReferenceRow("Журнал тренировок") { onNavigate(Screen.Workouts) } }
            item { MobileProfileReferenceRow("Чат с тренером") { onNavigate(Screen.Trainer) } }
            item { MobileProfileReferenceRow("Продукты и рецепты") { onNavigate(Screen.Catalog) } }
            item { MobileProfileReferenceRow("Статьи и информация") { onNavigate(Screen.Information) } }
            item { MobileProfileReferenceRow("Настройки") { showSettings = true } }
            item {
                MobileProfileReferenceRow("Выйти", danger = true) {
                    scope.launch { state.api.logout(); state.user = null }
                }
            }
            error?.let { message -> item { Text(message, color = MaterialTheme.colorScheme.error, fontSize = 12.sp) } }
            item { Spacer(Modifier.height(12.dp)) }
        }
    }
    if (showSettings) AlertDialog(
        onDismissRequest = { showSettings = false },
        title = { Text("Настройки") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Тёмная тема", Modifier.weight(1f))
                    androidx.compose.material3.Switch(checked = state.darkTheme, onCheckedChange = state::toggleTheme)
                }
                OutlinedButton(onClick = { apiUrl = state.api.baseUrl; showApi = true }) { Text("Адрес API") }
            }
        },
        confirmButton = { TextButton({ showSettings = false }) { Text("Закрыть") } }
    )
    if (showApi) AlertDialog(
        onDismissRequest = { showApi = false },
        title = { Text("Адрес API") },
        text = { OutlinedTextField(apiUrl, { apiUrl = it }, label = { Text("https://astra.example.com/api/v1") }, singleLine = true) },
        confirmButton = { Button({ state.api.baseUrl = apiUrl; showApi = false }) { Text("Сохранить") } },
        dismissButton = { TextButton({ showApi = false }) { Text("Отмена") } }
    )
}

@Composable
private fun MobileProfileReferenceScreen(state: AstraState, onNavigate: (Screen) -> Unit) {
    var progress by remember { mutableStateOf<List<ProgressEntry>>(emptyList()) }
    var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }
    var goalsExpanded by rememberSaveable { mutableStateOf(true) }
    var showSettings by remember { mutableStateOf(false) }
    var apiUrl by remember { mutableStateOf(state.api.baseUrl) }
    val scope = rememberCoroutineScope()
    val user = state.user
    val canManage = user?.isAdmin == true || user?.isTrainer == true
    val initial = (user?.name ?: "A").firstOrNull()?.uppercase() ?: "A"
    val latest = progress.firstOrNull()

    LaunchedEffect(Unit) {
        suspendResult { Pair(state.api.progress(), state.api.plans()) }.onSuccess { progress = it.first; plans = it.second }
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        LazyColumn(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Column(Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(77.dp).background(AstraTheme.blue, RoundedCornerShape(50.dp)), contentAlignment = Alignment.Center) { Text(initial, color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold) }
                    Spacer(Modifier.height(10.dp)); Text(user?.name ?: "Пользователь", fontSize = 21.sp, fontWeight = FontWeight.Bold); Text(user?.email ?: "—", color = AstraTheme.muted, fontSize = 13.sp)
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Person, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Text("Имя", fontSize = 17.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.weight(1f)); Text("Профиль", color = AstraTheme.muted, fontSize = 11.sp) }
                        Text(user?.name ?: "Пользователь", fontSize = 20.sp, fontWeight = FontWeight.Bold)
                        Text(user?.email ?: "—", color = AstraTheme.muted, fontSize = 12.sp)
                    }
                }
            }
            item {
                MobileCard(Modifier.clickable { goalsExpanded = !goalsExpanded }) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.TrendingUp, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text("Цели и предпочтения", fontSize = 17.sp, fontWeight = FontWeight.Bold); Text(if (goalsExpanded) "Развернуто" else "Свернуто", color = AstraTheme.muted, fontSize = 12.sp) }; Text(if (goalsExpanded) "⌃" else "⌄", color = AstraTheme.muted, fontSize = 22.sp) }
                }
            }
            if (goalsExpanded) {
                item {
                    MobileCard {
                        Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            MobileProfileMetric("Вес", latest?.weight.shown(" кг")); MobileProfileMetric("Желаемый вес", latest?.desiredWeight.shown(" кг")); MobileProfileMetric("Калории", latest?.kcalTarget.shown(" ккал в день")); MobileProfileMetric("Тренировки", if (plans.none { it.status == "planned" }) "Нет планов" else "${plans.count { it.status == "planned" }} запланировано")
                            Button({ onNavigate(Screen.Progress) }, modifier = Modifier.fillMaxWidth()) { Text("Открыть прогресс") }
                        }
                    }
                }
            }
            item {
                MobileCard {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Restaurant, null, tint = AstraTheme.muted); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text("Пищевые привычки", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AstraTheme.muted); Text("В разработке", color = AstraTheme.muted, fontSize = 12.sp) }; Text("⌁", color = AstraTheme.muted, fontSize = 20.sp) }
                }
            }
            item { MobileProfileReferenceRow("Обратная связь", onClick = { onNavigate(Screen.Trainer) }) }
            if (!canManage) {
                item { OutlinedButton(onClick = { }, enabled = false, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.FitnessCenter, null); Spacer(Modifier.width(6.dp)); Text("Стать тренером · В разработке") } }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(horizontal = 14.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Settings, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Text("Настройки", Modifier.weight(1f), fontWeight = FontWeight.SemiBold); TextButton({ showSettings = true }) { Text("Открыть") } }
                    }
                }
            }
            item { OutlinedButton(onClick = { scope.launch { state.api.logout(); state.user = null } }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.outlinedButtonColors(contentColor = AstraTheme.danger)) { Icon(Icons.Default.ArrowBack, null); Spacer(Modifier.width(6.dp)); Text("Выйти") } }
            item { Spacer(Modifier.height(12.dp)) }
        }
    }
    if (showSettings) AlertDialog(onDismissRequest = { showSettings = false }, title = { Text("Настройки") }, text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Text("Тёмная тема", Modifier.weight(1f)); androidx.compose.material3.Switch(checked = state.darkTheme, onCheckedChange = state::toggleTheme) }; OutlinedButton({ apiUrl = state.api.baseUrl }) { Text("API: $apiUrl") } } }, confirmButton = { TextButton({ showSettings = false }) { Text("Закрыть") } })
}

@Composable
private fun MobileProfileMetric(title: String, value: String) {
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = AstraTheme.muted)
            Spacer(Modifier.weight(1f))
            Text(value, color = AstraTheme.blue, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.fillMaxWidth().height(1.dp).background(AstraTheme.line))
    }
}

@Composable
private fun MobileProfileReferenceRow(title: String, danger: Boolean = false, onClick: () -> Unit) {
    Card(Modifier.fillMaxWidth().border(1.dp, AstraTheme.line, RoundedCornerShape(12.dp)).clickable(onClick = onClick), shape = RoundedCornerShape(12.dp), colors = CardDefaults.cardColors(MaterialTheme.colorScheme.surface), elevation = CardDefaults.cardElevation(1.dp)) {
        Row(Modifier.padding(horizontal = 16.dp).height(45.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, color = if (danger) AstraTheme.danger else MaterialTheme.colorScheme.onSurface, fontSize = 14.sp)
            Spacer(Modifier.weight(1f))
            if (!danger) Text("›", color = AstraTheme.muted, fontSize = 24.sp)
        }
    }
}

@Composable
private fun MobileProfileScreen(state: AstraState, onNavigate: (Screen) -> Unit) {
    var showApi by remember { mutableStateOf(false) }
    var apiUrl by remember { mutableStateOf(state.api.baseUrl) }
    val scope = rememberCoroutineScope()
    val user = state.user
    val initial = (user?.name ?: "A").firstOrNull()?.uppercase() ?: "A"
    val role = when {
        user?.isAdmin == true -> "Администратор"
        user?.isTrainer == true -> "Тренер"
        else -> "Пользователь"
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 16.dp)) {
            Text("Профиль", fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text("Аккаунт, настройки и разделы Astra", color = AstraTheme.muted)
        }
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                MobileCard {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(58.dp).background(AstraTheme.blue, RoundedCornerShape(50.dp)), contentAlignment = Alignment.Center) {
                            Text(initial, color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(user?.name ?: "Пользователь", fontSize = 19.sp, fontWeight = FontWeight.Bold)
                            Text(user?.email ?: "—", color = AstraTheme.muted, fontSize = 13.sp)
                            Text(role, color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
            item { Text("Моя активность", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { MobileProfileTile("Замеры и цели", "Прогресс", Icons.Default.TrendingUp, AstraTheme.blue) { onNavigate(Screen.Progress) } }
                    Box(Modifier.weight(1f)) { MobileProfileTile("Журнал", "Тренировки", Icons.Default.FitnessCenter, AstraTheme.green) { onNavigate(Screen.Workouts) } }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { MobileProfileTile("Обратная связь", "Тренер", Icons.Default.Person, AstraTheme.amber) { onNavigate(Screen.Trainer) } }
                    Box(Modifier.weight(1f)) { MobileProfileTile("Материалы", "Информация", Icons.Default.Info, AstraTheme.blue) { onNavigate(Screen.Information) } }
                }
            }
            item { Text("Настройки", fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp)) }
            item {
                MobileCard {
                    Column(Modifier.padding(horizontal = 14.dp, vertical = 5.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Settings, null, tint = AstraTheme.blue)
                            Spacer(Modifier.width(10.dp))
                            Text("Тёмная тема", Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                            androidx.compose.material3.Switch(checked = state.darkTheme, onCheckedChange = state::toggleTheme)
                        }
                        TextButton(onClick = { apiUrl = state.api.baseUrl; showApi = true }) {
                            Icon(Icons.Default.Settings, null)
                            Spacer(Modifier.width(6.dp))
                            Column(horizontalAlignment = Alignment.Start) {
                                Text("Адрес API")
                                Text(state.api.baseUrl, color = AstraTheme.muted, fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
            item { Text("Разделы", fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp)) }
            item {
                MobileCard {
                    Column(Modifier.padding(horizontal = 14.dp, vertical = 5.dp)) {
                        MobileProfileAction("Продукты и рецепты", "Каталог веб-версии", Icons.Default.Book) { onNavigate(Screen.Catalog) }
                        MobileProfileAction("Статьи и информация", "Полезные материалы", Icons.Default.Info) { onNavigate(Screen.Information) }
                    }
                }
            }
            item {
                OutlinedButton(onClick = { scope.launch { state.api.logout(); state.user = null } }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Default.ArrowBack, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Выйти из аккаунта")
                }
            }
            item { Spacer(Modifier.height(12.dp)) }
        }
    }
    if (showApi) AlertDialog(
        onDismissRequest = { showApi = false },
        title = { Text("Адрес API") },
        text = { OutlinedTextField(apiUrl, { apiUrl = it }, label = { Text("https://astra.example.com/api/v1") }, singleLine = true) },
        confirmButton = { Button({ state.api.baseUrl = apiUrl; showApi = false }) { Text("Сохранить") } },
        dismissButton = { TextButton({ showApi = false }) { Text("Отмена") } }
    )
}

@Composable
private fun MobileProfileTile(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, onClick: () -> Unit) {
    MobileCard(Modifier.clickable(onClick = onClick)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(23.dp))
            Text(title, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Text(subtitle, color = AstraTheme.muted, fontSize = 11.sp)
        }
    }
}

@Composable
private fun MobileProfileAction(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = AstraTheme.blue)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = AstraTheme.muted, fontSize = 11.sp)
        }
        Text("›", fontSize = 22.sp, color = AstraTheme.muted)
    }
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
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }; var recipes by remember { mutableStateOf<List<Recipe>>(emptyList()) }; var productCategories by remember { mutableStateOf<List<ContentCategory>>(emptyList()) }; var recipeCategories by remember { mutableStateOf<List<ContentCategory>>(emptyList()) }; var selected by remember { mutableStateOf<Recipe?>(null) }; var selectedProduct by remember { mutableStateOf<Product?>(null) }
    var editingProduct by remember { mutableStateOf<Product?>(null) }
    var editingRecipe by remember { mutableStateOf<Recipe?>(null) }
    var showProductEditor by remember { mutableStateOf(false) }
    var showRecipeEditor by remember { mutableStateOf(false) }
    var showCatalogManage by remember { mutableStateOf(false) }
    var shareType by remember { mutableStateOf<String?>(null) }
    var shareId by remember { mutableStateOf<Int?>(null) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    var catalogError by remember { mutableStateOf<String?>(null) }
    val catalogScope = rememberCoroutineScope()
    val canManageProducts = state.user?.isAdmin == true
    suspend fun reloadCatalog() {
        products = suspendResult { state.api.products() }.getOrDefault(emptyList())
        recipes = suspendResult { state.api.recipes() }.getOrDefault(emptyList())
        productCategories = suspendResult { state.api.categories("product") }.getOrDefault(emptyList())
        recipeCategories = suspendResult { state.api.categories("recipe") }.getOrDefault(emptyList())
    }
    LaunchedEffect(Unit) { products = suspendResult { state.api.products() }.getOrDefault(emptyList()); recipes = suspendResult { state.api.recipes() }.getOrDefault(emptyList()); productCategories = suspendResult { state.api.categories("product") }.getOrDefault(emptyList()); recipeCategories = suspendResult { state.api.categories("recipe") }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { reloadCatalog() }
    LaunchedEffect(shareType) { if (shareType != null && clients.isEmpty()) clients = suspendResult { state.api.clients() }.getOrDefault(emptyList()) }
    if (selectedProduct != null) {
        val product = selectedProduct!!
        val canManageProducts = state.user?.isAdmin == true || state.user?.isTrainer == true
        MobileProductDetailScreen(product, { selectedProduct = null }, { editingProduct = product; showProductEditor = true }, { selectedProduct = null; catalogScope.launch { suspendResult { state.api.deleteProduct(product.id) }.onSuccess { reloadCatalog() }.onFailure { catalogError = it.message } } }, { catalogScope.launch { suspendResult { state.api.shareToTrainer("product", product.id) }.onFailure { catalogError = it.message } } }, onShareClient = { shareType = "product"; shareId = product.id }, canEdit = state.user?.isAdmin == true, canShareToTrainer = !canManageProducts, canShareToClient = canManageProducts)
        if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId -> val type = shareType!!; val id = shareId!!; catalogScope.launch { suspendResult { state.api.shareToClient(clientId, type, id) }.onFailure { catalogError = it.message }; shareType = null; shareId = null } }, { shareType = null; shareId = null })
        return
    }
    if (selected != null) {
        val recipe = selected!!
        val canManageRecipes = state.user?.isAdmin == true || state.user?.isTrainer == true
        val canEditRecipe = state.user?.isAdmin == true || recipe.collection == "local"
        MobileRecipeDetailScreen(state, recipe, { selected = null }, { selected = null; editingRecipe = recipe; showRecipeEditor = true }, { selected = null; catalogScope.launch { suspendResult { state.api.deleteRecipe(recipe.id) }.onSuccess { reloadCatalog() }.onFailure { catalogError = it.message } } }, { catalogScope.launch { suspendResult { state.api.shareToTrainer("recipe", recipe.id) }.onFailure { catalogError = it.message } } }, onShareClient = { shareType = "recipe"; shareId = recipe.id }, canEdit = canEditRecipe, canShareToTrainer = !canManageRecipes, canShareToClient = canManageRecipes, onSubmit = { catalogScope.launch { suspendResult { state.api.requestRecipeSubmission(recipe.id) }.onSuccess { reloadCatalog() }.onFailure { catalogError = it.message } } }, onCancelSubmission = { catalogScope.launch { suspendResult { state.api.cancelRecipeSubmission(recipe.id) }.onSuccess { reloadCatalog() }.onFailure { catalogError = it.message } } })
        if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId -> val type = shareType!!; val id = shareId!!; catalogScope.launch { suspendResult { state.api.shareToClient(clientId, type, id) }.onFailure { catalogError = it.message }; shareType = null; shareId = null } }, { shareType = null; shareId = null })
        return
    }
    val categories = if (mode == 0) productCategories.map { it.name } else recipeCategories.map { it.name }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        TextButton({ showCatalogManage = true }, modifier = Modifier.padding(horizontal = 16.dp)) { Text("manage catalog") }
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), horizontalArrangement = Arrangement.End) {
            if (mode == 0 && canManageProducts) TextButton({ editingProduct = null; showProductEditor = true }) { Text("+ продукт") }
            TextButton({ editingRecipe = null; showRecipeEditor = true }) { Text("+ блюдо") }
        }
        Column(Modifier.padding(16.dp)) { Text("Каталог", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Структура разделов веб-версии", color = AstraTheme.muted) }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) { if (mode == 0) OutlinedButton({ mode = 0 }, colors = ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue)) { Text("Продукты") } else OutlinedButton({ mode = 0; category = "Все" }) { Text("Продукты") }; if (mode == 1) OutlinedButton({ mode = 1 }, colors = ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue)) { Text("Рецепты") } else OutlinedButton({ mode = 1; category = "Все" }) { Text("Рецепты") } }
        OutlinedTextField(search, { search = it }, label = { Text("Поиск") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(16.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            (listOf("Все") + categories.distinct()).forEach { name ->
                CatalogCategoryTile(name, category == name) { category = name }
            }
        }
        val visibleProducts = products.filter { (search.isBlank() || it.name.contains(search, true)) && (category == "Все" || it.category == category) }
        val visibleRecipes = recipes.filter { (search.isBlank() || it.name.contains(search, true)) && (category == "Все" || it.category == category) }
        if (mode == 0) {
            LazyVerticalGrid(columns = GridCells.Fixed(2), modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 16.dp)) {
                items(visibleProducts.size, key = { visibleProducts[it].id }) { index ->
                    val product = visibleProducts[index]
                    CatalogFoodCard(product.name, product.category ?: "Без категории", product.kcal, product.protein, product.fat, product.carbs) { selectedProduct = product }
                }
            }
        } else {
            LazyVerticalGrid(columns = GridCells.Fixed(2), modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 16.dp)) {
                items(visibleRecipes.size, key = { visibleRecipes[it].id }) { index ->
                    val recipe = visibleRecipes[index]
                    CatalogFoodCard(recipe.name, recipe.category, recipe.kcal, recipe.protein, recipe.fat, recipe.carbs) { selected = recipe }
                }
            }
        }
    }
    catalogError?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
    if (showProductEditor) ProductEditorDialog(editingProduct, { body -> catalogScope.launch { suspendResult { if (editingProduct == null) state.api.createProduct(body) else state.api.updateProduct(editingProduct!!.id, body) }.onSuccess { reloadCatalog(); showProductEditor = false }.onFailure { catalogError = it.message } } }, if (editingProduct != null) ({ catalogScope.launch { suspendResult { state.api.deleteProduct(editingProduct!!.id) }.onSuccess { reloadCatalog(); showProductEditor = false }.onFailure { catalogError = it.message } } }) else null) { showProductEditor = false }
    if (showRecipeEditor) RecipeEditorDialog(editingRecipe, products, { body -> catalogScope.launch { suspendResult { if (editingRecipe == null) state.api.createRecipe(body) else state.api.updateRecipe(editingRecipe!!.id, body) }.onSuccess { reloadCatalog(); showRecipeEditor = false }.onFailure { catalogError = it.message } } }, if (editingRecipe != null) ({ catalogScope.launch { suspendResult { state.api.deleteRecipe(editingRecipe!!.id) }.onSuccess { reloadCatalog(); showRecipeEditor = false }.onFailure { catalogError = it.message } } }) else null) { showRecipeEditor = false }
    if (showCatalogManage) CatalogEntityManageDialog(products, recipes, { item -> editingProduct = item; showProductEditor = true; showCatalogManage = false }, { item -> catalogScope.launch { suspendResult { state.api.deleteProduct(item.id) }.onSuccess { reloadCatalog(); showCatalogManage = false }.onFailure { catalogError = it.message } } }, { item -> editingRecipe = item; showRecipeEditor = true; showCatalogManage = false }, { item -> catalogScope.launch { suspendResult { state.api.deleteRecipe(item.id) }.onSuccess { reloadCatalog(); showCatalogManage = false }.onFailure { catalogError = it.message } } }, { type, id -> catalogScope.launch { suspendResult { state.api.shareToTrainer(type, id) }.onFailure { catalogError = it.message } }; shareType = type; shareId = id; showCatalogManage = false }, { showCatalogManage = false })
    if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId -> val type = shareType!!; val id = shareId!!; catalogScope.launch { suspendResult { state.api.shareToClient(clientId, type, id) }.onFailure { catalogError = it.message }; shareType = null; shareId = null } }, { shareType = null; shareId = null })
}

@Composable
private fun MobileProductDetailScreen(product: Product, onBack: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit, onShare: () -> Unit, onShareClient: () -> Unit, canEdit: Boolean, canShareToTrainer: Boolean, canShareToClient: Boolean) {
    var confirmDelete by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
            Text("Продукт", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp), contentPadding = PaddingValues(bottom = 20.dp)) {
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.LocalGroceryStore, null, tint = AstraTheme.green, modifier = Modifier.size(34.dp))
                        Text(product.name, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        Text(product.category ?: "Без категории", color = AstraTheme.muted)
                        Text("${product.code} · ${product.unit ?: "г"}", color = AstraTheme.muted, fontSize = 12.sp)
                    }
                }
            }
            item {
                MobileCard {
                    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        RecipeMetric("Ккал", product.kcal.shown(), AstraTheme.blue, Modifier.weight(1f))
                        RecipeMetric("Белки", product.protein.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                        RecipeMetric("Жиры", product.fat.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                        RecipeMetric("Угл.", product.carbs.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                    }
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Параметры продукта", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Text("Цена за 100 г/ед.: ${product.pricePer100.shown(" RSD")}", color = AstraTheme.muted)
                        Text("Упаковка: ${product.packageSize.shown()} ${product.unit ?: "г"} · ${product.packagePrice.shown(" RSD")}", color = AstraTheme.muted)
                        product.note?.takeIf { it.isNotBlank() }?.let { Text(it, color = AstraTheme.muted, fontSize = 13.sp) }
                    }
                }
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (canEdit) Button(onClick = onEdit, modifier = Modifier.fillMaxWidth()) { Text("Редактировать") }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (canShareToTrainer) OutlinedButton(onClick = onShare, modifier = Modifier.weight(1f)) { Text("Тренеру") }
                        if (canShareToClient) OutlinedButton(onClick = onShareClient, modifier = Modifier.weight(1f)) { Text("Клиенту") }
                    }
                    if (canEdit) TextButton(onClick = { confirmDelete = true }, colors = androidx.compose.material3.ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)) { Text("Удалить") }
                }
            }
        }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text("Удалить продукт?") }, text = { Text("Это действие нельзя отменить.") }, confirmButton = { Button(onClick = { confirmDelete = false; onDelete() }, colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) { Text("Удалить") } }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Отмена") } })
}

@Composable
fun MobileRecipeDetailScreen(state: AstraState, recipe: Recipe, onBack: () -> Unit, onEdit: () -> Unit = {}, onDelete: () -> Unit = {}, onShare: () -> Unit = {}, onShareClient: () -> Unit = {}, canEdit: Boolean = true, canShareToTrainer: Boolean = true, canShareToClient: Boolean = false, onSubmit: (() -> Unit)? = null, onCancelSubmission: (() -> Unit)? = null) {
    var detail by remember { mutableStateOf<RecipeDetail?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    LaunchedEffect(recipe.id) {
        suspendResult { state.api.recipe(recipe.id) }
            .onSuccess { detail = it; error = null }
            .onFailure { error = it.message }
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        LazyColumn(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(16.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
            item {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                        .background(recipeCoverAccent(recipe.category).copy(alpha = .24f))
                ) {
                    Text(
                        "✦",
                        color = recipeCoverAccent(recipe.category),
                        fontSize = 88.sp,
                        fontWeight = FontWeight.Light,
                        modifier = Modifier.padding(start = 28.dp).align(Alignment.CenterStart)
                    )
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier
                            .padding(start = 16.dp, top = 16.dp)
                            .size(36.dp)
                            .background(Color.Black.copy(alpha = .5f), RoundedCornerShape(50.dp))
                    ) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад", tint = Color.White) }
                }
            }
            item {
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(recipe.name, color = MaterialTheme.colorScheme.onBackground, fontSize = 26.sp, fontWeight = FontWeight.Bold, maxLines = 3)
                    Text(recipe.category, color = AstraTheme.muted, fontSize = 14.sp)
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        RecipeInfoPill(recipe.category)
                        recipe.servings?.let { RecipeInfoPill("${it.shown(" порц.")}") }
                    }
                }
            }
            item {
                MobileCard(Modifier.padding(horizontal = 20.dp)) {
                    Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        RecipeMetric("Ккал", recipe.kcal.shown(), AstraTheme.blue, Modifier.weight(1f))
                        RecipeMetric("Белки", recipe.protein.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                        RecipeMetric("Жиры", recipe.fat.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                        RecipeMetric("Угл.", recipe.carbs.shown(), MaterialTheme.colorScheme.onSurface, Modifier.weight(1f))
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Ингредиенты", color = MaterialTheme.colorScheme.onBackground, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    if (canEdit) {
                        IconButton(onClick = onEdit, modifier = Modifier.size(32.dp).background(MaterialTheme.colorScheme.surface, RoundedCornerShape(50.dp))) { Icon(Icons.Default.Edit, "Редактировать", tint = AstraTheme.blue, modifier = Modifier.size(16.dp)) }
                        Spacer(Modifier.width(8.dp))
                        IconButton(onClick = { confirmDelete = true }, modifier = Modifier.size(32.dp).background(MaterialTheme.colorScheme.surface, RoundedCornerShape(50.dp))) { Icon(Icons.Default.Delete, "Удалить", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(16.dp)) }
                    }
                }
            }
            if (error != null) {
                item { Text(error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 20.dp)) }
            } else if (detail == null) {
                item { CircularProgressIndicator(Modifier.padding(horizontal = 20.dp)) }
            } else {
                items(detail!!.ingredients, key = { it.id }) { ingredient ->
                    Column(Modifier.padding(horizontal = 20.dp)) {
                        Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(ingredient.name, Modifier.weight(1f), color = MaterialTheme.colorScheme.onBackground, maxLines = 2)
                            Text("${ingredient.quantity.shown()} ${ingredient.unit ?: ""}", color = AstraTheme.muted, fontSize = 13.sp)
                        }
                        Box(Modifier.fillMaxWidth().height(1.dp).background(MaterialTheme.colorScheme.onBackground.copy(alpha = .08f)))
                    }
                }
            }
            item {
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (canShareToTrainer) OutlinedButton(onClick = onShare, modifier = Modifier.weight(1f)) { Text("Тренеру") }
                        if (canShareToClient) OutlinedButton(onClick = onShareClient, modifier = Modifier.weight(1f)) { Text("Клиенту") }
                    }
                    if (recipe.moderationStatus == "revision" && recipe.isSubmitter) {
                        onSubmit?.let { Button(onClick = it, modifier = Modifier.fillMaxWidth()) { Text("Отправить повторно") } }
                        onCancelSubmission?.let { OutlinedButton(onClick = it, modifier = Modifier.fillMaxWidth()) { Text("Отменить отправку") } }
                    } else if (!recipe.submissionRequested && recipe.collection == "local") {
                        onSubmit?.let { OutlinedButton(onClick = it, modifier = Modifier.fillMaxWidth()) { Text("Отправить на проверку") } }
                    } else if (recipe.submissionRequested) {
                        onCancelSubmission?.let { OutlinedButton(onClick = it, modifier = Modifier.fillMaxWidth()) { Text("Отменить отправку") } }
                    }
                }
            }
        }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text("Удалить рецепт?") }, text = { Text("Это действие нельзя отменить.") }, confirmButton = { Button(onClick = { confirmDelete = false; onDelete() }, colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) { Text("Удалить") } }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Отмена") } })
}

private fun recipeCoverAccent(category: String): Color = when {
    category.contains("breakfast", ignoreCase = true) || category.contains("завтрак", ignoreCase = true) -> Color(0xFF6F82FF)
    category.contains("dessert", ignoreCase = true) || category.contains("десерт", ignoreCase = true) -> Color(0xFFC88731)
    category.contains("salad", ignoreCase = true) || category.contains("салат", ignoreCase = true) || category.contains("drink", ignoreCase = true) || category.contains("напит", ignoreCase = true) -> Color(0xFF4B9DB0)
    category.contains("wrap", ignoreCase = true) || category.contains("врап", ignoreCase = true) || category.contains("garnish", ignoreCase = true) || category.contains("гарнир", ignoreCase = true) -> Color(0xFF329A63)
    category.contains("sauce", ignoreCase = true) || category.contains("соус", ignoreCase = true) || category.contains("snack", ignoreCase = true) || category.contains("перекус", ignoreCase = true) -> Color(0xFF6F82FF)
    else -> Color(0xFF329A63)
}

@Composable
private fun RecipeInfoPill(title: String) {
    Text(title, color = AstraTheme.blue, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier
        .background(AstraTheme.blue.copy(alpha = .08f), RoundedCornerShape(50.dp))
        .border(1.dp, AstraTheme.blue, RoundedCornerShape(50.dp))
        .padding(horizontal = 11.dp, vertical = 6.dp))
}

@Composable
private fun RecipeMetric(label: String, value: String, tint: Color, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(value, color = tint, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(label, color = AstraTheme.muted, fontSize = 11.sp)
    }
}

@Composable
private fun CatalogCategoryTile(name: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        Modifier
            .clip(shape)
            .clickable(onClick = onClick)
            .background(if (selected) AstraTheme.blue.copy(alpha = .12f) else MaterialTheme.colorScheme.surface)
            .border(1.dp, if (selected) AstraTheme.blue else AstraTheme.line, shape)
            .padding(horizontal = 16.dp, vertical = 9.dp)
    ) {
        Text(name, color = if (selected) AstraTheme.blue else AstraTheme.ink, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
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
fun TrainerClientsScreen(state: AstraState) {
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    var selected by remember { mutableStateOf<ClientSummary?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { suspendResult { state.api.clients() }.onSuccess { clients = it }.onFailure { error = it.message } }
    if (selected != null) {
        TrainerClientDetailScreen(state, selected!!) { selected = null }
        return
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) {
            Text("Клиенты", fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text("Выберите клиента, чтобы открыть его данные и историю", color = AstraTheme.muted)
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        if (clients.isEmpty() && error == null) EmptyMessage("Клиентов пока нет", "Добавьте клиента в веб-версии или назначьте ему этого тренера.")
        else LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(clients, key = { it.id }) { client ->
                MobileCard(Modifier.clickable { selected = client }) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Person, null, tint = AstraTheme.blue)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(client.name, fontWeight = FontWeight.Bold)
                            Text(client.email, color = AstraTheme.muted, fontSize = 12.sp)
                            client.nextWorkout?.let { Text("Ближайшая тренировка: ${it.scheduledAt}", color = AstraTheme.green, fontSize = 11.sp) }
                        }
                        if (client.unreadMessages > 0) Text(client.unreadMessages.toString(), color = AstraTheme.amber, fontWeight = FontWeight.Bold)
                        Text("›", fontSize = 22.sp, color = AstraTheme.muted)
                    }
                }
            }
        }
    }
}

@Composable
private fun TrainerClientDetailScreen(state: AstraState, client: ClientSummary, onBack: () -> Unit) {
    var detail by remember { mutableStateOf<ClientDetail?>(null) }
    var selectedWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    var selectedPlan by remember { mutableStateOf<WorkoutPlan?>(null) }
    var showChat by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(client.id) { suspendResult { state.api.client(client.id) }.onSuccess { detail = it }.onFailure { error = it.message } }
    if (selectedPlan != null) {
        val plan = selectedPlan!!
        TrainerPlanDetailScreen(
            plan,
            onBack = { selectedPlan = null },
            onEdit = if (plan.status == "planned") ({ selectedPlan = null; editingPlan = plan; planFromComplex = null; showPlanEditor = true }) else null,
            onRepeat = { selectedPlan = null; editingPlan = plan.copy(id = 0, scheduledAt = todayTime()); planFromComplex = null; showPlanEditor = true },
            onCancel = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null,
            onDelete = if (plan.status == "canceled") ({ scope.launch { suspendResult { state.api.deletePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null,
            onComplete = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null
        )
        return
    }
    if (selectedWorkout != null) {
        val workout = selectedWorkout!!
        TrainerWorkoutDetailScreen(selectedWorkout!!, onBack = { selectedWorkout = null })
        return
    }
    if (showChat) {
        TrainerClientChatPage(state, client) { showChat = false }
        return
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
            Text(client.name, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            IconButton(onClick = { showChat = true }) { Icon(Icons.Default.Chat, contentDescription = "Чат") }
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        val loaded = detail
        if (loaded == null && error == null) CircularProgressIndicator(Modifier.padding(20.dp))
        else if (loaded != null) LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(loaded.name, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                        Text(loaded.email, color = AstraTheme.muted)
                        loaded.nextWorkout?.let { Text("Следующая тренировка: ${it.scheduledAt}", color = AstraTheme.green, fontSize = 12.sp) }
                    }
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Последние замеры", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        val latest = loaded.progress.firstOrNull()
                        if (latest == null) Text("Замеры ещё не добавлены.", color = AstraTheme.muted)
                        else {
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(Modifier.weight(1f)) { MobileMetric("Вес", latest.weight.shown(" кг"), AstraTheme.blue) {} }
                                Box(Modifier.weight(1f)) { MobileMetric("Рост", latest.height.shown(" см"), AstraTheme.green) {} }
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Box(Modifier.weight(1f)) { MobileMetric("Жир", latest.bodyFat.shown("%"), AstraTheme.amber) {} }
                                Box(Modifier.weight(1f)) { MobileMetric("Дата", latest.date, AstraTheme.blue) {} }
                            }
                        }
                    }
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Питание за сегодня", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Text(loaded.today.date, color = AstraTheme.muted, fontSize = 12.sp)
                        if (loaded.today.entries.isEmpty()) Text("Сегодня блюд и продуктов пока нет.", color = AstraTheme.muted)
                        loaded.today.entries.forEach { entry ->
                            Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Restaurant, null, tint = AstraTheme.green); Spacer(Modifier.width(8.dp)); Column(Modifier.weight(1f)) { Text(entry.name ?: "Блюдо", fontWeight = FontWeight.SemiBold); Text(entry.meal ?: "Приём пищи", color = AstraTheme.muted, fontSize = 12.sp) }; Text(entry.kcal.shown(" ккал"), color = AstraTheme.blue, fontSize = 12.sp) }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Box(Modifier.weight(1f)) { MobileMetric("Съедено", loaded.today.totals.kcal.shown(" ккал"), AstraTheme.blue) {} }
                            Box(Modifier.weight(1f)) { MobileMetric("Осталось", loaded.today.remaining.kcal.shown(" ккал"), AstraTheme.green) {} }
                        }
                        Text("Б / Ж / У: ${loaded.today.totals.protein.shown()} / ${loaded.today.totals.fat.shown()} / ${loaded.today.totals.carbs.shown()} г", color = AstraTheme.muted, fontSize = 12.sp)
                    }
                }
            }
            item { Text("Запланированные тренировки", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            items(loaded.workoutPlans.filter { it.status == "planned" }, key = { "plan-${it.id}" }) { plan ->
                MobileCard(Modifier.clickable { selectedPlan = plan }) { Column(Modifier.padding(14.dp)) { Text(plan.displayName, fontWeight = FontWeight.Bold); Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp); Text(plan.items.joinToString(" · ") { it.name.displayOr("Упражнение") }, color = AstraTheme.muted, fontSize = 12.sp) } }
            }
            if (loaded.workoutPlans.none { it.status == "planned" }) item { Text("Планов пока нет.", color = AstraTheme.muted, fontSize = 12.sp) }
            item { Text("История тренировок", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            items(loaded.workouts, key = { "workout-${it.id}" }) { workout ->
                MobileCard(Modifier.clickable { selectedWorkout = workout }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(workout.name, fontWeight = FontWeight.Bold); Text("${workout.date} · ${workout.sets.shown(" подходов")} × ${workout.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } }
            }
            if (loaded.workouts.isEmpty()) item { Text("История пока пуста.", color = AstraTheme.muted, fontSize = 12.sp) }
        }
    }
}

@Composable
private fun TrainerClientChatPage(state: AstraState, client: ClientSummary, onBack: () -> Unit) {
    var messages by remember { mutableStateOf<List<TrainerChatMessage>>(emptyList()) }
    var draft by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(client.id) { suspendResult { state.api.clientChat(client.id) }.onSuccess { messages = it }.onFailure { error = it.message } }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }; Text("Чат · ${client.name}", fontSize = 20.sp, fontWeight = FontWeight.Bold) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(16.dp)) }
        LazyColumn(Modifier.weight(1f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(messages, key = { it.id }) { message -> Text("${message.senderName}: ${message.message}", Modifier.background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp)).padding(10.dp)) } }
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Bottom) { OutlinedTextField(draft, { draft = it }, label = { Text("Сообщение клиенту") }, modifier = Modifier.weight(1f)); IconButton({ val text = draft.trim(); if (text.isNotEmpty()) { draft = ""; scope.launch { suspendResult { state.api.sendClientChat(client.id, text) }.onSuccess { messages = messages + it }.onFailure { error = it.message } } } }) { Icon(Icons.Default.Send, contentDescription = "Отправить") } }
    }
}

@Composable
fun TrainerWorkspaceFullScreen(state: AstraState) {
    var section by rememberSaveable { mutableStateOf(0) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }; var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }; var history by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }; var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }; var complexes by remember { mutableStateOf<List<WorkoutComplex>>(emptyList()) }; var equipment by remember { mutableStateOf<List<WorkoutEquipment>>(emptyList()) }; var error by remember { mutableStateOf<String?>(null) }
    var selectedClient by remember { mutableStateOf<ClientSummary?>(null) }; var selectedExercise by remember { mutableStateOf<Exercise?>(null) }; var selectedComplex by remember { mutableStateOf<WorkoutComplex?>(null) }; var selectedEquipment by remember { mutableStateOf<WorkoutEquipment?>(null) }; var selectedPlan by remember { mutableStateOf<WorkoutPlan?>(null) }; var selectedWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    var editingComplex by remember { mutableStateOf<WorkoutComplex?>(null) }; var showComplexEditor by remember { mutableStateOf(false) }; var planFromComplex by remember { mutableStateOf<WorkoutComplex?>(null) }; var editingPlan by remember { mutableStateOf<WorkoutPlan?>(null) }; var showPlanEditor by remember { mutableStateOf(false) }
    var editingExercise by remember { mutableStateOf<Exercise?>(null) }; var showExerciseEditor by remember { mutableStateOf(false) }; var editingEquipment by remember { mutableStateOf<WorkoutEquipment?>(null) }; var showEquipmentEditor by remember { mutableStateOf(false) }; var shareType by remember { mutableStateOf<String?>(null) }; var shareId by remember { mutableStateOf<Int?>(null) }; var shareClients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    val scope = rememberCoroutineScope()
    val canManage = true
    val planned = plans.filter { it.status == "planned" }; val historyPlans = plans.filter { it.isHistory }.sortedByDescending { it.completedAt ?: it.scheduledAt }; val machines = equipment.filter { it.kind == "machine" }; val freeEquipment = equipment.filter { it.kind != "machine" }
    suspend fun load() { suspendResult { state.api.clients() }.onSuccess { clients = it }; suspendResult { state.api.plans() }.onSuccess { plans = it }; suspendResult { state.api.workouts() }.onSuccess { history = it }; suspendResult { state.api.exercises() }.onSuccess { exercises = it }; suspendResult { state.api.workoutComplexes() }.onSuccess { complexes = it }; suspendResult { state.api.workoutEquipment() }.onSuccess { equipment = it }.onFailure { error = it.message } }
    LaunchedEffect(Unit) { load() }
    LaunchedEffect(shareType) { if (shareType != null && shareClients.isEmpty()) shareClients = suspendResult { state.api.clients() }.getOrDefault(emptyList()) }
    if (selectedPlan != null) {
        val plan = selectedPlan!!
        TrainerPlanDetailScreen(
            plan,
            onBack = { selectedPlan = null },
            onEdit = if (plan.status == "planned") ({ selectedPlan = null; editingPlan = plan; planFromComplex = null; showPlanEditor = true }) else null,
            onRepeat = { selectedPlan = null; editingPlan = plan.copy(id = 0, scheduledAt = todayTime()); planFromComplex = null; showPlanEditor = true },
            onCancel = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null,
            onDelete = if (plan.status == "canceled") ({ scope.launch { suspendResult { state.api.deletePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null,
            onComplete = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null
        )
        return
    }
    if (selectedWorkout != null) {
        val workout = selectedWorkout!!
        TrainerWorkoutDetailScreen(selectedWorkout!!, onBack = { selectedWorkout = null })
        return
    }
    if (selectedExercise != null) {
        val exercise = selectedExercise!!
        MobileExerciseDetailScreen(
            exercise,
            allExercises = exercises,
            onBack = { selectedExercise = null },
            onEdit = { item -> selectedExercise = null; editingExercise = item; showExerciseEditor = true },
            onDelete = { item -> scope.launch { suspendResult { state.api.deleteExercise(item.id) }.onSuccess { load(); selectedExercise = null }.onFailure { error = it.message } } },
            onShareClient = { item -> shareType = "exercise"; shareId = item.id }
        )
        return
    }
    if (selectedComplex != null) {
        val complex = selectedComplex!!
        TrainerComplexDetailScreen(
            complex = complex,
            onBack = { selectedComplex = null },
            onEdit = { selectedComplex = null; editingComplex = complex; showComplexEditor = true },
            onSchedule = { selectedComplex = null; planFromComplex = complex; editingPlan = null; showPlanEditor = true },
            onDelete = {
                scope.launch {
                    suspendResult { state.api.deleteComplex(complex.id) }
                        .onSuccess { load(); selectedComplex = null }
                        .onFailure { error = it.message }
                }
            },
            onShareClient = { shareType = "workout_complex"; shareId = complex.id }
        )
        return
    }
    if (selectedEquipment != null) {
        val item = selectedEquipment!!
        MobileEquipmentDetailScreen(
            item,
            onBack = { selectedEquipment = null },
            onEdit = { selectedEquipment = null; editingEquipment = item; showEquipmentEditor = true },
            onDelete = { scope.launch { suspendResult { state.api.deleteEquipment(item.id) }.onSuccess { load(); selectedEquipment = null }.onFailure { error = it.message } } },
            onShareClient = { shareType = "workout_equipment"; shareId = item.id }
        )
        return
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        if (section == 0) Column(Modifier.padding(16.dp)) { Text("Тренерский workspace", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text(if (state.user?.isAdmin == true) "Администратор: полный доступ к инструментам тренера" else "Клиенты, тренировки и справочники", color = AstraTheme.muted) }
        else Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) { TextButton({ section = 0 }) { Text("‹ Разделы") }; Spacer(Modifier.weight(1f)); Text(listOf("", "Клиенты", "Планы тренировок", "История тренировок", "Упражнения", "Комплексы", "Тренажёры", "Инвентарь")[section], fontWeight = FontWeight.Bold) }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        if (section == 0) {
            LazyColumn(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("Клиенты", clients.size, AstraTheme.blue) { section = 1 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Планы", planned.size, AstraTheme.green) { section = 2 } } } }
                item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("История", historyPlans.size, AstraTheme.blue) { section = 3 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Упражнения", exercises.size, AstraTheme.blue) { section = 4 } } } }
                item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { Box(Modifier.weight(1f)) { MobileTrainerTile("Комплексы", complexes.size, AstraTheme.blue) { section = 5 } }; Box(Modifier.weight(1f)) { MobileTrainerTile("Тренажёры", machines.size, AstraTheme.green) { section = 6 } } } }
                item { MobileTrainerTile("Инвентарь", freeEquipment.size, Color(0xFFB56A16)) { section = 7 } }
                item { Text("Все плитки открывают соответствующие разделы, а карточки элементов — подробности.", color = AstraTheme.muted, fontSize = 12.sp) }
            }
        } else {
            MobileTrainerSectionGrid(
                section = section,
                clients = clients,
                planned = planned,
                history = history,
                historyPlans = historyPlans,
                exercises = exercises,
                complexes = complexes,
                machines = machines,
                freeEquipment = freeEquipment,
                onClient = { selectedClient = it },
                onPlan = { selectedPlan = it },
                onWorkout = { selectedWorkout = it },
                onExercise = { selectedExercise = it },
                onComplex = { selectedComplex = it },
                onEquipment = { selectedEquipment = it },
                onEditExercise = { editingExercise = it; showExerciseEditor = true },
                onDeleteExercise = { item -> scope.launch { suspendResult { state.api.deleteExercise(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onShareClient = { type, id -> shareType = type; shareId = id },
                onEditComplex = { editingComplex = it; showComplexEditor = true },
                onScheduleComplex = { planFromComplex = it; editingPlan = null; showPlanEditor = true },
                onDeleteComplex = { item -> scope.launch { suspendResult { state.api.deleteComplex(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onEditEquipment = { editingEquipment = it; showEquipmentEditor = true },
                onDeleteEquipment = { item -> scope.launch { suspendResult { state.api.deleteEquipment(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onCompletePlan = { plan -> scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onEditPlan = { plan -> editingPlan = plan; planFromComplex = null; showPlanEditor = true },
                onRepeatPlan = { plan -> editingPlan = plan.copy(id = 0, scheduledAt = todayTime()); planFromComplex = null; showPlanEditor = true },
                onCancelPlan = { plan -> scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onDeletePlan = { plan -> scope.launch { suspendResult { state.api.deletePlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } }
            )
            if (section < 0) when (section) {
            1 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(clients, key = { it.id }) { client -> MobileCard(Modifier.clickable { selectedClient = client }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.Person, null, tint = AstraTheme.blue); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(client.name, fontWeight = FontWeight.Bold); Text(client.email, color = AstraTheme.muted, fontSize = 12.sp); client.nextWorkout?.let { Text("Ближайшая тренировка: ${it.scheduledAt}", color = AstraTheme.green, fontSize = 11.sp) } }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } } } }
            2 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(planned, key = { it.id }) { plan -> MobileCard(Modifier.clickable { selectedPlan = plan }) { Column(Modifier.padding(14.dp)) { Text(plan.displayName, fontWeight = FontWeight.Bold); Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp); Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            3 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(history, key = { it.id }) { workout -> MobileCard(Modifier.clickable { selectedWorkout = workout }) { Column(Modifier.padding(14.dp)) { Text(workout.name, fontWeight = FontWeight.Bold); Text("${workout.date} · ${workout.sets.shown(" подходов")} × ${workout.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            4 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(exercises, key = { it.id }) { exercise -> MobileCard(Modifier.clickable { selectedExercise = exercise }) { Column(Modifier.padding(14.dp)) { Text(exercise.name, fontWeight = FontWeight.Bold); Text("${exercise.muscleGroup ?: "Другое"} · ${exercise.defaultSets.shown(" подхода")} × ${exercise.defaultReps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            5 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(complexes, key = { it.id }) { complex -> MobileCard(Modifier.clickable { selectedComplex = complex }) { Column(Modifier.padding(14.dp)) { Text(complex.name, fontWeight = FontWeight.Bold); Text("${complex.items.size} упражнений", color = AstraTheme.muted, fontSize = 12.sp); complex.comment.displayOrNull()?.let { Text(it, fontSize = 12.sp) } } } } }
            6 -> TrainerEquipmentList(machines, selectedEquipment = { selectedEquipment = it })
            else -> TrainerEquipmentList(freeEquipment, selectedEquipment = { selectedEquipment = it })
        }
        }
    }
    selectedClient?.let { TrainerClientChatScreen(state, it) { selectedClient = null } }
    if (showPlanEditor) WorkoutPlanEditorDialog(editingPlan, planFromComplex, exercises, { body -> scope.launch { suspendResult { if (editingPlan == null || editingPlan!!.id == 0) state.api.createPlan(body) else state.api.updatePlan(editingPlan!!.id, body) }.onSuccess { load(); showPlanEditor = false; editingPlan = null; planFromComplex = null }.onFailure { error = it.message } } }, { showPlanEditor = false; editingPlan = null; planFromComplex = null })
    if (showComplexEditor) WorkoutComplexEditorDialog(editingComplex, exercises, { body -> scope.launch { suspendResult { if (editingComplex == null) state.api.createComplex(body) else state.api.updateComplex(editingComplex!!.id, body) }.onSuccess { load(); showComplexEditor = false; editingComplex = null }.onFailure { error = it.message } } }, { showComplexEditor = false; editingComplex = null })
    if (showExerciseEditor) ExerciseEditorDialog(editingExercise, { body -> scope.launch { suspendResult { if (editingExercise == null) state.api.createExercise(body) else state.api.updateExercise(editingExercise!!.id, body) }.onSuccess { load(); showExerciseEditor = false; editingExercise = null }.onFailure { error = it.message } } }, if (editingExercise != null) ({ scope.launch { suspendResult { state.api.deleteExercise(editingExercise!!.id) }.onSuccess { load(); showExerciseEditor = false; editingExercise = null }.onFailure { error = it.message } } }) else null) { showExerciseEditor = false; editingExercise = null }
    if (showEquipmentEditor) EquipmentEditorDialog(editingEquipment, { body -> scope.launch { suspendResult { if (editingEquipment == null) state.api.createEquipment(body) else state.api.updateEquipment(editingEquipment!!.id, body) }.onSuccess { load(); showEquipmentEditor = false; editingEquipment = null }.onFailure { error = it.message } } }, if (editingEquipment != null) ({ scope.launch { suspendResult { state.api.deleteEquipment(editingEquipment!!.id) }.onSuccess { load(); showEquipmentEditor = false; editingEquipment = null }.onFailure { error = it.message } } }) else null) { showEquipmentEditor = false; editingEquipment = null }
    if (shareType != null && shareId != null) ShareToClientDialog(shareClients, { clientId -> val type = shareType!!; val id = shareId!!; scope.launch { suspendResult { state.api.shareToClient(clientId, type, id) }.onFailure { error = it.message }; shareType = null; shareId = null } }, { shareType = null; shareId = null })
    selectedExercise?.let { exercise -> AlertDialog(onDismissRequest = { selectedExercise = null }, title = { Text(exercise.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(exercise.muscleGroup ?: "Другое", color = AstraTheme.muted); Text("Единица: ${exercise.unit ?: "—"}"); Text("Подходы: ${exercise.defaultSets.shown()}"); Text("Повторения: ${exercise.defaultReps.shown()}") } }, confirmButton = { TextButton({ selectedExercise = null }) { Text("Закрыть") } }) }
    selectedEquipment?.let { item -> AlertDialog(onDismissRequest = { selectedEquipment = null }, title = { Text(item.name) }, text = { Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted); item.description.displayOrNull()?.let { Text(it) } } }, confirmButton = { TextButton({ selectedEquipment = null }) { Text("Закрыть") } }) }
}

@Composable
private fun MobileWorkoutEntityActions(
    onEdit: (() -> Unit)? = null,
    onDelete: (() -> Unit)? = null,
    onShareTrainer: (() -> Unit)? = null,
    onShareClient: (() -> Unit)? = null
) {
    if (onEdit == null && onDelete == null && onShareTrainer == null && onShareClient == null) return
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
        onEdit?.let { action -> IconButton(onClick = action, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Edit, "Редактировать", modifier = Modifier.size(17.dp)) } }
        onDelete?.let { action -> IconButton(onClick = action, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Delete, "Удалить", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(17.dp)) } }
        onShareTrainer?.let { action -> IconButton(onClick = action, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Send, "Отправить тренеру", tint = AstraTheme.blue, modifier = Modifier.size(17.dp)) } }
        onShareClient?.let { action -> IconButton(onClick = action, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Send, "Отправить клиенту", tint = AstraTheme.green, modifier = Modifier.size(17.dp)) } }
    }
}

@Composable
private fun MobileWorkoutCategoryGrid(
    category: Int,
    plans: List<WorkoutPlan>,
    exercises: List<Exercise>,
    complexes: List<WorkoutComplex>,
    equipment: List<WorkoutEquipment>,
    logs: List<WorkoutEntry>,
    historyPlans: List<WorkoutPlan>,
    onPlan: (WorkoutPlan) -> Unit,
    onExercise: (Exercise) -> Unit,
    onComplex: (WorkoutComplex) -> Unit,
    onEquipment: (WorkoutEquipment) -> Unit,
    onWorkout: (WorkoutEntry) -> Unit,
    canManage: Boolean,
    hasTrainer: Boolean,
    onAddExercise: () -> Unit,
    onEditExercise: (Exercise) -> Unit,
    onDeleteExercise: (Exercise) -> Unit,
    onShareClient: (String, Int) -> Unit,
    onShareTrainer: (String, Int) -> Unit,
    onEditComplex: (WorkoutComplex) -> Unit,
    onScheduleComplex: (WorkoutComplex) -> Unit,
    onDeleteComplex: (WorkoutComplex) -> Unit,
    onEditEquipment: (WorkoutEquipment) -> Unit,
    onDeleteEquipment: (WorkoutEquipment) -> Unit,
    onCompletePlan: (WorkoutPlan) -> Unit = {},
    onEditPlan: (WorkoutPlan) -> Unit = {},
    onRepeatPlan: (WorkoutPlan) -> Unit = {},
    onCancelPlan: (WorkoutPlan) -> Unit = {},
    onDeletePlan: (WorkoutPlan) -> Unit = {}
) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (category == 3) {
            MobileItemGrid(historyPlans) { plan ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onPlan(plan) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(plan.displayName, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                        Text("${plan.items.size} \u0443\u043F\u0440\u0430\u0436\u043D\u0435\u043D\u0438\u0439", color = AstraTheme.blue, fontSize = 12.sp)
                        Text(plan.historyStatus, color = AstraTheme.muted, fontSize = 11.sp)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            TextButton(onClick = { onRepeatPlan(plan) }) { Text("Повторить", fontSize = 11.sp) }
                            if (plan.status == "canceled") TextButton(onClick = { onDeletePlan(plan) }) { Text("Удалить", fontSize = 11.sp, color = MaterialTheme.colorScheme.error) }
                        }
                    }
                }
            }
        } else {
            when (category) {
            0 -> MobileItemGrid(plans.filter { it.status == "planned" }) { plan ->
                MobileCard(Modifier.heightIn(min = 150.dp).clickable { onPlan(plan) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(plan.displayName, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                        Text("${plan.items.size} упражнений", color = AstraTheme.blue, fontSize = 12.sp)
                        Text(plan.status, color = AstraTheme.muted, fontSize = 11.sp)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                            if (plan.status == "planned") {
                                IconButton(onClick = { onCompletePlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.CheckCircle, "Выполнено", tint = AstraTheme.green, modifier = Modifier.size(18.dp)) }
                                if (canManage) IconButton(onClick = { onEditPlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Edit, "Редактировать", modifier = Modifier.size(17.dp)) }
                                TextButton(onClick = { onCancelPlan(plan) }) { Text("Отменить", fontSize = 11.sp) }
                            } else {
                                TextButton(onClick = { onRepeatPlan(plan) }) { Text("Повторить", fontSize = 11.sp) }
                                if (plan.status == "canceled") IconButton(onClick = { onDeletePlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Delete, "Удалить", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(17.dp)) }
                            }
                        }
                    }
                }
            }
            1 -> {
                Text("СПРАВОЧНИК", color = AstraTheme.blue, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text("Упражнения", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                OutlinedTextField(exerciseSearch, { exerciseSearch = it }, label = { Text("Найти упражнение") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                val groups = listOf("Все группы") + exercises.map { it.muscleGroup.displayOr("Другое") }.distinct().sorted()
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    groups.forEach { group ->
                        if (group == selectedMuscleGroup) Button(onClick = { selectedMuscleGroup = group }, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) { Text(group, fontSize = 11.sp) }
                        else OutlinedButton(onClick = { selectedMuscleGroup = group }, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) { Text(group, fontSize = 11.sp) }
                    }
                }
                val visibleExercises = exercises.filter { exercise ->
                    val searchable = listOfNotNull(exercise.name, exercise.description, exercise.note, exercise.code).joinToString(" ")
                    (selectedMuscleGroup == "Все группы" || exercise.muscleGroup.displayOr("Другое") == selectedMuscleGroup) && (exerciseSearch.isBlank() || searchable.contains(exerciseSearch, ignoreCase = true))
                }
                MobileItemGrid(visibleExercises) { exercise ->
                    MobileCard(Modifier.heightIn(min = 190.dp).clickable { onExercise(exercise) }) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green)
                            Text(exercise.muscleGroup.displayOr("Другое"), color = AstraTheme.green, fontSize = 10.sp, maxLines = 1)
                            exercise.code.displayOrNull()?.let { Text(it, color = AstraTheme.muted, fontSize = 10.sp) }
                            Text(exercise.name, fontWeight = FontWeight.Bold, maxLines = 3)
                            Text(exercise.description.displayOr(exercise.note.displayOr("Описание упражнения пока не добавлено")), color = AstraTheme.muted, fontSize = 11.sp, maxLines = 3)
                            Text("${exercise.defaultSets.shown()} × ${exercise.defaultReps.shown()}", color = AstraTheme.blue, fontSize = 11.sp)
                            if (exercise.photos.isNotEmpty() || exercise.video.displayOrNull() != null) Text(listOfNotNull(exercise.photos.takeIf { it.isNotEmpty() }?.let { "Фото: ${it.size}" }, exercise.video.displayOrNull()?.let { "Видео" }).joinToString(" · "), color = AstraTheme.muted, fontSize = 10.sp)
                            MobileWorkoutEntityActions(
                                onEdit = if (canManage) ({ onEditExercise(exercise) }) else null,
                                onDelete = if (canManage) ({ onDeleteExercise(exercise) }) else null,
                                onShareTrainer = if (hasTrainer && !canManage) ({ onShareTrainer("exercise", exercise.id) }) else null,
                                onShareClient = if (canManage) ({ onShareClient("exercise", exercise.id) }) else null
                            )
                        }
                    }
                }
                if (canManage) MobileItemGrid(listOf(Unit)) {
                    MobileCard(Modifier.heightIn(min = 125.dp).clickable(onClick = onAddExercise)) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Text("+", color = AstraTheme.green, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                            Text("Добавить новое упражнение", fontWeight = FontWeight.Bold)
                            Text("Создать карточку в справочнике", color = AstraTheme.muted, fontSize = 11.sp)
                        }
                    }
                }
            }
            2 -> {
                Text("Оборудование", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                MobileItemGrid(equipment) { item ->
                    MobileCard(Modifier.heightIn(min = 145.dp).clickable { onEquipment(item) }) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.amber)
                            Text(item.name, fontWeight = FontWeight.Bold, maxLines = 3)
                            Text(item.description.displayOr(if (item.kind == "machine") "Тренажёр" else "Инвентарь"), color = AstraTheme.muted, fontSize = 12.sp, maxLines = 3)
                            MobileWorkoutEntityActions(
                                onEdit = if (canManage) ({ onEditEquipment(item) }) else null,
                                onDelete = if (canManage) ({ onDeleteEquipment(item) }) else null,
                                onShareTrainer = if (hasTrainer && !canManage) ({ onShareTrainer("workout_equipment", item.id) }) else null,
                                onShareClient = if (canManage) ({ onShareClient("workout_equipment", item.id) }) else null
                            )
                        }
                    }
                }
                Text("Комплексы", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                MobileItemGrid(complexes) { complex ->
                    MobileCard(Modifier.heightIn(min = 145.dp).clickable { onComplex(complex) }) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Icon(Icons.Default.Book, null, tint = AstraTheme.blue)
                            Text(complex.name, fontWeight = FontWeight.Bold, maxLines = 3)
                            Text("${complex.items.size} упражнений", color = AstraTheme.blue, fontSize = 12.sp)
                            complex.comment.displayOrNull()?.let { Text(it, color = AstraTheme.muted, fontSize = 11.sp, maxLines = 2) }
                            MobileWorkoutEntityActions(
                                onEdit = if (canManage) ({ onEditComplex(complex) }) else null,
                                onDelete = if (canManage) ({ onDeleteComplex(complex) }) else null,
                                onShareTrainer = if (hasTrainer && !canManage) ({ onShareTrainer("workout_complex", complex.id) }) else null,
                                onShareClient = if (canManage) ({ onShareClient("workout_complex", complex.id) }) else null
                            )
                            TextButton(onClick = { onScheduleComplex(complex) }) { Text("Запланировать", fontSize = 11.sp) }
                        }
                    }
                }
            }
            else -> MobileItemGrid(logs) { workout ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onWorkout(workout) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(workout.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(workout.date, color = AstraTheme.muted, fontSize = 12.sp)
                        Text("${workout.sets.shown()} × ${workout.reps.shown()}", color = AstraTheme.blue, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun MobileTrainerSectionGrid(
    section: Int,
    clients: List<ClientSummary>,
    planned: List<WorkoutPlan>,
    history: List<WorkoutEntry>,
    historyPlans: List<WorkoutPlan>,
    exercises: List<Exercise>,
    complexes: List<WorkoutComplex>,
    machines: List<WorkoutEquipment>,
    freeEquipment: List<WorkoutEquipment>,
    onClient: (ClientSummary) -> Unit,
    onPlan: (WorkoutPlan) -> Unit,
    onWorkout: (WorkoutEntry) -> Unit,
    onExercise: (Exercise) -> Unit,
    onComplex: (WorkoutComplex) -> Unit,
    onEquipment: (WorkoutEquipment) -> Unit,
    onEditExercise: (Exercise) -> Unit,
    onDeleteExercise: (Exercise) -> Unit,
    onShareClient: (String, Int) -> Unit,
    onEditComplex: (WorkoutComplex) -> Unit,
    onScheduleComplex: (WorkoutComplex) -> Unit,
    onDeleteComplex: (WorkoutComplex) -> Unit,
    onEditEquipment: (WorkoutEquipment) -> Unit,
    onDeleteEquipment: (WorkoutEquipment) -> Unit,
    onCompletePlan: (WorkoutPlan) -> Unit,
    onEditPlan: (WorkoutPlan) -> Unit,
    onRepeatPlan: (WorkoutPlan) -> Unit,
    onCancelPlan: (WorkoutPlan) -> Unit,
    onDeletePlan: (WorkoutPlan) -> Unit
) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        when (section) {
            1 -> MobileItemGrid(clients) { client ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onClient(client) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(Icons.Default.Person, null, tint = AstraTheme.blue)
                        Text(client.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(client.email, color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
                        client.nextWorkout?.let { Text(it.scheduledAt, color = AstraTheme.green, fontSize = 11.sp, maxLines = 2) }
                        if (client.unreadMessages > 0) Text("${client.unreadMessages} новых сообщений", color = AstraTheme.amber, fontSize = 11.sp)
                    }
                }
            }
            2 -> MobileItemGrid(planned) { plan ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onPlan(plan) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(plan.displayName, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                        Text("${plan.items.size} упражнений", color = AstraTheme.blue, fontSize = 12.sp)
                        Text(plan.status, color = AstraTheme.muted, fontSize = 11.sp)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = { onCompletePlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.CheckCircle, "Выполнено", tint = AstraTheme.green, modifier = Modifier.size(18.dp)) }
                            IconButton(onClick = { onEditPlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Edit, "Редактировать", modifier = Modifier.size(17.dp)) }
                            TextButton(onClick = { onCancelPlan(plan) }) { Text("Отменить", fontSize = 11.sp) }
                        }
                    }
                }
            }
            3 -> MobileItemGrid(historyPlans) { plan ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onPlan(plan) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(plan.displayName, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                        Text("${plan.items.size} \u0443\u043F\u0440\u0430\u0436\u043D\u0435\u043D\u0438\u0439", color = AstraTheme.blue, fontSize = 12.sp)
                        Text(plan.historyStatus, color = AstraTheme.muted, fontSize = 11.sp)
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                            TextButton(onClick = { onRepeatPlan(plan) }) { Text("Повторить", fontSize = 11.sp) }
                            if (plan.status == "canceled") IconButton(onClick = { onDeletePlan(plan) }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Delete, "Удалить", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(17.dp)) }
                        }
                    }
                }
            }
            4 -> MobileItemGrid(exercises) { exercise ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onExercise(exercise) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green)
                        Text(exercise.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(exercise.muscleGroup ?: "Другое", color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2)
                        Text(exercise.description.displayOr(exercise.note.displayOr("Описание упражнения пока не добавлено")), color = AstraTheme.muted, fontSize = 11.sp, maxLines = 3)
                        MobileWorkoutEntityActions(onEdit = { onEditExercise(exercise) }, onDelete = { onDeleteExercise(exercise) }, onShareClient = { onShareClient("exercise", exercise.id) })
                    }
                }
            }
            5 -> MobileItemGrid(complexes) { complex ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onComplex(complex) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(Icons.Default.Book, null, tint = AstraTheme.blue)
                        Text(complex.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text("${complex.items.size} упражнений", color = AstraTheme.blue, fontSize = 12.sp)
                        MobileWorkoutEntityActions(onEdit = { onEditComplex(complex) }, onDelete = { onDeleteComplex(complex) }, onShareClient = { onShareClient("workout_complex", complex.id) })
                        TextButton(onClick = { onScheduleComplex(complex) }) { Text("Запланировать", fontSize = 11.sp) }
                    }
                }
            }
            6 -> MobileItemGrid(machines) { item ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onEquipment(item) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green)
                        Text(item.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(item.description.displayOr("Тренажёр"), color = AstraTheme.muted, fontSize = 12.sp, maxLines = 3)
                        MobileWorkoutEntityActions(onEdit = { onEditEquipment(item) }, onDelete = { onDeleteEquipment(item) }, onShareClient = { onShareClient("workout_equipment", item.id) })
                    }
                }
            }
            else -> MobileItemGrid(freeEquipment) { item ->
                MobileCard(Modifier.heightIn(min = 145.dp).clickable { onEquipment(item) }) {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.amber)
                        Text(item.name, fontWeight = FontWeight.Bold, maxLines = 3)
                        Text(item.description.displayOr("Инвентарь"), color = AstraTheme.muted, fontSize = 12.sp, maxLines = 3)
                        MobileWorkoutEntityActions(onEdit = { onEditEquipment(item) }, onDelete = { onDeleteEquipment(item) }, onShareClient = { onShareClient("workout_equipment", item.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun MobileTrainerTile(title: String, count: Int, tint: Color, onClick: () -> Unit) { MobileCard(Modifier.clickable(onClick = onClick)) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(title, color = tint, fontWeight = FontWeight.Bold); Text(count.toString(), fontSize = 22.sp, fontWeight = FontWeight.Bold); Text("Открыть раздел ›", color = AstraTheme.muted, fontSize = 11.sp) } } }

@Composable
private fun TrainerEquipmentList(items: List<WorkoutEquipment>, selectedEquipment: (WorkoutEquipment) -> Unit) { LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(items, key = { it.id }) { item -> MobileCard(Modifier.clickable { selectedEquipment(item) }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column(Modifier.weight(1f)) { Text(item.name, fontWeight = FontWeight.Bold); Text(item.description.displayOr(if (item.kind == "machine") "Тренажёр" else "Инвентарь"), color = AstraTheme.muted, fontSize = 12.sp) }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } } } } }

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
    var sections by remember { mutableStateOf<List<ArticleSection>>(emptyList()) }
    var articles by remember { mutableStateOf<List<Article>>(emptyList()) }
    var selectedSection by remember { mutableStateOf<Int?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var selected by remember { mutableStateOf<Article?>(null) }
    var editing by remember { mutableStateOf<Article?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var shareType by remember { mutableStateOf<String?>(null) }
    var shareId by remember { mutableStateOf<Int?>(null) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val isAdmin = state.user?.isAdmin == true
    val canManage = isAdmin || state.user?.isTrainer == true
    var hasTrainer by remember { mutableStateOf(false) }

    fun replaceArticle(updated: Article) {
        articles = articles.map { if (it.id == updated.id) updated else it }
        if (selected?.id == updated.id) selected = updated
    }
    fun shareToTrainer(article: Article) {
        scope.launch { suspendResult { state.api.shareToTrainer("article", article.id) }.onFailure { error = it.message } }
    }
    fun shareToClient(article: Article) {
        shareType = "article"; shareId = article.id
        scope.launch { clients = suspendResult { state.api.clients() }.getOrDefault(emptyList()) }
    }
    fun toggleFlag(article: Article, flag: String) {
        if (!isAdmin) return
        val value = when (flag) { "is_pinned" -> !article.isPinned; else -> !article.isHidden }
        scope.launch { suspendResult { state.api.updateArticleFlags(article.id, org.json.JSONObject().put(flag, value)) }.onSuccess { replaceArticle(it) }.onFailure { error = it.message } }
    }
    fun deleteArticle(article: Article) {
        scope.launch { suspendResult { state.api.deleteArticle(article.id) }.onSuccess { articles = articles.filterNot { it.id == article.id }; selected = null; showEditor = false }.onFailure { error = it.message } }
    }

    LaunchedEffect(Unit) {
        suspendResult { Pair(state.api.articleSections(), state.api.articles()) }
            .onSuccess { sections = it.first; articles = it.second }
            .onFailure { error = it.message }
        if (!canManage) hasTrainer = suspendResult { state.api.myTrainerChat() }.getOrNull()?.trainer != null
    }
    if (selected != null) {
        ArticleDetailScreen(
            state = state,
            article = selected!!,
            sections = sections,
            isAdmin = isAdmin,
            canManage = canManage,
            hasTrainer = hasTrainer,
            onBack = { selected = null },
            onChanged = ::replaceArticle,
            onEdit = { editing = it; showEditor = true },
            onDelete = ::deleteArticle,
            onToggleFlag = ::toggleFlag,
            onShareClient = ::shareToClient,
            onShareTrainer = ::shareToTrainer
        )
        if (showEditor) ArticleEditorDialog(editing, sections, { body ->
            scope.launch { suspendResult { if (editing == null) state.api.createArticle(body) else state.api.updateArticle(editing!!.id, body) }.onSuccess { replaceArticle(it); selected = it; showEditor = false }.onFailure { error = it.message } }
        }, if (editing != null) ({ deleteArticle(editing!!) }) else null) { showEditor = false }
        if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId ->
            val id = shareId!!
            scope.launch { suspendResult { state.api.shareToClient(clientId, "article", id) }.onFailure { error = it.message }; shareType = null; shareId = null }
        }, { shareType = null; shareId = null })
        return
    }

    val filtered = articles.filter { (selectedSection == null || it.sectionId == selectedSection) && (search.isBlank() || it.title.contains(search, true) || it.body.stripHtml().contains(search, true) || (it.tags ?: "").contains(search, true)) }
    val pinned = articles.filter { it.isPinned && (search.isBlank() || it.title.contains(search, true) || it.body.stripHtml().contains(search, true) || (it.tags ?: "").contains(search, true)) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, top = 16.dp, end = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text("Информация", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Питание, тренировки и полезные материалы", color = AstraTheme.muted) }
            if (isAdmin) OutlinedButton({ editing = null; showEditor = true }) { Text("＋ Статья") }
        }
        OutlinedTextField(search, { search = it }, label = { Text("Найти статью") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(16.dp))
        if (pinned.isNotEmpty()) {
            Text("Закреплённые статьи", modifier = Modifier.padding(horizontal = 16.dp), fontWeight = FontWeight.Bold)
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pinned.forEach { article -> ArticleCarouselCard(article) { selected = article } }
            }
        }
        Text("Разделы статей", modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp), fontWeight = FontWeight.Bold)
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            val sectionTiles = listOf("Все" to articles.size) + sections.map { it.name to it.articleCount }
            sectionTiles.chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { (name, count) ->
                        Box(Modifier.weight(1f)) { ArticleSectionTile(name, count, selected = if (name == "Все") selectedSection == null else sections.firstOrNull { it.name == name }?.id == selectedSection) { selectedSection = if (name == "Все") null else sections.firstOrNull { it.name == name }?.id } }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }
        if (filtered.isEmpty()) EmptyMessage("Статей пока нет", "Материалы появятся здесь после публикации в веб-версии.")
        else LazyVerticalGrid(columns = GridCells.Fixed(2), modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(filtered.size, key = { filtered[it].id }) { index ->
                val article = filtered[index]
                ArticleTile(article, isAdmin, canManage, hasTrainer, onOpen = { selected = article }, onPin = { toggleFlag(article, "is_pinned") }, onHide = { toggleFlag(article, "is_hidden") }, onEdit = { editing = article; showEditor = true }, onShareClient = { shareToClient(article) }, onShareTrainer = { shareToTrainer(article) })
            }
        }
    }
    if (showEditor) ArticleEditorDialog(editing, sections, { body ->
        scope.launch { suspendResult { if (editing == null) state.api.createArticle(body) else state.api.updateArticle(editing!!.id, body) }.onSuccess { updated -> if (editing == null) articles = articles + updated else replaceArticle(updated); showEditor = false }.onFailure { error = it.message } }
    }, if (editing != null) ({ deleteArticle(editing!!) }) else null) { showEditor = false }
    if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId ->
        val id = shareId!!
        scope.launch { suspendResult { state.api.shareToClient(clientId, "article", id) }.onFailure { error = it.message }; shareType = null; shareId = null }
    }, { shareType = null; shareId = null })
}

@Composable
private fun ArticleSectionTile(title: String, count: Int, selected: Boolean, onClick: () -> Unit) {
    MobileCard(Modifier.heightIn(min = 102.dp).clickable(onClick = onClick)) {
        Row(Modifier.fillMaxWidth().padding(13.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(articleSectionIcon(title), null, tint = if (selected) AstraTheme.blue else AstraTheme.green, modifier = Modifier.size(30.dp))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, color = if (selected) AstraTheme.blue else AstraTheme.ink, fontWeight = FontWeight.Bold, maxLines = 2)
                Text("$count статей", color = AstraTheme.muted, fontSize = 11.sp)
            }
        }
    }
}

private fun articleSectionIcon(title: String) = when {
    title.contains("трен", ignoreCase = true) || title.contains("упраж", ignoreCase = true) -> Icons.Default.FitnessCenter
    title.contains("питан", ignoreCase = true) || title.contains("рецеп", ignoreCase = true) -> Icons.Default.Restaurant
    else -> Icons.Default.Book
}

@Composable
private fun ArticleCarouselCard(article: Article, onOpen: () -> Unit) {
    MobileCard(Modifier.width(252.dp).height(142.dp).clickable(onClick = onOpen)) { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(article.sectionName.uppercase(), color = AstraTheme.blue, fontSize = 10.sp, fontWeight = FontWeight.Bold); Text(article.title, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 2); Text(article.body.stripHtml(), color = AstraTheme.muted, fontSize = 12.sp, maxLines = 2); Text("Читать статью →", color = AstraTheme.blue, fontSize = 11.sp, fontWeight = FontWeight.Bold) } }
}

@Composable
private fun ArticleTile(article: Article, isAdmin: Boolean, canManage: Boolean, hasTrainer: Boolean, onOpen: () -> Unit, onPin: () -> Unit, onHide: () -> Unit, onEdit: () -> Unit, onShareClient: () -> Unit, onShareTrainer: () -> Unit) {
    MobileCard(Modifier.fillMaxWidth().heightIn(min = 275.dp).clickable(onClick = onOpen)) {
        Column(Modifier.padding(12.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) { Text(article.sectionName.uppercase(), color = AstraTheme.blue, fontSize = 10.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); if (isAdmin) IconButton(onClick = onPin, modifier = Modifier.size(30.dp)) { Text(if (article.isPinned) "★" else "☆", color = AstraTheme.blue, fontSize = 18.sp) } }
            Text(article.title, color = AstraTheme.ink, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 3)
            Text(article.body.stripHtml(), color = AstraTheme.muted, fontSize = 12.sp, maxLines = 3)
            Spacer(Modifier.weight(1f))
            Button(onClick = onOpen, modifier = Modifier.fillMaxWidth().height(38.dp), contentPadding = PaddingValues(horizontal = 8.dp)) { Text("Читать статью", fontSize = 12.sp) }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                if (isAdmin) { TextButton(onClick = onHide, modifier = Modifier.weight(1f)) { Text(if (article.isHidden) "Вернуть" else "Скрыть", fontSize = 10.sp) }; TextButton(onClick = onEdit, modifier = Modifier.weight(1f)) { Text("Изм.", fontSize = 10.sp) } }
                if (canManage) TextButton(onClick = onShareClient, modifier = Modifier.weight(1f)) { Text("Клиенту", fontSize = 10.sp) }
                if (hasTrainer && !canManage) TextButton(onClick = onShareTrainer, modifier = Modifier.weight(1f)) { Text("Тренеру", fontSize = 10.sp) }
            }
        }
    }
}

@Composable
private fun ArticleDetailScreen(state: AstraState, article: Article, sections: List<ArticleSection>, isAdmin: Boolean, canManage: Boolean, hasTrainer: Boolean, onBack: () -> Unit, onChanged: (Article) -> Unit, onEdit: (Article) -> Unit, onDelete: (Article) -> Unit, onToggleFlag: (Article, String) -> Unit, onShareClient: (Article) -> Unit, onShareTrainer: (Article) -> Unit) {
    var confirmDelete by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(10.dp), verticalAlignment = Alignment.CenterVertically) { IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Назад") }; Text("Статья", fontSize = 20.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.weight(1f)) }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(article.sectionName.uppercase(), color = AstraTheme.blue, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Text(article.title, color = AstraTheme.ink, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            MobileCard { Text(article.body.stripHtml(), Modifier.padding(14.dp), color = AstraTheme.ink, lineHeight = 24.sp) }
            article.tags?.takeIf { it.isNotBlank() }?.let { Text(it, color = AstraTheme.muted, fontSize = 12.sp) }
            if (article.links.isNotEmpty() || article.video != null) MobileCard { Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) { Text("Ссылки", fontWeight = FontWeight.Bold); article.links.forEach { Text("${it.title}: ${it.url}", color = AstraTheme.blue, fontSize = 12.sp) }; article.video?.let { Text("Видео: $it", color = AstraTheme.blue, fontSize = 12.sp) } } }
            Button(onClick = { onEdit(article) }, modifier = Modifier.fillMaxWidth()) { Text("Редактировать") }
            if (isAdmin) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton(onClick = { onToggleFlag(article, "is_pinned") }, modifier = Modifier.weight(1f)) { Text(if (article.isPinned) "Открепить" else "Закрепить") }; OutlinedButton(onClick = { onToggleFlag(article, "is_hidden") }, modifier = Modifier.weight(1f)) { Text(if (article.isHidden) "Вернуть" else "Скрыть") } }
                TextButton(onClick = { confirmDelete = true }, colors = ButtonDefaults.textButtonColors(contentColor = AstraTheme.danger), modifier = Modifier.fillMaxWidth()) { Text("Удалить статью") }
            }
            if (canManage) OutlinedButton(onClick = { onShareClient(article) }, modifier = Modifier.fillMaxWidth()) { Text("Отправить клиенту") }
            if (hasTrainer && !canManage) OutlinedButton(onClick = { onShareTrainer(article) }, modifier = Modifier.fillMaxWidth()) { Text("Отправить тренеру") }
        }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text("Удалить статью?") }, text = { Text("Это действие нельзя отменить.") }, confirmButton = { Button(onClick = { confirmDelete = false; onDelete(article) }, colors = ButtonDefaults.buttonColors(containerColor = AstraTheme.danger)) { Text("Удалить") } }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Отмена") } })
}

@Composable
private fun ArticleEditorDialog(existing: Article?, sections: List<ArticleSection>, onSave: (org.json.JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var sectionId by remember { mutableStateOf(existing?.sectionId ?: sections.firstOrNull()?.id ?: 0) }
    var title by remember { mutableStateOf(existing?.title.orEmpty()) }
    var body by remember { mutableStateOf(existing?.body?.stripHtml().orEmpty()) }
    var tags by remember { mutableStateOf(existing?.tags.orEmpty()) }
    var video by remember { mutableStateOf(existing?.video.orEmpty()) }
    var links by remember { mutableStateOf(existing?.links?.joinToString("\n") { "${it.title}|${it.url}" }.orEmpty()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "Новая статья" else "Редактировать статью") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                if (sections.isNotEmpty()) Picker("Раздел", sections.map { it.name }) { name -> sectionId = sections.firstOrNull { it.name == name }?.id ?: sectionId }
                EditField("Заголовок", title) { title = it }
                EditField("Текст статьи", body) { body = it }
                EditField("Хэштеги", tags) { tags = it }
                EditField("Видео URL", video) { video = it }
                EditField("Ссылки: название|URL, по одной в строке", links) { links = it }
            }
        },
        confirmButton = {
            Button(onClick = {
                val linkArray = org.json.JSONArray()
                links.lines().mapNotNull { line ->
                    val parts = line.split("|", limit = 2)
                    if (parts.size == 2 && parts[0].trim().isNotEmpty() && parts[1].trim().isNotEmpty()) org.json.JSONObject().put("title", parts[0].trim()).put("url", parts[1].trim()) else null
                }.forEach { linkArray.put(it) }
                onSave(org.json.JSONObject().put("section_id", sectionId).put("title", title.trim()).put("body", body).put("tags", tags.trim()).put("video", video.trim().ifBlank { org.json.JSONObject.NULL }).put("links", linkArray).put("photos", org.json.JSONArray(existing?.photos ?: emptyList<String>())))
            }, enabled = sectionId > 0 && title.isNotBlank() && body.isNotBlank()) { Text("Сохранить") }
        },
        dismissButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                onDelete?.let { TextButton(onClick = it, colors = ButtonDefaults.textButtonColors(contentColor = AstraTheme.danger)) { Text("Удалить") } }
                TextButton(onClick = onDismiss) { Text("Отмена") }
            }
        }
    )
}

private fun String.stripHtml(): String = replace(Regex("<[^>]+>"), " ").replace("&nbsp;", " ").replace(Regex("\\s+"), " ").trim()

@Composable
private fun MobileWorkoutsDashboardScreen(state: AstraState) {
    var category by rememberSaveable { mutableStateOf<Int?>(null) }
    var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }
    var logs by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }
    var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }
    var complexes by remember { mutableStateOf<List<WorkoutComplex>>(emptyList()) }
    var equipment by remember { mutableStateOf<List<WorkoutEquipment>>(emptyList()) }
    var selectedPlan by remember { mutableStateOf<WorkoutPlan?>(null) }
    var selectedWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    var selectedExercise by remember { mutableStateOf<Exercise?>(null) }
    var selectedComplex by remember { mutableStateOf<WorkoutComplex?>(null) }
    var selectedEquipment by remember { mutableStateOf<WorkoutEquipment?>(null) }
    var showAdd by remember { mutableStateOf(false) }
    var showPlanEditor by remember { mutableStateOf(false) }
    var editingPlan by remember { mutableStateOf<WorkoutPlan?>(null) }
    var planFromComplex by remember { mutableStateOf<WorkoutComplex?>(null) }
    var editingWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    var showWorkoutEditor by remember { mutableStateOf(false) }
    var editingExercise by remember { mutableStateOf<Exercise?>(null) }
    var showExerciseEditor by remember { mutableStateOf(false) }
    var editingEquipment by remember { mutableStateOf<WorkoutEquipment?>(null) }
    var showEquipmentEditor by remember { mutableStateOf(false) }
    var showComplexEditor by remember { mutableStateOf(false) }
    var showWorkoutManage by remember { mutableStateOf(false) }
    var editingComplex by remember { mutableStateOf<WorkoutComplex?>(null) }
    var shareType by remember { mutableStateOf<String?>(null) }
    var shareId by remember { mutableStateOf<Int?>(null) }
    var clients by remember { mutableStateOf<List<ClientSummary>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val canManage = state.user?.isAdmin == true || state.user?.isTrainer == true
    var hasTrainer by remember { mutableStateOf(false) }

    suspend fun load() {
        plans = suspendResult { state.api.plans() }.getOrDefault(emptyList())
        logs = suspendResult { state.api.workouts() }.getOrDefault(emptyList())
        exercises = suspendResult { state.api.exercises() }.getOrDefault(emptyList())
        complexes = suspendResult { state.api.workoutComplexes() }.getOrDefault(emptyList())
        equipment = suspendResult { state.api.workoutEquipment() }.getOrDefault(emptyList())
    }

    val historyPlans = plans.filter { it.isHistory }.sortedByDescending { it.completedAt ?: it.scheduledAt }

    LaunchedEffect(Unit) { load() }
    LaunchedEffect(canManage) {
        if (!canManage) hasTrainer = suspendResult { state.api.myTrainerChat() }.getOrNull()?.trainer != null
    }
    LaunchedEffect(shareType) { if (shareType != null && clients.isEmpty()) clients = suspendResult { state.api.clients() }.getOrDefault(emptyList()) }

    if (selectedPlan != null) {
        val plan = selectedPlan!!
        TrainerPlanDetailScreen(plan, onBack = { selectedPlan = null }, onEdit = if (canManage) ({ selectedPlan = null; editingPlan = plan; planFromComplex = null; showPlanEditor = true }) else null, onRepeat = { selectedPlan = null; editingPlan = plan.copy(id = 0, scheduledAt = todayTime()); planFromComplex = null; showPlanEditor = true }, onCancel = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null, onDelete = if (plan.status == "canceled") ({ scope.launch { suspendResult { state.api.deletePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null, onComplete = if (plan.status == "planned") ({ scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load(); selectedPlan = null }.onFailure { error = it.message } } }) else null)
        return
    }
    if (selectedWorkout != null) {
        val workout = selectedWorkout!!
        TrainerWorkoutDetailScreen(workout, onBack = { selectedWorkout = null }, onEdit = { selectedWorkout = null; editingWorkout = workout; showWorkoutEditor = true }, onRepeat = { selectedWorkout = null; editingPlan = WorkoutPlan(0, workout.date, null, "planned", null, listOf(WorkoutPlanItem(null, workout.exerciseId, workout.name, workout.muscleGroup, workout.weight, workout.sets, null, null))); planFromComplex = null; showPlanEditor = true }, onDelete = { scope.launch { suspendResult { state.api.deleteWorkout(workout.id) }.onSuccess { load(); selectedWorkout = null }.onFailure { error = it.message } } })
        return
    }
    if (selectedExercise != null) {
        val exercise = selectedExercise!!
        MobileExerciseDetailScreen(
            exercise,
            allExercises = exercises,
            onBack = { selectedExercise = null },
            onEdit = if (canManage) ({ item: Exercise -> selectedExercise = null; editingExercise = item; showExerciseEditor = true }) else null,
            onDelete = if (canManage) ({ item: Exercise -> scope.launch { suspendResult { state.api.deleteExercise(item.id) }.onSuccess { load(); selectedExercise = null }.onFailure { error = it.message } } }) else null,
            onShareTrainer = if (hasTrainer && !canManage) ({ item: Exercise -> scope.launch { suspendResult { state.api.shareToTrainer("exercise", item.id) }.onFailure { error = it.message } } }) else null,
            onShareClient = if (canManage) ({ item: Exercise -> shareType = "exercise"; shareId = item.id }) else null
        )
        return
    }
    if (selectedComplex != null) {
        val complex = selectedComplex!!
        TrainerComplexDetailScreen(
            complex = complex,
            onBack = { selectedComplex = null },
            onEdit = if (canManage) ({ selectedComplex = null; editingComplex = complex; showComplexEditor = true }) else null,
            onSchedule = { selectedComplex = null; planFromComplex = complex; editingPlan = null; showPlanEditor = true },
            onDelete = if (canManage) ({
                scope.launch {
                    suspendResult { state.api.deleteComplex(complex.id) }
                        .onSuccess { load(); selectedComplex = null }
                        .onFailure { error = it.message }
                }
            }) else null,
            onShareTrainer = if (hasTrainer && !canManage) ({ scope.launch { suspendResult { state.api.shareToTrainer("workout_complex", complex.id) }.onFailure { error = it.message } } }) else null,
            onShareClient = if (canManage) ({ shareType = "workout_complex"; shareId = complex.id }) else null
        )
        return
    }
    if (selectedEquipment != null) {
        val item = selectedEquipment!!
        MobileEquipmentDetailScreen(
            item,
            onBack = { selectedEquipment = null },
            onEdit = if (canManage) ({ selectedEquipment = null; editingEquipment = item; showEquipmentEditor = true }) else null,
            onDelete = if (canManage) ({ scope.launch { suspendResult { state.api.deleteEquipment(item.id) }.onSuccess { load(); selectedEquipment = null }.onFailure { error = it.message } } }) else null,
            onShareTrainer = if (hasTrainer && !canManage) ({ scope.launch { suspendResult { state.api.shareToTrainer("workout_equipment", item.id) }.onFailure { error = it.message } } }) else null,
            onShareClient = if (canManage) ({ shareType = "workout_equipment"; shareId = item.id }) else null
        )
        return
    }

    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        if (category == null) {
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 16.dp), verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text("Тренировки", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text("План, упражнения и история нагрузки в одном месте", color = AstraTheme.muted)
                }
                TextButton(onClick = { showAdd = true }) { Text("Записать") }
            }
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (canManage) OutlinedButton(onClick = { showWorkoutManage = true }) { Text("Управление") }
                if (canManage) OutlinedButton(onClick = { editingComplex = null; showComplexEditor = true }) { Text("Новый комплекс") }
            }
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (canManage) OutlinedButton(onClick = { editingExercise = null; showExerciseEditor = true }) { Text("Новое упражнение") }
                if (canManage) OutlinedButton(onClick = { editingEquipment = null; showEquipmentEditor = true }) { Text("Новый инвентарь") }
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) }
            val planned = plans.filter { it.status == "planned" }
            LazyColumn(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (planned.isNotEmpty()) {
                    item { Text("Закреплённые тренировки", fontSize = 19.sp, fontWeight = FontWeight.Bold) }
                    item { MobileItemGrid(planned.take(3)) { plan ->
                        MobileCard(Modifier.clickable { selectedPlan = plan }) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text("БЛИЖАЙШАЯ ТРЕНИРОВКА", color = AstraTheme.blue, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                Text(plan.displayName, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                                Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                                Text(plan.items.joinToString(" · ") { it.name.displayOr("Упражнение") }.ifBlank { "План тренировки" }, color = AstraTheme.muted, maxLines = 2)
                                Text("Открыть тренировку  ›", color = AstraTheme.blue, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                                    IconButton(onClick = { scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.CheckCircle, "Выполнено", tint = AstraTheme.green, modifier = Modifier.size(18.dp)) }
                                    if (canManage) IconButton(onClick = { editingPlan = plan; planFromComplex = null; showPlanEditor = true }, modifier = Modifier.size(34.dp)) { Icon(Icons.Default.Edit, "Редактировать", modifier = Modifier.size(17.dp)) }
                                    TextButton(onClick = { scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } }) { Text("Отменить", fontSize = 11.sp) }
                                }
                            }
                        }
                    } }
                }
                item { Text("Разделы", fontSize = 19.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp)) }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.weight(1f)) {
                            MobileWorkoutCategoryTile("Тренировки", "Комплексы и программы", plans.size, Icons.Default.FitnessCenter, AstraTheme.blue) { category = 0 }
                        }
                        Box(Modifier.weight(1f)) {
                            MobileWorkoutCategoryTile("Упражнения", "Справочник упражнений", exercises.size, Icons.Default.FitnessCenter, AstraTheme.green) { category = 1 }
                        }
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.weight(1f)) {
                            MobileWorkoutCategoryTile("Инвентарь", "Оборудование", equipment.size, Icons.Default.Info, AstraTheme.amber) { category = 2 }
                        }
                        Box(Modifier.weight(1f)) {
                            MobileWorkoutCategoryTile("История", "Завершённые тренировки", historyPlans.size, Icons.Default.Book, AstraTheme.blue) { category = 3 }
                        }
                    }
                }
                item { Spacer(Modifier.height(12.dp)) }
            }
        } else {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { category = null }) { Text("‹ Разделы") }
                Spacer(Modifier.weight(1f))
                Text(listOf("Тренировки", "Упражнения", "Инвентарь", "История")[category!!], fontWeight = FontWeight.Bold)
            }
            MobileWorkoutCategoryGrid(
                category = category!!,
                plans = plans,
                exercises = exercises,
                complexes = complexes,
                equipment = equipment,
                logs = logs,
                historyPlans = historyPlans,
                onPlan = { selectedPlan = it },
                onExercise = { selectedExercise = it },
                onComplex = { selectedComplex = it },
                onEquipment = { selectedEquipment = it },
                onWorkout = { selectedWorkout = it },
                canManage = canManage,
                hasTrainer = hasTrainer,
                onAddExercise = { editingExercise = null; showExerciseEditor = true },
                onEditExercise = { editingExercise = it; showExerciseEditor = true },
                onDeleteExercise = { item -> scope.launch { suspendResult { state.api.deleteExercise(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onShareClient = { type, id -> shareType = type; shareId = id },
                onShareTrainer = { type, id -> scope.launch { suspendResult { state.api.shareToTrainer(type, id) }.onFailure { error = it.message } } },
                onEditComplex = { editingComplex = it; showComplexEditor = true },
                onScheduleComplex = { planFromComplex = it; editingPlan = null; showPlanEditor = true },
                onDeleteComplex = { item -> scope.launch { suspendResult { state.api.deleteComplex(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onEditEquipment = { editingEquipment = it; showEquipmentEditor = true },
                onDeleteEquipment = { item -> scope.launch { suspendResult { state.api.deleteEquipment(item.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onCompletePlan = { plan -> scope.launch { suspendResult { state.api.completePlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onEditPlan = { plan -> editingPlan = plan; planFromComplex = null; showPlanEditor = true },
                onRepeatPlan = { plan -> editingPlan = plan.copy(id = 0, scheduledAt = todayTime()); planFromComplex = null; showPlanEditor = true },
                onCancelPlan = { plan -> scope.launch { suspendResult { state.api.cancelPlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } },
                onDeletePlan = { plan -> scope.launch { suspendResult { state.api.deletePlan(plan.id) }.onSuccess { load() }.onFailure { error = it.message } } }
            )
            if (category == null) when (category) {
                0 -> LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(plans, key = { "plan-${it.id}" }) { plan ->
                        MobileCard(Modifier.clickable { selectedPlan = plan }) {
                            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(plan.displayName, fontWeight = FontWeight.Bold)
                                    Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp)
                                    Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp)
                                }
                                Text("›", fontSize = 22.sp, color = AstraTheme.muted)
                            }
                        }
                    }
                }
                1 -> LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(exercises, key = { "exercise-${it.id}" }) { exercise ->
                        MobileCard(Modifier.clickable { selectedExercise = exercise }) {
                            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green)
                                Spacer(Modifier.width(10.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(exercise.name, fontWeight = FontWeight.Bold)
                                    Text("${exercise.muscleGroup ?: "Другое"} · ${exercise.defaultSets.shown(" подхода")} × ${exercise.defaultReps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp)
                                }
                                Text("›", fontSize = 22.sp, color = AstraTheme.muted)
                            }
                        }
                    }
                }
                2 -> LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    item { Text("Оборудование", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
                    items(equipment, key = { "equipment-${it.id}" }) { item ->
                        MobileCard(Modifier.clickable { selectedEquipment = item }) {
                            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.amber)
                                Spacer(Modifier.width(10.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(item.name, fontWeight = FontWeight.Bold)
                                    Text(item.description.displayOr(if (item.kind == "machine") "Тренажёр" else "Инвентарь"), color = AstraTheme.muted, fontSize = 12.sp)
                                }
                                Text("›", fontSize = 22.sp, color = AstraTheme.muted)
                            }
                        }
                    }
                    item { Text("Комплексы", fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 10.dp)) }
                    items(complexes, key = { "complex-${it.id}" }) { complex ->
                        MobileCard(Modifier.clickable { planFromComplex = complex; editingPlan = null; showPlanEditor = true }) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(complex.name, fontWeight = FontWeight.Bold)
                                Text("${complex.items.size} упражнений", color = AstraTheme.muted, fontSize = 12.sp)
                                complex.comment.displayOrNull()?.let { Text(it, color = AstraTheme.muted, fontSize = 12.sp) }
                            }
                        }
                    }
                }
                else -> LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(logs, key = { "log-${it.id}" }) { log ->
                        MobileCard(Modifier.clickable { selectedWorkout = log }) {
                            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(log.name, fontWeight = FontWeight.Bold)
                                    Text("${log.date} · ${log.sets.shown(" подходов")} × ${log.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp)
                                }
                                Text("›", fontSize = 22.sp, color = AstraTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAdd) MobileAddWorkoutDialog(exercises, { date, exercise, weight, sets, reps, rir ->
        scope.launch {
            suspendResult { state.api.addWorkout(date, exercise.id, weight, sets, reps, rir) }
            load()
            showAdd = false
        }
    }, { showAdd = false })
    if (showPlanEditor) WorkoutPlanEditorDialog(editingPlan, planFromComplex, exercises, { body -> scope.launch { suspendResult { if (editingPlan == null || editingPlan!!.id == 0) state.api.createPlan(body) else state.api.updatePlan(editingPlan!!.id, body) }.onSuccess { load(); showPlanEditor = false; editingPlan = null; planFromComplex = null }.onFailure { error = it.message } } }, { showPlanEditor = false; editingPlan = null; planFromComplex = null })
    if (showWorkoutEditor) WorkoutEntryEditorDialog(editingWorkout, exercises, { body -> scope.launch { suspendResult { if (editingWorkout == null) state.api.createWorkout(body) else state.api.updateWorkout(editingWorkout!!.id, body) }.onSuccess { load(); showWorkoutEditor = false; editingWorkout = null }.onFailure { error = it.message } } }, if (editingWorkout != null) ({ scope.launch { suspendResult { state.api.deleteWorkout(editingWorkout!!.id) }.onSuccess { load(); showWorkoutEditor = false; editingWorkout = null }.onFailure { error = it.message } } }) else null) { showWorkoutEditor = false; editingWorkout = null }
    if (showExerciseEditor) ExerciseEditorDialog(editingExercise, { body -> scope.launch { suspendResult { if (editingExercise == null) state.api.createExercise(body) else state.api.updateExercise(editingExercise!!.id, body) }.onSuccess { load(); showExerciseEditor = false; editingExercise = null }.onFailure { error = it.message } } }, if (editingExercise != null) ({ scope.launch { suspendResult { state.api.deleteExercise(editingExercise!!.id) }.onSuccess { load(); showExerciseEditor = false; editingExercise = null }.onFailure { error = it.message } } }) else null) { showExerciseEditor = false; editingExercise = null }
    if (showEquipmentEditor) EquipmentEditorDialog(editingEquipment, { body -> scope.launch { suspendResult { if (editingEquipment == null) state.api.createEquipment(body) else state.api.updateEquipment(editingEquipment!!.id, body) }.onSuccess { load(); showEquipmentEditor = false; editingEquipment = null }.onFailure { error = it.message } } }, if (editingEquipment != null) ({ scope.launch { suspendResult { state.api.deleteEquipment(editingEquipment!!.id) }.onSuccess { load(); showEquipmentEditor = false; editingEquipment = null }.onFailure { error = it.message } } }) else null) { showEquipmentEditor = false; editingEquipment = null }
    if (showComplexEditor) WorkoutComplexEditorDialog(editingComplex, exercises, { body -> scope.launch { suspendResult { if (editingComplex == null) state.api.createComplex(body) else state.api.updateComplex(editingComplex!!.id, body) }.onSuccess { load(); showComplexEditor = false; editingComplex = null }.onFailure { error = it.message } } }, { showComplexEditor = false; editingComplex = null })
    if (showWorkoutManage) WorkoutEntityManageDialog(exercises, equipment, complexes, { item -> editingExercise = item; showExerciseEditor = true; showWorkoutManage = false }, { item -> scope.launch { suspendResult { state.api.deleteExercise(item.id) }.onSuccess { load(); showWorkoutManage = false }.onFailure { error = it.message } } }, { item -> editingEquipment = item; showEquipmentEditor = true; showWorkoutManage = false }, { item -> scope.launch { suspendResult { state.api.deleteEquipment(item.id) }.onSuccess { load(); showWorkoutManage = false }.onFailure { error = it.message } } }, { item -> editingComplex = item; showComplexEditor = true; showWorkoutManage = false }, { item -> planFromComplex = item; editingPlan = null; showPlanEditor = true; showWorkoutManage = false }, { type, id -> scope.launch { suspendResult { state.api.shareToTrainer(type, id) }.onFailure { error = it.message } }; shareType = type; shareId = id; showWorkoutManage = false }, { showWorkoutManage = false })
    if (shareType != null && shareId != null) ShareToClientDialog(clients, { clientId -> val type = shareType!!; val id = shareId!!; scope.launch { suspendResult { state.api.shareToClient(clientId, type, id) }.onFailure { error = it.message }; shareType = null; shareId = null } }, { shareType = null; shareId = null })
    selectedExercise?.let { exercise ->
        AlertDialog(onDismissRequest = { selectedExercise = null }, title = { Text(exercise.name) }, text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(exercise.muscleGroup ?: "Другое", color = AstraTheme.muted)
                Text("Единица: ${exercise.unit ?: "—"}")
                Text("Подходы: ${exercise.defaultSets.shown()}")
                Text("Повторения: ${exercise.defaultReps.shown()}")
            }
        }, confirmButton = { TextButton({ selectedExercise = null }) { Text("Закрыть") } })
    }
    selectedEquipment?.let { item ->
        AlertDialog(onDismissRequest = { selectedEquipment = null }, title = { Text(item.name) }, text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted)
                item.description.displayOrNull()?.let { Text(it) }
            }
        }, confirmButton = { TextButton({ selectedEquipment = null }) { Text("Закрыть") } })
    }
}

@Composable
private fun MobileWorkoutCategoryTile(title: String, subtitle: String, count: Int, icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, onClick: () -> Unit) {
    MobileCard(Modifier.clickable(onClick = onClick)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(24.dp))
            Text(title, fontWeight = FontWeight.Bold)
            Text(subtitle, color = AstraTheme.muted, fontSize = 11.sp, maxLines = 2)
            Text(count.toString(), color = tint, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun WorkoutDetailHeader(title: String, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
        Text(title, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun WorkoutDetailHero(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(176.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(tint.copy(alpha = .13f)),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(76.dp))
    }
}

@Composable
private fun WorkoutDetailBadge(title: String, tint: Color) {
    Text(
        title,
        color = tint,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(tint.copy(alpha = .08f))
            .border(1.dp, tint.copy(alpha = .7f), RoundedCornerShape(50.dp))
            .padding(horizontal = 11.dp, vertical = 6.dp)
    )
}

@Composable
private fun WorkoutDetailRow(index: Int, title: String, value: String) {
    MobileCard {
        Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(32.dp)
                    .background(AstraTheme.blue.copy(alpha = .10f), RoundedCornerShape(50.dp)),
                contentAlignment = Alignment.Center
            ) {
                Text(index.toString(), color = AstraTheme.blue, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, fontWeight = FontWeight.Bold)
                Text(value, color = AstraTheme.muted, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun MobileExerciseDetailScreen(exercise: Exercise, allExercises: List<Exercise> = emptyList(), onBack: () -> Unit, onEdit: ((Exercise) -> Unit)? = null, onDelete: ((Exercise) -> Unit)? = null, onShareTrainer: ((Exercise) -> Unit)? = null, onShareClient: ((Exercise) -> Unit)? = null) {
    var currentIndex by remember(exercise.id) { mutableStateOf(allExercises.indexOfFirst { it.id == exercise.id }.coerceAtLeast(0)) }
    val current = allExercises.getOrNull(currentIndex) ?: exercise
    val total = allExercises.size.coerceAtLeast(1)
    val progress = ((currentIndex + 1).toFloat() / total.toFloat()).coerceIn(0f, 1f)
    val nextExercise = { if (currentIndex < allExercises.lastIndex) currentIndex += 1 else onBack() }
    val previousExercise = { if (currentIndex > 0) currentIndex -= 1 else onBack() }
    val currentEdit: (() -> Unit)? = onEdit?.let { callback -> { callback(current) } }
    val currentDelete: (() -> Unit)? = onDelete?.let { callback -> { callback(current) } }
    val currentShareTrainer: (() -> Unit)? = onShareTrainer?.let { callback -> { callback(current) } }
    val currentShareClient: (() -> Unit)? = onShareClient?.let { callback -> { callback(current) } }

    Column(Modifier.fillMaxSize().background(Color(0xFF0A0908)).verticalScroll(rememberScrollState()).padding(top = 12.dp, bottom = 16.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(3.dp)).background(Color.White.copy(alpha = .13f))) {
                Box(Modifier.fillMaxWidth(progress).fillMaxHeight().background(AstraTheme.blue))
            }
            Box(
                Modifier
                    .width(88.dp)
                    .height(27.dp)
                    .clip(RoundedCornerShape(50.dp))
                    .background(Color.White.copy(alpha = .04f))
                    .border(1.dp, Color.White.copy(alpha = .08f), RoundedCornerShape(50.dp))
                    .clickable(onClick = onBack),
                contentAlignment = Alignment.Center
            ) { Text("Пропустить", color = AstraTheme.blue, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }
        }
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            WorkoutDetailHero(Icons.Default.FitnessCenter, AstraTheme.green)
            Text(current.muscleGroup.displayOr("Другое"), color = AstraTheme.green, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            current.code.displayOrNull()?.let { Text(it, color = Color.White.copy(alpha = .55f), fontSize = 12.sp) }
            Text(current.name, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, maxLines = 3)
            Text(current.description.displayOr(current.note.displayOr("Описание упражнения пока не добавлено")), color = Color.White.copy(alpha = .68f), fontSize = 14.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WorkoutDetailBadge("${current.defaultSets.shown()} подходов", AstraTheme.blue)
                WorkoutDetailBadge("${current.defaultReps.shown()} повторений", AstraTheme.blue)
                current.unit.displayOrNull()?.let { WorkoutDetailBadge(it, AstraTheme.green) }
            }
            if (current.targetRir.displayOrNull() != null) Text("Целевой RIR: ${current.targetRir}", color = Color.White.copy(alpha = .68f), fontSize = 13.sp)
            Text("Техника и варианты", color = Color.White, fontSize = 19.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
            if (current.variants.isEmpty()) {
                Text("Варианты выполнения пока не добавлены.", color = Color.White.copy(alpha = .62f), fontSize = 13.sp)
            } else current.variants.forEachIndexed { index, variant ->
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(variant.name.displayOr("Вариант ${index + 1}"), fontWeight = FontWeight.Bold)
                        variant.machine.displayOrNull()?.let { Text("Тренажёр: $it", color = AstraTheme.muted, fontSize = 12.sp) }
                        variant.equipment.displayOrNull()?.let { Text("Инвентарь: $it", color = AstraTheme.muted, fontSize = 12.sp) }
                        variant.description.displayOrNull()?.let { Text(it, fontSize = 13.sp) }
                        variant.technique.displayOrNull()?.let { Text("Техника: $it", color = AstraTheme.muted, fontSize = 12.sp) }
                        variant.tips.displayOrNull()?.let { Text("Советы: $it", color = AstraTheme.muted, fontSize = 12.sp) }
                    }
                }
            }
            if (current.photos.isNotEmpty() || current.video.displayOrNull() != null) {
                Text("Медиа", color = Color.White, fontSize = 19.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
                Text(listOfNotNull(current.photos.takeIf { it.isNotEmpty() }?.let { "Фото: ${it.size}" }, current.video.displayOrNull()?.let { "Видео доступно" }).joinToString(" · "), color = Color.White.copy(alpha = .68f), fontSize = 13.sp)
            }
            MobileWorkoutEntityActions(onEdit = currentEdit, onDelete = currentDelete, onShareTrainer = currentShareTrainer, onShareClient = currentShareClient)
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 22.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = previousExercise, modifier = Modifier.weight(1f).height(44.dp), shape = RoundedCornerShape(22.dp), colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White)) { Text("Назад") }
            Button(onClick = nextExercise, modifier = Modifier.weight(1f).height(44.dp), shape = RoundedCornerShape(22.dp), colors = ButtonDefaults.buttonColors(containerColor = AstraTheme.blue, contentColor = Color.White)) { Text("Далее") }
        }
    }
}

@Composable
private fun MobileEquipmentDetailScreen(item: WorkoutEquipment, onBack: () -> Unit, onEdit: (() -> Unit)? = null, onDelete: (() -> Unit)? = null, onShareTrainer: (() -> Unit)? = null, onShareClient: (() -> Unit)? = null) {
    val kind = if (item.kind == "machine") "Тренажёр" else "Инвентарь"
    val tint = if (item.kind == "machine") AstraTheme.green else AstraTheme.amber
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        WorkoutDetailHeader(kind, onBack)
        LazyColumn(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { WorkoutDetailHero(Icons.Default.FitnessCenter, tint) }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.name, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    Text(kind, color = AstraTheme.muted)
                }
            }
            item { Row { WorkoutDetailBadge(kind, tint) } }
            item { Text("Описание", fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp)) }
            item { WorkoutDetailRow(1, "Тип", kind) }
            item { WorkoutDetailRow(2, "Описание", item.description.displayOr("—")) }
            item { MobileWorkoutEntityActions(onEdit = onEdit, onDelete = onDelete, onShareTrainer = onShareTrainer, onShareClient = onShareClient) }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
fun MobileWorkoutsScreen(state: AstraState) {
    var section by rememberSaveable { mutableStateOf(0) }; var plans by remember { mutableStateOf<List<WorkoutPlan>>(emptyList()) }; var logs by remember { mutableStateOf<List<WorkoutEntry>>(emptyList()) }; var exercises by remember { mutableStateOf<List<Exercise>>(emptyList()) }; var complexes by remember { mutableStateOf<List<WorkoutComplex>>(emptyList()) }; var equipment by remember { mutableStateOf<List<WorkoutEquipment>>(emptyList()) }; var showAdd by remember { mutableStateOf(false) }; var selectedWorkout by remember { mutableStateOf<WorkoutEntry?>(null) }
    suspend fun load() { plans = suspendResult { state.api.plans() }.getOrDefault(emptyList()); logs = suspendResult { state.api.workouts() }.getOrDefault(emptyList()); exercises = suspendResult { state.api.exercises() }.getOrDefault(emptyList()); complexes = suspendResult { state.api.workoutComplexes() }.getOrDefault(emptyList()); equipment = suspendResult { state.api.workoutEquipment() }.getOrDefault(emptyList()) }
    LaunchedEffect(Unit) { load() }
    if (selectedWorkout != null) {
        TrainerWorkoutDetailScreen(selectedWorkout!!, onBack = { selectedWorkout = null })
        return
    }
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.padding(16.dp)) { Text("Тренировки", fontSize = 28.sp, fontWeight = FontWeight.Bold); Text("Планы, журнал, упражнения и инвентарь", color = AstraTheme.muted) }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf("Журнал", "Упражнения", "Комплексы", "Инвентарь").forEachIndexed { index, title -> if (section == index) OutlinedButton({ section = index }, colors = ButtonDefaults.outlinedButtonColors(containerColor = AstraTheme.blue.copy(alpha = .12f), contentColor = AstraTheme.blue)) { Text(title) } else OutlinedButton({ section = index }) { Text(title) } } }
        if (section == 0) Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.End) { Button({ showAdd = true }) { Text("Записать") } }
        when (section) {
            0 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { if (plans.isNotEmpty()) item { Text("Планы", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; items(plans, key = { "p${it.id}" }) { plan -> MobileCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(plan.displayName, fontWeight = FontWeight.Bold); Text(plan.scheduledAt, color = AstraTheme.muted, fontSize = 12.sp); Text("${plan.items.size} упражнений · ${plan.status}", color = AstraTheme.muted, fontSize = 12.sp) }; if (plan.status == "planned") TextButton({ kotlinx.coroutines.MainScope().launch { state.api.completePlan(plan.id); load() } }) { Text("Готово") } } } }; item { Text("Журнал", fontSize = 18.sp, fontWeight = FontWeight.Bold) }; items(logs, key = { "l${it.id}" }) { log -> MobileCard(Modifier.clickable { selectedWorkout = log }) { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(log.name, fontWeight = FontWeight.Bold); Text("${log.date} · ${log.sets.shown(" подходов")} × ${log.reps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) }; Text("›", fontSize = 22.sp, color = AstraTheme.muted) } } } }
            1 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(exercises, key = { it.id }) { exercise -> MobileCard { Column(Modifier.padding(14.dp)) { Text(exercise.name, fontWeight = FontWeight.Bold); Text("${exercise.muscleGroup ?: "Другое"} · ${exercise.defaultSets.shown(" подхода")} × ${exercise.defaultReps.shown(" повторений")}", color = AstraTheme.muted, fontSize = 12.sp) } } } }
            2 -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(complexes, key = { it.id }) { complex -> MobileCard { Column(Modifier.padding(14.dp)) { Text(complex.name, fontWeight = FontWeight.Bold); Text("${complex.items.size} упражнений", color = AstraTheme.muted, fontSize = 12.sp); complex.comment.displayOrNull()?.let { Text(it, fontSize = 12.sp) } } } } }
            else -> LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { items(equipment, key = { it.id }) { item -> MobileCard { Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.FitnessCenter, null, tint = AstraTheme.green); Spacer(Modifier.width(10.dp)); Column { Text(item.name, fontWeight = FontWeight.Bold); Text(if (item.kind == "machine") "Тренажёр" else "Инвентарь", color = AstraTheme.muted, fontSize = 12.sp); item.description.displayOrNull()?.let { Text(it, fontSize = 12.sp) } } } } } }
        }
    }
    if (showAdd) MobileAddWorkoutDialog(exercises, { date, exercise, weight, sets, reps, rir -> kotlinx.coroutines.MainScope().launch { state.api.addWorkout(date, exercise.id, weight, sets, reps, rir); load(); showAdd = false } }, { showAdd = false })
}

@Composable
private fun TrainerPlanDetailScreen(plan: WorkoutPlan, onBack: () -> Unit, onEdit: (() -> Unit)? = null, onRepeat: () -> Unit = {}, onCancel: (() -> Unit)? = null, onDelete: (() -> Unit)? = null, onComplete: (() -> Unit)? = null) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
            Text("План тренировки", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(plan.displayName, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        Text(plan.scheduledAt, color = AstraTheme.muted)
                        Text(if (plan.isHistory) plan.historyStatus else plan.status, color = AstraTheme.muted)
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            if (plan.status == "planned") {
                                onComplete?.let { TextButton(onClick = it) { Text("Выполнено") } }
                                onEdit?.let { TextButton(onClick = it) { Text("Изменить") } }
                                onCancel?.let { TextButton(onClick = it) { Text("Отменить") } }
                            } else {
                                TextButton(onClick = onRepeat) { Text("Повторить") }
                                if (plan.status == "canceled") onDelete?.let { TextButton(onClick = it) { Text("Удалить", color = MaterialTheme.colorScheme.error) } }
                            }
                        }
                    }
                }
            }
            item { Text("Упражнения", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            items(plan.items) { item ->
                MobileCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(item.name.displayOr("Упражнение"), fontWeight = FontWeight.Bold)
                        Text("${item.sets.shown(" подхода")} · ${item.duration.shown(" мин")}", color = AstraTheme.muted, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun TrainerComplexDetailScreen(
    complex: WorkoutComplex,
    onBack: () -> Unit,
    onEdit: (() -> Unit)? = null,
    onSchedule: () -> Unit = {},
    onDelete: (() -> Unit)? = null,
    onShareTrainer: (() -> Unit)? = null,
    onShareClient: (() -> Unit)? = null
) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
            Text("Комплекс", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(complex.name, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        complex.comment.displayOrNull()?.let { Text(it, color = AstraTheme.muted) }
                        Text("${complex.items.size} упражнений", color = AstraTheme.blue, fontSize = 12.sp)
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            onEdit?.let { TextButton(onClick = it) { Text("Изменить") } }
                            TextButton(onClick = onSchedule) { Text("Запланировать") }
                            onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }
                        }
                        MobileWorkoutEntityActions(onShareTrainer = onShareTrainer, onShareClient = onShareClient)
                    }
                }
            }
            item { Text("Упражнения", fontSize = 18.sp, fontWeight = FontWeight.Bold) }
            if (complex.items.isEmpty()) {
                item { Text("В комплексе пока нет упражнений.", color = AstraTheme.muted) }
            } else {
                items(complex.items, key = { "complex-item-${it.id}" }) { item ->
                    MobileCard {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(item.name.displayOr("Упражнение"), fontWeight = FontWeight.Bold)
                            Text("${item.sets.shown(" подхода")} · ${item.durationMinutes.shown(" мин")}", color = AstraTheme.muted, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TrainerWorkoutDetailScreen(workout: WorkoutEntry, onBack: () -> Unit, onEdit: () -> Unit = {}, onRepeat: () -> Unit = {}, onDelete: () -> Unit = {}) {
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, contentDescription = "Назад") }
            Text("Тренировка", fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        LazyColumn(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(workout.name, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        Text(workout.date, color = AstraTheme.muted)
                        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) { TextButton(onClick = onEdit) { Text("Изменить") }; TextButton(onClick = onRepeat) { Text("Повторить") }; TextButton(onClick = onDelete) { Text("Удалить") } }
                    }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Box(Modifier.weight(1f)) { MobileMetric("Подходы", workout.sets.shown(), AstraTheme.blue) {} }
                    Box(Modifier.weight(1f)) { MobileMetric("Повторения", workout.reps.shown(), AstraTheme.green) {} }
                }
            }
            item {
                MobileCard {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Нагрузка", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Text("Вес: ${workout.weight.shown(" кг")}")
                        workout.comment.displayOrNull()?.let { Text(it, color = AstraTheme.muted) }
                    }
                }
            }
        }
    }
}

@Composable
private fun MobileAddWorkoutDialog(exercises: List<Exercise>, onSave: (String, Exercise, Double?, Double?, Double?, String?) -> Unit, onDismiss: () -> Unit) {
    var date by remember { mutableStateOf(todayTime()) }; var exercise by remember { mutableStateOf(exercises.firstOrNull()) }; var weight by remember { mutableStateOf("") }; var sets by remember { mutableStateOf("") }; var reps by remember { mutableStateOf("") }; var rir by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Записать тренировку") }, text = { Column(verticalArrangement = Arrangement.spacedBy(7.dp)) { Picker("Упражнение: ${exercise?.name ?: "—"}", exercises.map { it.name }) { exercise = exercises.firstOrNull { item -> item.name == it } }; OutlinedTextField(date, { date = it }, label = { Text("Дата и время") }, singleLine = true); OutlinedTextField(weight, { weight = it }, label = { Text("Вес") }, singleLine = true); OutlinedTextField(sets, { sets = it }, label = { Text("Подходы") }, singleLine = true); OutlinedTextField(reps, { reps = it }, label = { Text("Повторения") }, singleLine = true); OutlinedTextField(rir, { rir = it }, label = { Text("RIR") }, singleLine = true) } }, confirmButton = { Button({ exercise?.let { onSave(date, it, weight.toNumber(), sets.toNumber(), reps.toNumber(), rir.takeIf { it.isNotBlank() }) } }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}
