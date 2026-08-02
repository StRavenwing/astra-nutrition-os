from __future__ import annotations

from backend.models import ProgressEntry, User, current_database
from backend.services.calculations import int_number, number, progress_values
from backend.services.errors import NotFoundError
from backend.services.serialization import serialize_progress


def list_progress(user: User) -> list[dict]:
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
    entry.height_cm = height
    entry.bmi = bmi
    entry.body_fat_pct = body_fat
    entry.fat_mass_kg = fat_mass
    entry.muscle_pct = muscle
    entry.muscle_mass_kg = muscle_mass
    entry.protein_target_g = number(data.get("protein_target_g"))
    entry.fat_target_g = number(data.get("fat_target_g"))
    entry.waist_cm = number(data.get("waist_cm"))
    entry.chest_cm = number(data.get("chest_cm"))
    entry.hips_cm = number(data.get("hips_cm"))
    entry.sleep_score = int_number(data.get("sleep_score"))
    entry.wellbeing_score = int_number(data.get("wellbeing_score"))
    entry.comment = data.get("comment")
    return entry


def create_progress(data: dict, user: User) -> dict:
    with current_database().atomic():
        entry = _assign_progress(ProgressEntry(user=user), data)
        entry.save(force_insert=True)
        return serialize_progress(entry)


def update_progress(entry_id: int, data: dict, user: User) -> dict:
    with current_database().atomic():
        entry = _assign_progress(get_progress(entry_id, user), data)
        entry.save()
        return serialize_progress(entry)


def delete_progress(entry_id: int, user: User) -> dict:
    with current_database().atomic():
        entry = get_progress(entry_id, user)
        entry.delete_instance()
        return {"deleted": True, "id": entry_id}
