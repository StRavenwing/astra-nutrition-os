from __future__ import annotations

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from backend.models import User
from backend.services.auth import user_from_token
from backend.services.errors import ForbiddenError, UnauthorizedError


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise UnauthorizedError()
    return user_from_token(credentials.credentials, request.app.state.settings)


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise ForbiddenError("Только admin может изменять общие справочники")
    return current_user
