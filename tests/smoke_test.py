"""Dependency-free smoke test used locally and by GitHub Actions."""

import importlib
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer
from urllib.request import urlopen


ROOT = Path(__file__).resolve().parents[1]


def get(base_url, path):
    with urlopen(base_url + path, timeout=5) as response:
        return response, response.read()


def main():
    with tempfile.TemporaryDirectory(prefix="astra-ci-") as temp_dir:
        os.environ["ASTRA_DB_PATH"] = str(Path(temp_dir) / "astra-test.sqlite")
        os.environ["ASTRA_BACKUP_DIR"] = str(Path(temp_dir) / "backups")
        os.chdir(ROOT)
        sys.path.insert(0, str(ROOT))

        server_module = importlib.import_module("server")
        assert server_module.DB.parent == Path(temp_dir), server_module.DB

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

            response, body = get(base_url, "/manifest.webmanifest")
            manifest = json.loads(body)
            assert response.headers.get_content_type() == "application/manifest+json"
            assert manifest["display"] == "standalone"
            assert {icon["sizes"] for icon in manifest["icons"]} >= {"192x192", "512x512"}

            response, body = get(base_url, "/service-worker.js")
            assert response.headers.get_content_type() == "text/javascript"
            assert response.headers.get("Cache-Control") == "no-cache"
            assert b"CACHE_NAME" in body

            response, body = get(base_url, "/assets/app-icon-192.png")
            assert response.headers.get_content_type() == "image/png"
            assert body.startswith(b"\x89PNG")
        finally:
            server.shutdown()
            server.server_close()

    print("Astra smoke test passed")


if __name__ == "__main__":
    main()
