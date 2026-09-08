package com.astra.nutrition

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class ApiClient(context: Context) {
    private val prefs = context.getSharedPreferences("astra", Context.MODE_PRIVATE)
    var baseUrl: String
        get() = prefs.getString("api_url", "http://10.0.2.2:8787/api/v1") ?: "http://10.0.2.2:8787/api/v1"
        set(value) { prefs.edit().putString("api_url", value.trim().trimEnd('/')).apply() }
    var token: String?
        get() = prefs.getString("access_token", null)
        set(value) { prefs.edit().apply { if (value == null) remove("access_token") else putString("access_token", value) }.apply() }

    private suspend fun request(path: String, method: String = "GET", body: JSONObject? = null): Any = withContext(Dispatchers.IO) {
        val connection = (URL("${baseUrl.trimEnd('/')}/$path").openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 30_000
            setRequestProperty("Accept", "application/json")
            token?.let { setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                outputStream.use { it.write(body.toString().toByteArray()) }
            }
        }
        try {
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val message = runCatching { JSONObject(text).optString("error") }.getOrNull().orEmpty()
                throw AstraException(message.ifBlank { "Ошибка запроса ($status)" })
            }
            if (text.isBlank()) JSONObject() else if (text.trimStart().startsWith("[")) JSONArray(text) else JSONObject(text)
        } finally { connection.disconnect() }
    }

    suspend fun login(email: String, password: String, register: Boolean = false): AuthResponse {
        val result = request("auth/${if (register) "register" else "login"}", "POST", JSONObject().put("email", email).put("password", password)) as JSONObject
        return AuthResponse(result.optString("access_token"), result.optJSONObject("user")!!.user())
    }
    suspend fun me(): AuthUser = (request("auth/me") as JSONObject).user()
    suspend fun logout() {
        try { request("auth/logout", "POST") } catch (_: Throwable) { /* JWT is cleared locally below. */ }
        token = null
    }
    suspend fun dashboard(): Dashboard { val o = request("dashboard") as JSONObject; return Dashboard(o.optInt("products"), o.optInt("recipes"), o.optInt("approved"), o.optJSONObject("latest")?.progress(), o.optJSONArray("top").recipes()) }
    suspend fun products(): List<Product> = (request("products") as JSONArray).products()
    suspend fun recipes(): List<Recipe> = (request("recipes") as JSONArray).recipes()
    suspend fun recipe(id: Int): RecipeDetail { val o = request("recipes/$id") as JSONObject; return RecipeDetail(o.optJSONObject("recipe")!!.recipe(), o.optJSONArray("ingredients").ingredients()) }
    suspend fun diary(): List<DiaryEntry> = (request("diary") as JSONArray).diary()
    suspend fun progress(): List<ProgressEntry> = (request("progress") as JSONArray).progresses()
    suspend fun workouts(): List<WorkoutEntry> = (request("workouts") as JSONArray).workouts()
    suspend fun plans(): List<WorkoutPlan> = (request("workout-plans") as JSONArray).plans()
    suspend fun exercises(): List<Exercise> = (request("exercises") as JSONArray).exercises()

    suspend fun addDiary(date: String, meal: String, productId: Int?, recipeId: Int?, amount: Double): List<DiaryEntry> {
        val item = JSONObject().put("meal_type", meal).put("servings", if (recipeId != null) amount else 1.0)
        if (productId != null) item.put("product_id", productId).put("quantity", amount) else item.put("recipe_id", recipeId)
        return (request("diary", "POST", JSONObject().put("entry_date", date).put("items", JSONArray().put(item))) as JSONArray).diary()
    }
    suspend fun deleteDiary(id: Int) { request("diary/$id", "DELETE") }
    suspend fun addProgress(date: String, weight: Double?, waist: Double?, wellbeing: Double?, comment: String?): ProgressEntry {
        val body = JSONObject().put("measured_at", date).putNullable("weight_kg", weight).putNullable("waist_cm", waist).putNullable("wellbeing_score", wellbeing).putNullable("comment", comment)
        return (request("progress", "POST", body) as JSONObject).progress()
    }
    suspend fun addWorkout(date: String, exerciseId: Int, weight: Double?, sets: Double?, reps: Double?, rir: String?): WorkoutEntry {
        val body = JSONObject().put("performed_at", date).put("exercise_id", exerciseId).putNullable("working_weight", weight).putNullable("sets", sets).putNullable("reps", reps).putNullable("rir", rir)
        return (request("workouts", "POST", body) as JSONObject).workout()
    }
    suspend fun completePlan(id: Int): WorkoutPlan = (request("workout-plans/$id/complete", "POST") as JSONObject).plan()
}

