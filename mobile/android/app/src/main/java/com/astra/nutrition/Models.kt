package com.astra.nutrition

data class AuthUser(val id: Int, val email: String, val name: String, val isAdmin: Boolean, val isTrainer: Boolean)
data class AuthResponse(val token: String, val user: AuthUser)
data class Dashboard(val products: Int, val recipes: Int, val approved: Int, val latest: ProgressEntry?, val top: List<Recipe>)
data class Product(val id: Int, val code: String, val name: String, val category: String?, val unit: String?, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?)
data class Recipe(val id: Int, val code: String, val name: String, val category: String, val status: String?, val servings: Double?, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?, val cost: Double?)
data class Ingredient(val id: Int, val productId: Int, val name: String, val quantity: Double?, val unit: String?)
data class RecipeDetail(val recipe: Recipe, val ingredients: List<Ingredient>)
data class DiaryEntry(val id: Int, val date: String, val meal: String?, val recipeId: Int?, val productId: Int?, val servings: Double?, val quantity: Double?, val unit: String?, val name: String?, val itemType: String, val kcal: Double?, val protein: Double?, val fat: Double?, val carbs: Double?)
data class ProgressEntry(val id: Int, val date: String, val weight: Double?, val desiredWeight: Double?, val height: Double?, val bmi: Double?, val bodyFat: Double?, val muscleMass: Double?, val kcalTarget: Double?, val proteinTarget: Double?, val fatTarget: Double?, val carbsTarget: Double?, val waist: Double?, val chest: Double?, val hips: Double?, val sleep: Double?, val wellbeing: Double?, val comment: String?)
data class WorkoutPlanItem(val id: Int?, val exerciseId: Int, val name: String?, val muscleGroup: String?, val weight: Double?, val sets: Double?, val duration: Double?, val speed: Double?)
data class WorkoutPlan(val id: Int, val scheduledAt: String, val duration: Double?, val status: String, val completedAt: String?, val items: List<WorkoutPlanItem>)
data class WorkoutEntry(val id: Int, val date: String, val exerciseId: Int, val name: String, val muscleGroup: String?, val weight: Double?, val sets: Double?, val reps: Double?, val rir: String?, val comment: String?)
data class Exercise(val id: Int, val name: String, val muscleGroup: String?, val unit: String?, val defaultSets: Double?, val defaultReps: Double?)

class AstraException(message: String) : Exception(message)

fun Double?.shown(suffix: String = ""): String = if (this == null) "—" else {
    val value = if (this % 1.0 == 0.0) this.toInt().toString() else "%.1f".format(this)
    value + suffix
}
