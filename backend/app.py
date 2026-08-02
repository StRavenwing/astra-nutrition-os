from __future__ import annotations

from pathlib import Path

import uvicorn
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from peewee import IntegrityError

from backend.config import Settings, get_settings
from backend.migrations import backup_database, ensure_database
from backend.models import current_database, initialize_database
from backend.routers import dashboard, diary, health, products, progress, recipes, workouts
from backend.services.errors import DomainError


def _error_response(message: str, status_code: int, details: object | None = None) -> JSONResponse:
    payload: dict[str, object] = {"error": message}
    if details is not None:
        payload["details"] = details
    return JSONResponse(payload, status_code=status_code)


def _static_file(path: Path, media_type: str, headers: dict[str, str] | None = None):
    if not path.exists():
        return PlainTextResponse("UI build is missing. Run npm --prefix ui run build.", status_code=404)
    return FileResponse(path, media_type=media_type, headers=headers)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    ensure_database(settings)
    initialize_database(settings.db_path)

    app = FastAPI(title="Astra Nutrition OS API")
    app.state.settings = settings

    @app.middleware("http")
    async def database_session(request: Request, call_next):
        database = current_database()
        database.connect(reuse_if_open=True)
        try:
            return await call_next(request)
        finally:
            if not database.is_closed():
                database.close()

    @app.exception_handler(DomainError)
    async def handle_domain_error(request: Request, exc: DomainError):
        return _error_response(exc.message, exc.status_code, exc.details)

    @app.exception_handler(IntegrityError)
    async def handle_integrity_error(request: Request, exc: IntegrityError):
        return _error_response(str(exc), 409)

    @app.exception_handler(ValueError)
    async def handle_value_error(request: Request, exc: ValueError):
        return _error_response(str(exc), 400)

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(request: Request, exc: RequestValidationError):
        return _error_response("Некорректные данные запроса", 422, exc.errors())

    app.include_router(health.router)
    app.include_router(dashboard.router)
    app.include_router(products.router)
    app.include_router(recipes.router)
    app.include_router(diary.router)
    app.include_router(progress.router)
    app.include_router(workouts.router)

    assets = settings.static_root / "assets"
    if assets.exists():
        app.mount("/assets", StaticFiles(directory=assets), name="assets")

    @app.get("/manifest.webmanifest", include_in_schema=False)
    def manifest():
        return _static_file(
            settings.static_root / "manifest.webmanifest",
            "application/manifest+json",
        )

    @app.get("/service-worker.js", include_in_schema=False)
    def service_worker():
        return _static_file(
            settings.static_root / "service-worker.js",
            "text/javascript",
            {"Cache-Control": "no-cache", "Service-Worker-Allowed": "/"},
        )

    @app.get("/", include_in_schema=False)
    def index():
        return _static_file(settings.static_root / "index.html", "text/html")

    @app.get("/{full_path:path}", include_in_schema=False)
    def spa_fallback(full_path: str):
        if full_path.startswith("api/"):
            return _error_response("Not found", 404)
        return _static_file(settings.static_root / "index.html", "text/html")

    return app


def run() -> None:
    settings = get_settings()
    app = create_app(settings)
    backup_database(settings.db_path, settings.backup_dir)
    print(f"Astra Nutrition OS: http://{settings.host}:{settings.port}")
    uvicorn.run(app, host=settings.host, port=settings.port)

