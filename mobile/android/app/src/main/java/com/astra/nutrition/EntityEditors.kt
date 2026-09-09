package com.astra.nutrition

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

private fun JSONObject.putOptional(key: String, value: Any?): JSONObject = put(key, value ?: JSONObject.NULL)
private fun String.numberOrNull(): Double? = replace(',', '.').toDoubleOrNull()

@Composable
fun ShareToClientDialog(clients: List<ClientSummary>, onShare: (Int) -> Unit, onDismiss: () -> Unit) {
    var selected by remember { mutableStateOf(clients.firstOrNull()) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Отправить клиенту") }, text = {
        if (clients.isEmpty()) Text("Список клиентов пока пуст")
        else Picker("Клиент: ${selected?.name ?: "—"}", clients.map { it.name }) { name -> selected = clients.firstOrNull { it.name == name } }
    }, confirmButton = { Button({ selected?.let { onShare(it.id) } }) { Text("Отправить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
fun WorkoutEntityManageDialog(exercises: List<Exercise>, equipment: List<WorkoutEquipment>, complexes: List<WorkoutComplex>, onEditExercise: (Exercise) -> Unit, onDeleteExercise: (Exercise) -> Unit, onEditEquipment: (WorkoutEquipment) -> Unit, onDeleteEquipment: (WorkoutEquipment) -> Unit, onEditComplex: (WorkoutComplex) -> Unit, onScheduleComplex: (WorkoutComplex) -> Unit, onShare: (String, Int) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Управление тренировочными сущностями") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Упражнения", fontWeight = FontWeight.Bold)
        exercises.forEach { item -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) { Text(item.name, Modifier.weight(1f)); TextButton({ onEditExercise(item) }) { Text("изменить") }; TextButton({ onDeleteExercise(item) }) { Text("удалить") }; TextButton({ onShare("exercise", item.id) }) { Text("отправить") } } }
        Text("Тренажёры и инвентарь", fontWeight = FontWeight.Bold)
        equipment.forEach { item -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) { Text(item.name, Modifier.weight(1f)); TextButton({ onEditEquipment(item) }) { Text("изменить") }; TextButton({ onDeleteEquipment(item) }) { Text("удалить") }; TextButton({ onShare("workout_equipment", item.id) }) { Text("отправить") } } }
        Text("Комплексы тренировок", fontWeight = FontWeight.Bold)
        complexes.forEach { item -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) { Text(item.name, Modifier.weight(1f)); TextButton({ onEditComplex(item) }) { Text("изменить") }; TextButton({ onScheduleComplex(item) }) { Text("в план") }; TextButton({ onShare("workout_complex", item.id) }) { Text("отправить") } } }
    } }, confirmButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

@Composable
fun CatalogEntityManageDialog(products: List<Product>, recipes: List<Recipe>, onEditProduct: (Product) -> Unit, onDeleteProduct: (Product) -> Unit, onEditRecipe: (Recipe) -> Unit, onDeleteRecipe: (Recipe) -> Unit, onShare: (String, Int) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Управление каталогом") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Продукты", fontWeight = FontWeight.Bold)
        products.forEach { item -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) { Text(item.name, Modifier.weight(1f)); TextButton({ onEditProduct(item) }) { Text("изменить") }; TextButton({ onDeleteProduct(item) }) { Text("удалить") }; TextButton({ onShare("product", item.id) }) { Text("отправить") } } }
        Text("Блюда", fontWeight = FontWeight.Bold)
        recipes.forEach { item -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) { Text(item.name, Modifier.weight(1f)); TextButton({ onEditRecipe(item) }) { Text("изменить") }; TextButton({ onDeleteRecipe(item) }) { Text("удалить") }; TextButton({ onShare("recipe", item.id) }) { Text("отправить") } } }
    } }, confirmButton = { TextButton(onDismiss) { Text("Закрыть") } })
}

