from __future__ import annotations

from fastapi import APIRouter, status

from backend.schemas import RecipeInput, dump_model
from backend.services.recipes import (
    create_recipe,
    delete_recipe,
    get_recipe_detail,
    list_recipes,
    update_recipe,
)


router = APIRouter(prefix="/api/v1/recipes", tags=["recipes"])


@router.get("")
def get_recipes() -> list[dict]:
    return list_recipes()


@router.get("/{recipe_id}")
def get_recipe(recipe_id: int) -> dict:
    return get_recipe_detail(recipe_id)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_recipe(payload: RecipeInput) -> dict:
    return create_recipe(dump_model(payload))


@router.put("/{recipe_id}")
def put_recipe(recipe_id: int, payload: RecipeInput) -> dict:
    return update_recipe(recipe_id, dump_model(payload))


@router.delete("/{recipe_id}")
def remove_recipe(recipe_id: int) -> dict:
    return delete_recipe(recipe_id)

