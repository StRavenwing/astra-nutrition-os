from __future__ import annotations

from backend.models import FeedbackMessage, User, current_database
from backend.services.errors import NotFoundError
from backend.services.auth import utc_now


def serialize_feedback(item: FeedbackMessage) -> dict:
    return {
        "id": item.id,
        "email": item.user.email,
        "submitted_at": item.submitted_at,
        "message": item.message,
        "is_read": bool(item.is_read),
        "reply": item.reply,
        "replied_at": item.replied_at,
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


def list_feedback(user: User | None = None) -> list[dict]:
    query = (
        FeedbackMessage
        .select(FeedbackMessage, User)
        .join(User)
        .order_by(FeedbackMessage.submitted_at.desc(), FeedbackMessage.id.desc())
    )
    if user is not None:
        query = query.where(FeedbackMessage.user == user)
    return [serialize_feedback(item) for item in query]


def unread_feedback_count() -> int:
    return FeedbackMessage.select().where(FeedbackMessage.is_read == False).count()


def mark_feedback_read(message_id: int) -> None:
    item = FeedbackMessage.get_or_none(FeedbackMessage.id == message_id)
    if item is None:
        raise NotFoundError("Сообщение не найдено")
    if not item.is_read:
        item.is_read = True
        item.save(only=[FeedbackMessage.is_read])


def reply_feedback(message_id: int, reply: str) -> dict:
    item = FeedbackMessage.get_or_none(FeedbackMessage.id == message_id)
    if item is None:
        raise NotFoundError("Сообщение не найдено")
    value = reply.strip()
    if not value:
        raise ValueError("Ответ не может быть пустым")
    item.reply = value
    item.replied_at = utc_now()
    item.save(only=[FeedbackMessage.reply, FeedbackMessage.replied_at])
    return serialize_feedback(item)