@Composable
fun ProductEditorDialog(existing: Product?, onSave: (JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }
    var category by remember { mutableStateOf(existing?.category.orEmpty()) }
    var unit by remember { mutableStateOf(existing?.unit ?: "г") }
    var packagePrice by remember { mutableStateOf(existing?.packagePrice?.toString().orEmpty()) }
    var packageSize by remember { mutableStateOf(existing?.packageSize?.toString().orEmpty()) }
    var pricePer100 by remember { mutableStateOf(existing?.pricePer100?.toString().orEmpty()) }
    var kcal by remember { mutableStateOf(existing?.kcal?.toString().orEmpty()) }
    var protein by remember { mutableStateOf(existing?.protein?.toString() ?: "0") }
    var fat by remember { mutableStateOf(existing?.fat?.toString() ?: "0") }
    var carbs by remember { mutableStateOf(existing?.carbs?.toString() ?: "0") }
    var dataStatus by remember { mutableStateOf(existing?.dataStatus ?: "Подтверждено") }
    var note by remember { mutableStateOf(existing?.note.orEmpty()) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новый продукт" else "Редактировать продукт") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            EditField("Название", name) { name = it }
            EditField("Категория", category) { category = it }
            EditField("Единица", unit) { unit = it }
            EditField("Цена упаковки, RSD", packagePrice) { packagePrice = it }
            EditField("Размер упаковки", packageSize) { packageSize = it }
            EditField("Цена за 100 г / единицу, RSD", pricePer100) { pricePer100 = it }
            EditField("Ккал", kcal) { kcal = it }
            EditField("Белки, г", protein) { protein = it }
            EditField("Жиры, г", fat) { fat = it }
            EditField("Углеводы, г", carbs) { carbs = it }
            EditField("Статус данных", dataStatus) { dataStatus = it }
            EditField("Примечание", note) { note = it }
        }
    }, confirmButton = {
        Button({
            if (name.isNotBlank()) onSave(JSONObject().put("name", name).putOptional("category", category.takeIf { it.isNotBlank() }).put("unit", unit).putOptional("package_price_rsd", packagePrice.numberOrNull()).putOptional("package_size", packageSize.numberOrNull()).putOptional("price_per_100_or_unit_rsd", pricePer100.numberOrNull()).putOptional("kcal", kcal.numberOrNull()).put("protein_g", protein.numberOrNull() ?: 0).put("fat_g", fat.numberOrNull() ?: 0).put("carbs_g", carbs.numberOrNull() ?: 0).put("data_status", dataStatus).putOptional("note", note.takeIf { it.isNotBlank() }))
        }) { Text("Сохранить") }
    }, dismissButton = {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }; TextButton(onClick = onDismiss) { Text("Отмена") } }
    })
}

private data class IngredientDraft(var productId: Int?, var quantity: String = "", var unit: String = "г", var measurementName: String = "", var measurementQuantity: String = "", var portionDescription: String = "")

