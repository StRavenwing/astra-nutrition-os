from __future__ import annotations

import os
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Any

from backend.config import Settings
from backend.models import (
    AppMeta,
    Changelog,
    DiaryEntry,
    Exercise,
    IdSequence,
    MODELS,
    Product,
    ProductMeasure,
    ProgressEntry,
    Recipe,
    RecipeIngredient,
    User,
    WorkoutLog,
    database_proxy,
    make_database,
)
from backend.services.auth import hash_password, normalize_email, utc_now
from backend.services.calculations import RECIPE_PREFIXES, ensure_product_measures, int_number
from backend.services.codes import sequence_rows


SCHEMA_VERSION = "6"


def _connect_raw(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    return connection


def _table_exists(connection: sqlite3.Connection, table: str) -> bool:
    return connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone() is not None


def _columns(connection: sqlite3.Connection, table: str) -> set[str]:
    if not _table_exists(connection, table):
        return set()
    return {row[1] for row in connection.execute(f"PRAGMA table_info({table})")}


def _ensure_exercise_columns(connection: sqlite3.Connection) -> None:
    columns = _columns(connection, "exercises")
    additions = {
        "description": "TEXT",
        "photo_urls": "TEXT",
        "video_url": "TEXT",
    }
    for column, column_type in additions.items():
        if column not in columns:
            connection.execute(f"ALTER TABLE exercises ADD COLUMN {column} {column_type}")
    if "description" not in columns:
        connection.execute("UPDATE exercises SET description=note WHERE description IS NULL")


def _ensure_feedback_columns(connection: sqlite3.Connection) -> None:
    columns = _columns(connection, "feedback_messages")
    if columns and "is_read" not in columns:
        connection.execute("ALTER TABLE feedback_messages ADD COLUMN is_read INTEGER NOT NULL DEFAULT 0")


def _row_value(row: sqlite3.Row, key: str, default: Any = None) -> Any:
    return row[key] if key in row.keys() else default


def _count(connection: sqlite3.Connection, table: str) -> int:
    if not _table_exists(connection, table):
        return 0
    return int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def _admin_row(connection: sqlite3.Connection, settings: Settings) -> sqlite3.Row:
    email = normalize_email(settings.admin_email)
    password_hash = hash_password(settings.admin_password)
    connection.execute("UPDATE users SET is_admin=0 WHERE email<>?", (email,))
    row = connection.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()
    if row is None:
        connection.execute(
            "INSERT INTO users (email, password_hash, is_admin, created_at) VALUES (?, ?, 1, ?)",
            (email, password_hash, utc_now()),
        )
    else:
        connection.execute(
            "UPDATE users SET password_hash=?, is_admin=1 WHERE id=?",
            (password_hash, row["id"]),
        )
    return connection.execute("SELECT * FROM users WHERE email=?", (email,)).fetchone()


def backup_database(db_path: Path, backup_dir: Path, prefix: str = "astra-auto") -> Path | None:
    if not db_path.exists():
        return None
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_path = backup_dir / f"{prefix}-{datetime.now():%Y%m%d-%H%M%S}.sqlite"
    source = sqlite3.connect(db_path)
    target = sqlite3.connect(backup_path)
    try:
        with target:
            source.backup(target)
    finally:
        target.close()
        source.close()
    backups = sorted(backup_dir.glob(f"{prefix}-*.sqlite"))
    for old_backup in backups[:-20]:
        old_backup.unlink(missing_ok=True)
    return backup_path


def _create_legacy_database_from_template(settings: Settings) -> None:
    if not settings.database_template.exists():
        raise FileNotFoundError("Database template is missing")
    settings.db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(settings.db_path)
    try:
        connection.executescript(settings.database_template.read_text(encoding="utf-8"))
    finally:
        connection.close()


def _legacy_schema_status(path: Path) -> str:
    with _connect_raw(path) as connection:
        if _table_exists(connection, "app_meta"):
            row = connection.execute(
                "SELECT value FROM app_meta WHERE key='schema_version'"
            ).fetchone()
            if row and row[0] == SCHEMA_VERSION:
                return "normalized"
            if row and row[0] == "2":
                return "normalized_v2"
            if row and row[0] == "3":
                return "normalized_v3"
            if row and row[0] == "4":
                return "normalized_v4"
            if row and row[0] == "5":
                return "normalized_v5"
        if "product_id" in _columns(connection, "products"):
            return "legacy"
    return "unknown"


def _upgrade_legacy_schema(connection: sqlite3.Connection) -> None:
    recipe_columns = _columns(connection, "recipes")
    recipe_additions = {
        "manual_price_per_serving_rsd": "REAL",
        "manual_kcal_per_serving": "REAL",
        "manual_protein_per_serving_g": "REAL",
        "manual_fat_per_serving_g": "REAL",
        "manual_carbs_per_serving_g": "REAL",
    }
    for column, column_type in recipe_additions.items():
        if column not in recipe_columns:
            connection.execute(f"ALTER TABLE recipes ADD COLUMN {column} {column_type}")

    diary_columns = _columns(connection, "food_diary")
    diary_additions = {
        "product_id": "TEXT",
        "quantity": "REAL",
        "measurement_name": "TEXT",
        "measurement_quantity": "REAL",
    }
    for column, column_type in diary_additions.items():
        if column not in diary_columns:
            connection.execute(f"ALTER TABLE food_diary ADD COLUMN {column} {column_type}")

    ingredient_columns = _columns(connection, "recipe_ingredients")
    ingredient_additions = {
        "measurement_name": "TEXT",
        "measurement_quantity": "REAL",
    }
    for column, column_type in ingredient_additions.items():
        if column not in ingredient_columns:
            connection.execute(f"ALTER TABLE recipe_ingredients ADD COLUMN {column} {column_type}")

    progress_columns = _columns(connection, "progress")
    progress_additions = {
        "height_cm": "REAL",
        "bmi": "REAL",
        "body_fat_pct": "REAL",
        "fat_mass_kg": "REAL",
        "muscle_pct": "REAL",
        "muscle_mass_kg": "REAL",
        "protein_target_g": "REAL",
        "fat_target_g": "REAL",
    }
    for column, column_type in progress_additions.items():
        if column not in progress_columns:
            connection.execute(f"ALTER TABLE progress ADD COLUMN {column} {column_type}")


def _create_normalized_schema(path: Path):
    if path.exists():
        path.unlink()
    try:
        existing = database_proxy.obj
        if existing is not None and not existing.is_closed():
            existing.close()
    except Exception:
        pass
    database = make_database(path)
    database_proxy.initialize(database)
    database.connect()
    database.create_tables(MODELS)
    AppMeta.create(key="schema_version", value=SCHEMA_VERSION)
    return database


def _seed_default_measures() -> None:
    for product in Product.select():
        ensure_product_measures(product)

    overrides = [
        ("P-002", "ч. л.", 8), ("P-002", "ст. л.", 25),
        ("P-003", "ч. л.", 8), ("P-003", "ст. л.", 25),
        ("P-004", "ч. л.", 7), ("P-004", "ст. л.", 20),
        ("P-005", "ч. л.", 7), ("P-005", "ст. л.", 20),
        ("P-006", "ч. л.", 7), ("P-006", "ст. л.", 20),
        ("P-031", "ч. л.", 3), ("P-031", "ст. л.", 9),
        ("P-032", "ч. л.", 1), ("P-032", "ст. л.", 3),
    ]
    for code, measure_name, base_quantity in overrides:
        product = Product.get_or_none(Product.code == code)
        if product is None:
            continue
        measure, _ = ProductMeasure.get_or_create(
            product=product,
            measure_name=measure_name,
            defaults={"base_quantity": base_quantity},
        )
        measure.base_quantity = base_quantity
        measure.save()


def _migrate_legacy_rows(source: sqlite3.Connection, destination, settings: Settings) -> None:
    product_map: dict[str, int] = {}
    recipe_map: dict[str, int] = {}
    exercise_map: dict[str, int] = {}

    with destination.atomic():
        admin = User.create(
            email=normalize_email(settings.admin_email),
            password_hash=hash_password(settings.admin_password),
            is_admin=True,
            created_at=utc_now(),
        )

        for row in source.execute("SELECT * FROM products ORDER BY product_id"):
            product = Product.create(
                code=row["product_id"],
                name=row["name"],
                category=_row_value(row, "category"),
                unit=_row_value(row, "unit", "г") or "г",
                package_price_rsd=_row_value(row, "package_price_rsd"),
                package_size=_row_value(row, "package_size"),
                price_per_100_or_unit_rsd=_row_value(row, "price_per_100_or_unit_rsd"),
                kcal=_row_value(row, "kcal", 0) or 0,
                protein_g=_row_value(row, "protein_g", 0) or 0,
                fat_g=_row_value(row, "fat_g", 0) or 0,
                carbs_g=_row_value(row, "carbs_g", 0) or 0,
                data_status=_row_value(row, "data_status", "Подтверждено") or "Подтверждено",
                note=_row_value(row, "note"),
            )
            product_map[product.code] = product.id

        for row in source.execute("SELECT * FROM recipes ORDER BY recipe_id"):
            recipe = Recipe.create(
                code=row["recipe_id"],
                name=row["name"],
                category=row["category"],
                subcategory=_row_value(row, "subcategory"),
                version=str(_row_value(row, "version", "1.0") or "1.0"),
                status=_row_value(row, "status", "Draft") or "Draft",
                servings=_row_value(row, "servings", 1) or 1,
                tags=_row_value(row, "tags"),
                manual_price_per_serving_rsd=_row_value(row, "manual_price_per_serving_rsd"),
                manual_kcal_per_serving=_row_value(row, "manual_kcal_per_serving"),
                manual_protein_per_serving_g=_row_value(row, "manual_protein_per_serving_g"),
                manual_fat_per_serving_g=_row_value(row, "manual_fat_per_serving_g"),
                manual_carbs_per_serving_g=_row_value(row, "manual_carbs_per_serving_g"),
            )
            recipe_map[recipe.code] = recipe.id

        for row in source.execute("SELECT * FROM exercises ORDER BY exercise_id"):
            exercise = Exercise.create(
                code=row["exercise_id"],
                muscle_group=_row_value(row, "muscle_group"),
                name=row["name"],
                default_unit=_row_value(row, "default_unit", "кг"),
                default_sets=int_number(_row_value(row, "default_sets")),
                default_reps=int_number(_row_value(row, "default_reps")),
                target_rir=_row_value(row, "target_rir"),
                note=_row_value(row, "note"),
                description=_row_value(row, "description") or _row_value(row, "note"),
                photo_urls=_row_value(row, "photo_urls"),
                video_url=_row_value(row, "video_url"),
            )
            exercise_map[exercise.code] = exercise.id

        if _table_exists(source, "product_measures"):
            for row in source.execute("SELECT * FROM product_measures ORDER BY product_measure_id"):
                product_id = product_map.get(row["product_id"])
                if product_id is None:
                    continue
                ProductMeasure.get_or_create(
                    product=product_id,
                    measure_name=row["measure_name"],
                    defaults={"base_quantity": row["base_quantity"]},
                )
        _seed_default_measures()

        for row in source.execute("SELECT * FROM recipe_ingredients ORDER BY recipe_ingredient_id"):
            recipe_id = recipe_map.get(row["recipe_id"])
            product_id = product_map.get(row["product_id"])
            if recipe_id is None or product_id is None:
                continue
            RecipeIngredient.create(
                recipe=recipe_id,
                product=product_id,
                quantity=row["quantity"],
                unit=row["unit"],
                portion_description=_row_value(row, "portion_description"),
                measurement_name=_row_value(row, "measurement_name"),
                measurement_quantity=_row_value(row, "measurement_quantity"),
            )

        for row in source.execute("SELECT * FROM food_diary ORDER BY diary_id"):
            recipe_id = recipe_map.get(_row_value(row, "recipe_id"))
            product_id = product_map.get(_row_value(row, "product_id"))
            DiaryEntry.create(
                user=admin,
                entry_date=row["entry_date"],
                meal_type=_row_value(row, "meal_type"),
                recipe=recipe_id,
                product=product_id,
                servings=_row_value(row, "servings", 1) or 1,
                quantity=_row_value(row, "quantity"),
                measurement_name=_row_value(row, "measurement_name"),
                measurement_quantity=_row_value(row, "measurement_quantity"),
                comment=_row_value(row, "comment"),
            )

        for row in source.execute("SELECT * FROM progress ORDER BY progress_id"):
            ProgressEntry.create(
                user=admin,
                measured_at=row["measured_at"],
                weight_kg=_row_value(row, "weight_kg"),
                height_cm=_row_value(row, "height_cm"),
                bmi=_row_value(row, "bmi"),
                body_fat_pct=_row_value(row, "body_fat_pct"),
                fat_mass_kg=_row_value(row, "fat_mass_kg"),
                muscle_pct=_row_value(row, "muscle_pct"),
                muscle_mass_kg=_row_value(row, "muscle_mass_kg"),
                protein_target_g=_row_value(row, "protein_target_g"),
                fat_target_g=_row_value(row, "fat_target_g"),
                waist_cm=_row_value(row, "waist_cm"),
                chest_cm=_row_value(row, "chest_cm"),
                hips_cm=_row_value(row, "hips_cm"),
                sleep_score=int_number(_row_value(row, "sleep_score")),
                wellbeing_score=int_number(_row_value(row, "wellbeing_score")),
                comment=_row_value(row, "comment"),
            )

        for row in source.execute("SELECT * FROM workout_logs ORDER BY workout_log_id"):
            exercise_id = exercise_map.get(row["exercise_id"])
            if exercise_id is None:
                continue
            WorkoutLog.create(
                user=admin,
                performed_at=row["performed_at"],
                exercise=exercise_id,
                working_weight=_row_value(row, "working_weight"),
                sets=int_number(_row_value(row, "sets")),
                reps=int_number(_row_value(row, "reps")),
                rir=_row_value(row, "rir"),
                machine_location=_row_value(row, "machine_location"),
                comment=_row_value(row, "comment"),
            )

        if _table_exists(source, "changelog"):
            for row in source.execute("SELECT * FROM changelog ORDER BY change_id"):
                Changelog.create(
                    changed_at=row["changed_at"],
                    object_code=_row_value(row, "object_id"),
                    version=_row_value(row, "version"),
                    status=_row_value(row, "status"),
                    change_type=_row_value(row, "change_type"),
                    description=_row_value(row, "description"),
                    author=_row_value(row, "author"),
                    next_action=_row_value(row, "next_action"),
                )

        codes = [
            *[product.code for product in Product.select(Product.code)],
            *[recipe.code for recipe in Recipe.select(Recipe.code)],
            *[exercise.code for exercise in Exercise.select(Exercise.code)],
        ]
        required_prefixes = ["P", "EX", *RECIPE_PREFIXES.values()]
        IdSequence.insert_many(sequence_rows(codes, required_prefixes)).execute()


def _validate_migration(source: sqlite3.Connection) -> None:
    expected_counts = {
        "products": _count(source, "products"),
        "recipes": _count(source, "recipes"),
        "exercises": _count(source, "exercises"),
        "recipe_ingredients": _count(source, "recipe_ingredients"),
        "food_diary": _count(source, "food_diary"),
        "progress": _count(source, "progress"),
        "workout_logs": _count(source, "workout_logs"),
    }
    actual_counts = {
        "products": Product.select().count(),
        "recipes": Recipe.select().count(),
        "exercises": Exercise.select().count(),
        "recipe_ingredients": RecipeIngredient.select().count(),
        "food_diary": DiaryEntry.select().count(),
        "progress": ProgressEntry.select().count(),
        "workout_logs": WorkoutLog.select().count(),
    }
    if actual_counts != expected_counts:
        raise RuntimeError(f"Migration count mismatch: expected {expected_counts}, got {actual_counts}")

    if Product.select().where(Product.code.is_null()).exists():
        raise RuntimeError("Migration produced product without code")
    if Recipe.select().where(Recipe.code.is_null()).exists():
        raise RuntimeError("Migration produced recipe without code")
    if Exercise.select().where(Exercise.code.is_null()).exists():
        raise RuntimeError("Migration produced exercise without code")


def migrate_legacy_database(settings: Settings, backup_existing: bool) -> None:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    temp_path = settings.db_path.with_name(f"{settings.db_path.name}.v2-{timestamp}.tmp")

    if backup_existing:
        backup_database(settings.db_path, settings.backup_dir, prefix="astra-pre-migrate")

    source = _connect_raw(settings.db_path)
    destination = None
    try:
        _upgrade_legacy_schema(source)
        source.commit()
        destination = _create_normalized_schema(temp_path)
        _migrate_legacy_rows(source, destination, settings)
        _validate_migration(source)
    except Exception:
        if destination is not None and not destination.is_closed():
            destination.close()
        temp_path.unlink(missing_ok=True)
        raise
    finally:
        source.close()

    if destination is not None and not destination.is_closed():
        destination.close()

    for suffix in ("-wal", "-shm"):
        settings.db_path.with_name(settings.db_path.name + suffix).unlink(missing_ok=True)
        temp_path.with_name(temp_path.name + suffix).unlink(missing_ok=True)
    os.replace(temp_path, settings.db_path)


def _create_users_table(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email VARCHAR(255) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            is_admin INTEGER NOT NULL,
            created_at VARCHAR(255) NOT NULL
        )
        """
    )
    connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS users_email ON users (email)")


def _create_oauth_tables(connection: sqlite3.Connection) -> None:
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS oauth_clients (
            client_id VARCHAR(255) PRIMARY KEY,
            client_secret_hash VARCHAR(255),
            client_secret_expires_at INTEGER,
            client_id_issued_at INTEGER NOT NULL,
            redirect_uris TEXT NOT NULL,
            token_endpoint_auth_method VARCHAR(255) NOT NULL,
            grant_types TEXT NOT NULL,
            response_types TEXT NOT NULL,
            scope TEXT,
            client_name TEXT,
            metadata_json TEXT
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS oauth_pending_authorizations (
            request_id VARCHAR(255) PRIMARY KEY,
            client_id VARCHAR(255) NOT NULL,
            redirect_uri TEXT NOT NULL,
            scopes TEXT NOT NULL,
            state TEXT,
            code_challenge TEXT NOT NULL,
            resource TEXT,
            expires_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(client_id) REFERENCES oauth_clients(client_id) ON DELETE CASCADE
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS oauth_authorization_codes (
            code_hash VARCHAR(255) PRIMARY KEY,
            client_id VARCHAR(255) NOT NULL,
            user_id INTEGER NOT NULL,
            scopes TEXT NOT NULL,
            code_challenge TEXT NOT NULL,
            redirect_uri TEXT NOT NULL,
            resource TEXT,
            expires_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            used_at INTEGER,
            FOREIGN KEY(client_id) REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS oauth_refresh_tokens (
            token_hash VARCHAR(255) PRIMARY KEY,
            client_id VARCHAR(255) NOT NULL,
            user_id INTEGER NOT NULL,
            scopes TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            revoked_at INTEGER,
            replaced_by_hash VARCHAR(255),
            FOREIGN KEY(client_id) REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
        """
    )
    for table, column in (
        ("oauth_pending_authorizations", "expires_at"),
        ("oauth_authorization_codes", "client_id"),
        ("oauth_authorization_codes", "user_id"),
        ("oauth_authorization_codes", "expires_at"),
        ("oauth_refresh_tokens", "client_id"),
        ("oauth_refresh_tokens", "user_id"),
        ("oauth_refresh_tokens", "expires_at"),
    ):
        connection.execute(f"CREATE INDEX IF NOT EXISTS {table}_{column} ON {table} ({column})")


