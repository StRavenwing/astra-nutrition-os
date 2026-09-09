package com.astra.nutrition

data class AuthUser(val id: Int, val email: String, val name: String, val isAdmin: Boolean, val isTrainer: Boolean)
data class AuthResponse(val token: String, val user: AuthUser)
data class Dashboard(val products: Int, val recipes: Int, val approved: Int, val latest: ProgressEntry?, val top: List<Recipe>)
data class Product(val id: Int, val code: String, val name: String, val category: String?, val unit: String?, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?, val packagePrice: Double? = null, val packageSize: Double? = null, val pricePer100: Double? = null, val dataStatus: String? = null, val note: String? = null)
data class Recipe(val id: Int, val code: String, val name: String, val category: String, val status: String?, val servings: Double?, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?, val cost: Double?, val subcategory: String? = null, val version: String? = null, val tags: String? = null, val isReady: Boolean = false, val needsGarnish: Boolean = false, val collection: String? = null, val ownerId: Int? = null, val submissionRequested: Boolean = false, val moderationStatus: String? = null, val moderationNote: String? = null, val isSubmitter: Boolean = false)
data class Ingredient(val id: Int, val productId: Int, val name: String, val quantity: Double?, val unit: String?, val portionDescription: String? = null, val kcal: Double? = null, val protein: Double? = null, val fat: Double? = null, val carbs: Double? = null, val cost: Double? = null)
data class RecipeDetail(val recipe: Recipe, val ingredients: List<Ingredient>)
data class DiaryEntry(val id: Int, val date: String, val meal: String?, val recipeId: Int?, val productId: Int?, val servings: Double?, val quantity: Double?, val unit: String?, val measurementName: String? = null, val measurementQuantity: Double? = null, val comment: String? = null, val name: String?, val itemType: String, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?, val cost: Double? = null)
data class ProgressEntry(val id: Int, val date: String, val weight: Double?, val desiredWeight: Double?, val height: Double?, val bmi: Double?, val bodyFat: Double?, val muscleMass: Double?, val kcalTarget: Double?, val proteinTarget: Double?, val fatTarget: Double?, val carbsTarget: Double?, val waist: Double?, val chest: Double?, val hips: Double?, val sleep: Double?, val wellbeing: Double?, val comment: String?)
data class WorkoutPlanItem(val id: Int?, val exerciseId: Int, val name: String?, val muscleGroup: String?, val weight: Double?, val sets: Double?, val duration: Double?, val speed: Double?)
data class WorkoutPlan(val id: Int, val scheduledAt: String, val duration: Double?, val status: String, val completedAt: String?, val items: List<WorkoutPlanItem>, val name: String? = null)
val WorkoutPlan.displayName: String get() = name?.trim()?.takeIf { it.isNotEmpty() } ?: "Тренировка"
data class WorkoutEntry(val id: Int, val date: String, val exerciseId: Int, val name: String, val muscleGroup: String?, val weight: Double?, val sets: Double?, val reps: Double?, val rir: String?, val comment: String?)
data class ExerciseVariant(val machine: String?, val equipment: String?, val description: String?, val technique: String?, val tips: String?, val name: String? = null)
data class Exercise(val id: Int, val name: String, val muscleGroup: String?, val unit: String?, val defaultSets: Double?, val defaultReps: Double?, val targetRir: String? = null, val note: String? = null, val description: String? = null, val photos: List<String> = emptyList(), val video: String? = null, val variants: List<ExerciseVariant> = emptyList())
data class WorkoutEquipment(val id: Int, val kind: String, val name: String, val description: String?, val photo: String?)
data class WorkoutComplexItem(val id: Int, val exerciseId: Int, val exerciseCode: String?, val name: String, val muscleGroup: String?, val defaultUnit: String?, val workingWeight: Double?, val sets: Double?, val durationMinutes: Double?, val speedKmh: Double?)
data class WorkoutComplex(val id: Int, val name: String, val comment: String?, val photos: List<String>, val video: String?, val items: List<WorkoutComplexItem>)
data class ContentCategory(val id: Int, val kind: String, val name: String, val collection: String, val ownerId: Int?)
data class ArticleSection(val id: Int, val name: String, val description: String?, val articleCount: Int)
data class ArticleLink(val title: String, val url: String)
data class Article(val id: Int, val sectionId: Int, val sectionName: String, val title: String, val body: String, val tags: String?, val links: List<ArticleLink>, val photos: List<String>, val video: String?, val isPinned: Boolean, val isHidden: Boolean, val createdAt: String, val updatedAt: String?)
data class TrainerInfo(val id: Int, val name: String, val email: String)
data class SharedChatItem(val type: String, val id: Int, val name: String)
data class TrainerChatMessage(val id: Int, val senderId: Int?, val senderName: String, val message: String, val sharedItem: SharedChatItem?, val createdAt: String)
data class TrainerChatResponse(val trainer: TrainerInfo?, val messages: List<TrainerChatMessage>, val unreadCount: Int)
data class ClientNextWorkout(val id: Int, val scheduledAt: String, val status: String)
data class ClientSummary(val id: Int, val name: String, val email: String, val nextWorkout: ClientNextWorkout?, val unreadMessages: Int)
data class ClientNutritionValues(val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?)
data class ClientToday(val date: String, val entries: List<DiaryEntry>, val totals: ClientNutritionValues, val targets: ClientNutritionValues, val remaining: ClientNutritionValues)
data class ClientDetail(val id: Int, val name: String, val email: String, val nextWorkout: ClientNextWorkout?, val unreadMessages: Int, val progress: List<ProgressEntry>, val today: ClientToday, val workouts: List<WorkoutEntry>, val workoutPlans: List<WorkoutPlan>)

class AstraException(message: String) : Exception(message)

fun Double?.shown(suffix: String = ""): String = if (this == null) "—" else {
    val value = if (this % 1.0 == 0.0) this.toInt().toString() else "%.1f".format(this)
    value + suffix
}
