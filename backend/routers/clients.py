from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import require_trainer
from backend.models import User
from backend.schemas import (
    ClientCreateInput,
    ClientNutritionTargetsInput,
    DiaryCreateInput,
    TrainerChatMessageInput,
    WorkoutPlanInput,
    dump_model,
)
from backend.services.clients import (
    add_client,
    add_client_diary_entry,
    delete_client_diary_entry,
    get_client_diary,
    get_client_detail,
    list_chat_messages,
    list_clients,
    schedule_client_workout,
    send_chat_message,
    update_client_targets,
)


router = APIRouter(prefix="/api/v1/clients", tags=["clients"])


@router.get("")
def get_clients(current_user: User = Depends(require_trainer)) -> list[dict]:
    return list_clients(current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_client(payload: ClientCreateInput, current_user: User = Depends(require_trainer)) -> dict:
    return add_client(dump_model(payload), current_user)


@router.get("/{client_id}")
def get_client(client_id: int, current_user: User = Depends(require_trainer)) -> dict:
    return get_client_detail(client_id, current_user)


@router.post("/{client_id}/diary", status_code=status.HTTP_201_CREATED)
def post_client_diary(client_id: int, payload: DiaryCreateInput, current_user: User = Depends(require_trainer)) -> list[dict]:
    return add_client_diary_entry(client_id, dump_model(payload), current_user)


@router.get("/{client_id}/diary")
def get_diary_for_client(client_id: int, current_user: User = Depends(require_trainer)) -> list[dict]:
    return get_client_diary(client_id, current_user)


@router.delete("/{client_id}/diary/{entry_id}")
def remove_client_diary(client_id: int, entry_id: int, current_user: User = Depends(require_trainer)) -> dict:
    return delete_client_diary_entry(client_id, entry_id, current_user)


@router.post("/{client_id}/workout-plans", status_code=status.HTTP_201_CREATED)
def post_client_workout_plan(client_id: int, payload: WorkoutPlanInput, current_user: User = Depends(require_trainer)) -> dict:
    return schedule_client_workout(client_id, dump_model(payload), current_user)


@router.put("/{client_id}/nutrition-targets")
def put_client_targets(client_id: int, payload: ClientNutritionTargetsInput, current_user: User = Depends(require_trainer)) -> dict:
    return update_client_targets(client_id, dump_model(payload), current_user)


@router.get("/{client_id}/chat")
def get_client_chat(client_id: int, current_user: User = Depends(require_trainer)) -> list[dict]:
    return list_chat_messages(client_id, current_user)


@router.post("/{client_id}/chat", status_code=status.HTTP_201_CREATED)
def post_client_chat(client_id: int, payload: TrainerChatMessageInput, current_user: User = Depends(require_trainer)) -> dict:
    return send_chat_message(client_id, dump_model(payload), current_user)
