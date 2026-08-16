from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
from backend.schemas import ExerciseInput, WorkoutComplexInput, WorkoutEquipmentInput, WorkoutInput, WorkoutPlanInput, dump_model
from backend.services.workouts import (
    create_exercise,
    update_exercise,
    create_workout,
    delete_exercise,
    delete_workout,
    list_exercises,
    list_workouts,
    update_workout,
    complete_workout_plan,
    create_workout_plan,
    list_workout_plans,
    update_workout_plan,
    cancel_workout_plan as cancel_plan_service,
    delete_workout_plan,
    create_workout_complex,
    list_workout_complexes,
    update_workout_complex,
    create_workout_equipment,
    list_workout_equipment,
    update_workout_equipment,
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


@router.put("/exercises/{exercise_id}")
def put_exercise(exercise_id: int, payload: ExerciseInput, current_user: User = Depends(require_admin)) -> dict:
    return update_exercise(exercise_id, dump_model(payload))


@router.get("/workout-equipment")
def get_workout_equipment_list(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_workout_equipment()


@router.post("/workout-equipment", status_code=status.HTTP_201_CREATED)
def post_workout_equipment(payload: WorkoutEquipmentInput, current_user: User = Depends(require_admin)) -> dict:
    return create_workout_equipment(dump_model(payload))


@router.put("/workout-equipment/{equipment_id}")
def put_workout_equipment(equipment_id: int, payload: WorkoutEquipmentInput, current_user: User = Depends(require_admin)) -> dict:
    return update_workout_equipment(equipment_id, dump_model(payload))


@router.get("/workout-complexes")
def get_workout_complexes(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_workout_complexes()


@router.post("/workout-complexes", status_code=status.HTTP_201_CREATED)
def post_workout_complex(payload: WorkoutComplexInput, current_user: User = Depends(require_admin)) -> dict:
    return create_workout_complex(dump_model(payload))


@router.put("/workout-complexes/{complex_id}")
def put_workout_complex(complex_id: int, payload: WorkoutComplexInput, current_user: User = Depends(require_admin)) -> dict:
    return update_workout_complex(complex_id, dump_model(payload))


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


@router.get("/workout-plans")
def get_workout_plans(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_workout_plans(current_user)


@router.post("/workout-plans", status_code=status.HTTP_201_CREATED)
def post_workout_plan(payload: WorkoutPlanInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_workout_plan(dump_model(payload), current_user)


@router.put("/workout-plans/{plan_id}")
def put_workout_plan(plan_id: int, payload: WorkoutPlanInput, current_user: User = Depends(get_current_user)) -> dict:
    return update_workout_plan(plan_id, dump_model(payload), current_user)


@router.post("/workout-plans/{plan_id}/complete")
def finish_workout_plan(plan_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return complete_workout_plan(plan_id, current_user)


@router.post("/workout-plans/{plan_id}/cancel")
def stop_workout_plan(plan_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return cancel_plan_service(plan_id, current_user)


@router.delete("/workout-plans/{plan_id}")
def remove_workout_plan(plan_id: int, current_user: User = Depends(get_current_user)) -> dict:
    return delete_workout_plan(plan_id, current_user)
