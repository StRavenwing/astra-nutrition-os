from __future__ import annotations

from fastapi import APIRouter, status

from backend.schemas import ExerciseInput, WorkoutInput, dump_model
from backend.services.workouts import (
    create_exercise,
    create_workout,
    delete_exercise,
    delete_workout,
    list_exercises,
    list_workouts,
    update_workout,
)


router = APIRouter(prefix="/api/v1", tags=["workouts"])


@router.get("/exercises")
def get_exercises() -> list[dict]:
    return list_exercises()


@router.post("/exercises", status_code=status.HTTP_201_CREATED)
def post_exercise(payload: ExerciseInput) -> dict:
    return create_exercise(dump_model(payload))


@router.delete("/exercises/{exercise_id}")
def remove_exercise(exercise_id: int) -> dict:
    return delete_exercise(exercise_id)


@router.get("/workouts")
def get_workouts() -> list[dict]:
    return list_workouts()


@router.post("/workouts", status_code=status.HTTP_201_CREATED)
def post_workout(payload: WorkoutInput) -> dict:
    return create_workout(dump_model(payload))


@router.put("/workouts/{log_id}")
def put_workout(log_id: int, payload: WorkoutInput) -> dict:
    return update_workout(log_id, dump_model(payload))


@router.delete("/workouts/{log_id}")
def remove_workout(log_id: int) -> dict:
    return delete_workout(log_id)

