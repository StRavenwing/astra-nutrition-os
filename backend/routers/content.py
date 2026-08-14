from __future__ import annotations

from fastapi import APIRouter, Depends, status

from backend.dependencies import get_current_user, require_admin
from backend.models import User
from backend.schemas import ArticleFlagsInput, ArticleInput, ArticleSectionInput, CategoryInput, dump_model
from backend.services.articles import create_article, create_section, delete_article as remove_article, list_articles, list_sections, update_article, update_article_flags
from backend.services.categories import create_category, list_categories


router = APIRouter(prefix="/api/v1", tags=["content"])


@router.get("/categories")
def get_categories(kind: str, current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_categories(kind, current_user)


@router.post("/categories", status_code=status.HTTP_201_CREATED)
def post_category(payload: CategoryInput, current_user: User = Depends(get_current_user)) -> dict:
    return create_category(dump_model(payload), current_user)


@router.get("/article-sections")
def get_article_sections(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_sections(current_user)


@router.post("/article-sections", status_code=status.HTTP_201_CREATED)
def post_article_section(payload: ArticleSectionInput, current_user: User = Depends(require_admin)) -> dict:
    return create_section(dump_model(payload), current_user)


@router.get("/articles")
def get_articles(current_user: User = Depends(get_current_user)) -> list[dict]:
    return list_articles(current_user)


@router.post("/articles", status_code=status.HTTP_201_CREATED)
def post_article(payload: ArticleInput, current_user: User = Depends(require_admin)) -> dict:
    return create_article(dump_model(payload), current_user)


@router.put("/articles/{article_id}")
def put_article(article_id: int, payload: ArticleInput, current_user: User = Depends(require_admin)) -> dict:
    return update_article(article_id, dump_model(payload), current_user)


@router.patch("/articles/{article_id}/flags")
def patch_article_flags(article_id: int, payload: ArticleFlagsInput, current_user: User = Depends(require_admin)) -> dict:
    return update_article_flags(article_id, dump_model(payload), current_user)


@router.delete("/articles/{article_id}")
def delete_article_route(article_id: int, current_user: User = Depends(require_admin)) -> dict:
    return remove_article(article_id, current_user)
