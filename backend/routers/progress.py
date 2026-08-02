from __future__ import annotations

from fastapi import APIRouter, status

from backend.schemas import ProgressInput, dump_model
from backend.services.progress import (
    create_progress,
    delete_progress,
    list_progress,
    update_progress,
)


router = APIRouter(prefix="/api/v1/progress", tags=["progress"])


@router.get("")
def get_progress() -> list[dict]:
    return list_progress()


@router.post("", status_code=status.HTTP_201_CREATED)
def post_progress(payload: ProgressInput) -> dict:
    return create_progress(dump_model(payload))


@router.put("/{entry_id}")
def put_progress(entry_id: int, payload: ProgressInput) -> dict:
    return update_progress(entry_id, dump_model(payload))


@router.delete("/{entry_id}")
def remove_progress(entry_id: int) -> dict:
    return delete_progress(entry_id)

