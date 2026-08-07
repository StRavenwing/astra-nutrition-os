from __future__ import annotations

from typing import Any

from backend.models import Product, ProductMeasure
from backend.services.errors import NotFoundError


COUNT_UNITS = {"шт", "бут."}
STANDARD_MEASURE_NAMES = ("ч. л.", "ст. л.", "стакан (200 г)", "стакан (200 мл)")

RECIPE_PREFIXES = {
    "Breakfast": "B",
    "Main": "M",
    "Wrap": "W",
    "Dessert": "D",
    "Garnish": "G",
    "Salad": "S",
    "Sauce": "SA",
    "Snack": "SN",
    "Drink": "DR",
    "Ready": "R",
}


def number(value: Any, default: float | None = None) -> float | None:
    if value in (None, ""):
        return default
    return float(value)


def int_number(value: Any, default: int | None = None) -> int | None:
    numeric = number(value, None if default is None else float(default))
    return None if numeric is None else int(numeric)


def rounded(value: float | None) -> float | None:
    return None if value is None else round(value, 2)


def product_unit_price(data: dict[str, Any]) -> float | None:
    package_price = number(data.get("package_price_rsd"))
    package_size = number(data.get("package_size"))
    if package_price is not None and package_size and package_size > 0:
        multiplier = 100 if data.get("unit", "г") in ("г", "мл") else 1
        return round(package_price / package_size * multiplier, 2)
    return number(data.get("price_per_100_or_unit_rsd"))


def product_kcal(data: dict[str, Any]) -> float:
    kcal = number(data.get("kcal"))
    if kcal is not None:
        return kcal
    protein = number(data.get("protein_g"), 0) or 0
    fat = number(data.get("fat_g"), 0) or 0
    carbs = number(data.get("carbs_g"), 0) or 0
    return round(protein * 4 + fat * 9 + carbs * 4, 2)


def progress_values(data: dict[str, Any]) -> tuple[float | None, ...]:
    weight = number(data.get("weight_kg"))
    height = number(data.get("height_cm"))
    body_fat = number(data.get("body_fat_pct"))
    muscle = number(data.get("muscle_pct"))
    bmi = round(weight / ((height / 100) ** 2), 2) if weight and height else None
    fat_mass = round(weight * body_fat / 100, 2) if weight is not None and body_fat is not None else None
    muscle_mass = round(weight * muscle / 100, 2) if weight is not None and muscle is not None else None
    return height, bmi, body_fat, fat_mass, muscle, muscle_mass


def amount_factor(unit: str | None, quantity: float | None) -> float | None:
    if quantity is None:
        return None
    return quantity if unit in COUNT_UNITS else quantity / 100.0


def amount_value(unit: str | None, quantity: float | None, value: float | None) -> float | None:
    factor = amount_factor(unit, quantity)
    if factor is None or value is None:
        return None
    return factor * value


def product_amount_values(product: Product, quantity: float | None) -> dict[str, float | None]:
    return {
        "kcal": rounded(amount_value(product.unit, quantity, product.kcal)),
        "protein_g": rounded(amount_value(product.unit, quantity, product.protein_g)),
        "fat_g": rounded(amount_value(product.unit, quantity, product.fat_g)),
        "carbs_g": rounded(amount_value(product.unit, quantity, product.carbs_g)),
        "cost_rsd": rounded(amount_value(product.unit, quantity, product.price_per_100_or_unit_rsd)),
    }


def ensure_product_measures(product: Product) -> None:
    if product.unit == "г":
        measures = [
            ("ч. л.", 5),
            ("ст. л.", 15),
            ("стакан (200 г)", 200),
        ]
    elif product.unit == "мл":
        measures = [
            ("ч. л.", 5),
            ("ст. л.", 15),
            ("стакан (200 мл)", 200),
        ]
    else:
        measures = []

    for measure_name, base_quantity in measures:
        ProductMeasure.get_or_create(
            product=product,
            measure_name=measure_name,
            defaults={"base_quantity": base_quantity},
        )


def replace_product_measures(product: Product, measures: list[dict[str, Any]] | None) -> None:
    ProductMeasure.delete().where(
        (ProductMeasure.product == product)
        & (ProductMeasure.measure_name.in_(STANDARD_MEASURE_NAMES))
    ).execute()
    for measure in measures or []:
        name = measure.get("measure_name")
        quantity = number(measure.get("base_quantity"))
        if name in STANDARD_MEASURE_NAMES and quantity is not None and quantity > 0:
            ProductMeasure.create(product=product, measure_name=name, base_quantity=quantity)


def normalise_measure(
    product_id: int,
    quantity: Any,
    measure_name: str | None = None,
) -> tuple[float, str, float, str]:
    try:
        product = Product.get_by_id(product_id)
    except Product.DoesNotExist as exc:
        raise NotFoundError("Продукт не найден") from exc

    entered = number(quantity)
    if entered is None or entered <= 0:
        raise ValueError("Количество должно быть больше нуля")

    base_unit = product.unit
    shown_measure = measure_name or base_unit
    if shown_measure == base_unit:
        return entered, base_unit, entered, shown_measure

    try:
        measure = ProductMeasure.get(
            (ProductMeasure.product == product)
            & (ProductMeasure.measure_name == shown_measure)
        )
    except ProductMeasure.DoesNotExist as exc:
        raise ValueError("Эта единица измерения недоступна для выбранного продукта") from exc

    return entered * measure.base_quantity, base_unit, entered, shown_measure


def prefixed_code_parts(code: str | None) -> tuple[str, int] | None:
    if not code or "-" not in code:
        return None
    prefix, suffix = code.rsplit("-", 1)
    if not prefix or not suffix.isdigit():
        return None
    return prefix, int(suffix)

