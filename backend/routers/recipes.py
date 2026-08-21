from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, get_optional_user
from backend.models import User
from backend.schemas import RecipeInput, RecipeModerationInput, dump_model
from backend.services.recipes import (
    create_recipe,
    delete_recipe,
    get_recipe_detail,
    list_recipes,
    request_recipe_submission,
    cancel_recipe_submission,
    moderate_recipe,
    update_recipe,
)


router = APIRouter(prefix="/api/v1/recipes", tags=["recipes"])


@router.get("")
def get_recipes(current_user: User | None = Depends(get_optional_user)) -> list[dict]:
    return list_recipes(current_user)


@router.get("/{recipe_id}")
def get_recipe(recipe_id: int, current_user: User | None = Depends(get_optional_user)) -> dict:
    return get_recipe_detail(recipe_id, current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_recipe(payload: RecipeInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_recipe(dump_model(payload), None if current_user.is_admin else current_user)


@router.put("/{recipe_id}")
def put_recipe(recipe_id: int, payload: RecipeInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_recipe(recipe_id, dump_model(payload), current_user)


@router.delete("/{recipe_id}")
def remove_recipe(recipe_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_recipe(recipe_id, current_user)


@router.post("/{recipe_id}/submission-request")
def submit_recipe(recipe_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return request_recipe_submission(recipe_id, current_user)


@router.delete("/{recipe_id}/submission-request")
def cancel_submission(recipe_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return cancel_recipe_submission(recipe_id, current_user)


@router.post("/{recipe_id}/moderation")
def moderate(recipe_id: int, payload: RecipeModerationInput, current_user: User = Depends(get_current_user)) -> dict:
    return moderate_recipe(recipe_id, payload.action, payload.note, current_user)