def _add_recipe_ownership(connection: sqlite3.Connection) -> None:
    recipe_columns = _columns(connection, "recipes")
    if "owner_id" not in recipe_columns:
        connection.execute(
            "ALTER TABLE recipes ADD COLUMN owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE"
        )
    if "submission_requested" not in recipe_columns:
        connection.execute(
            "ALTER TABLE recipes ADD COLUMN submission_requested INTEGER NOT NULL DEFAULT 0"
        )
    if "submitted_by_id" not in recipe_columns:
        connection.execute("ALTER TABLE recipes ADD COLUMN submitted_by_id INTEGER REFERENCES users(id) ON DELETE SET NULL")
    if "moderation_status" not in recipe_columns:
        connection.execute("ALTER TABLE recipes ADD COLUMN moderation_status VARCHAR(255) NOT NULL DEFAULT 'none'")
    if "moderation_note" not in recipe_columns:
        connection.execute("ALTER TABLE recipes ADD COLUMN moderation_note TEXT")
    connection.execute(
        "UPDATE recipes SET moderation_status='pending', submitted_by_id=owner_id "
        "WHERE submission_requested=1 AND moderation_status='none'"
    )
    connection.execute("CREATE INDEX IF NOT EXISTS recipes_owner_id ON recipes (owner_id)")


