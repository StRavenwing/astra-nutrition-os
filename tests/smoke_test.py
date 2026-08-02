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
        os.environ["ASTRA_ADMIN_EMAIL"] = "admin@example.com"
        os.environ["ASTRA_ADMIN_PASSWORD"] = "admin-password"
        os.environ["ASTRA_AUTH_SECRET"] = "test-secret-with-at-least-thirty-two-bytes"
        os.chdir(ROOT)
        sys.path.insert(0, str(ROOT))

        from backend.app import create_app

        app = create_app()
        with TestClient(app) as client:
            response = client.get("/api/health")
            assert response.status_code == 200
            assert response.json() == {"status": "ok"}

            response = client.get("/api/v1/dashboard")
            assert response.status_code == 401

            response = client.post(
                "/api/v1/auth/login",
                json={"email": "ADMIN@example.com", "password": "admin-password"},
            )
            assert response.status_code == 200, response.text
            admin_auth = response.json()
            admin_headers = {"Authorization": f"Bearer {admin_auth['access_token']}"}
            assert admin_auth["user"]["email"] == "admin@example.com"
            assert admin_auth["user"]["is_admin"] is True

            response = client.get("/api/v1/auth/me", headers=admin_headers)
            assert response.status_code == 200
            assert response.json()["email"] == "admin@example.com"

            response = client.get("/api/v1/dashboard", headers=admin_headers)
            dashboard = response.json()
            assert response.status_code == 200
            assert dashboard["products"] > 0
            assert dashboard["recipes"] > 0
            assert dashboard["latest"] is None or "weight_kg" in dashboard["latest"]
            assert all("id" in recipe and "code" in recipe for recipe in dashboard["top"])
            assert len(client.get("/api/v1/diary", headers=admin_headers).json()) > 0

            response = client.post(
                "/api/v1/products",
                headers=admin_headers,
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
                headers=admin_headers,
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
                headers=admin_headers,
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
            response = client.get(f"/api/v1/recipes/{recipe['id']}", headers=admin_headers)
            detail = response.json()
            assert response.status_code == 200
            assert detail["recipe"]["id"] == recipe["id"]
            assert detail["ingredients"][0]["quantity"] == 18.0

            response = client.post(
                "/api/v1/diary",
                headers=admin_headers,
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
                headers=admin_headers,
                json={
                    "measured_at": "2099-01-01",
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
                headers=admin_headers,
                json={"name": "Smoke exercise", "muscle_group": "Кор"},
            )
            assert response.status_code == 201, response.text
            exercise = response.json()
            response = client.post(
                "/api/v1/workouts",
                headers=admin_headers,
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

            response = client.post(
                "/api/v1/auth/register",
                json={"email": "user@example.com", "password": "user-password"},
            )
            assert response.status_code == 201, response.text
            user_auth = response.json()
            user_headers = {"Authorization": f"Bearer {user_auth['access_token']}"}
            assert user_auth["user"]["is_admin"] is False

            response = client.get("/api/v1/dashboard", headers=user_headers)
            assert response.status_code == 200
            assert response.json()["latest"] is None
            assert client.get("/api/v1/diary", headers=user_headers).json() == []
            assert client.get("/api/v1/progress", headers=user_headers).json() == []
            assert client.get("/api/v1/workouts", headers=user_headers).json() == []

            response = client.get("/api/v1/products", headers=user_headers)
            assert response.status_code == 200
            assert len(response.json()) > 0
            response = client.post(
                "/api/v1/products",
                headers=user_headers,
                json={"name": "Forbidden product", "protein_g": 1, "fat_g": 1, "carbs_g": 1},
            )
            assert response.status_code == 403
            response = client.post(
                "/api/v1/exercises",
                headers=user_headers,
                json={"name": "Forbidden exercise"},
            )
            assert response.status_code == 403

            response = client.put(
                f"/api/v1/diary/{diary_items[0]['id']}",
                headers=user_headers,
                json={
                    "entry_date": "2026-08-02",
                    "meal_type": "Обед",
                    "recipe_id": recipe["id"],
                    "servings": 1,
                },
            )
            assert response.status_code == 404

            response = client.post(
                "/api/v1/progress",
                headers=user_headers,
                json={"measured_at": "2099-01-01", "weight_kg": 65},
            )
            assert response.status_code == 201, response.text
            response = client.post(
                "/api/v1/workouts",
                headers=user_headers,
                json={
                    "performed_at": "2099-01-01",
                    "exercise_id": exercise["id"],
                    "sets": 2,
                    "reps": 10,
                },
            )
            assert response.status_code == 201, response.text
            assert client.delete(f"/api/v1/workouts/{workout['id']}", headers=user_headers).status_code == 404

            assert client.delete(f"/api/v1/workouts/{workout['id']}", headers=admin_headers).status_code == 200
            assert client.delete(f"/api/v1/exercises/{exercise['id']}", headers=admin_headers).status_code == 409

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
