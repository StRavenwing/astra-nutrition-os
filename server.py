from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
import json
import sqlite3
from datetime import datetime


ROOT = Path(__file__).resolve().parent
SHARED_DB = ROOT.parent / "Astra_Nutrition_OS_v7.sqlite"
DB = SHARED_DB if SHARED_DB.exists() else ROOT / "Astra_Nutrition_OS_v7.sqlite"


def db():
    connection = sqlite3.connect(DB)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    return connection


def backup_database():
    if not DB.exists():
        return
    backup_dir = ROOT.parent / "data-backups"
    backup_dir.mkdir(exist_ok=True)
    backup_path = backup_dir / f"astra-auto-{datetime.now():%Y%m%d-%H%M%S}.sqlite"
    source = sqlite3.connect(DB)
    target = sqlite3.connect(backup_path)
    with target:
        source.backup(target)
    target.close()
    source.close()
    for old_backup in sorted(backup_dir.glob("astra-auto-*.sqlite"))[:-20]:
        old_backup.unlink(missing_ok=True)


def rows(sql, args=()):
    with db() as connection:
        return [dict(row) for row in connection.execute(sql, args).fetchall()]


def number(value, default=None):
    if value in (None, ""):
        return default
    return float(value)


def product_unit_price(data):
    """Calculate price per 100 g/ml or per single item from package data."""
    package_price = number(data.get("package_price_rsd"))
    package_size = number(data.get("package_size"))
    if package_price is not None and package_size and package_size > 0:
        multiplier = 100 if data.get("unit", "г") in ("г", "мл") else 1
        return round(package_price / package_size * multiplier, 2)
    return number(data.get("price_per_100_or_unit_rsd"))


def product_kcal(data):
    """Use entered kcal, or derive it from macronutrients when it is blank."""
    kcal = number(data.get("kcal"))
    if kcal is not None:
        return kcal
    protein = number(data.get("protein_g"), 0)
    fat = number(data.get("fat_g"), 0)
    carbs = number(data.get("carbs_g"), 0)
    return round(protein * 4 + fat * 9 + carbs * 4, 2)


def progress_values(data):
    weight = number(data.get("weight_kg"))
    height = number(data.get("height_cm"))
    body_fat = number(data.get("body_fat_pct"))
    muscle = number(data.get("muscle_pct"))
    bmi = round(weight / ((height / 100) ** 2), 2) if weight and height else None
    fat_mass = round(weight * body_fat / 100, 2) if weight is not None and body_fat is not None else None
    muscle_mass = round(weight * muscle / 100, 2) if weight is not None and muscle is not None else None
    return height, bmi, body_fat, fat_mass, muscle, muscle_mass


def ensure_schema():
    additions = {
        "height_cm": "REAL", "bmi": "REAL", "body_fat_pct": "REAL",
        "fat_mass_kg": "REAL", "muscle_pct": "REAL", "muscle_mass_kg": "REAL",
    }
    with db() as connection:
        existing = {row[1] for row in connection.execute("PRAGMA table_info(progress)")}
        for column, column_type in additions.items():
            if column not in existing:
                connection.execute(f"ALTER TABLE progress ADD COLUMN {column} {column_type}")


def next_prefixed_id(connection, table, column, prefix):
    """Return the next PREFIX-001 style identifier inside a write transaction."""
    existing = connection.execute(
        f"SELECT {column} FROM {table} WHERE {column} LIKE ?",
        (f"{prefix}-%",),
    ).fetchall()
    numbers = []
    for row in existing:
        suffix = row[0].removeprefix(f"{prefix}-")
        if suffix.isdigit():
            numbers.append(int(suffix))
    return f"{prefix}-{max(numbers, default=0) + 1:03d}"


RECIPE_PREFIXES = {
    "Breakfast": "B",
    "Main": "M",
    "Wrap": "W",
    "Dessert": "D",
    "Garnish": "G",
    "Salad": "S",
    "Sauce": "SA",
    "Snack": "SN",
    "Drink": "DR",
    "Ready": "R",
}


