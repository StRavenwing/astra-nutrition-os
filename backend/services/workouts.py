from __future__ import annotations

import json
from datetime import datetime

from backend.models import (
    Exercise,
    ExerciseVariant,
    User,
    WorkoutEquipment,
    WorkoutComplex,
    WorkoutComplexItem,
    WorkoutLog,
    WorkoutPlan,
    WorkoutPlanItem,
    current_database,
)
from backend.services.calculations import int_number, number
from backend.services.codes import next_code
from backend.services.errors import ConflictError, ForbiddenError, NotFoundError
from backend.services.serialization import serialize_exercise, serialize_workout, serialize_workout_plan


DEFAULT_WORKOUT_COMPLEXES = (
    "Комплекс для рук",
    "Комплекс для плеч",
    "Комплекс на ягодицы",
    "Круговая",
    "День ног",
    "Комплекс для спины",
    "Пресс",
)

DEFAULT_WORKOUT_EQUIPMENT = {
    "machine": (
        "Блочный тренажёр", "Кроссовер", "Смит-машина", "Силовая рама", "Скамья",
        "Тренажёр для жима ногами", "Тренажёр для разгибания ног", "Тренажёр для сгибания ног",
        "Тренажёр для сведения/разведения ног", "Тренажёр для ягодиц", "Гиперэкстензия", "Кардио-тренажёр",
    ),
    "equipment": (
        "Гантели", "Штанга", "Диски", "Гиря", "Резиновая лента", "Эспандер", "Фитбол",
        "Медбол", "Степ-платформа", "Турник", "Петли TRX", "Коврик",
    ),
}


def list_exercises() -> list[dict]:
    query = Exercise.select().order_by(Exercise.muscle_group, Exercise.name)
    return [serialize_exercise(exercise) for exercise in query]


def get_exercise(exercise_id: int) -> Exercise:
    exercise = Exercise.get_or_none(Exercise.id == exercise_id)
    if exercise is None:
        raise NotFoundError("Упражнение не найдено")
    return exercise


def _ensure_default_workout_equipment() -> None:
    for kind, names in DEFAULT_WORKOUT_EQUIPMENT.items():
        for name in names:
            WorkoutEquipment.get_or_create(kind=kind, name=name)


def serialize_workout_equipment(item: WorkoutEquipment) -> dict:
    return {
        "id": item.id,
        "kind": item.kind,
        "name": item.name,
        "description": item.description,
        "photo": item.photo_url,
    }


def list_workout_equipment() -> list[dict]:
    _ensure_default_workout_equipment()
    query = WorkoutEquipment.select().order_by(WorkoutEquipment.kind, WorkoutEquipment.name)
    return [serialize_workout_equipment(item) for item in query]


def get_workout_equipment(equipment_id: int) -> WorkoutEquipment:
    item = WorkoutEquipment.get_or_none(WorkoutEquipment.id == equipment_id)
    if item is None:
        raise NotFoundError("Оборудование не найдено")
    return item


def _validate_workout_equipment(data: dict) -> tuple[str, str, str | None, str | None]:
    kind = str(data.get("kind") or "").strip()
    if kind not in DEFAULT_WORKOUT_EQUIPMENT:
        raise ValueError("Укажите тип оборудования")
    name = str(data.get("name") or "").strip()
    if not name:
        raise ValueError("Укажите название оборудования")
    description = str(data.get("description") or "").strip() or None
    photo = data.get("photo")
    if photo is not None and (not isinstance(photo, str) or not photo.strip()):
        raise ValueError("Некорректное фото оборудования")
    return kind, name, description, photo.strip() if isinstance(photo, str) else None


def create_workout_equipment(data: dict) -> dict:
    kind, name, description, photo = _validate_workout_equipment(data)
    if WorkoutEquipment.get_or_none((WorkoutEquipment.kind == kind) & (WorkoutEquipment.name == name)) is not None:
        raise ConflictError("Оборудование с таким названием уже существует")
    with current_database().atomic():
        item = WorkoutEquipment.create(kind=kind, name=name, description=description, photo_url=photo)
        return serialize_workout_equipment(item)


def update_workout_equipment(equipment_id: int, data: dict) -> dict:
    kind, name, description, photo = _validate_workout_equipment(data)
    item = get_workout_equipment(equipment_id)
    duplicate = WorkoutEquipment.get_or_none(
        (WorkoutEquipment.kind == kind)
        & (WorkoutEquipment.name == name)
        & (WorkoutEquipment.id != equipment_id)
    )
    if duplicate is not None:
        raise ConflictError("Оборудование с таким названием уже существует")
    item.kind = kind
    item.name = name
    item.description = description
    item.photo_url = photo
    item.save()
    return serialize_workout_equipment(item)


