from __future__ import annotations

from backend.models import DiaryEntry, Product, ProductMeasure, RecipeIngredient, current_database
from backend.services.calculations import (
    ensure_product_measures,
    number,
    product_kcal,
    product_unit_price,
    replace_product_measures,
)
from backend.services.codes import next_code
from backend.services.errors import ConflictError, NotFoundError
from backend.services.serialization import serialize_product, serialize_product_measure


def list_products() -> list[dict]:
    query = Product.select().order_by(Product.category, Product.name)
    return [serialize_product(product) for product in query]


def list_product_measures() -> list[dict]:
    query = (
        ProductMeasure
        .select()
        .order_by(ProductMeasure.product, ProductMeasure.base_quantity, ProductMeasure.measure_name)
    )
    return [serialize_product_measure(measure) for measure in query]


def get_product(product_id: int) -> Product:
    product = Product.get_or_none(Product.id == product_id)
    if product is None:
        raise NotFoundError("Продукт не найден")
    return product


def create_product(data: dict) -> dict:
    with current_database().atomic():
        product = Product.create(
            code=next_code("P"),
            name=data["name"],
            category=data.get("category"),
            unit=data.get("unit", "г"),
            package_price_rsd=number(data.get("package_price_rsd")),
            package_size=number(data.get("package_size")),
            price_per_100_or_unit_rsd=product_unit_price(data),
            kcal=product_kcal(data),
            protein_g=number(data.get("protein_g"), 0) or 0,
            fat_g=number(data.get("fat_g"), 0) or 0,
            carbs_g=number(data.get("carbs_g"), 0) or 0,
            data_status=data.get("data_status", "Подтверждено"),
            note=data.get("note"),
        )
        if "measures" in data and data.get("measures") is not None:
            replace_product_measures(product, data.get("measures"))
        else:
            ensure_product_measures(product)
        return serialize_product(product)


def update_product(product_id: int, data: dict) -> dict:
    with current_database().atomic():
        product = get_product(product_id)
        old_unit = product.unit
        product.name = data["name"]
        product.category = data.get("category")
        product.unit = data.get("unit", "г")
        product.package_price_rsd = number(data.get("package_price_rsd"))
        product.package_size = number(data.get("package_size"))
        product.price_per_100_or_unit_rsd = product_unit_price(data)
        product.kcal = product_kcal(data)
        product.protein_g = number(data.get("protein_g"), 0) or 0
        product.fat_g = number(data.get("fat_g"), 0) or 0
        product.carbs_g = number(data.get("carbs_g"), 0) or 0
        product.data_status = data.get("data_status", "Подтверждено")
        product.note = data.get("note")
        product.save()

        if "measures" in data and data.get("measures") is not None:
            replace_product_measures(product, data.get("measures"))
        elif old_unit != product.unit:
            ensure_product_measures(product)
        return serialize_product(product)


def delete_product(product_id: int) -> dict:
    with current_database().atomic():
        product = get_product(product_id)
        recipe_count = (
            RecipeIngredient
            .select(RecipeIngredient.recipe)
            .where(RecipeIngredient.product == product)
            .distinct()
            .count()
        )
        if recipe_count:
            raise ConflictError(
                f"Продукт используется в рецептах: {recipe_count}. "
                "Сначала удалите его из состава этих рецептов."
            )
        diary_count = DiaryEntry.select().where(DiaryEntry.product == product).count()
        if diary_count:
            raise ConflictError(
                f"Продукт используется в дневнике питания: {diary_count}. "
                "Сначала удалите связанные записи дневника."
            )
        product.delete_instance()
        return {"deleted": True, "id": product_id}
