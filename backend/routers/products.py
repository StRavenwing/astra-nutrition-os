from __future__ import annotations

from fastapi import APIRouter, status

from backend.schemas import ProductInput, dump_model
from backend.services.products import (
    create_product,
    delete_product,
    list_product_measures,
    list_products,
    update_product,
)


router = APIRouter(prefix="/api/v1", tags=["products"])


@router.get("/products")
def get_products() -> list[dict]:
    return list_products()


@router.get("/product-measures")
def get_product_measures() -> list[dict]:
    return list_product_measures()


@router.post("/products", status_code=status.HTTP_201_CREATED)
def post_product(payload: ProductInput) -> dict:
    return create_product(dump_model(payload))


@router.put("/products/{product_id}")
def put_product(product_id: int, payload: ProductInput) -> dict:
    return update_product(product_id, dump_model(payload))


@router.delete("/products/{product_id}")
def remove_product(product_id: int) -> dict:
    return delete_product(product_id)

