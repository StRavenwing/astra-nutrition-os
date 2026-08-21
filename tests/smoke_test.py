"""FastAPI smoke test used locally and by GitHub Actions."""

from __future__ import annotations

import base64
import hashlib
import os
from pathlib import Path
import sys
import tempfile
from urllib.parse import parse_qs, urlparse

from fastapi.testclient import TestClient


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="astra-ci-") as temp_dir:
        os.environ["ASTRA_DB_PATH"] = str(Path(temp_dir) / "astra-test.sqlite")
        os.environ["ASTRA_BACKUP_DIR"] = str(Path(temp_dir) / "backups")
        os.environ["ASTRA_ADMIN_EMAIL"] = "admin@example.com"
        os.environ["ASTRA_ADMIN_PASSWORD"] = "admin-password"
        os.environ["ASTRA_AUTH_SECRET"] = "test-secret-with-at-least-thirty-two-bytes"
        os.environ["ASTRA_PUBLIC_BASE_URL"] = "http://testserver"
        os.chdir(ROOT)
        sys.path.insert(0, str(ROOT))

        from backend.app import create_app

        app = create_app()
        with TestClient(app) as client:
            def pkce() -> tuple[str, str]:
                verifier = "smoke-verifier-abcdefghijklmnopqrstuvwxyz0123456789"
                digest = hashlib.sha256(verifier.encode("ascii")).digest()
                challenge = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
                return verifier, challenge

            def issue_mcp_token() -> str:
                redirect_uri = "https://chat.openai.com/aip/smoke/oauth/callback"
                registered = client.post(
                    "/oauth/register",
                    json={
                        "redirect_uris": [redirect_uri],
                        "token_endpoint_auth_method": "none",
                        "scope": "recipes:read recipes:write",
                    },
                )
                assert registered.status_code == 201, registered.text
                verifier, challenge = pkce()
                authorization = client.get(
                    "/oauth/authorize",
                    params={
                        "response_type": "code",
                        "client_id": registered.json()["client_id"],
                        "redirect_uri": redirect_uri,
                        "scope": "recipes:read recipes:write",
                        "state": "smoke",
                        "code_challenge": challenge,
                        "code_challenge_method": "S256",
                        "resource": "http://testserver/mcp",
                    },
                    follow_redirects=False,
                )
                assert authorization.status_code == 302, authorization.text
                request_id = parse_qs(urlparse(authorization.headers["location"]).query)["request"][0]
                login = client.post(
                    "/oauth/login",
                    data={"request": request_id, "email": "admin@example.com", "password": "admin-password"},
                    follow_redirects=False,
                )
                assert login.status_code == 302, login.text
                code = parse_qs(urlparse(login.headers["location"]).query)["code"][0]
                token = client.post(
                    "/oauth/token",
                    data={
                        "grant_type": "authorization_code",
                        "client_id": registered.json()["client_id"],
                        "code": code,
                        "redirect_uri": redirect_uri,
                        "code_verifier": verifier,
                    },
                )
                assert token.status_code == 200, token.text
                return token.json()["access_token"]

            def mcp_call(access_token: str, name: str, arguments: dict, request_id: int) -> dict:
                response = client.post(
                    "/mcp",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Accept": "application/json",
                        "Content-Type": "application/json",
                        "mcp-protocol-version": "2025-11-25",
                    },
                    json={
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "method": "tools/call",
                        "params": {"name": name, "arguments": arguments},
                    },
                )
                assert response.status_code == 200, response.text
                return response.json()

            response = client.get("/api/health")
            assert response.status_code == 200
            assert response.json() == {"status": "ok"}

            response = client.get("/api/v1/dashboard")
            assert response.status_code == 200
            guest_dashboard = response.json()
            assert guest_dashboard["latest"] is None
            assert client.get("/api/v1/diary").json() == []
            assert client.get("/api/v1/progress").json() == []
            assert client.post("/api/v1/products", json={"name": "guest-write"}).status_code == 401

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

            mcp_access_token = issue_mcp_token()
            response = client.post(
                "/mcp",
                headers={
                    "Authorization": f"Bearer {mcp_access_token}",
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                },
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-11-25",
                        "capabilities": {},
                        "clientInfo": {"name": "smoke", "version": "1"},
                    },
                },
            )
            assert response.status_code == 200, response.text
            assert response.json()["result"]["serverInfo"]["name"] == "Astra Nutrition OS"

            mcp_search = mcp_call(mcp_access_token, "recipes.search", {"limit": 1}, 2)
            assert mcp_search["result"]["structuredContent"]["result"][0]["code"]
            mcp_recipe = mcp_call(
                mcp_access_token,
                "recipes.create",
                {
                    "category": "Ready",
                    "name": "Smoke MCP recipe",
                    "servings": 1,
                    "manual_kcal_per_serving": 250,
                    "manual_protein_per_serving_g": 20,
                    "manual_fat_per_serving_g": 10,
                    "manual_carbs_per_serving_g": 15,
                },
                3,
            )
            assert mcp_recipe["result"]["structuredContent"]["code"].startswith("R-")

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
            assert b"precacheAndRoute" in response.content or b"addEventListener" in response.content

            response = client.get("/assets/app-icon-192.png")
            assert response.headers["content-type"].startswith("image/png")
            assert response.content.startswith(b"\x89PNG")

    print("Astra smoke test passed")


if __name__ == "__main__":
    main()
