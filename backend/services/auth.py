from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import secrets
import smtplib
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from typing import Any

import jwt

from backend.config import Settings
from backend.models import PasswordResetCode, User, current_database
from backend.services.errors import ConflictError, DomainError, UnauthorizedError


JWT_ALGORITHM = "HS256"
PASSWORD_ITERATIONS = 260_000
PASSWORD_RESET_TTL_SECONDS = 10 * 60
PASSWORD_RESET_MAX_ATTEMPTS = 5
logger = logging.getLogger(__name__)


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
        "name": user.display_name or user.email.split("@", 1)[0],
        "is_admin": bool(user.is_admin),
        "is_trainer": bool(user.is_trainer),
    }


def create_access_token(user: User, settings: Settings) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": str(user.id),
        "email": user.email,
        "is_admin": bool(user.is_admin),
        "is_trainer": bool(user.is_trainer),
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


def _reset_code_hash(email: str, code: str, settings: Settings) -> str:
    value = f"{email}:{code}".encode("utf-8")
    return hmac.new(settings.auth_secret.encode("utf-8"), value, hashlib.sha256).hexdigest()


def _send_password_reset_email(email: str, code: str, settings: Settings) -> None:
    if not settings.smtp_host or not settings.smtp_from:
        raise DomainError("Отправка писем не настроена: укажите SMTP-параметры в .env", 503)

    message = EmailMessage()
    message["Subject"] = "Код восстановления Astra Nutrition OS"
    message["From"] = settings.smtp_from
    message["To"] = email
    message.set_content(
        "Здравствуйте!\n\n"
        f"Код для восстановления пароля: {code}\n\n"
        "Код действует 10 минут. Если вы не запрашивали восстановление, просто проигнорируйте это письмо.\n"
    )
    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            if settings.smtp_use_tls:
                server.starttls()
            if settings.smtp_username:
                server.login(settings.smtp_username, settings.smtp_password)
            server.send_message(message)
    except (OSError, smtplib.SMTPException) as exc:
        logger.exception("Password reset email delivery failed")
        raise DomainError("Не удалось отправить письмо с кодом. Попробуйте ещё раз позже", 503) from exc


def request_password_reset(email_value: str, settings: Settings) -> dict[str, Any]:
    email = normalize_email(email_value)
    user = User.get_or_none(User.email == email)
    if user is None:
        return {"ok": True, "message": "Если аккаунт существует, код отправлен на почту"}

    code = f"{secrets.randbelow(1_000_000):06d}"
    now = int(datetime.now(timezone.utc).timestamp())
    with current_database().atomic():
        PasswordResetCode.update(used_at=now).where(
            (PasswordResetCode.email == email) & PasswordResetCode.used_at.is_null(True)
        ).execute()
        PasswordResetCode.create(
            email=email,
            code_hash=_reset_code_hash(email, code, settings),
            expires_at=now + PASSWORD_RESET_TTL_SECONDS,
            attempts=0,
            created_at=now,
        )
    try:
        _send_password_reset_email(email, code, settings)
    except DomainError:
        PasswordResetCode.update(used_at=now).where(
            (PasswordResetCode.email == email) & PasswordResetCode.used_at.is_null(True)
        ).execute()
        raise
    return {"ok": True, "message": "Если аккаунт существует, код отправлен на почту"}


def confirm_password_reset(email_value: str, code: str, password: str, settings: Settings) -> dict[str, Any]:
    email = normalize_email(email_value)
    now = int(datetime.now(timezone.utc).timestamp())
    reset = (
        PasswordResetCode.select()
        .where(
            (PasswordResetCode.email == email)
            & PasswordResetCode.used_at.is_null(True)
            & (PasswordResetCode.expires_at >= now)
        )
        .order_by(PasswordResetCode.created_at.desc())
        .first()
    )
    if reset is None or reset.attempts >= PASSWORD_RESET_MAX_ATTEMPTS:
        raise UnauthorizedError("Код недействителен или истёк")

    reset.attempts += 1
    reset.save()
    expected = _reset_code_hash(email, code, settings)
    if not hmac.compare_digest(reset.code_hash, expected):
        raise UnauthorizedError("Код недействителен или истёк")

    user = User.get_or_none(User.email == email)
    if user is None:
        raise UnauthorizedError("Код недействителен или истёк")
    with current_database().atomic():
        user.password_hash = hash_password(password)
        user.save()
        reset.used_at = now
        reset.save()
    return {"ok": True, "message": "Пароль изменён"}
