from __future__ import annotations

import json

from backend.models import (
    DiaryEntry,
    Exercise,
    Product,
    ProductMeasure,
    ProgressEntry,
    Recipe,
    RecipeIngredient,
    WorkoutLog,
    WorkoutPlan,
    WorkoutPlanItem,
)
from backend.services.calculations import amount_value, product_amount_values, rounded


def _sum_defined(values: list[float | None]) -> float | None:
    defined = [value for value in values if value is not None]
    if not defined:
        return None
    return round(sum(defined), 2)


def serialize_product_measure(measure: ProductMeasure) -> dict:
    return {
        "id": measure.id,
        "product_id": measure.product_id,
        "measure_name": measure.measure_name,
        "base_quantity": measure.base_quantity,
    }


def serialize_product(product: Product, include_measures: bool = True) -> dict:
    data = {
        "id": product.id,
        "code": product.code,
        "name": product.name,
        "category": product.category,
        "unit": product.unit,
        "package_price_rsd": product.package_price_rsd,
        "package_size": product.package_size,
        "price_per_100_or_unit_rsd": product.price_per_100_or_unit_rsd,
        "kcal": product.kcal,
        "protein_g": product.protein_g,
        "fat_g": product.fat_g,
        "carbs_g": product.carbs_g,
        "data_status": product.data_status,
        "note": product.note,
    }
    if include_measures:
        data["measures"] = [
            serialize_product_measure(measure)
            for measure in product.measures.order_by(ProductMeasure.base_quantity, ProductMeasure.measure_name)
        ]
    return data


def recipe_totals(recipe: Recipe) -> dict[str, float | None]:
    ingredients = list(
        RecipeIngredient
        .select(RecipeIngredient, Product)
        .join(Product)
        .where(RecipeIngredient.recipe == recipe)
    )
    values = [
        {
            "kcal": amount_value(ingredient.product.unit, ingredient.quantity, ingredient.product.kcal),
            "protein_g": amount_value(ingredient.product.unit, ingredient.quantity, ingredient.product.protein_g),
            "fat_g": amount_value(ingredient.product.unit, ingredient.quantity, ingredient.product.fat_g),
            "carbs_g": amount_value(ingredient.product.unit, ingredient.quantity, ingredient.product.carbs_g),
            "cost_rsd": amount_value(
                ingredient.product.unit,
                ingredient.quantity,
                ingredient.product.price_per_100_or_unit_rsd,
            ),
        }
        for ingredient in ingredients
    ]
    cost = _sum_defined([item["cost_rsd"] for item in values])

    if recipe.manual_kcal_per_serving is not None:
        kcal = round(recipe.manual_kcal_per_serving * recipe.servings, 2)
    else:
        kcal = _sum_defined([item["kcal"] for item in values])

    if recipe.manual_protein_per_serving_g is not None:
        protein = round(recipe.manual_protein_per_serving_g * recipe.servings, 2)
    else:
        protein = _sum_defined([item["protein_g"] for item in values])

    if recipe.manual_fat_per_serving_g is not None:
        fat = round(recipe.manual_fat_per_serving_g * recipe.servings, 2)
    else:
        fat = _sum_defined([item["fat_g"] for item in values])

    if recipe.manual_carbs_per_serving_g is not None:
        carbs = round(recipe.manual_carbs_per_serving_g * recipe.servings, 2)
    else:
        carbs = _sum_defined([item["carbs_g"] for item in values])

    servings = recipe.servings or 1
    cost_per_serving = (
        recipe.manual_price_per_serving_rsd
        if recipe.manual_price_per_serving_rsd is not None
        else rounded(cost / servings) if cost is not None else None
    )
    return {
        "recipe_cost_rsd": cost,
        "kcal": kcal,
        "protein_g": protein,
        "fat_g": fat,
        "carbs_g": carbs,
        "cost_per_serving_rsd": rounded(cost_per_serving),
        "kcal_per_serving": rounded(kcal / servings) if kcal is not None else None,
        "protein_per_serving_g": rounded(protein / servings) if protein is not None else None,
        "fat_per_serving_g": rounded(fat / servings) if fat is not None else None,
        "carbs_per_serving_g": rounded(carbs / servings) if carbs is not None else None,
    }


def serialize_recipe_summary(recipe: Recipe) -> dict:
    return {
        "id": recipe.id,
        "code": recipe.code,
        "name": recipe.name,
        "category": recipe.category,
        "subcategory": recipe.subcategory,
        "version": recipe.version,
        "status": recipe.status,
        "servings": recipe.servings,
        "tags": recipe.tags,
        "manual_price_per_serving_rsd": recipe.manual_price_per_serving_rsd,
        "manual_kcal_per_serving": recipe.manual_kcal_per_serving,
        "manual_protein_per_serving_g": recipe.manual_protein_per_serving_g,
        "manual_fat_per_serving_g": recipe.manual_fat_per_serving_g,
        "manual_carbs_per_serving_g": recipe.manual_carbs_per_serving_g,
        "collection": "local" if recipe.owner_id is not None else "common",
        "owner_id": recipe.owner_id,
        "submission_requested": bool(recipe.submission_requested),
        "moderation_status": recipe.moderation_status,
        "moderation_note": recipe.moderation_note,
        "submitted_by_id": recipe.submitted_by_id,
        **recipe_totals(recipe),
    }


def serialize_recipe_ingredient(ingredient: RecipeIngredient) -> dict:
    values = product_amount_values(ingredient.product, ingredient.quantity)
    return {
        "id": ingredient.id,
        "product_id": ingredient.product_id,
        "product_code": ingredient.product.code,
        "name": ingredient.product.name,
        "quantity": ingredient.quantity,
        "unit": ingredient.unit,
        "measurement_name": ingredient.measurement_name,
        "measurement_quantity": ingredient.measurement_quantity,
        "portion_description": ingredient.portion_description,
        "kcal": values["kcal"],
        "protein_g": values["protein_g"],
        "fat_g": values["fat_g"],
        "carbs_g": values["carbs_g"],
        "cost_rsd": values["cost_rsd"],
    }


