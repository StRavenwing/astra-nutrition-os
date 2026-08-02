from __future__ import annotations

from fastapi import APIRouter, status

from backend.schemas import DiaryCreateInput, DiaryUpdateInput, dump_model
from backend.services.diary import (
    create_diary_entries,
    delete_diary_entry,
    list_diary,
    update_diary_entry,
)


router = APIRouter(prefix="/api/v1/diary", tags=["diary"])


@router.get("")
def get_diary() -> list[dict]:
    return list_diary()


@router.post("", status_code=status.HTTP_201_CREATED)
def post_diary(payload: DiaryCreateInput) -> list[dict]:
    return create_diary_entries(dump_model(payload))


@router.put("/{entry_id}")
def put_diary(entry_id: int, payload: DiaryUpdateInput) -> dict:
    return update_diary_entry(entry_id, dump_model(payload))


@router.delete("/{entry_id}")
def remove_diary(entry_id: int) -> dict:
    return delete_diary_entry(entry_id)

