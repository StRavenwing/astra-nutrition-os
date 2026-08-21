from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, get_optional_user
from backend.models import User
from backend.schemas import ProgressInput, dump_model
from backend.services.progress import (
    create_progress,
    delete_progress,
    list_progress,
    update_progress,
)


router = APIRouter(prefix="/api/v1/progress", tags=["progress"])


@router.get("")
def get_progress(current_user: User | None = Depends(get_optional_user)) -> list[dict]:
    return list_progress(current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_progress(payload: ProgressInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_progress(dump_model(payload), current_user)


@router.put("/{entry_id}")
def put_progress(entry_id: int, payload: ProgressInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_progress(entry_id, dump_model(payload), current_user)


@router.delete("/{entry_id}")
def remove_progress(entry_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_progress(entry_id, current_user)
