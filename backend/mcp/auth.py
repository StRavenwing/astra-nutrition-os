from __future__ import annotations

from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.provider import AccessToken

from backend.config import Settings
from backend.models import User
from backend.services.errors import ForbiddenError, UnauthorizedError
from backend.services.oauth import decode_access_token, mcp_resource_url


class AstraMCPTokenVerifier:
    def __init__(self, settings: Settings):
        self.settings = settings

    async def verify_token(self, token: str) -> AccessToken | None:
        payload = decode_access_token(token, self.settings)
        if payload is None:
            return None
        return AccessToken(
            token=token,
            client_id=str(payload["client_id"]),
            scopes=[str(scope) for scope in payload["scopes"]],
            expires_at=int(payload["exp"]),
            resource=mcp_resource_url(self.settings),
            subject=str(payload["sub"]),
            claims=payload,
        )


def require_mcp_user(scope: str, *, admin: bool = False) -> User:
    access_token = get_access_token()
    if access_token is None:
        raise UnauthorizedError()
    if scope not in access_token.scopes:
        raise ForbiddenError(f"Требуется scope {scope}")
    try:
        user_id = int(access_token.subject or "")
    except ValueError as exc:
        raise UnauthorizedError("Сессия MCP недействительна") from exc
    user = User.get_or_none(User.id == user_id)
    if user is None:
        raise UnauthorizedError("Пользователь не найден")
    if admin and not user.is_admin:
        raise ForbiddenError("Только admin может изменять рецепты через MCP")
    return user