def _complex_media_values(data: dict) -> tuple[str | None, str | None]:
    photos = data.get("photos") or []
    if not isinstance(photos, list) or len(photos) > 6:
        raise ValueError("Можно добавить не более 6 фотографий комплекса")
    if any(not isinstance(item, str) or not item for item in photos):
        raise ValueError("Некорректное изображение комплекса")
    video = data.get("video")
    if video is not None and not isinstance(video, str):
        raise ValueError("Некорректное видео комплекса")
    return json.dumps(photos, ensure_ascii=False) if photos else None, video or None


def _replace_workout_complex_items(complex_item: WorkoutComplex, items: list[dict]) -> None:
    WorkoutComplexItem.delete().where(WorkoutComplexItem.complex == complex_item).execute()
    for item in items:
        exercise = get_exercise(int(item["exercise_id"]))
        WorkoutComplexItem.create(
            complex=complex_item,
            exercise=exercise,
            working_weight=number(item.get("working_weight")),
            sets=int_number(item.get("sets")),
            duration_minutes=int_number(item.get("duration_minutes")),
            speed_kmh=number(item.get("speed_kmh")),
        )


def serialize_workout_complex(complex_item: WorkoutComplex) -> dict:
    try:
        photos = json.loads(complex_item.photo_urls or "[]")
    except json.JSONDecodeError:
        photos = []
    items = (
        WorkoutComplexItem
        .select(WorkoutComplexItem, Exercise)
        .join(Exercise)
        .where(WorkoutComplexItem.complex == complex_item)
        .order_by(WorkoutComplexItem.id)
    )
    return {
        "id": complex_item.id,
        "name": complex_item.name,
        "comment": complex_item.comment,
        "photos": photos,
        "video": complex_item.video_url,
        "items": [
            {
                "id": item.id,
                "exercise_id": item.exercise.id,
                "exercise_code": item.exercise.code,
                "name": item.exercise.name,
                "muscle_group": item.exercise.muscle_group,
                "default_unit": item.exercise.default_unit,
                "working_weight": item.working_weight,
                "sets": item.sets,
                "duration_minutes": item.duration_minutes,
                "speed_kmh": item.speed_kmh,
            }
            for item in items
        ],
    }


def _ensure_default_workout_complexes() -> None:
    for name in DEFAULT_WORKOUT_COMPLEXES:
        if not WorkoutComplex.get_or_none(WorkoutComplex.name == name):
            WorkoutComplex.create(name=name, created_at=datetime.utcnow().isoformat(timespec="seconds"))


def list_workout_complexes() -> list[dict]:
    _ensure_default_workout_complexes()
    query = WorkoutComplex.select().order_by(WorkoutComplex.id)
    return [serialize_workout_complex(item) for item in query]


def create_workout_complex(data: dict) -> dict:
    name = str(data.get("name") or "").strip()
    if not name:
        raise ValueError("Укажите название комплекса")
    photo_urls, video_url = _complex_media_values(data)
    with current_database().atomic():
        complex_item = WorkoutComplex.create(
            name=name,
            comment=(data.get("comment") or "").strip() or None,
            photo_urls=photo_urls,
            video_url=video_url,
            created_at=datetime.utcnow().isoformat(timespec="seconds"),
        )
        _replace_workout_complex_items(complex_item, data.get("items") or [])
        return serialize_workout_complex(complex_item)


def update_workout_complex(complex_id: int, data: dict) -> dict:
    name = str(data.get("name") or "").strip()
    if not name:
        raise ValueError("Укажите название комплекса")
    complex_item = WorkoutComplex.get_or_none(WorkoutComplex.id == complex_id)
    if complex_item is None:
        raise NotFoundError("Комплекс тренировок не найден")
    photo_urls, video_url = _complex_media_values(data)
    with current_database().atomic():
        complex_item.name = name
        complex_item.comment = (data.get("comment") or "").strip() or None
        complex_item.photo_urls = photo_urls
        complex_item.video_url = video_url
        complex_item.save()
        _replace_workout_complex_items(complex_item, data.get("items") or [])
        return serialize_workout_complex(complex_item)


