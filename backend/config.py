from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]
STATIC_ROOT = PROJECT_ROOT / "ui" / "dist"
DATABASE_TEMPLATE = PROJECT_ROOT / "database" / "Astra_Nutrition_OS_v7.sql"
DATABASE_NAME = "Astra_Nutrition_OS_v7.sqlite"

load_dotenv(PROJECT_ROOT / ".env")


@dataclass(frozen=True)
class Settings:
    project_root: Path
    static_root: Path
    database_template: Path
    db_path: Path
    backup_dir: Path
    host: str
    port: int
    admin_email: str
    admin_password: str
    auth_secret: str
    access_token_minutes: int


def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if value:
        return value
    raise RuntimeError(f"Set {name} in .env or environment before starting Astra Nutrition OS")


def _default_db_path() -> Path:
    candidates = [
        PROJECT_ROOT / ".data" / DATABASE_NAME,
        PROJECT_ROOT / DATABASE_NAME,
        PROJECT_ROOT.parent / DATABASE_NAME,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def get_settings() -> Settings:
    configured_db = os.environ.get("ASTRA_DB_PATH")
    db_path = (
        Path(configured_db).expanduser()
        if configured_db
        else _default_db_path()
    )
    if not db_path.is_absolute():
        db_path = PROJECT_ROOT / db_path
    db_path = db_path.resolve()

    configured_backup_dir = os.environ.get("ASTRA_BACKUP_DIR")
    backup_dir = (
        Path(configured_backup_dir).expanduser()
        if configured_backup_dir
        else db_path.parent / "backups"
    )
    if not backup_dir.is_absolute():
        backup_dir = PROJECT_ROOT / backup_dir

    return Settings(
        project_root=PROJECT_ROOT,
        static_root=STATIC_ROOT,
        database_template=DATABASE_TEMPLATE,
        db_path=db_path,
        backup_dir=backup_dir.resolve(),
        host=os.environ.get("ASTRA_HOST", "127.0.0.1"),
        port=int(os.environ.get("ASTRA_PORT", "8787")),
        admin_email=_required_env("ASTRA_ADMIN_EMAIL"),
        admin_password=_required_env("ASTRA_ADMIN_PASSWORD"),
        auth_secret=_required_env("ASTRA_AUTH_SECRET"),
        access_token_minutes=int(os.environ.get("ASTRA_ACCESS_TOKEN_MINUTES", "10080")),
    )
