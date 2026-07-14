from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
import json
import sqlite3


ROOT = Path(__file__).resolve().parent
DB = ROOT / "Astra_Nutrition_OS_v7.sqlite"


def db():
    connection = sqlite3.connect(DB)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys=ON")
    return connection


def rows(sql, args=()):
    with db() as connection:
        return [dict(row) for row in connection.execute(sql, args).fetchall()]


def number(value, default=None):
    if value in (None, ""):
        return default
    return float(value)


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
                            "SELECT weight_kg, waist_cm, measured_at FROM progress "
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
                        "SELECT fd.*, r.name, rps.kcal_per_serving, "
                        "rps.protein_per_serving_g FROM food_diary fd "
                        "LEFT JOIN recipes r USING(recipe_id) "
                        "LEFT JOIN recipe_per_serving rps USING(recipe_id) "
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
                if path == "/api/products":
                    connection.execute(
                        "INSERT INTO products VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (
                            data["product_id"], data["name"], data.get("category"),
                            data.get("unit", "г"), number(data.get("package_price_rsd")),
                            number(data.get("package_size")),
                            number(data.get("price_per_100_or_unit_rsd")),
                            number(data.get("kcal"), 0), number(data.get("protein_g"), 0),
                            number(data.get("fat_g"), 0), number(data.get("carbs_g"), 0),
                            data.get("data_status", "Подтверждено"), data.get("note"),
                        ),
                    )
                elif path == "/api/recipes":
                    connection.execute(
                        "INSERT INTO recipes VALUES (?,?,?,?,?,?,?,?)",
                        (
                            data["recipe_id"], data["name"], data["category"],
                            data.get("subcategory"), data.get("version", "1.0"),
                            data.get("status", "Draft"), number(data.get("servings"), 1),
                            data.get("tags"),
                        ),
                    )
                    for ingredient in data.get("ingredients", []):
                        connection.execute(
                            "INSERT INTO recipe_ingredients"
                            "(recipe_id, product_id, quantity, unit, portion_description) "
                            "VALUES (?,?,?,?,?)",
                            (
                                data["recipe_id"], ingredient["product_id"],
                                number(ingredient["quantity"]), ingredient.get("unit", "г"),
                                ingredient.get("portion_description"),
                            ),
                        )
                elif path == "/api/diary":
                    connection.execute(
                        "INSERT INTO food_diary"
                        "(entry_date, meal_type, recipe_id, servings, comment) VALUES (?,?,?,?,?)",
                        (
                            data["entry_date"], data.get("meal_type"), data.get("recipe_id"),
                            number(data.get("servings"), 1), data.get("comment"),
                        ),
                    )
                elif path == "/api/progress":
                    connection.execute(
                        "INSERT INTO progress"
                        "(measured_at, weight_kg, waist_cm, chest_cm, hips_cm, "
                        "sleep_score, wellbeing_score, comment) VALUES (?,?,?,?,?,?,?,?)",
                        (
                            data["measured_at"], number(data.get("weight_kg")),
                            number(data.get("waist_cm")), number(data.get("chest_cm")),
                            number(data.get("hips_cm")), number(data.get("sleep_score")),
                            number(data.get("wellbeing_score")), data.get("comment"),
                        ),
                    )
                elif path == "/api/workouts":
                    exercise_id = data.get("exercise_id")
                    if not exercise_id:
                        exercise_id = data["new_exercise_id"]
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


if __name__ == "__main__":
    print("Astra Nutrition OS: http://127.0.0.1:8787")
    ThreadingHTTPServer(("127.0.0.1", 8787), App).serve_forever()
