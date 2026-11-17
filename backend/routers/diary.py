from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, get_optional_user
from backend.models import User
from backend.schemas import DiaryCreateInput, DiaryDayNutritionInput, DiaryUpdateInput, dump_model
from backend.services.diary import (
    create_diary_entries,
    delete_diary_entry,
    list_day_nutrition,
    list_diary,
    save_day_nutrition,
    update_diary_entry,
)


router = APIRouter(prefix="/api/v1/diary", tags=["diary"])


@router.get("")
def get_diary(current_user: User | None = Depends(get_optional_user)) -> list[dict]:
    return list_diary(current_user)


@router.get("/day-nutrition")
def get_day_nutrition(current_user: User | None = Depends(get_optional_user)) -> list[dict]:
    return list_day_nutrition(current_user)


@router.put("/day-nutrition")
def put_day_nutrition(payload: DiaryDayNutritionInput, current_user: User = Depends(get_current_user)) -> dict:
    return save_day_nutrition(dump_model(payload), current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_diary(payload: DiaryCreateInput, current_user: User = Depends(get_current_user)) -> list[dict]:
    return create_diary_entries(dump_model(payload), current_user)


@router.put("/{entry_id}")
def put_diary(entry_id: int, payload: DiaryUpdateInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_diary_entry(entry_id, dump_model(payload), current_user)


@router.delete("/{entry_id}")
def remove_diary(entry_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_diary_entry(entry_id, current_user)