def ensure_schema():
    """Apply small backward-compatible migrations for existing databases."""
    with db() as connection:
        recipe_columns = {
            row[1] for row in connection.execute("PRAGMA table_info(recipes)")
        }
        if "manual_price_per_serving_rsd" not in recipe_columns:
            connection.execute(
                "ALTER TABLE recipes ADD COLUMN manual_price_per_serving_rsd REAL"
            )
        manual_macro_columns = {
            "manual_kcal_per_serving": "REAL",
            "manual_protein_per_serving_g": "REAL",
            "manual_fat_per_serving_g": "REAL",
            "manual_carbs_per_serving_g": "REAL",
        }
        for column, column_type in manual_macro_columns.items():
            if column not in recipe_columns:
                connection.execute(
                    f"ALTER TABLE recipes ADD COLUMN {column} {column_type}"
                )
        diary_columns = {
            row[1] for row in connection.execute("PRAGMA table_info(food_diary)")
        }
        if "product_id" not in diary_columns:
            connection.execute("ALTER TABLE food_diary ADD COLUMN product_id TEXT")
        if "quantity" not in diary_columns:
            connection.execute("ALTER TABLE food_diary ADD COLUMN quantity REAL")

        connection.execute("DROP VIEW IF EXISTS recipe_per_serving")
        connection.execute("DROP VIEW IF EXISTS recipe_totals")
        connection.execute(
            """
            CREATE VIEW recipe_totals AS
            SELECT r.recipe_id, r.name, r.category, r.subcategory, r.version,
                   r.status, r.servings, r.tags, r.manual_price_per_serving_rsd,
                   r.manual_kcal_per_serving, r.manual_protein_per_serving_g,
                   r.manual_fat_per_serving_g, r.manual_carbs_per_serving_g,
                   ROUND(SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.price_per_100_or_unit_rsd
                       ELSE ri.quantity * p.price_per_100_or_unit_rsd / 100.0 END), 2)
                       AS recipe_cost_rsd,
                   ROUND(COALESCE(r.manual_kcal_per_serving * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.kcal
                       ELSE ri.quantity * p.kcal / 100.0 END)), 2) AS kcal,
                   ROUND(COALESCE(r.manual_protein_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.protein_g
                       ELSE ri.quantity * p.protein_g / 100.0 END)), 2) AS protein_g,
                   ROUND(COALESCE(r.manual_fat_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.fat_g
                       ELSE ri.quantity * p.fat_g / 100.0 END)), 2) AS fat_g,
                   ROUND(COALESCE(r.manual_carbs_per_serving_g * r.servings,
                       SUM(CASE WHEN p.unit IN ('шт', 'бут.')
                       THEN ri.quantity * p.carbs_g
                       ELSE ri.quantity * p.carbs_g / 100.0 END)), 2) AS carbs_g
            FROM recipes r
            LEFT JOIN recipe_ingredients ri ON ri.recipe_id = r.recipe_id
            LEFT JOIN products p ON p.product_id = ri.product_id
            GROUP BY r.recipe_id
            """
        )
        connection.execute(
            """
            CREATE VIEW recipe_per_serving AS
            SELECT *,
                   ROUND(COALESCE(manual_price_per_serving_rsd,
                       recipe_cost_rsd / servings), 2) AS cost_per_serving_rsd,
                   ROUND(kcal / servings, 2) AS kcal_per_serving,
                   ROUND(protein_g / servings, 2) AS protein_per_serving_g,
                   ROUND(fat_g / servings, 2) AS fat_per_serving_g,
                   ROUND(carbs_g / servings, 2) AS carbs_per_serving_g
            FROM recipe_totals
            """
        )


ensure_schema()


