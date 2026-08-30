from __future__ import annotations

import math

from backend.models import DiaryEntry, Recipe, User, current_database
from backend.services.calculations import normalise_measure, number
from backend.services.codes import next_code
from backend.services.errors import NotFoundError
from backend.services.serialization import serialize_diary_entry

DIARY_RECIPE_CATEGORY = "Diary"


def list_diary(user: User | None) -> list[dict]:
    if user is None:
        return []
    query = (
        DiaryEntry
        .select()
        .where(DiaryEntry.user == user)
        .order_by(DiaryEntry.entry_date.desc(), DiaryEntry.id.desc())
    )
    return [serialize_diary_entry(entry) for entry in query]


def get_diary_entry(entry_id: int, user: User) -> DiaryEntry:
    entry = DiaryEntry.get_or_none((DiaryEntry.id == entry_id) & (DiaryEntry.user == user))
    if entry is None:
        raise NotFoundError("Запись не найдена")
    return entry


def _recipe_available(recipe_id: int, user: User) -> bool:
    return Recipe.select().where(
        (Recipe.id == recipe_id)
        & ((Recipe.owner.is_null(True)) | (Recipe.owner == user))
    ).exists()


def _create_custom_recipe(custom_dish: dict, user: User) -> Recipe:
    name = str(custom_dish.get("name", "")).strip()
    nutrition = {
        "kcal": number(custom_dish.get("kcal")),
        "protein_g": number(custom_dish.get("protein_g")),
        "fat_g": number(custom_dish.get("fat_g")),
        "carbs_g": number(custom_dish.get("carbs_g")),
    }
    if not name:
        raise ValueError("Название блюда обязательно")
    if any(value is None or not math.isfinite(value) or value < 0 for value in nutrition.values()):
        raise ValueError("Калории и КБЖУ должны быть неотрицательными числами")
    return Recipe.create(
        code=next_code("M"),
        name=name,
        category=DIARY_RECIPE_CATEGORY,
        version="1.0",
        status="Draft",
        servings=1,
        tags="Добавлено через дневник питания",
        is_ready=True,
        needs_garnish=False,
        manual_kcal_per_serving=nutrition["kcal"],
        manual_protein_per_serving_g=nutrition["protein_g"],
        manual_fat_per_serving_g=nutrition["fat_g"],
        manual_carbs_per_serving_g=nutrition["carbs_g"],
        owner=user,
        submitted_by=user,
        submission_requested=False,
        moderation_status="none",
    )


def _create_entry(entry_date: str, item: dict, user: User) -> DiaryEntry:
    shown_quantity = shown_measure = None
    quantity = number(item.get("quantity"))
    product_id = item.get("product_id")
    recipe_id = item.get("recipe_id")
    custom_dish = item.get("custom_dish")

    if custom_dish:
        if product_id or recipe_id:
            raise ValueError("Новое блюдо нельзя объединять с рецептом или продуктом")
        recipe = _create_custom_recipe(custom_dish, user)
        recipe_id = recipe.id
        product_id = None
    elif product_id:
        quantity, _, shown_quantity, shown_measure = normalise_measure(
            product_id,
            item.get("measurement_quantity", item.get("quantity")),
            item.get("measurement_name"),
        )
        recipe_id = None
    elif recipe_id:
        if not _recipe_available(recipe_id, user):
            raise NotFoundError("Рецепт не найден")
        product_id = None
    else:
        raise ValueError("Нужно выбрать рецепт или продукт")

    return DiaryEntry.create(
        user=user,
        entry_date=entry_date,
        meal_type=item.get("meal_type"),
        recipe=recipe_id,
        servings=number(item.get("servings"), 1) or 1,
        comment=item.get("comment"),
        product=product_id,
        quantity=quantity,
        measurement_name=shown_measure,
        measurement_quantity=shown_quantity,
    )


def create_diary_entries(data: dict, user: User) -> list[dict]:
    with current_database().atomic():
        items = data.get("items") or [data]
        created = []
        for item in items:
            entry_date = data.get("entry_date") or item.get("entry_date")
            if not entry_date:
                raise ValueError("Дата обязательна")
            created.append(_create_entry(entry_date, item, user))
        return [serialize_diary_entry(entry) for entry in created]


def update_diary_entry(entry_id: int, data: dict, user: User) -> dict:
    with current_database().atomic():
        entry = get_diary_entry(entry_id, user)
        shown_quantity = shown_measure = None
        quantity = number(data.get("quantity"))
        product_id = data.get("product_id")
        recipe_id = data.get("recipe_id")
        if product_id:
            quantity, _, shown_quantity, shown_measure = normalise_measure(
                product_id,
                data.get("measurement_quantity", data.get("quantity")),
                data.get("measurement_name"),
            )
            recipe_id = None
        elif recipe_id and not _recipe_available(recipe_id, user):
            raise NotFoundError("Рецепт не найден")

        entry.entry_date = data["entry_date"]
        entry.meal_type = data.get("meal_type")
        entry.recipe = recipe_id
        entry.servings = number(data.get("servings"), 1) or 1
        entry.comment = data.get("comment")
        entry.product = product_id
        entry.quantity = quantity
        entry.measurement_name = shown_measure
        entry.measurement_quantity = shown_quantity
        entry.save()
        return serialize_diary_entry(entry)


def delete_diary_entry(entry_id: int, user: User) -> dict:
    with current_database().atomic():
        entry = get_diary_entry(entry_id, user)
        entry.delete_instance()
        return {"deleted": True, "id": entry_id}
