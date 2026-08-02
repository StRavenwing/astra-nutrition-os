from __future__ import annotations

from backend.models import DiaryEntry, Recipe, current_database
from backend.services.calculations import normalise_measure, number
from backend.services.errors import NotFoundError
from backend.services.serialization import serialize_diary_entry


def list_diary() -> list[dict]:
    query = DiaryEntry.select().order_by(DiaryEntry.entry_date.desc(), DiaryEntry.id.desc())
    return [serialize_diary_entry(entry) for entry in query]


def get_diary_entry(entry_id: int) -> DiaryEntry:
    entry = DiaryEntry.get_or_none(DiaryEntry.id == entry_id)
    if entry is None:
        raise NotFoundError("Запись не найдена")
    return entry


def _create_entry(entry_date: str, item: dict) -> DiaryEntry:
    shown_quantity = shown_measure = None
    quantity = number(item.get("quantity"))
    product_id = item.get("product_id")
    recipe_id = item.get("recipe_id")

    if product_id:
        quantity, _, shown_quantity, shown_measure = normalise_measure(
            product_id,
            item.get("measurement_quantity", item.get("quantity")),
            item.get("measurement_name"),
        )
        recipe_id = None
    elif recipe_id:
        if Recipe.get_or_none(Recipe.id == recipe_id) is None:
            raise NotFoundError("Рецепт не найден")
        product_id = None
    else:
        raise ValueError("Нужно выбрать рецепт или продукт")

    return DiaryEntry.create(
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


def create_diary_entries(data: dict) -> list[dict]:
    with current_database().atomic():
        items = data.get("items") or [data]
        created = []
        for item in items:
            entry_date = data.get("entry_date") or item.get("entry_date")
            if not entry_date:
                raise ValueError("Дата обязательна")
            created.append(_create_entry(entry_date, item))
        return [serialize_diary_entry(entry) for entry in created]


def update_diary_entry(entry_id: int, data: dict) -> dict:
    with current_database().atomic():
        entry = get_diary_entry(entry_id)
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
        elif recipe_id and Recipe.get_or_none(Recipe.id == recipe_id) is None:
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


def delete_diary_entry(entry_id: int) -> dict:
    with current_database().atomic():
        entry = get_diary_entry(entry_id)
        entry.delete_instance()
        return {"deleted": True, "id": entry_id}

