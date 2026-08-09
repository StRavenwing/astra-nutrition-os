from __future__ import annotations

from datetime import datetime

from backend.models import Exercise, User, WorkoutLog, WorkoutPlan, WorkoutPlanItem, current_database
from backend.services.calculations import int_number, number
from backend.services.codes import next_code
from backend.services.errors import ConflictError, ForbiddenError, NotFoundError
from backend.services.serialization import serialize_exercise, serialize_workout, serialize_workout_plan


def list_exercises() -> list[dict]:
    query = Exercise.select().order_by(Exercise.muscle_group, Exercise.name)
    return [serialize_exercise(exercise) for exercise in query]


def get_exercise(exercise_id: int) -> Exercise:
    exercise = Exercise.get_or_none(Exercise.id == exercise_id)
    if exercise is None:
        raise NotFoundError("Упражнение не найдено")
    return exercise


def create_exercise(data: dict) -> dict:
    with current_database().atomic():
        exercise = Exercise.create(
            code=next_code("EX"),
            muscle_group=data.get("muscle_group"),
            name=data["name"],
            default_unit=data.get("default_unit", "кг"),
            default_sets=int_number(data.get("default_sets"), 3),
            default_reps=int_number(data.get("default_reps"), 12),
            target_rir=data.get("target_rir", "0–2"),
            note=data.get("note"),
        )
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
