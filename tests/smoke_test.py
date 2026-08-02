"""Dependency-free smoke test used locally and by GitHub Actions."""

import importlib
import gc
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]


def get(base_url, path):
    with urlopen(base_url + path, timeout=5) as response:
        return response, response.read()


def send_json(base_url, path, payload, method="POST"):
    request = Request(
        base_url + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method=method,
    )
    with urlopen(request, timeout=5) as response:
        return response, response.read()


def main():
    with tempfile.TemporaryDirectory(prefix="astra-ci-") as temp_dir:
        os.environ["ASTRA_DB_PATH"] = str(Path(temp_dir) / "astra-test.sqlite")
        os.environ["ASTRA_BACKUP_DIR"] = str(Path(temp_dir) / "backups")
        os.chdir(ROOT)
        sys.path.insert(0, str(ROOT))

        server_module = importlib.import_module("server")
        assert server_module.DB.parent == Path(temp_dir).resolve(), server_module.DB

        server = ThreadingHTTPServer(("127.0.0.1", 0), server_module.App)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        base_url = f"http://127.0.0.1:{server.server_port}"

        try:
            response, body = get(base_url, "/api/health")
            assert response.status == 200
            assert json.loads(body) == {"status": "ok"}

            response, body = get(base_url, "/api/dashboard")
            dashboard = json.loads(body)
            assert response.status == 200
            assert dashboard["products"] > 0
            assert dashboard["recipes"] > 0

            response, _ = send_json(
                base_url,
                "/api/products",
                {
                    "name": "Соус для smoke-теста",
                    "category": "Соусы",
                    "unit": "мл",
                    "protein_g": 1,
                    "fat_g": 0,
                    "carbs_g": 2,
                },
            )
            assert response.status == 201
            _, body = get(base_url, "/api/products")
            created = next(
                product for product in json.loads(body)
                if product["name"] == "Соус для smoke-теста"
            )
            _, body = get(base_url, "/api/product-measures")
            created_measures = {
                item["measure_name"]: item["base_quantity"]
                for item in json.loads(body)
                if item["product_id"] == created["product_id"]
            }
            assert created_measures == {
                "ч. л.": 5.0,
                "ст. л.": 15.0,
                "стакан (200 мл)": 200.0,
            }

            custom = dict(created)
            custom["measures"] = [
                {"measure_name": "ч. л.", "base_quantity": 6},
                {"measure_name": "ст. л.", "base_quantity": 18},
                {"measure_name": "стакан (200 мл)", "base_quantity": 240},
            ]
            response, _ = send_json(
                base_url,
                f"/api/products/{created['product_id']}",
                custom,
                method="PUT",
            )
            assert response.status == 200
            _, body = get(base_url, "/api/product-measures")
            custom_measures = {
                item["measure_name"]: item["base_quantity"]
                for item in json.loads(body)
                if item["product_id"] == created["product_id"]
            }
            assert custom_measures == {
                "ч. л.": 6.0,
                "ст. л.": 18.0,
                "стакан (200 мл)": 240.0,
            }

            response, body = get(base_url, "/manifest.webmanifest")
            manifest = json.loads(body)
            assert response.headers.get_content_type() == "application/manifest+json"
            assert manifest["display"] == "standalone"
            assert {icon["sizes"] for icon in manifest["icons"]} >= {"192x192", "512x512"}

            response, body = get(base_url, "/")
            assert response.status == 200
            assert b'id="app"' in body
            assert b"/assets/app-icon-192.png" in body

            response, body = get(base_url, "/service-worker.js")
            assert response.headers.get_content_type() == "text/javascript"
            assert response.headers.get("Cache-Control") == "no-cache"
            assert b"CACHE_NAME" in body

            response, body = get(base_url, "/assets/app-icon-192.png")
            assert response.headers.get_content_type() == "image/png"
            assert body.startswith(b"\x89PNG")
        finally:
            server.shutdown()
            worker.join(timeout=5)
            server.server_close()
            gc.collect()

    print("Astra smoke test passed")


if __name__ == "__main__":
    main()
