from __future__ import annotations

from backend.models import DiaryEntry, Recipe, RecipeComponent, RecipeIngredient, User, current_database
from backend.services.calculations import RECIPE_PREFIXES, normalise_measure, number
from backend.services.codes import next_code
from backend.services.errors import ConflictError, ForbiddenError, NotFoundError
from backend.services.serialization import serialize_recipe_detail, serialize_recipe_summary


def list_recipes(current_user: User | None) -> list[dict]:
    visibility = Recipe.owner.is_null(True)
    if current_user is not None:
        visibility = visibility | (Recipe.owner == current_user)
    if current_user is not None and current_user.is_admin:
        visibility = visibility | (Recipe.moderation_status == "pending")
    query = (
        Recipe.select()
        .where(visibility)
        .order_by(Recipe.owner, Recipe.category, Recipe.name)
    )
    result = []
    for recipe in query:
        item = serialize_recipe_summary(recipe)
        item["is_submitter"] = bool(current_user and recipe.submitted_by_id == current_user.id)
        result.append(item)
    return result


def get_recipe(recipe_id: int, current_user: User | None = None) -> Recipe:
    recipe = Recipe.get_or_none(Recipe.id == recipe_id)
    if recipe is None:
        raise NotFoundError("Рецепт не найден")
    admin_review = bool(current_user and current_user.is_admin and recipe.moderation_status == "pending")
    if recipe.owner_id is not None and (current_user is None or recipe.owner_id != current_user.id) and not admin_review:
        raise NotFoundError("Рецепт не найден")
    return recipe


def get_recipe_detail(recipe_id: int, current_user: User | None) -> dict:
    recipe = get_recipe(recipe_id, current_user)
    result = serialize_recipe_detail(recipe)
    result["recipe"]["is_submitter"] = bool(current_user and recipe.submitted_by_id == current_user.id)
    return result


def _recipe_prefix(category: str) -> str:
    prefix = RECIPE_PREFIXES.get(category)
    return prefix or "M"


def _get_component_recipe(recipe_id: int, owner: User | None) -> Recipe:
    child = Recipe.get_or_none(Recipe.id == recipe_id)
    if child is None:
        raise NotFoundError("Вложенное блюдо не найдено")
    if owner is None and child.owner_id is not None:
        raise NotFoundError("Общее блюдо может содержать только общие блюда")
    if owner is not None and child.owner_id not in (None, owner.id):
        raise NotFoundError("Вложенное блюдо недоступно для этого пользователя")
    return child


def _assert_no_recipe_cycle(parent: Recipe, child: Recipe) -> None:
    pending = [child.id]
    visited: set[int] = set()
    while pending:
        recipe_id = pending.pop()
        if recipe_id == parent.id:
            raise ValueError("Нельзя включить рецепт в самого себя или создать циклический состав")
        if recipe_id in visited:
            continue
        visited.add(recipe_id)
        pending.extend(
            component.child_recipe_id
            for component in RecipeComponent.select(RecipeComponent.child_recipe)
            .where(RecipeComponent.recipe == recipe_id)
        )


def _write_recipe_ingredients(recipe: Recipe, ingredients: list[dict]) -> None:
    for ingredient in ingredients:
        if ingredient.get("recipe_id") is not None:
            continue
        if ingredient.get("product_id") is None:
            raise ValueError("Для ингредиента выберите продукт или блюдо")
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


def _write_recipe_components(recipe: Recipe, ingredients: list[dict], owner: User | None) -> None:
    for ingredient in ingredients:
        recipe_id = ingredient.get("recipe_id")
        if recipe_id is None:
            continue
        if ingredient.get("product_id") is not None:
            raise ValueError("Компонент не может одновременно быть продуктом и блюдом")
        child = _get_component_recipe(int(recipe_id), owner)
        if child.id == recipe.id:
            raise ValueError("Нельзя включить рецепт в самого себя или создать циклический состав")
        if child.yield_g is None or child.yield_g <= 0:
            raise ValueError(
                f'Для вложенного блюда «{child.name}» необходимо указать выход в граммах'
            )
        _assert_no_recipe_cycle(recipe, child)
        quantity = number(ingredient.get("quantity"), None)
        if quantity is None or quantity <= 0:
            raise ValueError("Количество вложенного блюда должно быть больше нуля")
        RecipeComponent.create(
            recipe=recipe,
            child_recipe=child,
            quantity=quantity,
            unit="г",
            portion_description=ingredient.get("portion_description"),
        )


def create_recipe(data: dict, owner: User | None = None) -> dict:
    with current_database().atomic():
        category = data["category"]
        legacy_ready = category == "Ready"
        if legacy_ready:
            category = "Main"
        prefix = "R" if legacy_ready else _recipe_prefix(category)
        yield_g = number(data.get("yield_g"))
        if yield_g is not None and yield_g <= 0:
            raise ValueError("Выход блюда должен быть больше нуля")
        recipe = Recipe.create(
            code=next_code(prefix),
            name=data["name"],
            category=category,
            subcategory=data.get("subcategory"),
            version=data.get("version", "1.0"),
            status=data.get("status", "Draft"),
            servings=number(data.get("servings"), 1) or 1,
            yield_g=yield_g,
            tags=data.get("tags"),
            is_ready=bool(data.get("is_ready", False)) or legacy_ready,
            needs_garnish=bool(data.get("needs_garnish", False)),
            manual_price_per_serving_rsd=number(data.get("manual_price_per_serving_rsd")),
            manual_kcal_per_serving=number(data.get("manual_kcal_per_serving")),
            manual_protein_per_serving_g=number(data.get("manual_protein_per_serving_g")),
            manual_fat_per_serving_g=number(data.get("manual_fat_per_serving_g")),
            manual_carbs_per_serving_g=number(data.get("manual_carbs_per_serving_g")),
            owner=owner,
            submitted_by=owner,
            submission_requested=False,
            moderation_status="none",
        )
        _write_recipe_ingredients(recipe, data.get("ingredients", []))
        _write_recipe_components(recipe, data.get("ingredients", []), owner)
        return serialize_recipe_summary(recipe)


