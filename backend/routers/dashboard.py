from __future__ import annotations

from fastapi import APIRouter, Depends

from backend.dependencies import get_optional_user
from backend.models import User
from backend.services.dashboard import dashboard


router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


@router.get("")
def get_dashboard(current_user: User | None = Depends(get_optional_user)) -> dict:
    return dashboard(current_user)
