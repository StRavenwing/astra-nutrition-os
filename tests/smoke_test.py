"""FastAPI smoke test used locally and by GitHub Actions."""

from __future__ import annotations

import os
from pathlib import Path
import sys
import tempfile

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="astra-ci-") as temp_dir:
        os.environ["ASTRA_DB_PATH"] = str(Path(temp_dir) / "astra-test.sqlite")
        os.environ["ASTRA_BACKUP_DIR"] = str(Path(temp_dir) / "backups")
        os.chdir(ROOT)
        sys.path.insert(0, str(ROOT))

        from backend.app import create_app

        app = create_app()
        with TestClient(app) as client:
            response = client.get("/api/health")
            assert response.status_code == 200
            assert response.json() == {"status": "ok"}

            response = client.get("/api/v1/dashboard")
            dashboard = response.json()
            assert response.status_code == 200
            assert dashboard["products"] > 0
            assert dashboard["recipes"] > 0
            assert dashboard["latest"] is None or "weight_kg" in dashboard["latest"]
            assert all("id" in recipe and "code" in recipe for recipe in dashboard["top"])

            response = client.post(
                "/api/v1/products",
                json={
                    "name": "Соус для smoke-теста",
                    "category": "Соусы",
                    "unit": "мл",
                    "protein_g": 1,
                    "fat_g": 0,
                    "carbs_g": 2,
                },
            )
            assert response.status_code == 201, response.text
            created_product = response.json()
            assert created_product["code"].startswith("P-")
            assert {
                item["measure_name"]: item["base_quantity"]
                for item in created_product["measures"]
            } == {
                "ч. л.": 5.0,
                "ст. л.": 15.0,
                "стакан (200 мл)": 200.0,
            }

            response = client.put(
                f"/api/v1/products/{created_product['id']}",
                json={
                    "name": "Соус для smoke-теста",
                    "category": "Соусы",
                    "unit": "мл",
                    "protein_g": 1,
                    "fat_g": 0,
                    "carbs_g": 2,
                    "measures": [
                        {"measure_name": "ч. л.", "base_quantity": 6},
                        {"measure_name": "ст. л.", "base_quantity": 18},
                        {"measure_name": "стакан (200 мл)", "base_quantity": 240},
                    ],
                },
            )
            assert response.status_code == 200, response.text
            custom_product = response.json()
            assert {
                item["measure_name"]: item["base_quantity"]
                for item in custom_product["measures"]
            } == {
                "ч. л.": 6.0,
                "ст. л.": 18.0,
                "стакан (200 мл)": 240.0,
            }

            response = client.post(
                "/api/v1/recipes",
                json={
                    "category": "Sauce",
                    "name": "Smoke recipe",
                    "servings": 2,
                    "ingredients": [
                        {
                            "product_id": created_product["id"],
                            "measurement_quantity": 1,
                            "measurement_name": "ст. л.",
                        }
                    ],
                },
            )
            assert response.status_code == 201, response.text
            recipe = response.json()
            response = client.get(f"/api/v1/recipes/{recipe['id']}")
            detail = response.json()
            assert response.status_code == 200
            assert detail["recipe"]["id"] == recipe["id"]
            assert detail["ingredients"][0]["quantity"] == 18.0

            response = client.post(
                "/api/v1/diary",
                json={
                    "entry_date": "2026-08-02",
                    "items": [
                        {"meal_type": "Обед", "recipe_id": recipe["id"], "servings": 1},
                        {
                            "meal_type": "Перекус",
                            "product_id": created_product["id"],
                            "measurement_quantity": 1,
                            "measurement_name": "ч. л.",
                            "servings": 1,
                        },
                    ],
                },
            )
            assert response.status_code == 201, response.text
            diary_items = response.json()
            assert len(diary_items) == 2
            assert {item["item_type"] for item in diary_items} == {"recipe", "product"}

            response = client.post(
                "/api/v1/progress",
                json={
                    "measured_at": "2026-08-02",
                    "weight_kg": 70,
                    "height_cm": 169,
                    "body_fat_pct": 25,
                    "muscle_pct": 40,
                },
            )
            assert response.status_code == 201, response.text
            progress = response.json()
            assert progress["bmi"] == 24.51
            assert progress["fat_mass_kg"] == 17.5

            response = client.post(
                "/api/v1/exercises",
                json={"name": "Smoke exercise", "muscle_group": "Кор"},
            )
            assert response.status_code == 201, response.text
            exercise = response.json()
            response = client.post(
                "/api/v1/workouts",
                json={
                    "performed_at": "2026-08-02",
                    "exercise_id": exercise["id"],
                    "sets": 3,
                    "reps": 12,
                    "working_weight": 10,
                },
            )
            assert response.status_code == 201, response.text
            workout = response.json()
            assert workout["exercise_id"] == exercise["id"]
            assert client.delete(f"/api/v1/workouts/{workout['id']}").status_code == 200
            assert client.delete(f"/api/v1/exercises/{exercise['id']}").status_code == 200

            response = client.get("/manifest.webmanifest")
            manifest = response.json()
            assert response.status_code == 200
            assert response.headers["content-type"].startswith("application/manifest+json")
            assert manifest["display"] == "standalone"
            assert {icon["sizes"] for icon in manifest["icons"]} >= {"192x192", "512x512"}

            response = client.get("/")
            assert response.status_code == 200
            assert b'id="app"' in response.content
            assert b"/assets/app-icon-192.png" in response.content

            response = client.get("/service-worker.js")
            assert response.headers["content-type"].startswith("text/javascript")
            assert response.headers["cache-control"] == "no-cache"
            assert b"CACHE_NAME" in response.content

            response = client.get("/assets/app-icon-192.png")
            assert response.headers["content-type"].startswith("image/png")
            assert response.content.startswith(b"\x89PNG")

    print("Astra smoke test passed")


if __name__ == "__main__":
    main()
