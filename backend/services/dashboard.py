from __future__ import annotations

from backend.models import Product, ProgressEntry, Recipe, User
from backend.services.serialization import serialize_progress, serialize_recipe_summary


def dashboard(user: User | None) -> dict:
    latest = None
    if user is not None:
        latest = (
            ProgressEntry
            .select()
            .where(ProgressEntry.user == user)
            .order_by(ProgressEntry.measured_at.desc())
            .first()
        )
    recipe_query = Recipe.select()
    if user is None:
        recipe_query = recipe_query.where(Recipe.owner.is_null(True))
    recipes = [serialize_recipe_summary(recipe) for recipe in recipe_query]
    top = sorted(
        recipes,
        key=lambda item: item.get("protein_per_serving_g") or 0,
        reverse=True,
    )[:6]
    recipe_count_query = Recipe.select()
    if user is None:
        recipe_count_query = recipe_count_query.where(Recipe.owner.is_null(True))
    return {
        "products": Product.select().count(),
        "recipes": recipe_count_query.count(),
        "approved": Recipe.select().where(Recipe.status == "Approved").count(),
        "latest": serialize_progress(latest) if latest else None,
        "top": top,
    }