@Composable
fun RecipeEditorDialog(existing: Recipe?, products: List<Product>, onSave: (JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var category by remember { mutableStateOf(existing?.category.orEmpty()) }
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }
    var subcategory by remember { mutableStateOf(existing?.subcategory.orEmpty()) }
    var version by remember { mutableStateOf(existing?.version ?: "1.0") }
    var servings by remember { mutableStateOf(existing?.servings?.toString() ?: "1") }
    var tags by remember { mutableStateOf(existing?.tags.orEmpty()) }
    var isReady by remember { mutableStateOf(existing?.isReady ?: false) }
    var needsGarnish by remember { mutableStateOf(existing?.needsGarnish ?: false) }
    var price by remember { mutableStateOf(existing?.cost?.toString().orEmpty()) }
    var kcal by remember { mutableStateOf(existing?.kcal?.toString().orEmpty()) }
    var protein by remember { mutableStateOf(existing?.protein?.toString().orEmpty()) }
    var fat by remember { mutableStateOf(existing?.fat?.toString().orEmpty()) }
    var carbs by remember { mutableStateOf(existing?.carbs?.toString().orEmpty()) }
    val ingredients = remember { mutableStateListOf(IngredientDraft(products.firstOrNull()?.id)) }
    fun updateIngredient(index: Int, update: (IngredientDraft) -> Unit) { val item = ingredients[index].copy(); update(item); ingredients[index] = item }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новое блюдо" else "Редактировать блюдо") }, text = {
        Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            EditField("Категория", category) { category = it }; EditField("Название", name) { name = it }; EditField("Подкатегория", subcategory) { subcategory = it }; EditField("Версия", version) { version = it }; EditField("Порций", servings) { servings = it }; EditField("Теги", tags) { tags = it }
            TextButton({ isReady = !isReady }) { Text(if (isReady) "✓ Готово" else "Отметить как готовое") }
            TextButton({ needsGarnish = !needsGarnish }) { Text(if (needsGarnish) "✓ Нужен гарнир" else "Добавить гарнир") }
            EditField("Цена за порцию, RSD", price) { price = it }; EditField("Ккал на порцию", kcal) { kcal = it }; EditField("Белки на порцию, г", protein) { protein = it }; EditField("Жиры на порцию, г", fat) { fat = it }; EditField("Углеводы на порцию, г", carbs) { carbs = it }
            Text("Ингредиенты", fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
            ingredients.forEachIndexed { index, ingredient ->
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    if (products.isNotEmpty()) Picker("Продукт: ${products.firstOrNull { it.id == ingredient.productId }?.name ?: "—"}", products.map { it.name }) { selected -> updateIngredient(index) { it.productId = products.firstOrNull { p -> p.name == selected }?.id } }
                    EditField("Количество", ingredient.quantity) { value -> updateIngredient(index) { it.quantity = value } }; EditField("Единица", ingredient.unit) { value -> updateIngredient(index) { it.unit = value } }; EditField("Название меры", ingredient.measurementName) { value -> updateIngredient(index) { it.measurementName = value } }; EditField("Количество меры", ingredient.measurementQuantity) { value -> updateIngredient(index) { it.measurementQuantity = value } }; EditField("Описание порции", ingredient.portionDescription) { value -> updateIngredient(index) { it.portionDescription = value } }
                    if (ingredients.size > 1) TextButton({ ingredients.removeAt(index) }) { Text("Удалить ингредиент") }
                }
            }
            TextButton({ ingredients.add(IngredientDraft(products.firstOrNull()?.id)) }) { Text("+ Добавить ингредиент") }
        }
    }, confirmButton = {
        Button({
            val ingredientArray = JSONArray(); ingredients.filter { it.productId != null }.forEach { item -> ingredientArray.put(JSONObject().put("product_id", item.productId).putOptional("quantity", item.quantity.numberOrNull()).putOptional("unit", item.unit.takeIf { it.isNotBlank() }).putOptional("measurement_name", item.measurementName.takeIf { it.isNotBlank() }).putOptional("measurement_quantity", item.measurementQuantity.numberOrNull()).putOptional("portion_description", item.portionDescription.takeIf { it.isNotBlank() })) }
            if (name.isNotBlank() && category.isNotBlank()) onSave(JSONObject().put("category", category).put("name", name).putOptional("subcategory", subcategory.takeIf { it.isNotBlank() }).put("version", version).put("servings", servings.numberOrNull() ?: 1).putOptional("tags", tags.takeIf { it.isNotBlank() }).put("is_ready", isReady).put("needs_garnish", needsGarnish).putOptional("manual_price_per_serving_rsd", price.numberOrNull()).putOptional("manual_kcal_per_serving", kcal.numberOrNull()).putOptional("manual_protein_per_serving_g", protein.numberOrNull()).putOptional("manual_fat_per_serving_g", fat.numberOrNull()).putOptional("manual_carbs_per_serving_g", carbs.numberOrNull()).put("ingredients", ingredientArray))
        }) { Text("Сохранить") }
    }, dismissButton = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }; TextButton(onClick = onDismiss) { Text("Отмена") } } })
}

private data class VariantDraft(var machine: String = "", var equipment: String = "", var description: String = "", var technique: String = "", var tips: String = "", var name: String = "")

