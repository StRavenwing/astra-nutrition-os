from __future__ import annotations

from html import escape

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response

from backend.services.errors import DomainError
from backend.services.oauth import (
    OAuthError,
    authorization_server_metadata,
    complete_authorization,
    exchange_token,
    load_pending_authorization,
    protected_resource_metadata,
    register_client,
    revoke_token,
    start_authorization,
)


router = APIRouter(tags=["oauth"])


def _settings(request: Request):
    return request.app.state.settings


def _oauth_error(exc: OAuthError) -> JSONResponse:
    return JSONResponse(
        {"error": exc.error, "error_description": exc.description},
        status_code=exc.status_code,
        headers={"Cache-Control": "no-store"},
    )


def _login_form(request_id: str, error: str | None = None) -> HTMLResponse:
    escaped_request = escape(request_id, quote=True)
    error_html = f'<p class="error">{escape(error)}</p>' if error else ""
    return HTMLResponse(
        f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Astra OAuth</title>
  <style>
    body {{
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font: 16px/1.4 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #1d2433;
      background: #f4f7f6;
    }}
    main {{
      width: min(420px, calc(100vw - 32px));
      padding: 28px;
      background: #fff;
      border: 1px solid #dfe7e4;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(21, 31, 43, .08);
    }}
    h1 {{ margin: 0 0 8px; font-size: 24px; }}
    p {{ margin: 0 0 20px; color: #5b6573; }}
    label {{ display: block; margin: 14px 0 6px; font-weight: 650; }}
    input {{
      width: 100%;
      box-sizing: border-box;
      padding: 11px 12px;
      border: 1px solid #cdd7d3;
      border-radius: 6px;
      font: inherit;
    }}
    button {{
      width: 100%;
      margin-top: 20px;
      padding: 12px 14px;
      border: 0;
      border-radius: 6px;
      background: #2f6f63;
      color: white;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }}
    .error {{ color: #a52828; }}
  </style>
</head>
<body>
  <main>
    <h1>Astra Nutrition OS</h1>
    <p>Войдите, чтобы разрешить AI-клиенту доступ к MCP tools рецептов.</p>
    {error_html}
    <form method="post" action="/oauth/login">
      <input type="hidden" name="request" value="{escaped_request}">
      <label for="email">Email</label>
      <input id="email" name="email" type="email" autocomplete="username" required>
      <label for="password">Пароль</label>
      <input id="password" name="password" type="password" autocomplete="current-password" required>
      <button type="submit">Разрешить доступ</button>
    </form>
  </main>
</body>
</html>""",
        headers={"Cache-Control": "no-store"},
    )


@router.get("/.well-known/oauth-authorization-server")
def oauth_metadata(request: Request) -> dict:
    return authorization_server_metadata(_settings(request))


@router.get("/.well-known/oauth-protected-resource/mcp")
def oauth_protected_resource(request: Request) -> dict:
    return protected_resource_metadata(_settings(request))


@router.post("/oauth/register", status_code=201)
async def oauth_register(request: Request):
    try:
        data = await request.json()
        return JSONResponse(register_client(data, _settings(request)), status_code=201)
    except OAuthError as exc:
        return _oauth_error(exc)


@router.get("/oauth/authorize")
def oauth_authorize(request: Request):
    try:
        request_id = start_authorization(dict(request.query_params), _settings(request))
    except OAuthError as exc:
        return _oauth_error(exc)
    login_url = f"{_settings(request).public_base_url}/oauth/login?request={request_id}"
    return RedirectResponse(login_url, status_code=302, headers={"Cache-Control": "no-store"})


@router.get("/oauth/login")
def oauth_login(request: Request):
    request_id = request.query_params.get("request") or ""
    try:
        load_pending_authorization(request_id)
    except OAuthError as exc:
        return _login_form(request_id, exc.description)
    return _login_form(request_id)


@router.post("/oauth/login")
async def oauth_login_submit(request: Request):
    form = await request.form()
    request_id = str(form.get("request") or "")
    try:
        redirect_url = complete_authorization(
            request_id,
            {"email": form.get("email"), "password": form.get("password")},
            _settings(request),
        )
    except OAuthError as exc:
        return _login_form(request_id, exc.description)
    except DomainError as exc:
        return _login_form(request_id, exc.message)
    return RedirectResponse(redirect_url, status_code=302, headers={"Cache-Control": "no-store"})


@router.post("/oauth/token")
async def oauth_token(request: Request):
    try:
        form = dict(await request.form())
        token = exchange_token(form, request.headers.get("Authorization"), _settings(request))
        return JSONResponse(token, headers={"Cache-Control": "no-store", "Pragma": "no-cache"})
    except OAuthError as exc:
        return _oauth_error(exc)


@router.post("/oauth/revoke")
async def oauth_revoke(request: Request):
    try:
        form = dict(await request.form())
        revoke_token(form, request.headers.get("Authorization"), _settings(request))
    except OAuthError as exc:
        return _oauth_error(exc)
    return Response(status_code=200, headers={"Cache-Control": "no-store"})
