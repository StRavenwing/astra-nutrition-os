from __future__ import annotations

import base64
import hashlib
import time
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import jwt
import pytest
from fastapi.testclient import TestClient

from backend.services.auth import JWT_ALGORITHM


PUBLIC_BASE_URL = "http://testserver"
REDIRECT_URI = "https://chat.openai.com/aip/test/oauth/callback"
PROTOCOL_VERSION = "2025-11-25"


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("ASTRA_DB_PATH", str(Path(tmp_path) / "astra-test.sqlite"))
    monkeypatch.setenv("ASTRA_BACKUP_DIR", str(Path(tmp_path) / "backups"))
    monkeypatch.setenv("ASTRA_ADMIN_EMAIL", "admin@example.com")
    monkeypatch.setenv("ASTRA_ADMIN_PASSWORD", "admin-password")
    monkeypatch.setenv("ASTRA_AUTH_SECRET", "test-secret-with-at-least-thirty-two-bytes")
    monkeypatch.setenv("ASTRA_PUBLIC_BASE_URL", PUBLIC_BASE_URL)

    from backend.app import create_app

    with TestClient(create_app()) as test_client:
        yield test_client


def _pkce() -> tuple[str, str]:
    verifier = "test-verifier-abcdefghijklmnopqrstuvwxyz0123456789"
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
    return verifier, challenge