private fun JSONObject.putNullable(key: String, value: Any?): JSONObject = put(key, value ?: JSONObject.NULL)
private fun JSONObject.optDoubleOrNull(key: String): Double? = if (!has(key) || isNull(key)) null else optDouble(key)
private fun JSONObject.optTextOrNull(key: String): String? = optString(key).takeIf { it.isNotBlank() }
private fun JSONObject.user() = AuthUser(optInt("id"), optString("email"), optString("name"), optBoolean("is_admin"), optBoolean("is_trainer"))
private fun JSONObject.recipe() = Recipe(optInt("id"), optString("code"), optString("name"), optString("category"), optTextOrNull("status"), optDoubleOrNull("servings"), optDoubleOrNull("kcal_per_serving"), optDoubleOrNull("protein_per_serving_g"), optDoubleOrNull("fat_per_serving_g"), optDoubleOrNull("carbs_per_serving_g"), optDoubleOrNull("cost_per_serving_rsd"))
private fun JSONObject.product() = Product(optInt("id"), optString("code"), optString("name"), optTextOrNull("category"), optTextOrNull("unit"), optDoubleOrNull("kcal"), optDoubleOrNull("protein_g"), optDoubleOrNull("fat_g"), optDoubleOrNull("carbs_g"))
private fun JSONObject.ingredient() = Ingredient(optInt("id"), optInt("product_id"), optString("name"), optDoubleOrNull("quantity"), optTextOrNull("unit"))
private fun JSONObject.diary() = DiaryEntry(optInt("id"), optString("entry_date"), optTextOrNull("meal_type"), optInt("recipe_id").takeIf { it > 0 }, optInt("product_id").takeIf { it > 0 }, optDoubleOrNull("servings"), optDoubleOrNull("quantity"), optTextOrNull("unit"), optTextOrNull("name"), optString("item_type"), optDoubleOrNull("kcal_per_serving"), optDoubleOrNull("protein_per_serving_g"), optDoubleOrNull("fat_per_serving_g"), optDoubleOrNull("carbs_per_serving_g"))
private fun JSONObject.progress() = ProgressEntry(optInt("id"), optString("measured_at"), optDoubleOrNull("weight_kg"), optDoubleOrNull("desired_weight_kg"), optDoubleOrNull("height_cm"), optDoubleOrNull("bmi"), optDoubleOrNull("body_fat_pct"), optDoubleOrNull("muscle_mass_kg"), optDoubleOrNull("kcal_target"), optDoubleOrNull("protein_target_g"), optDoubleOrNull("fat_target_g"), optDoubleOrNull("carbs_target_g"), optDoubleOrNull("waist_cm"), optDoubleOrNull("chest_cm"), optDoubleOrNull("hips_cm"), optDoubleOrNull("sleep_score"), optDoubleOrNull("wellbeing_score"), optTextOrNull("comment"))
private fun JSONObject.planItem() = WorkoutPlanItem(if (has("id") && !isNull("id")) optInt("id") else null, optInt("exercise_id"), optTextOrNull("name"), optTextOrNull("muscle_group"), optDoubleOrNull("working_weight"), optDoubleOrNull("sets"), optDoubleOrNull("duration_minutes"), optDoubleOrNull("speed_kmh"))
private fun JSONObject.plan() = WorkoutPlan(optInt("id"), optString("scheduled_at"), optDoubleOrNull("duration_minutes"), optString("status"), optTextOrNull("completed_at"), optJSONArray("items").planItems())
private fun JSONObject.workout() = WorkoutEntry(optInt("id"), optString("performed_at"), optInt("exercise_id"), optString("name"), optTextOrNull("muscle_group"), optDoubleOrNull("working_weight"), optDoubleOrNull("sets"), optDoubleOrNull("reps"), optTextOrNull("rir"), optTextOrNull("comment"))
private fun JSONObject.exercise() = Exercise(optInt("id"), optString("name"), optTextOrNull("muscle_group"), optTextOrNull("default_unit"), optDoubleOrNull("default_sets"), optDoubleOrNull("default_reps"))
private fun JSONArray?.recipes() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.recipe() }
private fun JSONArray?.products() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.product() }
private fun JSONArray?.ingredients() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.ingredient() }
private fun JSONArray?.diary() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.diary() }
private fun JSONArray?.progresses() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.progress() }
private fun JSONArray?.plans() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.plan() }
private fun JSONArray?.planItems() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.planItem() }
private fun JSONArray?.workouts() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.workout() }
private fun JSONArray?.exercises() = (0 until (this?.length() ?: 0)).mapNotNull { this?.optJSONObject(it)?.exercise() }
