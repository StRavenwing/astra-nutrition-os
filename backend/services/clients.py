from __future__ import annotations

from datetime import date

from peewee import JOIN

from backend.models import (
    ChatMessage,
    DiaryEntry,
    Exercise,
    Article,
    ProgressEntry,
    Product,
    Recipe,
    TrainerClient,
    TrainerSharedItem,
    User,
    WorkoutComplex,
    WorkoutEquipment,
    WorkoutLog,
    WorkoutPlan,
    current_database,
)
from backend.services.auth import normalize_email, utc_now
from backend.services.diary import create_diary_entries
from backend.services.errors import ConflictError, ForbiddenError, NotFoundError
from backend.services.serialization import serialize_diary_entry, serialize_progress, serialize_workout, serialize_workout_plan
from backend.services.workouts import create_workout_plan


def _display_name(user: User) -> str:
    return user.display_name or user.email.split("@", 1)[0]


def _today() -> str:
    return date.today().isoformat()


def _assert_trainer(actor: User) -> None:
    if not (actor.is_admin or actor.is_trainer):
        raise ForbiddenError("Раздел доступен только тренерам и администраторам")


def _relationship(client_id: int, actor: User) -> TrainerClient:
    _assert_trainer(actor)
    query = TrainerClient.select().where(TrainerClient.client == client_id)
    if not actor.is_admin:
        query = query.where(TrainerClient.trainer == actor)
    relation = query.first()
    if relation is None:
        raise NotFoundError("Клиент не найден в вашем списке")
    return relation


def _next_workout(client: User) -> dict | None:
    plan = (
        WorkoutPlan
        .select()
        .where(
            (WorkoutPlan.user == client)
            & (WorkoutPlan.status == "planned")
            & (WorkoutPlan.scheduled_at >= _today())
        )
        .order_by(WorkoutPlan.scheduled_at, WorkoutPlan.id)
        .first()
    )
    if plan is None:
        return None
    return {"id": plan.id, "scheduled_at": plan.scheduled_at, "status": plan.status}


def serialize_client_summary(client: User) -> dict:
    return {
        "id": client.id,
        "name": _display_name(client),
        "email": client.email,
        "next_workout": _next_workout(client),
    }


def list_clients(actor: User) -> list[dict]:
    _assert_trainer(actor)
    query = (
        TrainerClient
        .select(TrainerClient, User)
        .join(User, on=(TrainerClient.client == User.id))
        .order_by(User.display_name, User.email)
    )
    if not actor.is_admin:
        query = query.where(TrainerClient.trainer == actor)
    result = []
    seen: set[int] = set()
    for relation in query:
        client = relation.client
        if client.id in seen:
            continue
        seen.add(client.id)
        result.append(serialize_client_summary(client))
    return result


def add_client(data: dict, actor: User) -> dict:
    _assert_trainer(actor)
    email = normalize_email(data.get("email"))
    client = User.get_or_none(User.email == email)
    if client is None:
        raise NotFoundError("Пользователь с таким email не зарегистрирован")
    if client.id == actor.id:
        raise ConflictError("Нельзя добавить себя в список клиентов")
    relation, created = TrainerClient.get_or_create(
        trainer=actor,
        client=client,
        defaults={"created_at": utc_now()},
    )
    if not created:
        raise ConflictError("Этот клиент уже добавлен")
    return serialize_client_summary(client)


def _user_progress(client: User) -> list[ProgressEntry]:
    return list(ProgressEntry.select().where(ProgressEntry.user == client).order_by(ProgressEntry.measured_at.desc()))


def _user_diary(client: User, entry_date: str | None = None) -> list[dict]:
    query = DiaryEntry.select().where(DiaryEntry.user == client)
    if entry_date is not None:
        query = query.where(DiaryEntry.entry_date == entry_date)
    query = query.order_by(DiaryEntry.entry_date.desc(), DiaryEntry.id.desc())
    return [serialize_diary_entry(entry) for entry in query]


