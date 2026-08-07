from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt

from backend.config import Settings
from backend.models import User, current_database
from backend.services.errors import ConflictError, UnauthorizedError


JWT_ALGORITHM = "HS256"
PASSWORD_ITERATIONS = 260_000


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def normalize_email(email: str | None) -> str:
    value = (email or "").strip().lower()
    if "@" not in value or value.startswith("@") or value.endswith("@"):
        raise ValueError("Некорректный email")
    return value


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def hash_password(password: str) -> str:
    if len(password or "") < 8:
        raise ValueError("Пароль должен быть не короче 8 символов")
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS)
    return f"pbkdf2_sha256${PASSWORD_ITERATIONS}${_b64encode(salt)}${_b64encode(digest)}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, salt, digest = password_hash.split("$", 3)
    except ValueError:
        return False
    if algorithm != "pbkdf2_sha256":
        return False
    expected = hashlib.pbkdf2_hmac(
        "sha256",
        (password or "").encode("utf-8"),
        _b64decode(salt),
        int(iterations),
    )
    return hmac.compare_digest(_b64encode(expected), digest)


def serialize_user(user: User) -> dict[str, Any]:
    return {
        "id": user.id,
        "email": user.email,
        "is_admin": bool(user.is_admin),
    }


def create_access_token(user: User, settings: Settings) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "is_admin": bool(user.is_admin),
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.auth_secret, algorithm=JWT_ALGORITHM)


def user_from_token(token: str, settings: Settings) -> User:
    try:
        payload = jwt.decode(token, settings.auth_secret, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except Exception as exc:
        raise UnauthorizedError("Сессия недействительна или истекла") from exc
    user = User.get_or_none(User.id == user_id)
    if user is None:
        raise UnauthorizedError("Пользователь не найден")
    return user


def ensure_admin_user(settings: Settings) -> User:
    email = normalize_email(settings.admin_email)
    password_hash = hash_password(settings.admin_password)
    with current_database().atomic():
        User.update(is_admin=False).where(User.email != email).execute()
        user, _ = User.get_or_create(
            email=email,
            defaults={
                "password_hash": password_hash,
                "is_admin": True,
                "created_at": utc_now(),
            },
        )
        user.password_hash = password_hash
        user.is_admin = True
        user.save()
        return user


def register_user(data: dict[str, Any]) -> User:
    email = normalize_email(data.get("email"))
    with current_database().atomic():
        if User.select().where(User.email == email).exists():
            raise ConflictError("Пользователь с таким email уже существует")
        user = User.create(
            email=email,
            password_hash=hash_password(data.get("password") or ""),
            is_admin=False,
            created_at=utc_now(),
        )
    return user


def authenticate_user(data: dict[str, Any]) -> User:
    email = normalize_email(data.get("email"))
    user = User.get_or_none(User.email == email)
    if user is None or not verify_password(data.get("password") or "", user.password_hash):
        raise UnauthorizedError("Неверный email или пароль")
    return user