def _register_client(client: TestClient, scope: str = "recipes:read recipes:write") -> dict:
    response = client.post(
        "/oauth/register",
        json={
            "redirect_uris": [REDIRECT_URI],
            "token_endpoint_auth_method": "none",
            "scope": scope,
            "client_name": "MCP test client",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def _issue_token(
    client: TestClient,
    *,
    email: str = "admin@example.com",
    password: str = "admin-password",
    scope: str = "recipes:read recipes:write",
) -> dict:
    registered = _register_client(client, scope)
    verifier, challenge = _pkce()
    response = client.get(
        "/oauth/authorize",
        params={
            "response_type": "code",
            "client_id": registered["client_id"],
            "redirect_uri": REDIRECT_URI,
            "scope": scope,
            "state": "state-123",
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "resource": f"{PUBLIC_BASE_URL}/mcp",
        },
        follow_redirects=False,
    )
    assert response.status_code == 302, response.text
    request_id = parse_qs(urlparse(response.headers["location"]).query)["request"][0]

    response = client.post(
        "/oauth/login",
        data={"request": request_id, "email": email, "password": password},
        follow_redirects=False,
    )
    assert response.status_code == 302, response.text
    redirect = urlparse(response.headers["location"])
    assert f"{redirect.scheme}://{redirect.netloc}{redirect.path}" == REDIRECT_URI
    assert parse_qs(redirect.query)["state"] == ["state-123"]
    code = parse_qs(redirect.query)["code"][0]

    response = client.post(
        "/oauth/token",
        data={
            "grant_type": "authorization_code",
            "client_id": registered["client_id"],
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "code_verifier": verifier,
        },
    )
    assert response.status_code == 200, response.text
    token = response.json()
    token["client_id"] = registered["client_id"]
    return token


def _mcp_headers(access_token: str, *, initialized: bool = True) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    if initialized:
        headers["mcp-protocol-version"] = PROTOCOL_VERSION
    return headers


def _mcp_initialize(client: TestClient, access_token: str) -> dict:
    response = client.post(
        "/mcp",
        headers=_mcp_headers(access_token, initialized=False),
        json={
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "pytest", "version": "1"},
            },
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _mcp_call(client: TestClient, access_token: str, name: str, arguments: dict, request_id: int = 10) -> dict:
    response = client.post(
        "/mcp",
        headers=_mcp_headers(access_token),
        json={
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _structured_result(message: dict):
    structured = message["result"]["structuredContent"]
    return structured.get("result", structured)


def test_oauth_metadata_and_mcp_requires_bearer_token(client: TestClient) -> None:
    response = client.get("/.well-known/oauth-authorization-server")
    assert response.status_code == 200
    metadata = response.json()
    assert metadata["issuer"] == PUBLIC_BASE_URL
    assert metadata["authorization_endpoint"] == f"{PUBLIC_BASE_URL}/oauth/authorize"
    assert metadata["registration_endpoint"] == f"{PUBLIC_BASE_URL}/oauth/register"
    assert set(metadata["scopes_supported"]) == {"recipes:read", "recipes:write"}
    assert "none" in metadata["token_endpoint_auth_methods_supported"]

    response = client.get("/.well-known/oauth-protected-resource/mcp")
    assert response.status_code == 200
    protected = response.json()
    assert protected["resource"] == f"{PUBLIC_BASE_URL}/mcp"
    assert protected["authorization_servers"] == [PUBLIC_BASE_URL]

    response = client.post(
        "/mcp",
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        json={"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
    )
    assert response.status_code == 401
    assert 'resource_metadata="http://testserver/.well-known/oauth-protected-resource/mcp"' in response.headers[
        "www-authenticate"
    ]


def test_oauth_authorization_code_refresh_and_revoke(client: TestClient) -> None:
    token = _issue_token(client)
    assert token["token_type"] == "Bearer"
    assert token["scope"] == "recipes:read recipes:write"

    response = client.post(
        "/oauth/token",
        data={
            "grant_type": "refresh_token",
            "client_id": token["client_id"],
            "refresh_token": token["refresh_token"],
        },
    )
    assert response.status_code == 200, response.text
    rotated = response.json()
    assert rotated["refresh_token"] != token["refresh_token"]

    response = client.post(
        "/oauth/token",
        data={
            "grant_type": "refresh_token",
            "client_id": token["client_id"],
            "refresh_token": token["refresh_token"],
        },
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_grant"

    response = client.post(
        "/oauth/revoke",
        data={"client_id": token["client_id"], "token": rotated["refresh_token"]},
    )
    assert response.status_code == 200
    response = client.post(
        "/oauth/token",
        data={
            "grant_type": "refresh_token",
            "client_id": token["client_id"],
            "refresh_token": rotated["refresh_token"],
        },
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_grant"


def test_mcp_read_tools_and_annotations(client: TestClient) -> None:
    token = _issue_token(client, scope="recipes:read")
    _mcp_initialize(client, token["access_token"])

    response = client.post(
        "/mcp",
        headers=_mcp_headers(token["access_token"]),
        json={"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
    )
    assert response.status_code == 200, response.text
    tools = {tool["name"]: tool for tool in response.json()["result"]["tools"]}
    assert set(tools) == {"recipes.search", "recipes.get", "recipes.create", "recipes.update", "recipes.delete"}
    assert tools["recipes.search"]["annotations"]["readOnlyHint"] is True
    assert tools["recipes.delete"]["annotations"]["destructiveHint"] is True

    result = _mcp_call(client, token["access_token"], "recipes.search", {"limit": 1})
    recipes = _structured_result(result)
    assert len(recipes) == 1
    assert {"id", "code", "kcal_per_serving", "cost_per_serving_rsd"} <= recipes[0].keys()

    result = _mcp_call(client, token["access_token"], "recipes.get", {"code": recipes[0]["code"]})
    detail = _structured_result(result)
    assert detail["recipe"]["code"] == recipes[0]["code"]
    assert "ingredients" in detail


def test_mcp_write_requires_write_scope_and_admin(client: TestClient) -> None:
    read_token = _issue_token(client, scope="recipes:read")
    _mcp_initialize(client, read_token["access_token"])
    result = _mcp_call(
        client,
        read_token["access_token"],
        "recipes.create",
        {"category": "Ready", "name": "Forbidden MCP recipe", "servings": 1},
    )
    assert result["result"]["isError"] is True
    assert "recipes:write" in result["result"]["content"][0]["text"]

    response = client.post(
        "/api/v1/auth/register",
        json={"email": "user@example.com", "password": "user-password"},
    )
    assert response.status_code == 201, response.text
    user_token = _issue_token(client, email="user@example.com", password="user-password")
    assert user_token["scope"] == "recipes:read"
    _mcp_initialize(client, user_token["access_token"])
    result = _mcp_call(
        client,
        user_token["access_token"],
        "recipes.create",
        {"category": "Ready", "name": "Non-admin MCP recipe", "servings": 1},
    )
    assert result["result"]["isError"] is True


def test_mcp_admin_can_create_update_and_delete_recipe(client: TestClient) -> None:
    token = _issue_token(client)
    _mcp_initialize(client, token["access_token"])

    created = _structured_result(_mcp_call(
        client,
        token["access_token"],
        "recipes.create",
        {
            "category": "Ready",
            "name": "MCP Ready Test",
            "servings": 1,
            "manual_kcal_per_serving": 321,
            "manual_protein_per_serving_g": 22,
            "manual_fat_per_serving_g": 11,
            "manual_carbs_per_serving_g": 33,
        },
    ))
    assert created["code"].startswith("R-")
    assert created["kcal_per_serving"] == 321

    updated = _structured_result(_mcp_call(
        client,
        token["access_token"],
        "recipes.update",
        {"id": created["id"], "name": "MCP Ready Test Updated", "status": "Approved"},
    ))
    assert updated["id"] == created["id"]
    assert updated["name"] == "MCP Ready Test Updated"
    assert updated["status"] == "Approved"
    assert updated["kcal_per_serving"] == 321

    deleted = _structured_result(_mcp_call(
        client,
        token["access_token"],
        "recipes.delete",
        {"id": created["id"]},
    ))
    assert deleted == {"deleted": True, "id": created["id"], "deleted_diary_entries": 0}


def test_mcp_rejects_valid_jwt_without_required_read_scope(client: TestClient) -> None:
    payload = {
        "type": "mcp_access",
        "sub": "1",
        "client_id": "manual-test",
        "scopes": ["recipes:write"],
        "scope": "recipes:write",
        "iss": PUBLIC_BASE_URL,
        "aud": f"{PUBLIC_BASE_URL}/mcp",
        "exp": int(time.time()) + 3600,
    }
    access_token = jwt.encode(payload, "test-secret-with-at-least-thirty-two-bytes", algorithm=JWT_ALGORITHM)
    response = client.post(
        "/mcp",
        headers=_mcp_headers(access_token, initialized=False),
        json={"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
    )
    assert response.status_code == 403
    assert response.json()["error"] == "insufficient_scope"