@Composable
fun ExerciseEditorDialog(existing: Exercise?, onSave: (JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }; var muscle by remember { mutableStateOf(existing?.muscleGroup.orEmpty()) }; var unit by remember { mutableStateOf(existing?.unit ?: "кг") }; var sets by remember { mutableStateOf(existing?.defaultSets?.toString() ?: "3") }; var reps by remember { mutableStateOf(existing?.defaultReps?.toString() ?: "12") }; var rir by remember { mutableStateOf(existing?.targetRir ?: "0–2") }; var note by remember { mutableStateOf(existing?.note.orEmpty()) }; var description by remember { mutableStateOf(existing?.description.orEmpty()) }; var photos by remember { mutableStateOf(existing?.photos?.joinToString(", ").orEmpty()) }; var video by remember { mutableStateOf(existing?.video.orEmpty()) }
    val variants = remember { mutableStateListOf<VariantDraft>().also { list -> existing?.variants?.forEach { list.add(VariantDraft(it.machine.orEmpty(), it.equipment.orEmpty(), it.description.orEmpty(), it.technique.orEmpty(), it.tips.orEmpty(), it.name.orEmpty())) } } }
    fun updateVariant(index: Int, update: (VariantDraft) -> Unit) { val item = variants[index].copy(); update(item); variants[index] = item }
    val variant = variants.firstOrNull() ?: VariantDraft()
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новое упражнение" else "Редактировать упражнение") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) {
        EditField("Название", name) { name = it }; EditField("Мышечная группа", muscle) { muscle = it }; EditField("Единица", unit) { unit = it }; EditField("Подходы по умолчанию", sets) { sets = it }; EditField("Повторения по умолчанию", reps) { reps = it }; EditField("Целевой RIR", rir) { rir = it }; EditField("Заметка", note) { note = it }; EditField("Описание", description) { description = it }; EditField("Фото (URL через запятую)", photos) { photos = it }; EditField("Видео (URL)", video) { video = it }
        Text("Варианты выполнения", fontWeight = FontWeight.Bold)
        variants.forEachIndexed { index, variant -> Column(verticalArrangement = Arrangement.spacedBy(5.dp)) { EditField("Название варианта", variant.name) { value -> updateVariant(index) { draft -> draft.name = value } }; EditField("Тренажёр", variant.machine) { value -> updateVariant(index) { draft -> draft.machine = value } }; EditField("Инвентарь", variant.equipment) { value -> updateVariant(index) { draft -> draft.equipment = value } }; EditField("Описание варианта", variant.description) { value -> updateVariant(index) { draft -> draft.description = value } }; EditField("Техника", variant.technique) { value -> updateVariant(index) { draft -> draft.technique = value } }; EditField("Советы", variant.tips) { value -> updateVariant(index) { draft -> draft.tips = value } }; TextButton({ variants.removeAt(index) }) { Text("Удалить вариант") } } }
        TextButton({ variants.add(VariantDraft()) }) { Text("+ Добавить вариант") }
    } }, confirmButton = { Button({ val variantArray = JSONArray(); variants.forEach { variantArray.put(JSONObject().putOptional("name", variant.name.takeIf { it.isNotBlank() }).putOptional("machine", variant.machine.takeIf { it.isNotBlank() }).putOptional("equipment", variant.equipment.takeIf { it.isNotBlank() }).putOptional("description", variant.description.takeIf { it.isNotBlank() }).putOptional("technique", variant.technique.takeIf { it.isNotBlank() }).putOptional("tips", variant.tips.takeIf { it.isNotBlank() })) }; if (name.isNotBlank()) onSave(JSONObject().put("name", name).putOptional("muscle_group", muscle.takeIf { it.isNotBlank() }).put("default_unit", unit).put("default_sets", sets.numberOrNull() ?: 3).put("default_reps", reps.numberOrNull() ?: 12).putOptional("target_rir", rir.takeIf { it.isNotBlank() }).putOptional("note", note.takeIf { it.isNotBlank() }).putOptional("description", description.takeIf { it.isNotBlank() }).put("photos", JSONArray(photos.split(',').map { it.trim() }.filter { it.isNotBlank() })).putOptional("video", video.takeIf { it.isNotBlank() }).put("variants", variantArray)) }) { Text("Сохранить") } }, dismissButton = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }; TextButton(onClick = onDismiss) { Text("Отмена") } } })
}

