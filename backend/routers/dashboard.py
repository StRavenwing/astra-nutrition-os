from __future__ import annotations

from fastapi import APIRouter

from backend.services.dashboard import dashboard


router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


@router.get("")
def get_dashboard() -> dict:
    return dashboard()

