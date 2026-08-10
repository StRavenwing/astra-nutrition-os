from __future__ import annotations

from fastapi import APIRouter, Depends, Request, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
from backend.schemas import AuthInput, dump_model
from backend.services.auth import (
    authenticate_user,
    create_access_token,
    register_user,
    serialize_user,
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


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)) -> dict:
    return {"ok": True}


@router.get("/me")
def me(current_user: User = Depends(get_current_user)) -> dict:
    return serialize_user(current_user)


@router.get("/users")
def users(current_user: User = Depends(require_admin)) -> list[dict]:
    return [
        {
            **serialize_user(user),
            "created_at": user.created_at,
        }
        for user in User.select().order_by(User.created_at.desc(), User.id.desc())
    ]