def _totals(entries: list[dict]) -> dict[str, float]:
    totals = {"kcal": 0.0, "protein": 0.0, "fat": 0.0, "carbs": 0.0, "cost": 0.0}
    for entry in entries:
        factor = float(entry.get("servings") or 1)
        totals["kcal"] += float(entry.get("kcal_per_serving") or 0) * factor
        totals["protein"] += float(entry.get("protein_per_serving_g") or 0) * factor
        totals["fat"] += float(entry.get("fat_per_serving_g") or 0) * factor
        totals["carbs"] += float(entry.get("carbs_per_serving_g") or 0) * factor
        totals["cost"] += float(entry.get("cost_per_serving_rsd") or 0) * factor
    return {key: round(value, 2) for key, value in totals.items()}


def _targets(latest: ProgressEntry | None) -> dict[str, float | None]:
    if latest is None:
        return {"kcal": None, "protein": None, "fat": None, "carbs": None}
    weight = latest.desired_weight_kg or latest.weight_kg
    protein = latest.protein_target_g if latest.protein_target_g is not None else weight * 2 if weight else None
    fat = latest.fat_target_g if latest.fat_target_g is not None else weight if weight else None
    carbs = latest.carbs_target_g if latest.carbs_target_g is not None else weight * 3 if weight else None
    kcal = latest.kcal_target
    if kcal is None and protein is not None and fat is not None and carbs is not None:
        kcal = protein * 4 + fat * 9 + carbs * 4
    return {"kcal": kcal, "protein": protein, "fat": fat, "carbs": carbs}


def _remaining(totals: dict[str, float], targets: dict[str, float | None]) -> dict[str, float | None]:
    return {
        key: round(max(targets[key] - totals[source], 0), 2) if targets[key] is not None else None
        for key, source in (("kcal", "kcal"), ("protein", "protein"), ("fat", "fat"), ("carbs", "carbs"))
    }


def _user_workouts(client: User) -> tuple[list[dict], list[dict]]:
    logs = (
        WorkoutLog.select(WorkoutLog, Exercise).join(Exercise)
        .where(WorkoutLog.user == client)
        .order_by(WorkoutLog.performed_at.desc(), WorkoutLog.id.desc())
    )
    plans = WorkoutPlan.select().where(WorkoutPlan.user == client).order_by(WorkoutPlan.scheduled_at.desc(), WorkoutPlan.id.desc())
    return [serialize_workout(log) for log in logs], [serialize_workout_plan(plan) for plan in plans]


def get_client_detail(client_id: int, actor: User) -> dict:
    relation = _relationship(client_id, actor)
    client = relation.client
    progress = _user_progress(client)
    entries = _user_diary(client, _today())
    totals = _totals(entries)
    targets = _targets(progress[0] if progress else None)
    workouts, plans = _user_workouts(client)
    return {
        **serialize_client_summary(client),
        "progress": [serialize_progress(item) for item in progress],
        "today": {
            "date": _today(),
            "entries": entries,
            "totals": totals,
            "targets": targets,
            "remaining": _remaining(totals, targets),
        },
        "workouts": workouts,
        "workout_plans": plans,
    }


def add_client_diary_entry(client_id: int, data: dict, actor: User) -> list[dict]:
    client = _relationship(client_id, actor).client
    return create_diary_entries(data, client)


def get_client_diary(client_id: int, actor: User) -> list[dict]:
    client = _relationship(client_id, actor).client
    return _user_diary(client)


def delete_client_diary_entry(client_id: int, entry_id: int, actor: User) -> dict:
    client = _relationship(client_id, actor).client
    entry = DiaryEntry.get_or_none((DiaryEntry.id == entry_id) & (DiaryEntry.user == client))
    if entry is None:
        raise NotFoundError("Запись дневника не найдена")
    entry.delete_instance()
    return {"deleted": True, "id": entry_id}


def schedule_client_workout(client_id: int, data: dict, actor: User) -> dict:
    client = _relationship(client_id, actor).client
    return create_workout_plan(data, client)