def _rebuild_diary_entries(connection: sqlite3.Connection, admin_id: int) -> None:
    connection.execute(
        """
        CREATE TABLE diary_entries_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            entry_date VARCHAR(255) NOT NULL,
            meal_type VARCHAR(255),
            recipe_id INTEGER,
            product_id INTEGER,
            servings REAL NOT NULL CHECK(servings > 0),
            quantity REAL,
            measurement_name VARCHAR(255),
            measurement_quantity REAL,
            comment TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
            FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE SET NULL
        )
        """
    )
    connection.execute(
        """
        INSERT INTO diary_entries_v3 (
            id, user_id, entry_date, meal_type, recipe_id, product_id, servings,
            quantity, measurement_name, measurement_quantity, comment
        )
        SELECT
            id, ?, entry_date, meal_type, recipe_id, product_id, servings,
            quantity, measurement_name, measurement_quantity, comment
        FROM diary_entries
        """,
        (admin_id,),
    )
    connection.execute("DROP TABLE diary_entries")
    connection.execute("ALTER TABLE diary_entries_v3 RENAME TO diary_entries")
    connection.execute("CREATE INDEX diary_entries_user_id ON diary_entries (user_id)")
    connection.execute("CREATE INDEX diary_entries_entry_date ON diary_entries (entry_date)")
    connection.execute("CREATE INDEX diary_entries_recipe_id ON diary_entries (recipe_id)")
    connection.execute("CREATE INDEX diary_entries_product_id ON diary_entries (product_id)")


