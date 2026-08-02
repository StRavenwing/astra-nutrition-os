from __future__ import annotations

import sqlite3

import pytest

from backend.config import DATABASE_TEMPLATE, PROJECT_ROOT, STATIC_ROOT, Settings
from backend.migrations import ensure_database
from backend.models import (
    DiaryEntry,
    Exercise,
    Product,
    Recipe,
    RecipeIngredient,
    current_database,
    initialize_database,
)
from backend.services.serialization import serialize_diary_entry, serialize_recipe_summary


def _settings(tmp_path) -> Settings:
    return Settings(
        project_root=PROJECT_ROOT,
        static_root=STATIC_ROOT,
        database_template=DATABASE_TEMPLATE,
        db_path=tmp_path / "astra.sqlite",
        backup_dir=tmp_path / "backups",
        host="127.0.0.1",
        port=8787,
    )


def _create_legacy_database(path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.executescript(DATABASE_TEMPLATE.read_text(encoding="utf-8"))
    return connection


def _legacy_count(connection: sqlite3.Connection, table: str) -> int:
    return int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def test_migrates_legacy_template_to_normalized_schema(tmp_path) -> None:
    settings = _settings(tmp_path)
    legacy = _create_legacy_database(settings.db_path)
    expected = {
        "products": _legacy_count(legacy, "products"),
        "recipes": _legacy_count(legacy, "recipes"),
        "exercises": _legacy_count(legacy, "exercises"),
        "recipe_ingredients": _legacy_count(legacy, "recipe_ingredients"),
        "food_diary": _legacy_count(legacy, "food_diary"),
        "progress": _legacy_count(legacy, "progress"),
        "workout_logs": _legacy_count(legacy, "workout_logs"),
    }
    legacy.close()

    ensure_database(settings)
    database = initialize_database(settings.db_path)
    database.connect()
    try:
        assert Product.select().count() == expected["products"]
        assert Recipe.select().count() == expected["recipes"]
        assert Exercise.select().count() == expected["exercises"]
        assert RecipeIngredient.select().count() == expected["recipe_ingredients"]
        assert DiaryEntry.select().count() == expected["food_diary"]

        product = Product.get(Product.code == "P-001")
        recipe = Recipe.get(Recipe.code == "M-001")
        exercise = Exercise.get(Exercise.code == "EX-001")
        assert isinstance(product.id, int)
        assert isinstance(recipe.id, int)
        assert isinstance(exercise.id, int)

        ingredient = (
            RecipeIngredient
            .select()
            .join(Product)
            .where(RecipeIngredient.recipe == recipe)
            .first()
        )
        assert ingredient is not None
        assert ingredient.product.code.startswith("P-")
    finally:
        if not database.is_closed():
            database.close()


def test_migrated_totals_match_legacy_views(tmp_path) -> None:
    settings = _settings(tmp_path)
    legacy = _create_legacy_database(settings.db_path)
    legacy_recipe = legacy.execute(
        "SELECT * FROM recipe_per_serving WHERE recipe_id = 'M-001'"
    ).fetchone()
    legacy_diary = legacy.execute(
        "SELECT * FROM food_diary_totals WHERE entry_date = '2026-07-14'"
    ).fetchone()
    legacy.close()

    ensure_database(settings)
    database = initialize_database(settings.db_path)
    database.connect()
    try:
        recipe_summary = serialize_recipe_summary(Recipe.get(Recipe.code == "M-001"))
        for field in (
            "kcal",
            "protein_g",
            "fat_g",
            "carbs_g",
            "kcal_per_serving",
            "protein_per_serving_g",
            "fat_per_serving_g",
            "carbs_per_serving_g",
            "cost_per_serving_rsd",
        ):
            assert recipe_summary[field] == pytest.approx(legacy_recipe[field])

        entries = [
            serialize_diary_entry(entry)
            for entry in DiaryEntry.select().where(DiaryEntry.entry_date == "2026-07-14")
        ]
        totals = {
            "kcal": sum((item["kcal_per_serving"] or 0) * (item["servings"] or 0) for item in entries),
            "protein_g": sum((item["protein_per_serving_g"] or 0) * (item["servings"] or 0) for item in entries),
            "fat_g": sum((item["fat_per_serving_g"] or 0) * (item["servings"] or 0) for item in entries),
            "carbs_g": sum((item["carbs_per_serving_g"] or 0) * (item["servings"] or 0) for item in entries),
            "cost_rsd": sum((item["cost_per_serving_rsd"] or 0) * (item["servings"] or 0) for item in entries),
        }
        for field, value in totals.items():
            assert round(value, 2) == pytest.approx(legacy_diary[field])
    finally:
        if not database.is_closed():
            database.close()

