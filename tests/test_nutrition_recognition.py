from __future__ import annotations

import base64
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from backend.recognition.nutrition import OCRLine, parse_nutrition_label


PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR42mP8z8AABQMB"
    "gCkq4QAAAABJRU5ErkJggg=="
)


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("ASTRA_DB_PATH", str(Path(tmp_path) / "astra-test.sqlite"))
    monkeypatch.setenv("ASTRA_BACKUP_DIR", str(Path(tmp_path) / "backups"))
    monkeypatch.setenv("ASTRA_ADMIN_EMAIL", "admin@example.com")
    monkeypatch.setenv("ASTRA_ADMIN_PASSWORD", "admin-password")
    monkeypatch.setenv("ASTRA_AUTH_SECRET", "test-secret-with-at-least-thirty-two-bytes")
    monkeypatch.setenv("ASTRA_PUBLIC_BASE_URL", "http://testserver")

    from backend.app import create_app

    with TestClient(create_app()) as test_client:
        yield test_client


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_parse_english_label_per_100g() -> None:
    result = parse_nutrition_label(
        [
            "Typical values per 100 g",
            "Energy 512 kJ / 123 kcal",
            "Fat 2.0 g",
            "of which saturates 0.5 g",
            "Carbohydrate 21.0 g",
            "of which sugars 7.5 g",
            "Protein 4.5 g",
        ]
    )

    assert result["basis"] == "per_100"
    assert result["kcal"] == 123
    assert result["protein_g"] == 4.5
    assert result["fat_g"] == 2
    assert result["carbs_g"] == 21


def test_parse_serbian_latin_label_per_100g() -> None:
    result = parse_nutrition_label(
        [
            OCRLine("Nutritivna vrednost na 100 g", 0.96),
            OCRLine("Energetska vrednost 520 kJ / 124 kcal", 0.91),
            OCRLine("Masti 2,4 g", 0.88),
            OCRLine("Ugljeni hidrati 14,2 g", 0.9),
            OCRLine("Proteini 8,1 g", 0.94),
        ]
    )

    assert result["basis"] == "per_100"
    assert result["kcal"] == 124
    assert result["fat_g"] == 2.4
    assert result["carbs_g"] == 14.2
    assert result["protein_g"] == 8.1
    assert result["field_confidence"]["protein_g"] == 0.94


def test_parse_energy_prefers_kcal_over_kj() -> None:
    result = parse_nutrition_label(["per 100 ml", "Energy 1880 kJ 449 kcal", "Fat 10 g"])

    assert result["kcal"] == 449


def test_parse_subrows_do_not_overwrite_total_fat_or_carbs() -> None:
    result = parse_nutrition_label(
        [
            "per 100 g",
            "Fat 12 g of which saturates 3 g",
            "Saturated fat 3 g",
            "Carbohydrate 31 g of which sugars 5 g",
            "Sugars 5 g",
        ]
    )

    assert result["fat_g"] == 12
    assert result["carbs_g"] == 31


def test_parse_macro_values_without_space_before_unit() -> None:
    result = parse_nutrition_label(["per 100g", "Fat 2.5g", "Carbohydrate 18g", "Protein 7,2g"])

    assert result["fat_g"] == 2.5
    assert result["carbs_g"] == 18
    assert result["protein_g"] == 7.2


def test_parse_unknown_basis_returns_warning() -> None:
    result = parse_nutrition_label(["Energy 88 kcal", "Protein 20 g"])

    assert result["basis"] == "unknown"
    assert result["warnings"]
    assert result["kcal"] == 88


def test_ocr_payload_extractor_handles_array_like_scores() -> None:
    from backend.recognition.ocr import _extract_ocr_lines

    class ArrayLike(list):
        def __bool__(self) -> bool:
            raise ValueError("ambiguous truth value")

    lines = _extract_ocr_lines(
        [{"res": {"rec_texts": ArrayLike(["Protein 4.5 g"]), "rec_scores": ArrayLike([0.91])}}]
    )

    assert lines == [OCRLine("Protein 4.5 g", 0.91)]


def test_admin_can_scan_label_and_temp_file_is_deleted(client: TestClient, monkeypatch) -> None:
    import backend.routers.products as products_router

    seen_paths: list[Path] = []

    def fake_recognize(path: Path) -> dict:
        seen_paths.append(path)
        assert path.exists()
        return {
            "kcal": 123,
            "protein_g": 4.5,
            "fat_g": 2,
            "carbs_g": 21,
            "basis": "per_100",
            "confidence": 0.82,
            "field_confidence": {"kcal": 0.9, "protein_g": 0.8, "fat_g": 0.78, "carbs_g": 0.8},
            "raw_text": "Energy 123 kcal\nProtein 4.5 g",
            "warnings": [],
        }

    monkeypatch.setattr(products_router, "recognize_nutrition_label_image", fake_recognize)
    headers = _login(client, "admin@example.com", "admin-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.png", PNG_1X1, "image/png")},
    )

    assert response.status_code == 200, response.text
    assert response.json()["protein_g"] == 4.5
    assert seen_paths
    assert not seen_paths[0].exists()


def test_regular_user_cannot_scan_label(client: TestClient, monkeypatch) -> None:
    client.post("/api/v1/auth/register", json={"email": "user@example.com", "password": "user-password"})
    headers = _login(client, "user@example.com", "user-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.png", PNG_1X1, "image/png")},
    )

    assert response.status_code == 403


def test_scan_rejects_invalid_file_type(client: TestClient) -> None:
    headers = _login(client, "admin@example.com", "admin-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.txt", b"not an image", "text/plain")},
    )

    assert response.status_code == 415


def test_scan_returns_422_when_nutrition_is_not_found(client: TestClient, monkeypatch) -> None:
    import backend.routers.products as products_router
    from backend.recognition.nutrition import NutritionNotFoundError

    def fake_recognize(path: Path) -> dict:
        raise NutritionNotFoundError("not found")

    monkeypatch.setattr(products_router, "recognize_nutrition_label_image", fake_recognize)
    headers = _login(client, "admin@example.com", "admin-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.png", PNG_1X1, "image/png")},
    )

    assert response.status_code == 422


def test_scan_returns_503_when_ocr_is_unavailable(client: TestClient, monkeypatch) -> None:
    import backend.routers.products as products_router
    from backend.recognition.ocr import OCRUnavailableError

    def fake_recognize(path: Path) -> dict:
        raise OCRUnavailableError("missing")

    monkeypatch.setattr(products_router, "recognize_nutrition_label_image", fake_recognize)
    headers = _login(client, "admin@example.com", "admin-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.png", PNG_1X1, "image/png")},
    )

    assert response.status_code == 503


def test_scan_rejects_oversized_image(client: TestClient) -> None:
    headers = _login(client, "admin@example.com", "admin-password")

    response = client.post(
        "/api/v1/products/scan-nutrition-label",
        headers=headers,
        files={"image": ("label.jpg", b"x" * (8 * 1024 * 1024 + 1), "image/jpeg")},
    )

    assert response.status_code == 413
