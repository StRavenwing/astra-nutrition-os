from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
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
def get_exercises(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_exercises()


@router.post("/exercises", status_code=status.HTTP_201_CREATED)
def post_exercise(payload: ExerciseInput, current_user: User = Depends(require_admin)) -> dict:
    return create_exercise(dump_model(payload))


@router.delete("/exercises/{exercise_id}")
def remove_exercise(exercise_id: int, current_user: User = Depends(require_admin)) -> dict:
    return delete_exercise(exercise_id)


@router.get("/workouts")
def get_workouts(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_workouts(current_user)


@router.post("/workouts", status_code=status.HTTP_201_CREATED)
def post_workout(payload: WorkoutInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_workout(dump_model(payload), current_user)


@router.put("/workouts/{log_id}")
def put_workout(log_id: int, payload: WorkoutInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_workout(log_id, dump_model(payload), current_user)


@router.delete("/workouts/{log_id}")
def remove_workout(log_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_workout(log_id, current_user)