def _rebuild_progress_entries(connection: sqlite3.Connection, admin_id: int) -> None:
    connection.execute(
        """
        CREATE TABLE progress_entries_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            measured_at VARCHAR(255) NOT NULL,
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
            comment TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, measured_at)
        )
        """
    )
    connection.execute(
        """
        INSERT INTO progress_entries_v3 (
            id, user_id, measured_at, weight_kg, height_cm, bmi, body_fat_pct,
            fat_mass_kg, muscle_pct, muscle_mass_kg, protein_target_g,
            fat_target_g, waist_cm, chest_cm, hips_cm, sleep_score,
            wellbeing_score, comment
        )
        SELECT
            id, ?, measured_at, weight_kg, height_cm, bmi, body_fat_pct,
            fat_mass_kg, muscle_pct, muscle_mass_kg, protein_target_g,
            fat_target_g, waist_cm, chest_cm, hips_cm, sleep_score,
            wellbeing_score, comment
        FROM progress_entries
        """,
        (admin_id,),
    )
    connection.execute("DROP TABLE progress_entries")
    connection.execute("ALTER TABLE progress_entries_v3 RENAME TO progress_entries")
    connection.execute("CREATE INDEX progress_entries_user_id ON progress_entries (user_id)")


def _rebuild_workout_logs(connection: sqlite3.Connection, admin_id: int) -> None:
    connection.execute(
        """
        CREATE TABLE workout_logs_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            performed_at VARCHAR(255) NOT NULL,
            exercise_id INTEGER NOT NULL,
            working_weight REAL,
            sets INTEGER,
            reps INTEGER,
            rir VARCHAR(255),
            machine_location VARCHAR(255),
            comment TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(exercise_id) REFERENCES exercises(id)
        )
        """
    )
    connection.execute(
        """
        INSERT INTO workout_logs_v3 (
            id, user_id, performed_at, exercise_id, working_weight, sets, reps,
            rir, machine_location, comment
        )
        SELECT
            id, ?, performed_at, exercise_id, working_weight, sets, reps,
            rir, machine_location, comment
        FROM workout_logs
        """,
        (admin_id,),
    )
    connection.execute("DROP TABLE workout_logs")
    connection.execute("ALTER TABLE workout_logs_v3 RENAME TO workout_logs")
    connection.execute("CREATE INDEX workout_logs_user_id ON workout_logs (user_id)")
    connection.execute("CREATE INDEX workout_logs_performed_at ON workout_logs (performed_at)")
    connection.execute("CREATE INDEX workout_logs_exercise_id ON workout_logs (exercise_id)")