def _media_values(data: dict) -> tuple[str | None, str | None]:
    photos = data.get("photos") or []
    if not isinstance(photos, list) or len(photos) > 6:
        raise ValueError("Можно добавить не более 6 фотографий")
    if any(not isinstance(item, str) or not item for item in photos):
        raise ValueError("Некорректное изображение упражнения")
    video = data.get("video")
    if video is not None and not isinstance(video, str):
        raise ValueError("Некорректное видео упражнения")
    return json.dumps(photos, ensure_ascii=False) if photos else None, video or None


def _replace_exercise_variants(exercise: Exercise, variants: object) -> None:
    ExerciseVariant.delete().where(ExerciseVariant.exercise == exercise).execute()
    if not isinstance(variants, list):
        return
    for position, item in enumerate(variants, start=1):
        if not isinstance(item, dict):
            continue
        ExerciseVariant.create(
            exercise=exercise,
            position=position,
            machine=str(item.get("machine") or "").strip() or None,
            equipment=str(item.get("equipment") or "").strip() or None,
            description=str(item.get("description") or "").strip() or None,
            technique=str(item.get("technique") or "").strip() or None,
            tips=str(item.get("tips") or "").strip() or None,
        )


def create_exercise(data: dict) -> dict:
    with current_database().atomic():
        photo_urls, video_url = _media_values(data)
        exercise = Exercise.create(
            code=next_code("EX"),
            muscle_group=data.get("muscle_group"),
            name=data["name"],
            default_unit=data.get("default_unit", "кг"),
            default_sets=int_number(data.get("default_sets"), 3),
            default_reps=int_number(data.get("default_reps"), 12),
            target_rir=data.get("target_rir", "0–2"),
            note=data.get("note"),
            description=data.get("description") or data.get("note"),
            photo_urls=photo_urls,
            video_url=video_url,
        )
        _replace_exercise_variants(exercise, data.get("variants"))
        return serialize_exercise(exercise)


def update_exercise(exercise_id: int, data: dict) -> dict:
    with current_database().atomic():
        exercise = get_exercise(exercise_id)
        photo_urls, video_url = _media_values(data)
        exercise.name = data["name"]
        exercise.muscle_group = data.get("muscle_group")
        exercise.default_unit = data.get("default_unit", "кг")
        exercise.default_sets = int_number(data.get("default_sets"), 3)
        exercise.default_reps = int_number(data.get("default_reps"), 12)
        exercise.target_rir = data.get("target_rir", "0–2")
        exercise.note = data.get("note")
        exercise.description = data.get("description") or data.get("note")
        exercise.photo_urls = photo_urls
        exercise.video_url = video_url
        exercise.save()
        _replace_exercise_variants(exercise, data.get("variants"))
        return serialize_exercise(exercise)


def delete_exercise(exercise_id: int) -> dict:
    with current_database().atomic():
        exercise = get_exercise(exercise_id)
        usage_count = WorkoutLog.select().where(WorkoutLog.exercise == exercise).count()
        usage_count += WorkoutPlanItem.select().where(WorkoutPlanItem.exercise == exercise).count()
        if usage_count:
            raise ConflictError(
                f"Упражнение используется в тренировках: {usage_count}. "
                "Сначала удалите связанные записи тренировок."
            )
        exercise.delete_instance()
        return {"deleted": True, "id": exercise_id}


def list_workouts(user: User) -> list[dict]:
    query = (
        WorkoutLog
        .select(WorkoutLog, Exercise)
        .join(Exercise)
        .where(WorkoutLog.user == user)
        .order_by(WorkoutLog.performed_at.desc(), WorkoutLog.id.desc())
    )
    return [serialize_workout(log) for log in query]


def get_workout(log_id: int, user: User) -> WorkoutLog:
    log = WorkoutLog.get_or_none((WorkoutLog.id == log_id) & (WorkoutLog.user == user))
    if log is None:
        raise NotFoundError("Тренировка не найдена")
    return log


def _exercise_for_workout(data: dict, user: User) -> Exercise:
    exercise_id = data.get("exercise_id")
    if exercise_id:
        return get_exercise(exercise_id)
    if not data.get("exercise_name"):
        raise ValueError("Нужно выбрать или указать упражнение")
    if not user.is_admin:
        raise ForbiddenError("Только admin может создавать упражнения")
    return Exercise.create(
        code=next_code("EX"),
        name=data["exercise_name"],
        muscle_group=data.get("muscle_group"),
        default_unit=data.get("unit", "кг"),
        default_sets=int_number(data.get("sets"), 3),
        default_reps=int_number(data.get("reps"), 12),
        target_rir=data.get("rir", "0–2"),
        note=data.get("comment"),
    )


