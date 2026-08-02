from __future__ import annotations

from backend.models import Exercise, WorkoutLog, current_database
from backend.services.calculations import int_number, number
from backend.services.codes import next_code
from backend.services.errors import ConflictError, NotFoundError
from backend.services.serialization import serialize_exercise, serialize_workout


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
        if usage_count:
            raise ConflictError(
                f"Упражнение используется в тренировках: {usage_count}. "
                "Сначала удалите связанные записи тренировок."
            )
        exercise.delete_instance()
        return {"deleted": True, "id": exercise_id}


def list_workouts() -> list[dict]:
    query = (
        WorkoutLog
        .select(WorkoutLog, Exercise)
        .join(Exercise)
        .order_by(WorkoutLog.performed_at.desc(), WorkoutLog.id.desc())
    )
    return [serialize_workout(log) for log in query]


def get_workout(log_id: int) -> WorkoutLog:
    log = WorkoutLog.get_or_none(WorkoutLog.id == log_id)
    if log is None:
        raise NotFoundError("Тренировка не найдена")
    return log


def _exercise_for_workout(data: dict) -> Exercise:
    exercise_id = data.get("exercise_id")
    if exercise_id:
        return get_exercise(exercise_id)
    if not data.get("exercise_name"):
        raise ValueError("Нужно выбрать или указать упражнение")
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


def create_workout(data: dict) -> dict:
    with current_database().atomic():
        exercise = _exercise_for_workout(data)
        log = WorkoutLog.create(
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


def update_workout(log_id: int, data: dict) -> dict:
    with current_database().atomic():
        log = get_workout(log_id)
        exercise = _exercise_for_workout(data)
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


def delete_workout(log_id: int) -> dict:
    with current_database().atomic():
        log = get_workout(log_id)
        log.delete_instance()
        return {"deleted": True, "id": log_id}