def migrate_v2_database(settings: Settings, backup_existing: bool) -> None:
    if backup_existing:
        backup_database(settings.db_path, settings.backup_dir, prefix="astra-pre-v3")

    connection = _connect_raw(settings.db_path)
    try:
        connection.execute("PRAGMA foreign_keys=OFF")
        _create_users_table(connection)
        admin = _admin_row(connection, settings)
        _rebuild_diary_entries(connection, admin["id"])
        _rebuild_progress_entries(connection, admin["id"])
        _rebuild_workout_logs(connection, admin["id"])
        _create_oauth_tables(connection)
        _add_recipe_ownership(connection)
        _ensure_exercise_columns(connection)
        connection.execute("INSERT OR REPLACE INTO app_meta (key, value) VALUES ('schema_version', ?)", (SCHEMA_VERSION,))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.execute("PRAGMA foreign_keys=ON")
        connection.close()


def migrate_v3_database(settings: Settings, backup_existing: bool) -> None:
    if backup_existing:
        backup_database(settings.db_path, settings.backup_dir, prefix="astra-pre-v4")

    connection = _connect_raw(settings.db_path)
    try:
        _ensure_exercise_columns(connection)
        _create_oauth_tables(connection)
        _add_recipe_ownership(connection)
        connection.execute("INSERT OR REPLACE INTO app_meta (key, value) VALUES ('schema_version', ?)", (SCHEMA_VERSION,))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def migrate_v4_database(settings: Settings, backup_existing: bool) -> None:
    if backup_existing:
        backup_database(settings.db_path, settings.backup_dir, prefix="astra-pre-v5")

    connection = _connect_raw(settings.db_path)
    try:
        _ensure_exercise_columns(connection)
        _add_recipe_ownership(connection)
        connection.execute("INSERT OR REPLACE INTO app_meta (key, value) VALUES ('schema_version', ?)", (SCHEMA_VERSION,))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def migrate_v5_database(settings: Settings, backup_existing: bool) -> None:
    migrate_v4_database(settings, backup_existing)


def ensure_database(settings: Settings) -> None:
    existed = settings.db_path.exists()
    if not existed:
        _create_legacy_database_from_template(settings)

    status = _legacy_schema_status(settings.db_path)
    if status == "normalized":
        connection = _connect_raw(settings.db_path)
        try:
            _ensure_exercise_columns(connection)
            _ensure_feedback_columns(connection)
            connection.commit()
        finally:
            connection.close()
        return
    if status == "normalized_v2":
        migrate_v2_database(settings, backup_existing=existed)
        return
    if status == "normalized_v3":
        migrate_v3_database(settings, backup_existing=existed)
        return
    if status == "normalized_v4":
        migrate_v4_database(settings, backup_existing=existed)
        return
    if status == "normalized_v5":
        migrate_v5_database(settings, backup_existing=existed)
        return
    if status == "legacy":
        migrate_legacy_database(settings, backup_existing=existed)
        return
    raise RuntimeError(f"Unsupported database schema at {settings.db_path}")
