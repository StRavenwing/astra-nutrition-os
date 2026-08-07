from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user
from backend.models import User
from backend.schemas import DiaryCreateInput, DiaryUpdateInput, dump_model
from backend.services.diary import (
    create_diary_entries,
    delete_diary_entry,
    list_diary,
    update_diary_entry,
)


router = APIRouter(prefix="/api/v1/diary", tags=["diary"])


@router.get("")
def get_diary(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_diary(current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_diary(payload: DiaryCreateInput, current_user: User = Depends(get_current_user)) -> list[dict]:
    return create_diary_entries(dump_model(payload), current_user)


@router.put("/{entry_id}")
def put_diary(entry_id: int, payload: DiaryUpdateInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_diary_entry(entry_id, dump_model(payload), current_user)


@router.delete("/{entry_id}")
def remove_diary(entry_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_diary_entry(entry_id, current_user)
