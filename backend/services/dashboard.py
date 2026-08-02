from __future__ import annotations

from backend.models import Product, ProgressEntry, Recipe
from backend.services.serialization import serialize_progress, serialize_recipe_summary


def dashboard() -> dict:
    latest = (
        ProgressEntry
        .select()
        .order_by(ProgressEntry.measured_at.desc())
        .first()
    )
    recipes = [serialize_recipe_summary(recipe) for recipe in Recipe.select()]
    top = sorted(
        recipes,
        key=lambda item: item.get("protein_per_serving_g") or 0,
        reverse=True,
    )[:6]
    return {
        "products": Product.select().count(),
        "recipes": Recipe.select().count(),
        "approved": Recipe.select().where(Recipe.status == "Approved").count(),
        "latest": serialize_progress(latest) if latest else None,
        "top": top,
    }