def create_workout(data: dict, user: User) -> dict:
    with current_database().atomic():
        exercise = _exercise_for_workout(data, user)
        log = WorkoutLog.create(
            user=user,
            performed_at=data["performed_at"],
            exercise=exercise,
            working_weight=number(data.get("working_weight")),
            sets=int_number(data.get("sets")),
            reps=int_number(data.get("reps")),
            rir=data.get("rir"),
            machine_location=data.get("machine_location"),
            comment=data.get("comment"),
        )
        return serialize_workout(log)


def update_workout(log_id: int, data: dict, user: User) -> dict:
    with current_database().atomic():
        log = get_workout(log_id, user)
        exercise = _exercise_for_workout(data, user)
        log.performed_at = data["performed_at"]
        log.exercise = exercise
        log.working_weight = number(data.get("working_weight"))
        log.sets = int_number(data.get("sets"))
        log.reps = int_number(data.get("reps"))
        log.rir = data.get("rir")
        log.machine_location = data.get("machine_location")
        log.comment = data.get("comment")
        log.save()
        return serialize_workout(log)


def delete_workout(log_id: int, user: User) -> dict:
    with current_database().atomic():
        log = get_workout(log_id, user)
        log.delete_instance()
        return {"deleted": True, "id": log_id}


def list_workout_plans(user: User) -> list[dict]:
    query = (
        WorkoutPlan
        .select()
        .where(WorkoutPlan.user == user)
        .order_by(WorkoutPlan.status, WorkoutPlan.scheduled_at.desc(), WorkoutPlan.id.desc())
    )
    return [serialize_workout_plan(plan) for plan in query]


def get_workout_plan(plan_id: int, user: User) -> WorkoutPlan:
    plan = WorkoutPlan.get_or_none((WorkoutPlan.id == plan_id) & (WorkoutPlan.user == user))
    if plan is None:
        raise NotFoundError("Собранная тренировка не найдена")
    return plan


def create_workout_plan(data: dict, user: User) -> dict:
    items = data.get("items") or []
    if not items:
        raise ValueError("Добавьте хотя бы одно упражнение")
    with current_database().atomic():
        plan = WorkoutPlan.create(user=user, scheduled_at=data["scheduled_at"], status="planned")
        for item in items:
            exercise = get_exercise(int(item["exercise_id"]))
            WorkoutPlanItem.create(
                plan=plan,
                exercise=exercise,
                working_weight=number(item.get("working_weight")),
                sets=int_number(item.get("sets")),
                duration_minutes=int_number(item.get("duration_minutes")),
                speed_kmh=number(item.get("speed_kmh")),
            )
        return serialize_workout_plan(plan)


def _replace_workout_plan_items(plan: WorkoutPlan, items: list[dict]) -> None:
    if not items:
        raise ValueError("Добавьте хотя бы одно упражнение")
    WorkoutPlanItem.delete().where(WorkoutPlanItem.plan == plan).execute()
    for item in items:
        exercise = get_exercise(int(item["exercise_id"]))
        WorkoutPlanItem.create(
            plan=plan,
            exercise=exercise,
            working_weight=number(item.get("working_weight")),
            sets=int_number(item.get("sets")),
            duration_minutes=int_number(item.get("duration_minutes")),
            speed_kmh=number(item.get("speed_kmh")),
        )


def update_workout_plan(plan_id: int, data: dict, user: User) -> dict:
    with current_database().atomic():
        plan = get_workout_plan(plan_id, user)
        if plan.status != "planned":
            raise ConflictError("Редактировать можно только запланированную тренировку")
        plan.scheduled_at = data["scheduled_at"]
        plan.save()
        _replace_workout_plan_items(plan, data.get("items") or [])
        return serialize_workout_plan(plan)


def complete_workout_plan(plan_id: int, user: User) -> dict:
    with current_database().atomic():
        plan = get_workout_plan(plan_id, user)
        plan.status = "archived"
        plan.completed_at = datetime.utcnow().isoformat(timespec="seconds")
        plan.save()
        return serialize_workout_plan(plan)


def cancel_workout_plan(plan_id: int, user: User) -> dict:
    with current_database().atomic():
        plan = get_workout_plan(plan_id, user)
        plan.status = "canceled"
        plan.completed_at = datetime.utcnow().isoformat(timespec="seconds")
        plan.save()
        return serialize_workout_plan(plan)


def delete_workout_plan(plan_id: int, user: User) -> dict:
    with current_database().atomic():
        plan = get_workout_plan(plan_id, user)
        plan.delete_instance(recursive=True)
        return {"deleted": True, "id": plan_id}