def serialize_recipe_detail(recipe: Recipe) -> dict:
    ingredients = (
        RecipeIngredient
        .select(RecipeIngredient, Product)
        .join(Product)
        .where(RecipeIngredient.recipe == recipe)
        .order_by(RecipeIngredient.id)
    )
    return {
        "recipe": serialize_recipe_summary(recipe),
        "ingredients": [serialize_recipe_ingredient(ingredient) for ingredient in ingredients],
    }


def serialize_diary_entry(entry: DiaryEntry) -> dict:
    product = entry.product
    recipe = entry.recipe
    if product is not None:
        values = product_amount_values(product, entry.quantity)
        return {
            "id": entry.id,
            "entry_date": entry.entry_date,
            "meal_type": entry.meal_type,
            "recipe_id": None,
            "recipe_code": None,
            "product_id": product.id,
            "product_code": product.code,
            "servings": entry.servings,
            "quantity": entry.quantity,
            "unit": product.unit,
            "measurement_name": entry.measurement_name,
            "measurement_quantity": entry.measurement_quantity,
            "comment": entry.comment,
            "name": product.name,
            "item_type": "product",
            "kcal_per_serving": values["kcal"],
            "protein_per_serving_g": values["protein_g"],
            "fat_per_serving_g": values["fat_g"],
            "carbs_per_serving_g": values["carbs_g"],
            "cost_per_serving_rsd": values["cost_rsd"],
        }

    summary = serialize_recipe_summary(recipe) if recipe is not None else {}
    return {
        "id": entry.id,
        "entry_date": entry.entry_date,
        "meal_type": entry.meal_type,
        "recipe_id": recipe.id if recipe else None,
        "recipe_code": recipe.code if recipe else None,
        "product_id": None,
        "product_code": None,
        "servings": entry.servings,
        "quantity": entry.quantity,
        "unit": None,
        "measurement_name": entry.measurement_name,
        "measurement_quantity": entry.measurement_quantity,
        "comment": entry.comment,
        "name": recipe.name if recipe else None,
        "item_type": "recipe",
        "kcal_per_serving": summary.get("kcal_per_serving"),
        "protein_per_serving_g": summary.get("protein_per_serving_g"),
        "fat_per_serving_g": summary.get("fat_per_serving_g"),
        "carbs_per_serving_g": summary.get("carbs_per_serving_g"),
        "cost_per_serving_rsd": summary.get("cost_per_serving_rsd"),
    }


def serialize_progress(entry: ProgressEntry) -> dict:
    return {
        "id": entry.id,
        "measured_at": entry.measured_at,
        "weight_kg": entry.weight_kg,
        "height_cm": entry.height_cm,
        "bmi": entry.bmi,
        "body_fat_pct": entry.body_fat_pct,
        "fat_mass_kg": entry.fat_mass_kg,
        "muscle_pct": entry.muscle_pct,
        "muscle_mass_kg": entry.muscle_mass_kg,
        "protein_target_g": entry.protein_target_g,
        "fat_target_g": entry.fat_target_g,
        "waist_cm": entry.waist_cm,
        "chest_cm": entry.chest_cm,
        "hips_cm": entry.hips_cm,
        "sleep_score": entry.sleep_score,
        "wellbeing_score": entry.wellbeing_score,
        "comment": entry.comment,
    }


def serialize_exercise(exercise: Exercise) -> dict:
    try:
        photos = json.loads(exercise.photo_urls or "[]")
    except (TypeError, ValueError):
        photos = []
    if not isinstance(photos, list):
        photos = []
    return {
        "id": exercise.id,
        "code": exercise.code,
        "muscle_group": exercise.muscle_group,
        "name": exercise.name,
        "default_unit": exercise.default_unit,
        "default_sets": exercise.default_sets,
        "default_reps": exercise.default_reps,
        "target_rir": exercise.target_rir,
        "note": exercise.note,
        "description": exercise.description or exercise.note,
        "photos": photos,
        "video": exercise.video_url,
    }


def serialize_workout(log: WorkoutLog) -> dict:
    return {
        "id": log.id,
        "performed_at": log.performed_at,
        "exercise_id": log.exercise.id,
        "exercise_code": log.exercise.code,
        "working_weight": log.working_weight,
        "sets": log.sets,
        "reps": log.reps,
        "rir": log.rir,
        "machine_location": log.machine_location,
        "comment": log.comment,
        "name": log.exercise.name,
        "muscle_group": log.exercise.muscle_group,
        "default_unit": log.exercise.default_unit,
    }


def serialize_workout_plan(plan: WorkoutPlan) -> dict:
    items = (
        WorkoutPlanItem
        .select(WorkoutPlanItem, Exercise)
        .join(Exercise)
        .where(WorkoutPlanItem.plan == plan)
        .order_by(WorkoutPlanItem.id)
    )
    return {
        "id": plan.id,
        "scheduled_at": plan.scheduled_at,
        "status": plan.status,
        "completed_at": plan.completed_at,
        "items": [
            {
                "id": item.id,
                "exercise_id": item.exercise.id,
                "exercise_code": item.exercise.code,
                "name": item.exercise.name,
                "muscle_group": item.exercise.muscle_group,
                "default_unit": item.exercise.default_unit,
                "working_weight": item.working_weight,
                "sets": item.sets,
                "duration_minutes": item.duration_minutes,
                "speed_kmh": item.speed_kmh,
            }
            for item in items
        ],
    }