class App(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_json(self, data, status=200):
        raw = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def body(self):
        size = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(size) or b"{}")

    def do_GET(self):
        path = urlparse(self.path).path
        try:
            if path == "/api/dashboard":
                return self.send_json(
                    {
                        "products": rows("SELECT COUNT(*) n FROM products")[0]["n"],
                        "recipes": rows("SELECT COUNT(*) n FROM recipes")[0]["n"],
                        "approved": rows(
                            "SELECT COUNT(*) n FROM recipes WHERE status='Approved'"
                        )[0]["n"],
                        "latest": rows(
                            "SELECT weight_kg, waist_cm, height_cm, bmi, body_fat_pct, "
                            "fat_mass_kg, muscle_pct, muscle_mass_kg, measured_at FROM progress "
                            "ORDER BY measured_at DESC LIMIT 1"
                        ),
                        "top": rows(
                            "SELECT recipe_id, name, kcal_per_serving, "
                            "protein_per_serving_g, cost_per_serving_rsd "
                            "FROM recipe_per_serving "
                            "ORDER BY protein_per_serving_g DESC LIMIT 6"
                        ),
                    }
                )

            if path == "/api/products":
                return self.send_json(rows("SELECT * FROM products ORDER BY category, name"))
            if path == "/api/recipes":
                return self.send_json(
                    rows("SELECT * FROM recipe_per_serving ORDER BY category, name")
                )
            if path.startswith("/api/recipes/"):
                recipe_id = path.split("/")[-1]
                ingredient_sql = """
                    SELECT ri.product_id, p.name, ri.quantity, ri.unit,
                           ri.portion_description,
                           ROUND(CASE WHEN p.unit IN ('шт', 'бут.')
                                THEN ri.quantity * p.kcal
                                ELSE ri.quantity * p.kcal / 100.0 END, 2) kcal,
                           ROUND(CASE WHEN p.unit IN ('шт', 'бут.')
                                THEN ri.quantity * p.protein_g
                                ELSE ri.quantity * p.protein_g / 100.0 END, 2) protein_g,
                           ROUND(CASE WHEN p.unit IN ('шт', 'бут.')
                                THEN ri.quantity * p.fat_g
                                ELSE ri.quantity * p.fat_g / 100.0 END, 2) fat_g,
                           ROUND(CASE WHEN p.unit IN ('шт', 'бут.')
                                THEN ri.quantity * p.carbs_g
                                ELSE ri.quantity * p.carbs_g / 100.0 END, 2) carbs_g,
                           ROUND(CASE WHEN p.unit IN ('шт', 'бут.')
                                THEN ri.quantity * p.price_per_100_or_unit_rsd
                                ELSE ri.quantity * p.price_per_100_or_unit_rsd / 100.0 END, 2) cost_rsd
                    FROM recipe_ingredients ri
                    JOIN products p USING(product_id)
                    WHERE ri.recipe_id = ?
                    ORDER BY ri.recipe_ingredient_id
                """
                return self.send_json(
                    {
                        "recipe": rows(
                            "SELECT * FROM recipe_per_serving WHERE recipe_id = ?",
                            (recipe_id,),
                        ),
                        "ingredients": rows(ingredient_sql, (recipe_id,)),
                    }
                )
            if path == "/api/diary":
                return self.send_json(
                    rows(
                        "SELECT fd.*, COALESCE(r.name, p.name) AS name, p.unit, "
                        "CASE WHEN fd.product_id IS NULL THEN 'recipe' ELSE 'product' END AS item_type, "
                        "CASE WHEN fd.product_id IS NULL THEN rps.kcal_per_serving "
                        "     WHEN p.unit IN ('шт', 'бут.') THEN fd.quantity * p.kcal "
                        "     ELSE fd.quantity * p.kcal / 100.0 END AS kcal_per_serving, "
                        "CASE WHEN fd.product_id IS NULL THEN rps.protein_per_serving_g "
                        "     WHEN p.unit IN ('шт', 'бут.') THEN fd.quantity * p.protein_g "
                        "     ELSE fd.quantity * p.protein_g / 100.0 END AS protein_per_serving_g, "
                        "CASE WHEN fd.product_id IS NULL THEN rps.fat_per_serving_g "
                        "     WHEN p.unit IN ('шт', 'бут.') THEN fd.quantity * p.fat_g "
                        "     ELSE fd.quantity * p.fat_g / 100.0 END AS fat_per_serving_g, "
                        "CASE WHEN fd.product_id IS NULL THEN rps.carbs_per_serving_g "
                        "     WHEN p.unit IN ('шт', 'бут.') THEN fd.quantity * p.carbs_g "
                        "     ELSE fd.quantity * p.carbs_g / 100.0 END AS carbs_per_serving_g, "
                        "CASE WHEN fd.product_id IS NULL THEN rps.cost_per_serving_rsd "
                        "     WHEN p.unit IN ('шт', 'бут.') THEN fd.quantity * p.price_per_100_or_unit_rsd "
                        "     ELSE fd.quantity * p.price_per_100_or_unit_rsd / 100.0 END AS cost_per_serving_rsd "
                        "FROM food_diary fd "
                        "LEFT JOIN recipes r USING(recipe_id) "
                        "LEFT JOIN recipe_per_serving rps USING(recipe_id) "
                        "LEFT JOIN products p ON p.product_id = fd.product_id "
                        "ORDER BY entry_date DESC, diary_id DESC"
                    )
                )
            if path == "/api/progress":
                return self.send_json(rows("SELECT * FROM progress ORDER BY measured_at DESC"))
            if path == "/api/workouts":
                return self.send_json(
                    rows(
                        "SELECT wl.*, e.name, e.muscle_group, e.default_unit "
                        "FROM workout_logs wl JOIN exercises e USING(exercise_id) "
                        "ORDER BY performed_at DESC, workout_log_id DESC"
                    )
                )
            if path == "/api/exercises":
                return self.send_json(
                    rows("SELECT * FROM exercises ORDER BY muscle_group, name")
                )
            return super().do_GET()
        except Exception as error:
            return self.send_json({"error": str(error)}, 500)

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            data = self.body()
            with db() as connection:
                connection.execute("BEGIN IMMEDIATE")
                if path == "/api/exercises":
                    exercise_id = next_prefixed_id(
                        connection, "exercises", "exercise_id", "E"
                    )
                    connection.execute(
                        "INSERT INTO exercises"
                        "(exercise_id, muscle_group, name, default_unit, "
                        "default_sets, default_reps, target_rir, note) "
                        "VALUES (?,?,?,?,?,?,?,?)",
                        (
                            exercise_id, data.get("muscle_group"), data["name"],
                            data.get("default_unit", "кг"),
                            int(number(data.get("default_sets"), 3)),
                            int(number(data.get("default_reps"), 12)),
                            data.get("target_rir", "0–2"), data.get("note"),
                        ),
                    )
                elif path == "/api/products":
                    product_id = next_prefixed_id(
                        connection, "products", "product_id", "P"
                    )
                    connection.execute(
                        "INSERT INTO products VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            product_id, data["name"], data.get("category"),
                            data.get("unit", "г"), number(data.get("package_price_rsd")),
                            number(data.get("package_size")),
                            product_unit_price(data),
                            product_kcal(data), number(data.get("protein_g"), 0),
                            number(data.get("fat_g"), 0), number(data.get("carbs_g"), 0),
                            data.get("data_status", "Подтверждено"), data.get("note"),
                        ),
                    )
                elif path == "/api/recipes":
                    prefix = RECIPE_PREFIXES.get(data["category"])
                    if not prefix:
                        raise ValueError("Неизвестная категория рецепта")
                    recipe_id = next_prefixed_id(
                        connection, "recipes", "recipe_id", prefix
                    )
                    connection.execute(
                        "INSERT INTO recipes"
                        "(recipe_id, name, category, subcategory, version, status, "
                        "servings, tags, manual_price_per_serving_rsd, "
                        "manual_kcal_per_serving, manual_protein_per_serving_g, "
                        "manual_fat_per_serving_g, manual_carbs_per_serving_g) "
                        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            recipe_id, data["name"], data["category"],
                            data.get("subcategory"), data.get("version", "1.0"),
                            data.get("status", "Draft"), number(data.get("servings"), 1),
                            data.get("tags"),
                            number(data.get("manual_price_per_serving_rsd")),
                            number(data.get("manual_kcal_per_serving")),
                            number(data.get("manual_protein_per_serving_g")),
                            number(data.get("manual_fat_per_serving_g")),
                            number(data.get("manual_carbs_per_serving_g")),
                        ),
                    )
                    for ingredient in data.get("ingredients", []):
                        connection.execute(
                            "INSERT INTO recipe_ingredients"
                            "(recipe_id, product_id, quantity, unit, portion_description) "
                            "VALUES (?,?,?,?,?)",
                            (
                                recipe_id, ingredient["product_id"],
                                number(ingredient["quantity"]), ingredient.get("unit", "г"),
                                ingredient.get("portion_description"),
                            ),
                        )
                elif path == "/api/diary":
                    diary_items = data.get("items") or [data]
                    for item in diary_items:
                        connection.execute(
                            "INSERT INTO food_diary"
                            "(entry_date, meal_type, recipe_id, servings, comment, "
                            "product_id, quantity) VALUES (?,?,?,?,?,?,?)",
                            (
                                data.get("entry_date") or item["entry_date"],
                                item.get("meal_type"), item.get("recipe_id"),
                                number(item.get("servings"), 1), item.get("comment"),
                                item.get("product_id"), number(item.get("quantity")),
                            ),
                        )
                elif path == "/api/progress":
                    height, bmi, body_fat, fat_mass, muscle, muscle_mass = progress_values(data)
                    connection.execute(
                        "INSERT INTO progress"
                        "(measured_at, weight_kg, waist_cm, chest_cm, hips_cm, "
                        "sleep_score, wellbeing_score, comment, height_cm, bmi, "
                        "body_fat_pct, fat_mass_kg, muscle_pct, muscle_mass_kg) "
                        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            data["measured_at"], number(data.get("weight_kg")),
                            number(data.get("waist_cm")), number(data.get("chest_cm")),
                            number(data.get("hips_cm")), number(data.get("sleep_score")),
                            number(data.get("wellbeing_score")), data.get("comment"),
                            height, bmi, body_fat, fat_mass, muscle, muscle_mass,
                        ),
                    )
                elif path == "/api/workouts":
                    exercise_id = data.get("exercise_id")
                    if not exercise_id:
                        exercise_id = next_prefixed_id(
                            connection, "exercises", "exercise_id", "EX"
                        )
                        connection.execute(
                            "INSERT INTO exercises VALUES (?,?,?,?,?,?,?,?)",
                            (
                                exercise_id, data["exercise_name"], data.get("muscle_group"),
                                data.get("unit", "кг"), number(data.get("sets"), 3),
                                number(data.get("reps"), 12), data.get("rir", "0–2"),
                                data.get("comment"),
                            ),
                        )
                    connection.execute(
                        "INSERT INTO workout_logs"
                        "(performed_at, exercise_id, working_weight, sets, reps, rir, "
                        "machine_location, comment) VALUES (?,?,?,?,?,?,?,?)",
                        (
                            data["performed_at"], exercise_id,
                            number(data.get("working_weight")), number(data.get("sets")),
                            number(data.get("reps")), data.get("rir"),
                            data.get("machine_location"), data.get("comment"),
                        ),
                    )
                else:
                    return self.send_json({"error": "Not found"}, 404)
            return self.send_json({"ok": True}, 201)
        except sqlite3.IntegrityError as error:
            return self.send_json({"error": str(error)}, 409)
        except Exception as error:
            return self.send_json({"error": str(error)}, 400)

    def do_DELETE(self):
        path = urlparse(self.path).path
        try:
            with db() as connection:
                connection.execute("BEGIN IMMEDIATE")
                if path.startswith("/api/exercises/"):
                    exercise_id = path.split("/")[-1]
                    usage_count = connection.execute(
                        "SELECT COUNT(*) FROM workout_logs WHERE exercise_id = ?",
                        (exercise_id,),
                    ).fetchone()[0]
                    if usage_count:
                        return self.send_json(
                            {"error": f"Упражнение используется в тренировках: {usage_count}. "
                                      "Сначала удалите связанные записи тренировок."}, 409
                        )
                    cursor = connection.execute(
                        "DELETE FROM exercises WHERE exercise_id = ?", (exercise_id,)
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Упражнение не найдено"}, 404)
                    result = {"ok": True}
                elif path.startswith("/api/recipes/"):
                    recipe_id = path.split("/")[-1]
                    exists = connection.execute(
                        "SELECT 1 FROM recipes WHERE recipe_id = ?", (recipe_id,)
                    ).fetchone()
                    if not exists:
                        return self.send_json({"error": "Рецепт не найден"}, 404)
                    diary_count = connection.execute(
                        "SELECT COUNT(*) FROM food_diary WHERE recipe_id = ?",
                        (recipe_id,),
                    ).fetchone()[0]
                    connection.execute(
                        "DELETE FROM food_diary WHERE recipe_id = ?", (recipe_id,)
                    )
                    connection.execute(
                        "DELETE FROM recipes WHERE recipe_id = ?", (recipe_id,)
                    )
                    result = {"ok": True, "deleted_diary_entries": diary_count}
                elif path.startswith("/api/products/"):
                    product_id = path.split("/")[-1]
                    exists = connection.execute(
                        "SELECT 1 FROM products WHERE product_id = ?", (product_id,)
                    ).fetchone()
                    if not exists:
                        return self.send_json({"error": "Продукт не найден"}, 404)
                    recipe_count = connection.execute(
                        "SELECT COUNT(DISTINCT recipe_id) FROM recipe_ingredients "
                        "WHERE product_id = ?", (product_id,)
                    ).fetchone()[0]
                    if recipe_count:
                        return self.send_json(
                            {"error": f"Продукт используется в рецептах: {recipe_count}. "
                                      "Сначала удалите его из состава этих рецептов."}, 409
                        )
                    diary_count = connection.execute(
                        "SELECT COUNT(*) FROM food_diary WHERE product_id = ?",
                        (product_id,),
                    ).fetchone()[0]
                    if diary_count:
                        return self.send_json(
                            {"error": f"Продукт используется в дневнике питания: {diary_count}. "
                                      "Сначала удалите связанные записи дневника."}, 409
                        )
                    connection.execute(
                        "DELETE FROM products WHERE product_id = ?", (product_id,)
                    )
                    result = {"ok": True}
                elif path.startswith("/api/diary/"):
                    diary_id = path.split("/")[-1]
                    cursor = connection.execute(
                        "DELETE FROM food_diary WHERE diary_id = ?", (diary_id,)
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Запись не найдена"}, 404)
                    result = {"ok": True}
                elif path.startswith("/api/progress/"):
                    progress_id = path.split("/")[-1]
                    cursor = connection.execute(
                        "DELETE FROM progress WHERE progress_id = ?", (progress_id,)
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Замер не найден"}, 404)
                    result = {"ok": True}
                elif path.startswith("/api/workouts/"):
                    workout_log_id = path.split("/")[-1]
                    cursor = connection.execute(
                        "DELETE FROM workout_logs WHERE workout_log_id = ?",
                        (workout_log_id,),
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Тренировка не найдена"}, 404)
                    result = {"ok": True}
                else:
                    return self.send_json({"error": "Not found"}, 404)
            return self.send_json(result)
        except sqlite3.IntegrityError as error:
            return self.send_json({"error": str(error)}, 409)
        except Exception as error:
            return self.send_json({"error": str(error)}, 400)

    def do_PUT(self):
        path = urlparse(self.path).path
        if path.startswith("/api/progress/"):
            progress_id = path.split("/")[-1]
            try:
                data = self.body()
                height, bmi, body_fat, fat_mass, muscle, muscle_mass = progress_values(data)
                with db() as connection:
                    connection.execute("BEGIN IMMEDIATE")
                    cursor = connection.execute(
                        """
                        UPDATE progress
                        SET measured_at = ?, weight_kg = ?, waist_cm = ?, chest_cm = ?,
                            hips_cm = ?, sleep_score = ?, wellbeing_score = ?, comment = ?,
                            height_cm = ?, bmi = ?, body_fat_pct = ?, fat_mass_kg = ?,
                            muscle_pct = ?, muscle_mass_kg = ?
                        WHERE progress_id = ?
                        """,
                        (
                            data["measured_at"], number(data.get("weight_kg")),
                            number(data.get("waist_cm")), number(data.get("chest_cm")),
                            number(data.get("hips_cm")), number(data.get("sleep_score")),
                            number(data.get("wellbeing_score")), data.get("comment"),
                            height, bmi, body_fat, fat_mass, muscle, muscle_mass,
                            progress_id,
                        ),
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Замер не найден"}, 404)
                return self.send_json({"ok": True, "progress_id": int(progress_id)})
            except sqlite3.IntegrityError as error:
                return self.send_json({"error": "На эту дату уже существует замер"}, 409)
            except Exception as error:
                return self.send_json({"error": str(error)}, 400)
        if path.startswith("/api/workouts/"):
            workout_log_id = path.split("/")[-1]
            try:
                data = self.body()
                with db() as connection:
                    connection.execute("BEGIN IMMEDIATE")
                    cursor = connection.execute(
                        """
                        UPDATE workout_logs
                        SET performed_at = ?, exercise_id = ?, working_weight = ?,
                            sets = ?, reps = ?, rir = ?, machine_location = ?, comment = ?
                        WHERE workout_log_id = ?
                        """,
                        (
                            data["performed_at"], data["exercise_id"],
                            number(data.get("working_weight")), number(data.get("sets")),
                            number(data.get("reps")), data.get("rir"),
                            data.get("machine_location"), data.get("comment"),
                            workout_log_id,
                        ),
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Тренировка не найдена"}, 404)
                return self.send_json({"ok": True, "workout_log_id": int(workout_log_id)})
            except sqlite3.IntegrityError as error:
                return self.send_json({"error": str(error)}, 409)
            except Exception as error:
                return self.send_json({"error": str(error)}, 400)
        if path.startswith("/api/products/"):
            product_id = path.split("/")[-1]
            try:
                data = self.body()
                with db() as connection:
                    connection.execute("BEGIN IMMEDIATE")
                    cursor = connection.execute(
                        """
                        UPDATE products
                        SET name = ?, category = ?, unit = ?, package_price_rsd = ?,
                            package_size = ?, price_per_100_or_unit_rsd = ?, kcal = ?,
                            protein_g = ?, fat_g = ?, carbs_g = ?, data_status = ?,
                            note = ?
                        WHERE product_id = ?
                        """,
                        (
                            data["name"], data.get("category"), data.get("unit", "г"),
                            number(data.get("package_price_rsd")),
                            number(data.get("package_size")),
                            product_unit_price(data),
                            product_kcal(data), number(data.get("protein_g"), 0),
                            number(data.get("fat_g"), 0), number(data.get("carbs_g"), 0),
                            data.get("data_status", "Подтверждено"), data.get("note"),
                            product_id,
                        ),
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Продукт не найден"}, 404)
                return self.send_json({"ok": True, "product_id": product_id})
            except sqlite3.IntegrityError as error:
                return self.send_json({"error": str(error)}, 409)
            except Exception as error:
                return self.send_json({"error": str(error)}, 400)
        if path.startswith("/api/diary/"):
            diary_id = path.split("/")[-1]
            try:
                data = self.body()
                with db() as connection:
                    connection.execute("BEGIN IMMEDIATE")
                    cursor = connection.execute(
                        """
                        UPDATE food_diary
                        SET entry_date = ?, meal_type = ?, recipe_id = ?,
                            servings = ?, comment = ?, product_id = ?, quantity = ?
                        WHERE diary_id = ?
                        """,
                        (
                            data["entry_date"], data.get("meal_type"),
                            data.get("recipe_id"), number(data.get("servings"), 1),
                            data.get("comment"), data.get("product_id"),
                            number(data.get("quantity")), diary_id,
                        ),
                    )
                    if not cursor.rowcount:
                        return self.send_json({"error": "Запись не найдена"}, 404)
                return self.send_json({"ok": True, "diary_id": int(diary_id)})
            except sqlite3.IntegrityError as error:
                return self.send_json({"error": str(error)}, 409)
            except Exception as error:
                return self.send_json({"error": str(error)}, 400)
        if not path.startswith("/api/recipes/"):
            return self.send_json({"error": "Not found"}, 404)
        recipe_id = path.split("/")[-1]
        try:
            data = self.body()
            with db() as connection:
                connection.execute("BEGIN IMMEDIATE")
                current = connection.execute(
                    "SELECT * FROM recipes WHERE recipe_id = ?", (recipe_id,)
                ).fetchone()
                if not current:
                    return self.send_json({"error": "Рецепт не найден"}, 404)
                new_category = data.get("category", current["category"])
                prefix = RECIPE_PREFIXES.get(new_category)
                if not prefix:
                    raise ValueError("Неизвестная категория рецепта")
                new_recipe_id = recipe_id
                if new_category != current["category"]:
                    new_recipe_id = next_prefixed_id(
                        connection, "recipes", "recipe_id", prefix
                    )
                    connection.execute(
                        """
                        INSERT INTO recipes
                        (recipe_id, name, category, subcategory, version, status,
                         servings, tags, manual_price_per_serving_rsd,
                         manual_kcal_per_serving, manual_protein_per_serving_g,
                         manual_fat_per_serving_g, manual_carbs_per_serving_g)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                        """,
                        (
                            new_recipe_id, data["name"], new_category,
                            data.get("subcategory"), data.get("version", "1.0"),
                            data.get("status", "Draft"),
                            number(data.get("servings"), 1), data.get("tags"),
                            number(data.get("manual_price_per_serving_rsd")),
                            number(data.get("manual_kcal_per_serving")),
                            number(data.get("manual_protein_per_serving_g")),
                            number(data.get("manual_fat_per_serving_g")),
                            number(data.get("manual_carbs_per_serving_g")),
                        ),
                    )
                    connection.execute(
                        "UPDATE food_diary SET recipe_id = ? WHERE recipe_id = ?",
                        (new_recipe_id, recipe_id),
                    )
                    connection.execute(
                        "DELETE FROM recipes WHERE recipe_id = ?", (recipe_id,)
                    )
                else:
                    connection.execute(
                        """
                        UPDATE recipes
                        SET name = ?, subcategory = ?, version = ?, status = ?,
                            servings = ?, tags = ?, manual_price_per_serving_rsd = ?,
                            manual_kcal_per_serving = ?,
                            manual_protein_per_serving_g = ?,
                            manual_fat_per_serving_g = ?,
                            manual_carbs_per_serving_g = ?
                        WHERE recipe_id = ?
                        """,
                        (
                            data["name"], data.get("subcategory"),
                            data.get("version", "1.0"), data.get("status", "Draft"),
                            number(data.get("servings"), 1), data.get("tags"),
                            number(data.get("manual_price_per_serving_rsd")),
                            number(data.get("manual_kcal_per_serving")),
                            number(data.get("manual_protein_per_serving_g")),
                            number(data.get("manual_fat_per_serving_g")),
                            number(data.get("manual_carbs_per_serving_g")), recipe_id,
                        ),
                    )
                    connection.execute(
                        "DELETE FROM recipe_ingredients WHERE recipe_id = ?", (recipe_id,)
                    )
                for ingredient in data.get("ingredients", []):
                    connection.execute(
                        "INSERT INTO recipe_ingredients"
                        "(recipe_id, product_id, quantity, unit, portion_description) "
                        "VALUES (?,?,?,?,?)",
                        (
                            new_recipe_id, ingredient["product_id"],
                            number(ingredient["quantity"]), ingredient.get("unit", "г"),
                            ingredient.get("portion_description"),
                        ),
                    )
            return self.send_json({"ok": True, "recipe_id": new_recipe_id})
        except sqlite3.IntegrityError as error:
            return self.send_json({"error": str(error)}, 409)
        except Exception as error:
            return self.send_json({"error": str(error)}, 400)


if __name__ == "__main__":
    ensure_schema()
    backup_database()
    print("Astra Nutrition OS: http://127.0.0.1:8787")
    ThreadingHTTPServer(("127.0.0.1", 8787), App).serve_forever()
