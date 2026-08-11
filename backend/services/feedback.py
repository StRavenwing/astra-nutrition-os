from __future__ import annotations

from backend.models import FeedbackMessage, User, current_database
from backend.services.auth import utc_now


def serialize_feedback(item: FeedbackMessage) -> dict:
    return {
        "id": item.id,
        "email": item.user.email,
        "submitted_at": item.submitted_at,
        "message": item.message,
        "is_read": bool(item.is_read),
    }


def create_feedback(data: dict, user: User) -> dict:
    message = str(data.get("message") or "").strip()
    if not message:
        raise ValueError("Сообщение не может быть пустым")
    if len(message) > 500:
        raise ValueError("Сообщение не должно превышать 500 символов")
    with current_database().atomic():
        item = FeedbackMessage.create(user=user, message=message, submitted_at=utc_now())
        return serialize_feedback(item)


def list_feedback() -> list[dict]:
    query = (
        FeedbackMessage
        .select(FeedbackMessage, User)
        .join(User)
        .order_by(FeedbackMessage.submitted_at.desc(), FeedbackMessage.id.desc())
    )
    return [serialize_feedback(item) for item in query]


def unread_feedback_count() -> int:
    return FeedbackMessage.select().where(FeedbackMessage.is_read == False).count()


def mark_feedback_read() -> None:
    FeedbackMessage.update(is_read=True).where(FeedbackMessage.is_read == False).execute()
