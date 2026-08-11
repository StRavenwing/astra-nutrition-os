from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
from backend.schemas import FeedbackInput, dump_model
from backend.services.feedback import create_feedback, list_feedback, mark_feedback_read, unread_feedback_count


router = APIRouter(prefix="/api/v1/feedback", tags=["feedback"])


@router.get("/unread-count")
def get_unread_feedback_count(current_user: User = Depends(require_admin)) -> dict:
    return {"count": unread_feedback_count()}


@router.get("")
def get_feedback(current_user: User = Depends(require_admin)) -> list[dict]:
    return list_feedback()


@router.post("/read")
def read_feedback(current_user: User = Depends(require_admin)) -> dict:
    mark_feedback_read()
    return {"ok": True}


@router.post("", status_code=status.HTTP_201_CREATED)
def post_feedback(payload: FeedbackInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_feedback(dump_model(payload), current_user)
