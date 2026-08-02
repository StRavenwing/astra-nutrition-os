from __future__ import annotations

from backend.models import DiaryEntry, Recipe, RecipeIngredient, current_database
from backend.services.calculations import RECIPE_PREFIXES, normalise_measure, number
from backend.services.codes import next_code
from backend.services.errors import ConflictError, NotFoundError
from backend.services.serialization import serialize_recipe_detail, serialize_recipe_summary


def list_recipes() -> list[dict]:
    query = Recipe.select().order_by(Recipe.category, Recipe.name)
    return [serialize_recipe_summary(recipe) for recipe in query]


def get_recipe(recipe_id: int) -> Recipe:
    recipe = Recipe.get_or_none(Recipe.id == recipe_id)
    if recipe is None:
        raise NotFoundError("Рецепт не найден")
    return recipe


def get_recipe_detail(recipe_id: int) -> dict:
    return serialize_recipe_detail(get_recipe(recipe_id))


def _recipe_prefix(category: str) -> str:
    prefix = RECIPE_PREFIXES.get(category)
    if not prefix:
        raise ValueError("Неизвестная категория рецепта")
    return prefix


def _write_recipe_ingredients(recipe: Recipe, ingredients: list[dict]) -> None:
    for ingredient in ingredients:
        base_quantity, base_unit, shown_quantity, shown_measure = normalise_measure(
            ingredient["product_id"],
            ingredient.get("measurement_quantity", ingredient.get("quantity")),
            ingredient.get("measurement_name") or ingredient.get("unit"),
        )
        portion_description = ingredient.get("portion_description")
        if shown_measure != base_unit:
            portion_description = f"{shown_quantity:g} {shown_measure} ≈ {base_quantity:g} {base_unit}"
        RecipeIngredient.create(
            recipe=recipe,
            product=ingredient["product_id"],
            quantity=number(base_quantity),
            unit=base_unit,
            portion_description=portion_description,
            measurement_name=shown_measure,
            measurement_quantity=shown_quantity,
        )


def create_recipe(data: dict) -> dict:
    with current_database().atomic():
        prefix = _recipe_prefix(data["category"])
        recipe = Recipe.create(
            code=next_code(prefix),
            name=data["name"],
            category=data["category"],
            subcategory=data.get("subcategory"),
            version=data.get("version", "1.0"),
            status=data.get("status", "Draft"),
            servings=number(data.get("servings"), 1) or 1,
            tags=data.get("tags"),
            manual_price_per_serving_rsd=number(data.get("manual_price_per_serving_rsd")),
            manual_kcal_per_serving=number(data.get("manual_kcal_per_serving")),
            manual_protein_per_serving_g=number(data.get("manual_protein_per_serving_g")),
            manual_fat_per_serving_g=number(data.get("manual_fat_per_serving_g")),
            manual_carbs_per_serving_g=number(data.get("manual_carbs_per_serving_g")),
        )
        _write_recipe_ingredients(recipe, data.get("ingredients", []))
        return serialize_recipe_summary(recipe)


def update_recipe(recipe_id: int, data: dict) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id)
        new_category = data.get("category", recipe.category)
        if new_category != recipe.category:
            recipe.code = next_code(_recipe_prefix(new_category))
            recipe.category = new_category
        else:
            _recipe_prefix(new_category)
            recipe.category = new_category

        recipe.name = data["name"]
        recipe.subcategory = data.get("subcategory")
        recipe.version = data.get("version", "1.0")
        recipe.status = data.get("status", "Draft")
        recipe.servings = number(data.get("servings"), 1) or 1
        recipe.tags = data.get("tags")
        recipe.manual_price_per_serving_rsd = number(data.get("manual_price_per_serving_rsd"))
        recipe.manual_kcal_per_serving = number(data.get("manual_kcal_per_serving"))
        recipe.manual_protein_per_serving_g = number(data.get("manual_protein_per_serving_g"))
        recipe.manual_fat_per_serving_g = number(data.get("manual_fat_per_serving_g"))
        recipe.manual_carbs_per_serving_g = number(data.get("manual_carbs_per_serving_g"))
        recipe.save()

        RecipeIngredient.delete().where(RecipeIngredient.recipe == recipe).execute()
        _write_recipe_ingredients(recipe, data.get("ingredients", []))
        return serialize_recipe_summary(recipe)


def delete_recipe(recipe_id: int) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id)
        diary_count = DiaryEntry.select().where(DiaryEntry.recipe == recipe).count()
        if diary_count:
            raise ConflictError(
                f"Рецепт используется в дневнике питания: {diary_count}. "
                "Сначала удалите связанные записи дневника."
            )
        recipe.delete_instance(recursive=True)
        return {"deleted": True, "id": recipe_id, "deleted_diary_entries": 0}
