from __future__ import annotations

import sqlite3

import pytest

from backend.config import DATABASE_TEMPLATE, PROJECT_ROOT, STATIC_ROOT, Settings
from backend.migrations import ensure_database
from backend.models import (
    AppMeta,
    DiaryEntry,
    Exercise,
    OAuthAuthorizationCode,
    OAuthClient,
    OAuthPendingAuthorization,
    OAuthRefreshToken,
    Product,
    ProgressEntry,
    Recipe,
    RecipeIngredient,
    User,
    WorkoutLog,
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
        public_base_url="http://testserver",
        admin_email="admin@example.com",
        admin_password="admin-password",
        auth_secret="test-secret",
        access_token_minutes=10080,
        mcp_access_token_minutes=60,
        mcp_refresh_token_days=30,
        mcp_auth_code_minutes=5,
    )


def _create_legacy_database(path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.executescript(DATABASE_TEMPLATE.read_text(encoding="utf-8"))
    return connection


def _legacy_count(connection: sqlite3.Connection, table: str) -> int:
    return int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def _create_v2_database(path) -> None:
    connection = sqlite3.connect(path)
    try:
        connection.executescript(
            """
            CREATE TABLE app_meta (key VARCHAR(255) PRIMARY KEY, value TEXT NOT NULL);
            INSERT INTO app_meta VALUES ('schema_version', '2');

            CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code VARCHAR(255) NOT NULL UNIQUE,
                name VARCHAR(255) NOT NULL,
                category VARCHAR(255),
                unit VARCHAR(255) NOT NULL,
                package_price_rsd REAL,
                package_size REAL,
                price_per_100_or_unit_rsd REAL,
                kcal REAL NOT NULL,
                protein_g REAL NOT NULL,
                fat_g REAL NOT NULL,
                carbs_g REAL NOT NULL,
                data_status VARCHAR(255) NOT NULL,
                note TEXT
            );
            INSERT INTO products VALUES (1, 'P-999', 'Тестовый продукт', 'Тест', 'г', NULL, NULL, NULL, 100, 10, 2, 3, 'Подтверждено', NULL);

            CREATE TABLE recipes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code VARCHAR(255) NOT NULL UNIQUE,
                name VARCHAR(255) NOT NULL,
                category VARCHAR(255) NOT NULL,
                subcategory VARCHAR(255),
                version VARCHAR(255) NOT NULL,
                status VARCHAR(255) NOT NULL,
                servings REAL NOT NULL,
                tags TEXT,
                manual_price_per_serving_rsd REAL,
                manual_kcal_per_serving REAL,
                manual_protein_per_serving_g REAL,
                manual_fat_per_serving_g REAL,
                manual_carbs_per_serving_g REAL
            );
            INSERT INTO recipes VALUES (1, 'M-999', 'Тестовый рецепт', 'Main', NULL, '1.0', 'Approved', 1, NULL, NULL, NULL, NULL, NULL, NULL);

            CREATE TABLE exercises (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code VARCHAR(255) NOT NULL UNIQUE,
                muscle_group VARCHAR(255),
                name VARCHAR(255) NOT NULL,
                default_unit VARCHAR(255),
                default_sets INTEGER,
                default_reps INTEGER,
                target_rir VARCHAR(255),
                note TEXT
            );
            INSERT INTO exercises VALUES (1, 'EX-999', 'Кор', 'Тестовое упражнение', 'кг', 3, 12, '0-2', NULL);

            CREATE TABLE diary_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entry_date VARCHAR(255) NOT NULL,
                meal_type VARCHAR(255),
                recipe_id INTEGER,
                product_id INTEGER,
                servings REAL NOT NULL,
                quantity REAL,
                measurement_name VARCHAR(255),
                measurement_quantity REAL,
                comment TEXT
            );
            INSERT INTO diary_entries VALUES (1, '2026-01-01', 'Обед', 1, NULL, 1, NULL, NULL, NULL, NULL);

            CREATE TABLE progress_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                measured_at VARCHAR(255) NOT NULL UNIQUE,
                weight_kg REAL,
                height_cm REAL,
                bmi REAL,
                body_fat_pct REAL,
                fat_mass_kg REAL,
                muscle_pct REAL,
                muscle_mass_kg REAL,
                protein_target_g REAL,
                fat_target_g REAL,
                waist_cm REAL,
                chest_cm REAL,
                hips_cm REAL,
                sleep_score INTEGER,
                wellbeing_score INTEGER,
                comment TEXT
            );
            INSERT INTO progress_entries VALUES (1, '2026-01-01', 70, 169, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

            CREATE TABLE workout_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                performed_at VARCHAR(255) NOT NULL,
                exercise_id INTEGER NOT NULL,
                working_weight REAL,
                sets INTEGER,
                reps INTEGER,
                rir VARCHAR(255),
                machine_location VARCHAR(255),
                comment TEXT
            );
            INSERT INTO workout_logs VALUES (1, '2026-01-01', 1, 10, 3, 12, '0-2', NULL, NULL);
            """
        )
        connection.commit()
    finally:
        connection.close()


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
        assert AppMeta.get(AppMeta.key == "schema_version").value == "6"
        assert OAuthClient.select().count() == 0
        assert OAuthPendingAuthorization.select().count() == 0
        assert OAuthAuthorizationCode.select().count() == 0
        assert OAuthRefreshToken.select().count() == 0
        assert RecipeIngredient.select().count() == expected["recipe_ingredients"]
        assert DiaryEntry.select().count() == expected["food_diary"]
        assert ProgressEntry.select().count() == expected["progress"]
        assert WorkoutLog.select().count() == expected["workout_logs"]

        admin = User.get(User.email == "admin@example.com")
        assert admin.is_admin is True
        assert DiaryEntry.select().where(DiaryEntry.user == admin).count() == expected["food_diary"]
        assert ProgressEntry.select().where(ProgressEntry.user == admin).count() == expected["progress"]
        assert WorkoutLog.select().where(WorkoutLog.user == admin).count() == expected["workout_logs"]

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


def test_migrates_v2_database_to_user_scoped_schema(tmp_path) -> None:
    settings = _settings(tmp_path)
    _create_v2_database(settings.db_path)

    ensure_database(settings)
    database = initialize_database(settings.db_path)
    database.connect()
    try:
        admin = User.get(User.email == "admin@example.com")
        assert admin.is_admin is True
        assert AppMeta.get(AppMeta.key == "schema_version").value == "6"
        assert OAuthClient.select().count() == 0
        assert OAuthPendingAuthorization.select().count() == 0
        assert OAuthAuthorizationCode.select().count() == 0
        assert OAuthRefreshToken.select().count() == 0
        assert DiaryEntry.get_by_id(1).user_id == admin.id
        assert ProgressEntry.get_by_id(1).user_id == admin.id
        assert WorkoutLog.get_by_id(1).user_id == admin.id

        second = User.create(
            email="second@example.com",
            password_hash="test",
            is_admin=False,
            created_at="2026-01-01T00:00:00+00:00",
        )
        ProgressEntry.create(user=second, measured_at="2026-01-01")
        assert ProgressEntry.select().where(ProgressEntry.measured_at == "2026-01-01").count() == 2
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
