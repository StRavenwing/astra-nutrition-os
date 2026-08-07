from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

import jwt

from backend.config import Settings
from backend.models import (
    OAuthAuthorizationCode,
    OAuthClient,
    OAuthPendingAuthorization,
    OAuthRefreshToken,
    User,
    current_database,
)
from backend.services.auth import JWT_ALGORITHM, authenticate_user


VALID_SCOPES = ("recipes:read", "recipes:write")
DEFAULT_SCOPES = VALID_SCOPES
CLIENT_AUTH_METHODS = ("none", "client_secret_post", "client_secret_basic")
GRANT_TYPES = ("authorization_code", "refresh_token")
RESPONSE_TYPES = ("code",)


class OAuthError(Exception):
    def __init__(self, error: str, description: str, status_code: int = 400):
        super().__init__(description)
        self.error = error
        self.description = description
        self.status_code = status_code


def now_ts() -> int:
    return int(time.time())


def mcp_resource_url(settings: Settings) -> str:
    return f"{settings.public_base_url}/mcp"


def _hash_value(value: str, settings: Settings) -> str:
    return hmac.new(settings.auth_secret.encode("utf-8"), value.encode("utf-8"), hashlib.sha256).hexdigest()


def _json_list(value: str | None) -> list[str]:
    if not value:
        return []
    data = json.loads(value)
    if not isinstance(data, list):
        return []
    return [str(item) for item in data]


def _dump_list(values: list[str] | tuple[str, ...]) -> str:
    return json.dumps(list(values), ensure_ascii=False, separators=(",", ":"))


def _scope_string(scopes: list[str] | tuple[str, ...]) -> str:
    return " ".join(scopes)


def parse_scope(scope: str | None, default: tuple[str, ...] = DEFAULT_SCOPES) -> list[str]:
    if scope is None or not scope.strip():
        return list(default)
    scopes = [item for item in scope.split(" ") if item]
    invalid = sorted(set(scopes) - set(VALID_SCOPES))
    if invalid:
        raise OAuthError("invalid_scope", f"Unsupported scopes: {', '.join(invalid)}")
    return scopes


