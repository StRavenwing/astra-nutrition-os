from __future__ import annotations

from fastapi import APIRouter, Depends, Request, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
from backend.schemas import (
    AuthInput,
    EmailVerificationConfirmInput,
    PasswordChangeInput,
    PasswordResetConfirmInput,
    PasswordResetRequestInput,
    ProfileUpdateInput,
    dump_model,
)
from backend.services.auth import (
    authenticate_user,
    change_password,
    confirm_email_verification,
    create_access_token,
    register_user,
    confirm_password_reset,
    request_email_verification,
    request_password_reset,
    serialize_user,
    update_profile,
)


router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _auth_response(user: User, request: Request) -> dict:
    return {
        "access_token": create_access_token(user, request.app.state.settings),
        "token_type": "bearer",
        "user": serialize_user(user),
    }


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(payload: AuthInput, request: Request) -> dict:
    return _auth_response(register_user(dump_model(payload)), request)


@router.post("/login")
def login(payload: AuthInput, request: Request) -> dict:
    return _auth_response(authenticate_user(dump_model(payload)), request)


@router.post("/password-reset/request")
def password_reset_request(payload: PasswordResetRequestInput, request: Request) -> dict:
    return request_password_reset(payload.email, request.app.state.settings)


@router.post("/password-reset/confirm")
def password_reset_confirm(payload: PasswordResetConfirmInput, request: Request) -> dict:
    return confirm_password_reset(payload.email, payload.code, payload.password, request.app.state.settings)


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)) -> dict:
    return {"ok": True}


@router.get("/me")
def me(current_user: User = Depends(get_current_user)) -> dict:
    return serialize_user(current_user)


@router.put("/me/profile")
def update_me(payload: ProfileUpdateInput, current_user: User = Depends(get_current_user)) -> dict:
    return serialize_user(update_profile(dump_model(payload), current_user))


@router.post("/me/password")
def update_my_password(payload: PasswordChangeInput, current_user: User = Depends(get_current_user)) -> dict:
    change_password(dump_model(payload), current_user)
    return {"ok": True, "message": "Пароль изменён"}


@router.post("/me/email-verification/request")
def request_my_email_verification(request: Request, current_user: User = Depends(get_current_user)) -> dict:
    return request_email_verification(current_user, request.app.state.settings)


@router.post("/me/email-verification/confirm")
def confirm_my_email_verification(
    payload: EmailVerificationConfirmInput,
    request: Request,
    current_user: User = Depends(get_current_user),
) -> dict:
    return serialize_user(confirm_email_verification(payload.code, current_user, request.app.state.settings))


@router.get("/users")
def users(current_user: User = Depends(require_admin)) -> list[dict]:
    return [
        {
            **serialize_user(user),
            "created_at": user.created_at,
        }
        for user in User.select().order_by(User.created_at.desc(), User.id.desc())
    ]