def update_client_targets(client_id: int, data: dict, actor: User) -> dict:
    client = _relationship(client_id, actor).client
    with current_database().atomic():
        entry = ProgressEntry.select().where(ProgressEntry.user == client).order_by(ProgressEntry.measured_at.desc()).first()
        if entry is None:
            entry = ProgressEntry(user=client, measured_at=_today())
        entry.kcal_target = _number_or_none(data.get("kcal_target"))
        entry.protein_target_g = _number_or_none(data.get("protein_target_g"))
        entry.fat_target_g = _number_or_none(data.get("fat_target_g"))
        entry.carbs_target_g = _number_or_none(data.get("carbs_target_g"))
        if entry.id is None:
            entry.save(force_insert=True)
        else:
            entry.save()
        return serialize_progress(entry)


def _number_or_none(value: object) -> float | None:
    if value in (None, ""):
        return None
    result = float(value)
    if result < 0:
        raise ValueError("Нормы питания не могут быть отрицательными")
    return result


def list_chat_messages(client_id: int, actor: User) -> list[dict]:
    relation = _relationship(client_id, actor)
    query = ChatMessage.select(ChatMessage, User).join(User, on=(ChatMessage.sender == User.id), join_type=JOIN.LEFT_OUTER)
    query = query.where(ChatMessage.trainer_client == relation).order_by(ChatMessage.created_at, ChatMessage.id)
    return [
        {
            "id": item.id,
            "sender_id": item.sender_id,
            "sender_name": _display_name(item.sender) if item.sender else "Пользователь",
            "message": item.message,
            "shared_item": _shared_item_payload(item),
            "created_at": item.created_at,
        }
        for item in query
    ]


def send_chat_message(client_id: int, data: dict, actor: User) -> dict:
    relation = _relationship(client_id, actor)
    message = str(data.get("message") or "").strip()
    if not message:
        raise ValueError("Сообщение не может быть пустым")
    item = ChatMessage.create(trainer_client=relation, sender=actor, message=message, created_at=utc_now())
    return {
        "id": item.id,
        "sender_id": actor.id,
        "sender_name": _display_name(actor),
        "message": item.message,
        "shared_item": None,
        "created_at": item.created_at,
    }


def _shared_item_payload(item: ChatMessage) -> dict | None:
    if not item.shared_item_type or item.shared_item_id is None:
        return None
    return {
        "type": item.shared_item_type,
        "id": item.shared_item_id,
        "name": item.shared_item_name or "Отправленный материал",
    }


def share_item(data: dict, actor: User) -> dict:
    relation = _relationship(int(data.get("client_id")), actor)
    item_type = str(data.get("item_type") or "")
    item_id = int(data.get("item_id"))
    item_models = {
        "recipe": Recipe,
        "product": Product,
        "article": Article,
        "progress": ProgressEntry,
        "workout_complex": WorkoutComplex,
        "workout_equipment": WorkoutEquipment,
    }
    model = item_models.get(item_type)
    if model is None or model.get_or_none(model.id == item_id) is None:
        raise NotFoundError("Элемент для отправки не найден")
    with current_database().atomic():
        shared, created = TrainerSharedItem.get_or_create(
            trainer_client=relation,
            item_type=item_type,
            item_id=item_id,
            defaults={"created_at": utc_now()},
        )
        if created:
            shared_model = model.get_by_id(item_id)
            item_name = (
                f"Показатели за {shared_model.measured_at}"
                if item_type == "progress"
                else getattr(shared_model, "title", None) or getattr(shared_model, "name", None) or "Отправленный материал"
            )
            chat_message = ChatMessage.create(
                trainer_client=relation,
                sender=actor,
                message=f"Отправлен материал: {item_name}",
                shared_item_type=item_type,
                shared_item_id=item_id,
                shared_item_name=item_name,
                created_at=utc_now(),
            )
        else:
            chat_message = None
    return {
        "id": shared.id,
        "client_id": relation.client_id,
        "item_type": item_type,
        "item_id": item_id,
        "already_shared": not created,
        "chat_message_id": chat_message.id if chat_message else None,
    }
