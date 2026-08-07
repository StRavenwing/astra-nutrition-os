from __future__ import annotations

from fastapi import APIRouter, Depends

from backend.dependencies import get_current_user
from backend.models import User
from backend.services.dashboard import dashboard


router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])


@router.get("")
def get_dashboard(current_user: User = Depends(get_current_user)) -> dict:
    return dashboard(current_user)
