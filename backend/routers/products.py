from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, File, UploadFile, status
from starlette.concurrency import run_in_threadpool

from backend.dependencies import require_admin
from backend.models import User
from backend.recognition.nutrition import NutritionNotFoundError
from backend.recognition.ocr import OCRUnavailableError, recognize_nutrition_label_image
from backend.schemas import ProductInput, ProductNutritionScanResult, dump_model
from backend.services.errors import DomainError
from backend.services.products import (
    create_product,
    delete_product,
    list_product_measures,
    list_products,
    update_product,
)


router = APIRouter(prefix="/api/v1", tags=["products"])
MAX_NUTRITION_LABEL_IMAGE_BYTES = 8 * 1024 * 1024
NUTRITION_LABEL_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


@router.get("/products")
def get_products() -> list[dict]:
    return list_products()


@router.get("/product-measures")
def get_product_measures() -> list[dict]:
    return list_product_measures()


@router.post("/products", status_code=status.HTTP_201_CREATED)
def post_product(payload: ProductInput, current_user: User = Depends(require_admin)) -> dict:
    return create_product(dump_model(payload))


@router.post("/products/scan-nutrition-label")
async def scan_product_nutrition_label(
    image: UploadFile = File(...),
    current_user: User = Depends(require_admin),
) -> ProductNutritionScanResult:
    suffix = NUTRITION_LABEL_IMAGE_TYPES.get(image.content_type or "")
    if suffix is None:
        raise DomainError("Поддерживаются только изображения JPEG, PNG или WebP", 415)

    try:
        with tempfile.TemporaryDirectory(prefix="astra-ocr-") as temp_dir:
            temp_root = Path(temp_dir)
            source_path = temp_root / f"upload{suffix}"
            normalized_path = temp_root / "normalized.jpg"
            await _save_upload_file(image, source_path)
            await run_in_threadpool(_normalize_scan_image, source_path, normalized_path)
            result = await run_in_threadpool(recognize_nutrition_label_image, normalized_path)
    except NutritionNotFoundError as exc:
        raise DomainError("КБЖУ не найдено на изображении", 422) from exc
    except OCRUnavailableError as exc:
        raise DomainError("Модуль распознавания недоступен", 503) from exc
    finally:
        await image.close()

    return ProductNutritionScanResult(**result)


@router.put("/products/{product_id}")
def put_product(product_id: int, payload: ProductInput, current_user: User = Depends(require_admin)) -> dict:
    return update_product(product_id, dump_model(payload))


@router.delete("/products/{product_id}")
def remove_product(product_id: int, current_user: User = Depends(require_admin)) -> dict:
    return delete_product(product_id)


async def _save_upload_file(upload: UploadFile, target_path: Path) -> None:
    total = 0
    chunk_size = 1024 * 1024
    with target_path.open("wb") as target:
        while True:
            chunk = await upload.read(chunk_size)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_NUTRITION_LABEL_IMAGE_BYTES:
                raise DomainError("Изображение больше 8 MB", 413)
            target.write(chunk)
    if total == 0:
        raise ValueError("Файл изображения пуст")


def _normalize_scan_image(source_path: Path, target_path: Path) -> None:
    try:
        from PIL import Image, ImageOps, UnidentifiedImageError
    except Exception as exc:
        raise OCRUnavailableError("Pillow не установлен") from exc

    try:
        Image.MAX_IMAGE_PIXELS = 12_000_000
        with Image.open(source_path) as image:
            normalized = ImageOps.exif_transpose(image)
            normalized.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
            normalized.convert("RGB").save(target_path, "JPEG", quality=90, optimize=True)
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("Не удалось прочитать изображение") from exc