def update_recipe(recipe_id: int, data: dict, current_user: User) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id, current_user)
        if recipe.owner_id is None and not current_user.is_admin:
            raise ForbiddenError("Общие рецепты может редактировать только администратор")
        new_category = data.get("category", recipe.category)
        legacy_ready = new_category == "Ready"
        if legacy_ready:
            new_category = "Main"
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
        new_yield = number(data.get("yield_g"))
        if new_yield is not None and new_yield <= 0:
            raise ValueError("Выход блюда должен быть больше нуля")
        if new_yield is None and RecipeComponent.select().where(RecipeComponent.child_recipe == recipe).exists():
            raise ConflictError("Нельзя убрать выход в граммах: блюдо используется в составе другого блюда")
        recipe.yield_g = new_yield
        recipe.tags = data.get("tags")
        recipe.is_ready = bool(data.get("is_ready", False)) or legacy_ready
        recipe.needs_garnish = bool(data.get("needs_garnish", False))
        recipe.manual_price_per_serving_rsd = number(data.get("manual_price_per_serving_rsd"))
        recipe.manual_kcal_per_serving = number(data.get("manual_kcal_per_serving"))
        recipe.manual_protein_per_serving_g = number(data.get("manual_protein_per_serving_g"))
        recipe.manual_fat_per_serving_g = number(data.get("manual_fat_per_serving_g"))
        recipe.manual_carbs_per_serving_g = number(data.get("manual_carbs_per_serving_g"))
        if recipe.owner_id is not None and recipe.moderation_status != "revision":
            recipe.submission_requested = False
            recipe.moderation_status = "none"
            recipe.moderation_note = None
        recipe.save()

        RecipeIngredient.delete().where(RecipeIngredient.recipe == recipe).execute()
        RecipeComponent.delete().where(RecipeComponent.recipe == recipe).execute()
        _write_recipe_ingredients(recipe, data.get("ingredients", []))
        _write_recipe_components(recipe, data.get("ingredients", []), current_user)
        return serialize_recipe_summary(recipe)


def delete_recipe(recipe_id: int, current_user: User) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id, current_user)
        if recipe.owner_id is None and not current_user.is_admin:
            raise ForbiddenError("Общие рецепты может удалять только администратор")
        diary_count = DiaryEntry.select().where(DiaryEntry.recipe == recipe).count()
        if diary_count:
            raise ConflictError(
                f"Рецепт используется в дневнике питания: {diary_count}. "
                "Сначала удалите связанные записи дневника."
            )
        component_count = RecipeComponent.select().where(RecipeComponent.child_recipe == recipe).count()
        if component_count:
            raise ConflictError(
                f"Блюдо используется в составе других рецептов: {component_count}. "
                "Сначала удалите его из составов этих рецептов."
            )
        recipe.delete_instance(recursive=True)
        return {"deleted": True, "id": recipe_id, "deleted_diary_entries": 0}


def request_recipe_submission(recipe_id: int, current_user: User) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id, current_user)
        if recipe.owner_id != current_user.id:
            raise ForbiddenError("Отправить на рассмотрение можно только свой локальный рецепт")
        recipe.submission_requested = True
        recipe.submitted_by = current_user
        recipe.moderation_status = "pending"
        recipe.moderation_note = None
        recipe.save()
        return serialize_recipe_summary(recipe)


def cancel_recipe_submission(recipe_id: int, current_user: User) -> dict:
    with current_database().atomic():
        recipe = get_recipe(recipe_id, current_user)
        if recipe.owner_id != current_user.id:
            raise ForbiddenError("Отменить можно только отправку своего рецепта")
        if recipe.moderation_status not in {"pending", "revision"}:
            raise ConflictError("Запрос уже рассмотрен")
        recipe.submission_requested = False
        recipe.moderation_status = "none"
        recipe.moderation_note = None
        recipe.save()
        return serialize_recipe_summary(recipe)


def moderate_recipe(recipe_id: int, action: str, note: str | None, current_user: User) -> dict:
    if not current_user.is_admin:
        raise ForbiddenError("Модерация доступна только администратору")
    if action not in {"accept", "reject", "revision"}:
        raise ValueError("Неизвестное действие модерации")
    with current_database().atomic():
        recipe = Recipe.get_or_none((Recipe.id == recipe_id) & (Recipe.moderation_status == "pending"))
        if recipe is None:
            raise NotFoundError("Рецепт на рассмотрении не найден")
        if action == "accept":
            recipe.owner = None
            recipe.moderation_status = "accepted"
            recipe.moderation_note = None
            recipe.submission_requested = False
        elif action == "reject":
            recipe.moderation_status = "rejected"
            recipe.moderation_note = note
            recipe.submission_requested = False
        else:
            if not (note or "").strip():
                raise ValueError("Добавьте примечание для доработки")
            recipe.moderation_status = "revision"
            recipe.moderation_note = note.strip()
            recipe.submission_requested = True
        recipe.save()
        return serialize_recipe_summary(recipe)