@Composable
fun EquipmentEditorDialog(existing: WorkoutEquipment?, onSave: (JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var kind by remember { mutableStateOf(existing?.kind ?: "equipment") }; var name by remember { mutableStateOf(existing?.name.orEmpty()) }; var description by remember { mutableStateOf(existing?.description.orEmpty()) }; var photo by remember { mutableStateOf(existing?.photo.orEmpty()) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новый тренажёр / инвентарь" else "Редактировать оборудование") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { Picker("Тип: ${if (kind == "machine") "Тренажёр" else "Инвентарь"}", listOf("Тренажёр", "Инвентарь")) { kind = if (it == "Тренажёр") "machine" else "equipment" }; EditField("Название", name) { name = it }; EditField("Описание", description) { description = it }; EditField("Фото (URL)", photo) { photo = it } } }, confirmButton = { Button({ if (name.isNotBlank()) onSave(JSONObject().put("kind", kind).put("name", name).putOptional("description", description.takeIf { it.isNotBlank() }).putOptional("photo", photo.takeIf { it.isNotBlank() })) }) { Text("Сохранить") } }, dismissButton = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }; TextButton(onClick = onDismiss) { Text("Отмена") } } })
}

private data class PlanDraft(var exerciseId: Int?, var weight: String = "", var sets: String = "", var duration: String = "", var speed: String = "")

@Composable
fun WorkoutPlanEditorDialog(plan: WorkoutPlan?, complex: WorkoutComplex?, exercises: List<Exercise>, onSave: (JSONObject) -> Unit, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(plan?.name.orEmpty()) }; var scheduledAt by remember { mutableStateOf(plan?.scheduledAt ?: todayTime()) }; var duration by remember { mutableStateOf(plan?.duration?.toString().orEmpty()) }
    val sourceItems: List<WorkoutPlanItem> = plan?.items ?: complex?.items?.map { WorkoutPlanItem(it.id, it.exerciseId, it.name, it.muscleGroup, it.workingWeight, it.sets, it.durationMinutes, it.speedKmh) } ?: emptyList()
    val items = remember { mutableStateListOf<PlanDraft>().also { list -> sourceItems.forEach { item -> list.add(PlanDraft(item.exerciseId, item.weight?.toString().orEmpty(), item.sets?.toString().orEmpty(), item.duration?.toString().orEmpty(), item.speed?.toString().orEmpty())) }; if (list.isEmpty()) list.add(PlanDraft(exercises.firstOrNull()?.id)) } }
    fun updateItem(index: Int, update: (PlanDraft) -> Unit) { val item = items[index].copy(); update(item); items[index] = item }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (plan == null) "Включить тренировку в план" else "Редактировать план") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { EditField("Название тренировки", name) { name = it }; EditField("Дата и время", scheduledAt) { scheduledAt = it }; EditField("Длительность, мин", duration) { duration = it }; Text("Упражнения", fontWeight = FontWeight.Bold); items.forEachIndexed { index, item -> Column(verticalArrangement = Arrangement.spacedBy(5.dp)) { if (exercises.isNotEmpty()) Picker("Упражнение: ${exercises.firstOrNull { it.id == item.exerciseId }?.name ?: "—"}", exercises.map { it.name }) { selected -> updateItem(index) { draft -> draft.exerciseId = exercises.firstOrNull { exercise -> exercise.name == selected }?.id } }; EditField("Вес", item.weight) { value -> updateItem(index) { draft -> draft.weight = value } }; EditField("Подходы", item.sets) { value -> updateItem(index) { draft -> draft.sets = value } }; EditField("Длительность, мин", item.duration) { value -> updateItem(index) { draft -> draft.duration = value } }; EditField("Скорость, км/ч", item.speed) { value -> updateItem(index) { draft -> draft.speed = value } }; if (items.size > 1) TextButton({ items.removeAt(index) }) { Text("Удалить упражнение") } } }; TextButton({ items.add(PlanDraft(exercises.firstOrNull()?.id)) }) { Text("+ Добавить упражнение") } } }, confirmButton = { Button({ val array = JSONArray(); items.filter { it.exerciseId != null }.forEach { item -> array.put(JSONObject().put("exercise_id", item.exerciseId).putOptional("working_weight", item.weight.numberOrNull()).putOptional("sets", item.sets.numberOrNull()).putOptional("duration_minutes", item.duration.numberOrNull()).putOptional("speed_kmh", item.speed.numberOrNull())) }; if (scheduledAt.isNotBlank()) onSave(JSONObject().putOptional("name", name.takeIf { it.isNotBlank() }).put("scheduled_at", scheduledAt).putOptional("duration_minutes", duration.numberOrNull()).put("items", array)) }) { Text("Сохранить план") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
fun WorkoutComplexEditorDialog(existing: WorkoutComplex?, exercises: List<Exercise>, onSave: (JSONObject) -> Unit, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }; var comment by remember { mutableStateOf(existing?.comment.orEmpty()) }; var photos by remember { mutableStateOf(existing?.photos?.joinToString(", ").orEmpty()) }; var video by remember { mutableStateOf(existing?.video.orEmpty()) }
    val items = remember { mutableStateListOf<PlanDraft>().also { list -> existing?.items?.forEach { item -> list.add(PlanDraft(item.exerciseId, item.workingWeight?.toString().orEmpty(), item.sets?.toString().orEmpty(), item.durationMinutes?.toString().orEmpty(), item.speedKmh?.toString().orEmpty())) }; if (list.isEmpty()) list.add(PlanDraft(exercises.firstOrNull()?.id)) } }
    fun updateItem(index: Int, update: (PlanDraft) -> Unit) { val item = items[index].copy(); update(item); items[index] = item }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Новый комплекс" else "Редактировать комплекс") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { EditField("Название", name) { name = it }; EditField("Комментарий", comment) { comment = it }; EditField("Фото (URL через запятую)", photos) { photos = it }; EditField("Видео (URL)", video) { video = it }; Text("Упражнения", fontWeight = FontWeight.Bold); items.forEachIndexed { index, item -> Column(verticalArrangement = Arrangement.spacedBy(5.dp)) { if (exercises.isNotEmpty()) Picker("Упражнение: ${exercises.firstOrNull { it.id == item.exerciseId }?.name ?: "—"}", exercises.map { it.name }) { selected -> updateItem(index) { draft -> draft.exerciseId = exercises.firstOrNull { exercise -> exercise.name == selected }?.id } }; EditField("Вес", item.weight) { value -> updateItem(index) { draft -> draft.weight = value } }; EditField("Подходы", item.sets) { value -> updateItem(index) { draft -> draft.sets = value } }; EditField("Длительность, мин", item.duration) { value -> updateItem(index) { draft -> draft.duration = value } }; EditField("Скорость, км/ч", item.speed) { value -> updateItem(index) { draft -> draft.speed = value } }; if (items.size > 1) TextButton({ items.removeAt(index) }) { Text("Удалить упражнение") } } }; TextButton({ items.add(PlanDraft(exercises.firstOrNull()?.id)) }) { Text("+ Добавить упражнение") } } }, confirmButton = { Button({ val array = JSONArray(); items.filter { it.exerciseId != null }.forEach { item -> array.put(JSONObject().put("exercise_id", item.exerciseId).putOptional("working_weight", item.weight.numberOrNull()).putOptional("sets", item.sets.numberOrNull()).putOptional("duration_minutes", item.duration.numberOrNull()).putOptional("speed_kmh", item.speed.numberOrNull())) }; if (name.isNotBlank()) onSave(JSONObject().put("name", name).putOptional("comment", comment.takeIf { it.isNotBlank() }).put("photos", JSONArray(photos.split(',').map { it.trim() }.filter { it.isNotBlank() })).putOptional("video", video.takeIf { it.isNotBlank() }).put("items", array)) }) { Text("Сохранить") } }, dismissButton = { TextButton(onDismiss) { Text("Отмена") } })
}

@Composable
fun WorkoutEntryEditorDialog(existing: WorkoutEntry?, exercises: List<Exercise>, onSave: (JSONObject) -> Unit, onDelete: (() -> Unit)?, onDismiss: () -> Unit) {
    var performedAt by remember { mutableStateOf(existing?.date ?: todayTime()) }; var exerciseId by remember { mutableStateOf(existing?.exerciseId ?: exercises.firstOrNull()?.id) }; var weight by remember { mutableStateOf(existing?.weight?.toString().orEmpty()) }; var sets by remember { mutableStateOf(existing?.sets?.toString().orEmpty()) }; var reps by remember { mutableStateOf(existing?.reps?.toString().orEmpty()) }; var rir by remember { mutableStateOf(existing?.rir.orEmpty()) }; var machine by remember { mutableStateOf("") }; var comment by remember { mutableStateOf(existing?.comment.orEmpty()) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (existing == null) "Записать тренировку" else "Редактировать тренировку") }, text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(7.dp)) { if (exercises.isNotEmpty()) Picker("Упражнение: ${exercises.firstOrNull { it.id == exerciseId }?.name ?: "—"}", exercises.map { it.name }) { selected -> exerciseId = exercises.firstOrNull { it.name == selected }?.id }; EditField("Дата и время", performedAt) { performedAt = it }; EditField("Вес", weight) { weight = it }; EditField("Подходы", sets) { sets = it }; EditField("Повторения", reps) { reps = it }; EditField("RIR", rir) { rir = it }; EditField("Место тренажёра", machine) { machine = it }; EditField("Комментарий", comment) { comment = it } } }, confirmButton = { Button({ if (exerciseId != null) onSave(JSONObject().put("performed_at", performedAt).put("exercise_id", exerciseId).putOptional("working_weight", weight.numberOrNull()).putOptional("sets", sets.numberOrNull()).putOptional("reps", reps.numberOrNull()).putOptional("rir", rir.takeIf { it.isNotBlank() }).putOptional("machine_location", machine.takeIf { it.isNotBlank() }).putOptional("comment", comment.takeIf { it.isNotBlank() })) }) { Text("Сохранить") } }, dismissButton = { Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) { onDelete?.let { TextButton(onClick = it) { Text("Удалить") } }; TextButton(onClick = onDismiss) { Text("Отмена") } } })
}

@Composable
fun EditField(label: String, value: String, onValueChange: (String) -> Unit) { OutlinedTextField(value, onValueChange, label = { Text(label) }, singleLine = false, modifier = Modifier.fillMaxWidth()) }
