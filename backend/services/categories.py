from __future__ import annotations

from backend.models import ContentCategory, Product, Recipe, User, current_database
from backend.services.auth import utc_now
from backend.services.errors import ForbiddenError


VALID_KINDS = {"product", "recipe"}


def serialize_category(item: ContentCategory) -> dict:
    return {
        "id": item.id,
        "kind": item.kind,
        "name": item.name,
        "collection": "common" if item.owner_id is None else "local",
        "owner_id": item.owner_id,
    }


def list_categories(kind: str, user: User) -> list[dict]:
    if kind not in VALID_KINDS:
        raise ValueError("Неизвестный тип категории")
    _seed_existing_categories(kind)
    query = (
        ContentCategory.select()
        .where((ContentCategory.kind == kind) & ((ContentCategory.owner.is_null(True)) | (ContentCategory.owner == user)))
        .order_by(ContentCategory.name)
    )
    return [serialize_category(item) for item in query]


def _seed_existing_categories(kind: str) -> None:
    source = Product if kind == "product" else Recipe
    names = {value for value in source.select(source.category).tuples() if value and value[0]}
    for (name,) in names:
        ContentCategory.get_or_create(kind=kind, name=name, owner=None, defaults={"created_at": utc_now()})


def create_category(data: dict, user: User) -> dict:
    kind = str(data.get("kind") or "").strip()
    name = str(data.get("name") or "").strip()
    collection = str(data.get("collection") or "local").strip()
    if kind not in VALID_KINDS:
        raise ValueError("Неизвестный тип категории")
    if not name:
        raise ValueError("Название категории не может быть пустым")
    if collection not in {"common", "local"}:
        raise ValueError("Неизвестная коллекция категории")
    if collection == "common" and not user.is_admin:
        raise ForbiddenError("Общие категории может создавать только администратор")
    owner = None if collection == "common" else user
    with current_database().atomic():
        item = ContentCategory.create(kind=kind, name=name, owner=owner, created_at=utc_now())
    return serialize_category(item)
