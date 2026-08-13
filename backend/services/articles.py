from __future__ import annotations

import json
from datetime import datetime

from backend.models import Article, ArticleSection, User, current_database
from backend.services.errors import NotFoundError


DEFAULT_SECTIONS = ("Питание", "Тренировки", "Анатомия")


def ensure_default_sections() -> None:
    for name in DEFAULT_SECTIONS:
        ArticleSection.get_or_create(name=name, defaults={"created_at": datetime.utcnow().isoformat(timespec="seconds")})


def serialize_section(item: ArticleSection) -> dict:
    return {"id": item.id, "name": item.name, "article_count": item.articles.count()}


def serialize_article(item: Article) -> dict:
    try:
        photos = json.loads(item.photo_urls or "[]")
    except (TypeError, ValueError):
        photos = []
    return {
        "id": item.id,
        "section_id": item.section_id,
        "section_name": item.section.name,
        "title": item.title,
        "body": item.body,
        "links": item.links,
        "photos": photos if isinstance(photos, list) else [],
        "video": item.video_url,
        "created_at": item.created_at,
        "updated_at": item.updated_at,
    }


def list_sections() -> list[dict]:
    ensure_default_sections()
    return [serialize_section(item) for item in ArticleSection.select().order_by(ArticleSection.id)]


def create_section(data: dict) -> dict:
    name = str(data.get("name") or "").strip()
    if not name:
        raise ValueError("Название раздела не может быть пустым")
    item = ArticleSection.create(name=name, created_at=datetime.utcnow().isoformat(timespec="seconds"))
    return serialize_section(item)


def list_articles() -> list[dict]:
    ensure_default_sections()
    query = Article.select(Article, ArticleSection).join(ArticleSection).order_by(Article.created_at.desc(), Article.id.desc())
    return [serialize_article(item) for item in query]


def create_article(data: dict, user: User) -> dict:
    section = ArticleSection.get_or_none(ArticleSection.id == data.get("section_id"))
    if section is None:
        raise NotFoundError("Раздел статьи не найден")
    photos = data.get("photos") or []
    if not isinstance(photos, list) or len(photos) > 6 or any(not isinstance(item, str) or not item.strip() for item in photos):
        raise ValueError("Можно добавить до 6 фотографий")
    video = data.get("video")
    if video is not None and not isinstance(video, str):
        raise ValueError("Некорректное видео")
    links = data.get("links")
    if isinstance(links, list):
        links = "\n".join(str(item).strip() for item in links if str(item).strip())
    else:
        links = str(links or "").strip() or None
    now = datetime.utcnow().isoformat(timespec="seconds")
    with current_database().atomic():
        item = Article.create(
            section=section,
            title=str(data.get("title") or "").strip(),
            body=str(data.get("body") or "").strip(),
            links=links,
            photo_urls=json.dumps(photos, ensure_ascii=False) if photos else None,
            video_url=(video or "").strip() or None,
            created_at=now,
            updated_at=now,
        )
    return serialize_article(item)