def _require_string(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        raise OAuthError("invalid_request", f"Missing required field: {key}")
    return value.strip()


def _validate_url(value: str, *, allow_http_localhost: bool = True) -> str:
    parsed = urlparse(value)
    if parsed.scheme == "https" and parsed.netloc:
        return value
    if allow_http_localhost and parsed.scheme == "http" and parsed.hostname in {"localhost", "127.0.0.1", "testserver"}:
        return value
    raise OAuthError("invalid_request", "URLs must be HTTPS, except localhost/test URLs")


def _with_query(url: str, **params: str | None) -> str:
    parsed = urlparse(url)
    existing = dict(parse_qsl(parsed.query, keep_blank_values=True))
    for key, value in params.items():
        if value is not None:
            existing[key] = value
    return urlunparse(parsed._replace(query=urlencode(existing)))


def _code_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def _client_response(client: OAuthClient, client_secret: str | None = None) -> dict[str, Any]:
    metadata = json.loads(client.metadata_json or "{}")
    response = {
        **metadata,
        "client_id": client.client_id,
        "client_id_issued_at": client.client_id_issued_at,
        "redirect_uris": _json_list(client.redirect_uris),
        "token_endpoint_auth_method": client.token_endpoint_auth_method,
        "grant_types": _json_list(client.grant_types),
        "response_types": _json_list(client.response_types),
        "scope": client.scope,
    }
    if client_secret is not None:
        response["client_secret"] = client_secret
        response["client_secret_expires_at"] = client.client_secret_expires_at
    return {key: value for key, value in response.items() if value is not None}


def authorization_server_metadata(settings: Settings) -> dict[str, Any]:
    base = settings.public_base_url
    return {
        "issuer": base,
        "authorization_endpoint": f"{base}/oauth/authorize",
        "token_endpoint": f"{base}/oauth/token",
        "registration_endpoint": f"{base}/oauth/register",
        "revocation_endpoint": f"{base}/oauth/revoke",
        "response_types_supported": list(RESPONSE_TYPES),
        "response_modes_supported": ["query"],
        "grant_types_supported": list(GRANT_TYPES),
        "token_endpoint_auth_methods_supported": list(CLIENT_AUTH_METHODS),
        "scopes_supported": list(VALID_SCOPES),
        "code_challenge_methods_supported": ["S256"],
        "service_documentation": f"{base}/",
    }


def protected_resource_metadata(settings: Settings) -> dict[str, Any]:
    return {
        "resource": mcp_resource_url(settings),
        "authorization_servers": [settings.public_base_url],
        "scopes_supported": list(VALID_SCOPES),
        "bearer_methods_supported": ["header"],
        "resource_name": "Astra Nutrition OS MCP",
    }


def register_client(data: dict[str, Any], settings: Settings) -> dict[str, Any]:
    redirect_uris = data.get("redirect_uris")
    if not isinstance(redirect_uris, list) or not redirect_uris:
        raise OAuthError("invalid_client_metadata", "redirect_uris must be a non-empty list")
    redirect_uris = [_validate_url(str(uri)) for uri in redirect_uris]

    token_auth_method = data.get("token_endpoint_auth_method") or "none"
    if token_auth_method not in CLIENT_AUTH_METHODS:
        raise OAuthError("invalid_client_metadata", "Unsupported token_endpoint_auth_method")

    grant_types = data.get("grant_types") or list(GRANT_TYPES)
    response_types = data.get("response_types") or list(RESPONSE_TYPES)
    if not isinstance(grant_types, list) or not set(GRANT_TYPES).issubset({str(item) for item in grant_types}):
        raise OAuthError("invalid_client_metadata", "grant_types must include authorization_code and refresh_token")
    if not isinstance(response_types, list) or "code" not in {str(item) for item in response_types}:
        raise OAuthError("invalid_client_metadata", "response_types must include code")

    scopes = parse_scope(data.get("scope"), DEFAULT_SCOPES)
    client_id = secrets.token_urlsafe(24)
    client_secret = None
    client_secret_hash = None
    issued_at = now_ts()
    secret_expires_at = None
    if token_auth_method != "none":
        client_secret = secrets.token_urlsafe(32)
        client_secret_hash = _hash_value(client_secret, settings)
        secret_expires_at = issued_at + 365 * 24 * 60 * 60

    metadata_keys = {
        "client_name",
        "client_uri",
        "logo_uri",
        "contacts",
        "tos_uri",
        "policy_uri",
        "jwks_uri",
        "jwks",
        "software_id",
        "software_version",
    }
    metadata = {key: data.get(key) for key in metadata_keys if data.get(key) is not None}
    client = OAuthClient.create(
        client_id=client_id,
        client_secret_hash=client_secret_hash,
        client_secret_expires_at=secret_expires_at,
        client_id_issued_at=issued_at,
        redirect_uris=_dump_list(redirect_uris),
        token_endpoint_auth_method=token_auth_method,
        grant_types=_dump_list([str(item) for item in grant_types]),
        response_types=_dump_list([str(item) for item in response_types]),
        scope=_scope_string(scopes),
        client_name=str(data.get("client_name")) if data.get("client_name") is not None else None,
        metadata_json=json.dumps(metadata, ensure_ascii=False, separators=(",", ":")),
    )
    return _client_response(client, client_secret)


def _get_client(client_id: str) -> OAuthClient:
    client = OAuthClient.get_or_none(OAuthClient.client_id == client_id)
    if client is None:
        raise OAuthError("invalid_client", "Unknown client_id", 401)
    return client


def start_authorization(params: dict[str, Any], settings: Settings) -> str:
    if params.get("response_type") != "code":
        raise OAuthError("unsupported_response_type", "Only authorization code flow is supported")
    client = _get_client(_require_string(params, "client_id"))
    redirect_uri = _validate_url(_require_string(params, "redirect_uri"))
    if redirect_uri not in _json_list(client.redirect_uris):
        raise OAuthError("invalid_request", "redirect_uri is not registered for this client")
    if _require_string(params, "code_challenge_method") != "S256":
        raise OAuthError("invalid_request", "code_challenge_method must be S256")
    code_challenge = _require_string(params, "code_challenge")
    requested_scopes = parse_scope(params.get("scope"), tuple((client.scope or "").split()))
    invalid = sorted(set(requested_scopes) - set((client.scope or "").split()))
    if invalid:
        raise OAuthError("invalid_scope", f"Client is not registered for scopes: {', '.join(invalid)}")
    resource = params.get("resource")
    if resource and str(resource).rstrip("/") != mcp_resource_url(settings):
        raise OAuthError("invalid_target", "resource must match the MCP resource URL")

    request_id = secrets.token_urlsafe(24)
    timestamp = now_ts()
    with current_database().atomic():
        OAuthPendingAuthorization.delete().where(OAuthPendingAuthorization.expires_at < timestamp).execute()
        OAuthPendingAuthorization.create(
            request_id=request_id,
            client=client,
            redirect_uri=redirect_uri,
            scopes=_dump_list(requested_scopes),
            state=str(params.get("state")) if params.get("state") is not None else None,
            code_challenge=code_challenge,
            resource=str(resource) if resource is not None else None,
            expires_at=timestamp + settings.mcp_auth_code_minutes * 60,
            created_at=timestamp,
        )
    return request_id


def load_pending_authorization(request_id: str) -> OAuthPendingAuthorization:
    pending = OAuthPendingAuthorization.get_or_none(OAuthPendingAuthorization.request_id == request_id)
    if pending is None or pending.expires_at < now_ts():
        raise OAuthError("invalid_request", "Authorization request expired or not found")
    return pending


def complete_authorization(request_id: str, credentials: dict[str, Any], settings: Settings) -> str:
    pending = load_pending_authorization(request_id)
    user = authenticate_user(credentials)
    requested_scopes = _json_list(pending.scopes)
    granted_scopes = [scope for scope in requested_scopes if scope != "recipes:write" or user.is_admin]
    if not granted_scopes:
        raise OAuthError("access_denied", "This user cannot grant the requested scopes", 403)

    code = secrets.token_urlsafe(32)
    timestamp = now_ts()
    with current_database().atomic():
        OAuthAuthorizationCode.create(
            code_hash=_hash_value(code, settings),
            client=pending.client,
            user=user,
            scopes=_dump_list(granted_scopes),
            code_challenge=pending.code_challenge,
            redirect_uri=pending.redirect_uri,
            resource=pending.resource,
            expires_at=timestamp + settings.mcp_auth_code_minutes * 60,
            created_at=timestamp,
        )
        pending.delete_instance()
    return _with_query(pending.redirect_uri, code=code, state=pending.state)


def _authenticate_client(form: dict[str, Any], authorization_header: str | None, settings: Settings) -> OAuthClient:
    client_id = str(form.get("client_id") or "")
    basic_secret = None
    if authorization_header and authorization_header.startswith("Basic "):
        try:
            decoded = base64.b64decode(authorization_header[6:]).decode("utf-8")
            basic_client_id, basic_secret = decoded.split(":", 1)
        except Exception as exc:
            raise OAuthError("invalid_client", "Invalid Basic client authentication", 401) from exc
        if client_id and client_id != basic_client_id:
            raise OAuthError("invalid_client", "client_id mismatch", 401)
        client_id = basic_client_id

    if not client_id:
        raise OAuthError("invalid_client", "Missing client_id", 401)
    client = _get_client(client_id)
    if client.token_endpoint_auth_method == "none":
        return client

    supplied_secret = basic_secret if client.token_endpoint_auth_method == "client_secret_basic" else form.get("client_secret")
    if not isinstance(supplied_secret, str) or not supplied_secret:
        raise OAuthError("invalid_client", "Missing client_secret", 401)
    if client.client_secret_expires_at and client.client_secret_expires_at < now_ts():
        raise OAuthError("invalid_client", "Client secret expired", 401)
    if not client.client_secret_hash or not hmac.compare_digest(client.client_secret_hash, _hash_value(supplied_secret, settings)):
        raise OAuthError("invalid_client", "Invalid client_secret", 401)
    return client


def _create_access_token(user: User, client_id: str, scopes: list[str], settings: Settings) -> tuple[str, int]:
    expires_in = settings.mcp_access_token_minutes * 60
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
    payload = {
        "type": "mcp_access",
        "sub": str(user.id),
        "client_id": client_id,
        "scopes": scopes,
        "scope": _scope_string(scopes),
        "iss": settings.public_base_url,
        "aud": mcp_resource_url(settings),
        "iat": datetime.now(timezone.utc),
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.auth_secret, algorithm=JWT_ALGORITHM), expires_in


def _create_refresh_token(user: User, client: OAuthClient, scopes: list[str], settings: Settings) -> tuple[str, OAuthRefreshToken]:
    token = secrets.token_urlsafe(40)
    timestamp = now_ts()
    refresh = OAuthRefreshToken.create(
        token_hash=_hash_value(token, settings),
        client=client,
        user=user,
        scopes=_dump_list(scopes),
        expires_at=timestamp + settings.mcp_refresh_token_days * 24 * 60 * 60,
        created_at=timestamp,
    )
    return token, refresh


def exchange_token(form: dict[str, Any], authorization_header: str | None, settings: Settings) -> dict[str, Any]:
    client = _authenticate_client(form, authorization_header, settings)
    grant_type = form.get("grant_type")
    if grant_type == "authorization_code":
        return _exchange_authorization_code(form, client, settings)
    if grant_type == "refresh_token":
        return _exchange_refresh_token(form, client, settings)
    raise OAuthError("unsupported_grant_type", "Unsupported grant_type")


def _exchange_authorization_code(form: dict[str, Any], client: OAuthClient, settings: Settings) -> dict[str, Any]:
    code = _require_string(form, "code")
    verifier = _require_string(form, "code_verifier")
    authorization_code = OAuthAuthorizationCode.get_or_none(OAuthAuthorizationCode.code_hash == _hash_value(code, settings))
    if (
        authorization_code is None
        or authorization_code.client_id != client.client_id
        or authorization_code.used_at is not None
        or authorization_code.expires_at < now_ts()
    ):
        raise OAuthError("invalid_grant", "Authorization code is invalid or expired")
    redirect_uri = str(form.get("redirect_uri") or "")
    if redirect_uri != authorization_code.redirect_uri:
        raise OAuthError("invalid_request", "redirect_uri does not match the authorization request")
    if _code_challenge(verifier) != authorization_code.code_challenge:
        raise OAuthError("invalid_grant", "Invalid code_verifier")

    scopes = _json_list(authorization_code.scopes)
    with current_database().atomic():
        authorization_code.used_at = now_ts()
        authorization_code.save()
        refresh_token, _ = _create_refresh_token(authorization_code.user, client, scopes, settings)
    access_token, expires_in = _create_access_token(authorization_code.user, client.client_id, scopes, settings)
    return {
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": expires_in,
        "scope": _scope_string(scopes),
        "refresh_token": refresh_token,
    }


def _exchange_refresh_token(form: dict[str, Any], client: OAuthClient, settings: Settings) -> dict[str, Any]:
    token = _require_string(form, "refresh_token")
    refresh = OAuthRefreshToken.get_or_none(OAuthRefreshToken.token_hash == _hash_value(token, settings))
    if (
        refresh is None
        or refresh.client_id != client.client_id
        or refresh.revoked_at is not None
        or refresh.expires_at < now_ts()
    ):
        raise OAuthError("invalid_grant", "Refresh token is invalid or expired")
    existing_scopes = _json_list(refresh.scopes)
    requested_scopes = parse_scope(form.get("scope"), tuple(existing_scopes))
    if not set(requested_scopes).issubset(set(existing_scopes)):
        raise OAuthError("invalid_scope", "Requested scopes exceed the refresh token scopes")

    with current_database().atomic():
        refresh.revoked_at = now_ts()
        new_refresh_token, new_refresh = _create_refresh_token(refresh.user, client, requested_scopes, settings)
        refresh.replaced_by_hash = new_refresh.token_hash
        refresh.save()
    access_token, expires_in = _create_access_token(refresh.user, client.client_id, requested_scopes, settings)
    return {
        "access_token": access_token,
        "token_type": "Bearer",
        "expires_in": expires_in,
        "scope": _scope_string(requested_scopes),
        "refresh_token": new_refresh_token,
    }


def revoke_token(form: dict[str, Any], authorization_header: str | None, settings: Settings) -> None:
    _authenticate_client(form, authorization_header, settings)
    token = form.get("token")
    if not isinstance(token, str) or not token:
        return
    refresh = OAuthRefreshToken.get_or_none(OAuthRefreshToken.token_hash == _hash_value(token, settings))
    if refresh is not None and refresh.revoked_at is None:
        refresh.revoked_at = now_ts()
        refresh.save()


def decode_access_token(token: str, settings: Settings) -> dict[str, Any] | None:
    try:
        payload = jwt.decode(
            token,
            settings.auth_secret,
            algorithms=[JWT_ALGORITHM],
            audience=mcp_resource_url(settings),
            issuer=settings.public_base_url,
        )
    except Exception:
        return None
    if payload.get("type") != "mcp_access":
        return None
    scopes = payload.get("scopes")
    if not isinstance(scopes, list):
        return None
    try:
        user_id = int(payload.get("sub", 0))
    except (TypeError, ValueError):
        return None
    if User.get_or_none(User.id == user_id) is None:
        return None
    return payload
