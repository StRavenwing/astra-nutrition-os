from __future__ import annotations

import json
import re
from datetime import datetime

from backend.models import Article, ArticleSection, User, current_database
from backend.services.errors import NotFoundError


DEFAULT_SECTIONS = ("Питание", "Тренировки", "Анатомия")


def ensure_default_sections() -> None:
    for name in DEFAULT_SECTIONS:
        ArticleSection.get_or_create(name=name, defaults={"created_at": datetime.utcnow().isoformat(timespec="seconds")})


ARTICLE_TAG_STOPWORDS = {"этот", "этого", "статья", "статьи", "когда", "чтобы", "который", "которая", "главный", "главная", "для", "или", "при", "как", "the", "this", "with"}


def generate_article_tags(title: str, body: str) -> str | None:
    plain_body = re.sub(r"<[^>]+>", " ", body or "")
    source = f"{title or ''} {plain_body}"
    tags: list[str] = []
    for value in re.findall(r"#[\w-]+", source, flags=re.UNICODE):
        tag = value.lower()
        if tag not in tags:
            tags.append(tag)
    for value in re.findall(r"[^\W_]{4,}", title or "", flags=re.UNICODE):
        tag = f"#{value.lower()}"
        if value.lower() not in ARTICLE_TAG_STOPWORDS and tag not in tags:
            tags.append(tag)
        if len(tags) >= 6:
            break
    return " ".join(tags[:6]) or None


def serialize_section(item: ArticleSection, user: User) -> dict:
    query = item.articles
    if not user.is_admin:
        query = query.where(Article.is_hidden == False)
    return {"id": item.id, "name": item.name, "article_count": query.count()}


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
        "tags": item.tags,
        "links": deserialize_links(item.links),
        "photos": photos if isinstance(photos, list) else [],
        "video": item.video_url,
        "is_pinned": bool(item.is_pinned),
        "is_hidden": bool(item.is_hidden),
        "created_at": item.created_at,
        "updated_at": item.updated_at,
    }


def list_sections(user: User) -> list[dict]:
    ensure_default_sections()
    return [serialize_section(item, user) for item in ArticleSection.select().order_by(ArticleSection.id)]


def create_section(data: dict, user: User) -> dict:
    name = str(data.get("name") or "").strip()
    if not name:
        raise ValueError("Название раздела не может быть пустым")
    item = ArticleSection.create(name=name, created_at=datetime.utcnow().isoformat(timespec="seconds"))
    return serialize_section(item, user)


def list_articles(user: User) -> list[dict]:
    ensure_default_sections()
    query = Article.select(Article, ArticleSection).join(ArticleSection).order_by(Article.created_at.desc(), Article.id.desc())
    if not user.is_admin:
        query = query.where(Article.is_hidden == False)
    return [serialize_article(item) for item in query]


def deserialize_links(value: str | None) -> list[dict]:
    if not value:
        return []
    try:
        parsed = json.loads(value)
    except (TypeError, ValueError):
        parsed = None
    if isinstance(parsed, list):
        result = []
        for item in parsed:
            if isinstance(item, dict) and str(item.get("url") or "").strip():
                result.append({"title": str(item.get("title") or "Ссылка").strip(), "url": str(item["url"]).strip()})
            elif isinstance(item, str) and item.strip():
                result.append({"title": "Ссылка", "url": item.strip()})
        return result
    return [{"title": "Ссылка", "url": link.strip()} for link in value.splitlines() if link.strip()]


def normalize_links(value: object) -> str | None:
    if isinstance(value, list):
        links = []
        for item in value:
            if isinstance(item, dict):
                title = str(item.get("title") or "Ссылка").strip()
                url = str(item.get("url") or "").strip()
            else:
                title, url = "Ссылка", str(item or "").strip()
            if url:
                links.append({"title": title or "Ссылка", "url": url})
        return json.dumps(links, ensure_ascii=False) if links else None
    text = str(value or "").strip()
    return text or None


def validate_media(data: dict) -> tuple[list[str], str | None]:
    photos = data.get("photos") or []
    if not isinstance(photos, list) or len(photos) > 6 or any(not isinstance(item, str) or not item.strip() for item in photos):
        raise ValueError("Можно добавить до 6 фотографий")
    video = data.get("video")
    if video is not None and not isinstance(video, str):
        raise ValueError("Некорректное видео")
    return photos, (video or "").strip() or None


def create_article(data: dict, user: User) -> dict:
    section = ArticleSection.get_or_none(ArticleSection.id == data.get("section_id"))
    if section is None:
        raise NotFoundError("Раздел статьи не найден")
    photos, video = validate_media(data)
    now = datetime.utcnow().isoformat(timespec="seconds")
    with current_database().atomic():
        item = Article.create(
            section=section,
            title=str(data.get("title") or "").strip(),
            body=str(data.get("body") or "").strip(),
            tags=generate_article_tags(str(data.get("title") or "").strip(), str(data.get("body") or "").strip()),
            links=normalize_links(data.get("links")),
            photo_urls=json.dumps(photos, ensure_ascii=False) if photos else None,
            video_url=(video or "").strip() or None,
            is_pinned=False,
            is_hidden=False,
            created_at=now,
            updated_at=now,
        )
    return serialize_article(item)


def update_article_flags(article_id: int, data: dict, user: User) -> dict:
    item = Article.get_or_none(Article.id == article_id)
    if item is None:
        raise NotFoundError("Статья не найдена")
    if "is_pinned" in data:
        item.is_pinned = bool(data["is_pinned"])
    if "is_hidden" in data:
        item.is_hidden = bool(data["is_hidden"])
    item.updated_at = datetime.utcnow().isoformat(timespec="seconds")
    item.save()
    return serialize_article(item)


def update_article(article_id: int, data: dict, user: User) -> dict:
    item = Article.get_or_none(Article.id == article_id)
    if item is None:
        raise NotFoundError("Статья не найдена")
    section = ArticleSection.get_or_none(ArticleSection.id == data.get("section_id"))
    if section is None:
        raise NotFoundError("Раздел статьи не найден")
    photos, video = validate_media(data)
    item.section = section
    item.title = str(data.get("title") or "").strip()
    item.body = str(data.get("body") or "").strip()
    item.tags = generate_article_tags(item.title, item.body)
    item.links = normalize_links(data.get("links"))
    item.photo_urls = json.dumps(photos, ensure_ascii=False) if photos else None
    item.video_url = video
    item.updated_at = datetime.utcnow().isoformat(timespec="seconds")
    item.save()
    return serialize_article(item)


def delete_article(article_id: int, user: User) -> dict:
    item = Article.get_or_none(Article.id == article_id)
    if item is None:
        raise NotFoundError("Статья не найдена")

    item.delete_instance()
    return {"deleted": True, "id": article_id}
