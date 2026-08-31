from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, require_trainer
from backend.models import User
from backend.schemas import (
    ClientCreateInput,
    ClientShareItemInput,
    ClientNutritionTargetsInput,
    DiaryCreateInput,
    ShareItemInput,
    TrainerChatMessageInput,
    WorkoutPlanInput,
    dump_model,
)
from backend.services.clients import (
    add_client,
    add_client_diary_entry,
    delete_client_diary_entry,
    get_client_shared_item,
    get_client_diary,
    get_client_detail,
    get_my_shared_item,
    get_my_trainer,
    get_my_trainer_chat,
    list_chat_messages,
    list_clients,
    schedule_client_workout,
    send_chat_message,
    send_my_trainer_chat,
    share_item_to_trainer,
    share_item,
    update_client_targets,
)


router = APIRouter(prefix="/api/v1/clients", tags=["clients"])


@router.get("")
def get_clients(current_user: User = Depends(require_trainer)) -> list[dict]:
    return list_clients(current_user)


@router.post("", status_code=status.HTTP_201_CREATED)
def post_client(payload: ClientCreateInput, current_user: User = Depends(require_trainer)) -> dict:
    return add_client(dump_model(payload), current_user)


@router.post("/shares", status_code=status.HTTP_201_CREATED)
def post_shared_item(payload: ShareItemInput, current_user: User = Depends(require_trainer)) -> dict:
    return share_item(dump_model(payload), current_user)


@router.get("/me/chat")
def get_my_chat(current_user: User = Depends(get_current_user)) -> dict:
    return get_my_trainer_chat(current_user)


@router.get("/me/trainer")
def get_my_trainer_route(current_user: User = Depends(get_current_user)) -> dict:
    return get_my_trainer(current_user)


@router.post("/me/chat", status_code=status.HTTP_201_CREATED)
def post_my_chat(payload: TrainerChatMessageInput, current_user: User = Depends(get_current_user)) -> dict:
    return send_my_trainer_chat(current_user, dump_model(payload))


@router.get("/me/shared-items/{item_type}/{item_id}")
def get_my_shared_item_route(item_type: str, item_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return get_my_shared_item(current_user, item_type, item_id)


@router.post("/me/shares", status_code=status.HTTP_201_CREATED)
def post_shared_item_to_trainer(payload: ClientShareItemInput, current_user: User = Depends(get_current_user)) -> dict:
    return share_item_to_trainer(dump_model(payload), current_user)


@router.get("/{client_id}/shared-items/{item_type}/{item_id}")
def get_client_shared_item_route(client_id: int, item_type: str, item_id: int, current_user: User = Depends(require_trainer)) -> dict:
    return get_client_shared_item(client_id, item_type, item_id, current_user)


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
