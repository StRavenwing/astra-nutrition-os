from __future__ import annotations

from datetime import date

from peewee import IntegrityError

from backend.models import ProgressEntry, User, current_database
from backend.services.calculations import int_number, number, progress_values
from backend.services.errors import ConflictError, NotFoundError
from backend.services.serialization import serialize_progress


PROGRESS_DATE_CONFLICT_MESSAGE = "На выбранную дату уже есть замер. Выберите другую дату или измените существующий замер."


def list_progress(user: User | None) -> list[dict]:
    if user is None:
        return []
    query = (
        ProgressEntry
        .select()
        .where(ProgressEntry.user == user)
        .order_by(ProgressEntry.measured_at.desc())
    )
    return [serialize_progress(entry) for entry in query]


def get_progress(entry_id: int, user: User) -> ProgressEntry:
    entry = ProgressEntry.get_or_none((ProgressEntry.id == entry_id) & (ProgressEntry.user == user))
    if entry is None:
        raise NotFoundError("Замер не найден")
    return entry


def _assign_progress(entry: ProgressEntry, data: dict) -> ProgressEntry:
    height, bmi, body_fat, fat_mass, muscle, muscle_mass = progress_values(data)
    entry.measured_at = data["measured_at"]
    entry.weight_kg = number(data.get("weight_kg"))
    entry.desired_weight_kg = number(data.get("desired_weight_kg"))
    entry.height_cm = height
    entry.bmi = bmi
    entry.body_fat_pct = body_fat
    entry.fat_mass_kg = fat_mass
    entry.muscle_pct = muscle
    entry.muscle_mass_kg = muscle_mass
    entry.kcal_target = number(data.get("kcal_target"))
    entry.protein_target_g = number(data.get("protein_target_g"))
    entry.fat_target_g = number(data.get("fat_target_g"))
    entry.carbs_target_g = number(data.get("carbs_target_g"))
    entry.waist_cm = number(data.get("waist_cm"))
    entry.chest_cm = number(data.get("chest_cm"))
    entry.hips_cm = number(data.get("hips_cm"))
    entry.biceps_cm = number(data.get("biceps_cm"))
    entry.thigh_cm = number(data.get("thigh_cm"))
    entry.sleep_score = int_number(data.get("sleep_score"))
    entry.wellbeing_score = int_number(data.get("wellbeing_score"))
    entry.comment = data.get("comment")
    return entry


def _ensure_date_available(user: User, measured_at: str, entry_id: int | None = None) -> None:
    query = ProgressEntry.select().where(
        (ProgressEntry.user == user) & (ProgressEntry.measured_at == measured_at)
    )
    if entry_id is not None:
        query = query.where(ProgressEntry.id != entry_id)
    if query.exists():
        raise ConflictError(PROGRESS_DATE_CONFLICT_MESSAGE)


def _validate_measured_at(measured_at: str) -> None:
    try:
        measured_date = date.fromisoformat(measured_at)
    except (TypeError, ValueError) as exc:
        raise ValueError("Введите корректную дату замера.") from exc
    if measured_date > date.today():
        raise ValueError("Дата замера не может быть в будущем. Выберите сегодняшнюю или более раннюю дату.")


def _save_progress(entry: ProgressEntry, *, force_insert: bool = False) -> None:
    try:
        entry.save(force_insert=force_insert)
    except IntegrityError as exc:
        if "progress_entries.user_id, progress_entries.measured_at" in str(exc):
            raise ConflictError(PROGRESS_DATE_CONFLICT_MESSAGE) from exc
        raise


def create_progress(data: dict, user: User) -> dict:
    with current_database().atomic():
        _validate_measured_at(data["measured_at"])
        _ensure_date_available(user, data["measured_at"])
        entry = _assign_progress(ProgressEntry(user=user), data)
        _save_progress(entry, force_insert=True)
        return serialize_progress(entry)


def update_progress(entry_id: int, data: dict, user: User) -> dict:
    with current_database().atomic():
        _validate_measured_at(data["measured_at"])
        entry = get_progress(entry_id, user)
        _ensure_date_available(user, data["measured_at"], entry.id)
        entry = _assign_progress(entry, data)
        _save_progress(entry)
        return serialize_progress(entry)


def delete_progress(entry_id: int, user: User) -> dict:
    with current_database().atomic():
        entry = get_progress(entry_id, user)
        entry.delete_instance()
        return {"deleted": True, "id": entry_id}
