from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class AuthInput(BaseModel):
    email: str
    password: str


class FeedbackInput(BaseModel):
    message: str = Field(min_length=1, max_length=500)


class FeedbackReplyInput(BaseModel):
    reply: str = Field(min_length=1, max_length=2000)


class CategoryInput(BaseModel):
    kind: str
    name: str = Field(min_length=1, max_length=120)
    collection: str = "local"


class ArticleSectionInput(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class ArticleLinkInput(BaseModel):
    title: str = Field(min_length=1, max_length=240)
    url: str = Field(min_length=1, max_length=2000)


class ArticleInput(BaseModel):
    section_id: int
    title: str = Field(min_length=1, max_length=240)
    body: str = Field(min_length=1)
    tags: str | None = None
    links: str | list[str] | list[ArticleLinkInput] | None = None
    photos: list[str] = Field(default_factory=list, max_length=6)
    video: str | None = None


class ArticleFlagsInput(BaseModel):
    is_pinned: bool | None = None
    is_hidden: bool | None = None


class ProductMeasureInput(BaseModel):
    measure_name: str
    base_quantity: Any = None


class ProductInput(BaseModel):
    name: str
    category: str | None = None
    unit: str = "г"
    package_price_rsd: Any = None
    package_size: Any = None
    price_per_100_or_unit_rsd: Any = None
    kcal: Any = None
    protein_g: Any = 0
    fat_g: Any = 0
    carbs_g: Any = 0
    data_status: str = "Подтверждено"
    note: str | None = None
    measures: list[ProductMeasureInput] | None = None


class ProductNutritionScanResult(BaseModel):
    kcal: float | None = None
    protein_g: float | None = None
    fat_g: float | None = None
    carbs_g: float | None = None
    basis: str
    confidence: float
    field_confidence: dict[str, float]
    raw_text: str
    warnings: list[str] = Field(default_factory=list)


class RecipeIngredientInput(BaseModel):
    product_id: int
    quantity: Any = None
    unit: str | None = None
    measurement_name: str | None = None
    measurement_quantity: Any = None
    portion_description: str | None = None


class RecipeInput(BaseModel):
    category: str
    name: str
    subcategory: str | None = None
    version: str = "1.0"
    status: str = "Draft"
    servings: Any = 1
    tags: str | None = None
    manual_price_per_serving_rsd: Any = None
    manual_kcal_per_serving: Any = None
    manual_protein_per_serving_g: Any = None
    manual_fat_per_serving_g: Any = None
    manual_carbs_per_serving_g: Any = None
    ingredients: list[RecipeIngredientInput] = Field(default_factory=list)


class RecipeModerationInput(BaseModel):
    action: str
    note: str | None = None


class DiaryItemInput(BaseModel):
    meal_type: str | None = None
    recipe_id: int | None = None
    product_id: int | None = None
    servings: Any = 1
    quantity: Any = None
    measurement_name: str | None = None
    measurement_quantity: Any = None
    comment: str | None = None


class DiaryCreateInput(BaseModel):
    entry_date: str | None = None
    items: list[DiaryItemInput] | None = None
    meal_type: str | None = None
    recipe_id: int | None = None
    product_id: int | None = None
    servings: Any = 1
    quantity: Any = None
    measurement_name: str | None = None
    measurement_quantity: Any = None
    comment: str | None = None


class DiaryUpdateInput(DiaryItemInput):
    entry_date: str


class ProgressInput(BaseModel):
    measured_at: str
    weight_kg: Any = None
    height_cm: Any = None
    bmi: Any = None
    body_fat_pct: Any = None
    fat_mass_kg: Any = None
    muscle_pct: Any = None
    muscle_mass_kg: Any = None
    protein_target_g: Any = None
    fat_target_g: Any = None
    waist_cm: Any = None
    chest_cm: Any = None
    hips_cm: Any = None
    sleep_score: Any = None
    wellbeing_score: Any = None
    comment: str | None = None


class ExerciseInput(BaseModel):
    name: str
    muscle_group: str | None = None
    default_unit: str = "кг"
    default_sets: Any = 3
    default_reps: Any = 12
    target_rir: str | None = "0–2"
    note: str | None = None
    description: str | None = None
    photos: list[str] = Field(default_factory=list, max_length=6)
    video: str | None = None


class WorkoutInput(BaseModel):
    performed_at: str
    exercise_id: int | None = None
    exercise_name: str | None = None
    muscle_group: str | None = None
    unit: str | None = "кг"
    working_weight: Any = None
    sets: Any = None
    reps: Any = None
    rir: str | None = None
    machine_location: str | None = None
    comment: str | None = None


class WorkoutPlanItemInput(BaseModel):
    exercise_id: int
    working_weight: Any = None
    sets: Any = None
    duration_minutes: Any = None
    speed_kmh: Any = None


class WorkoutPlanInput(BaseModel):
    scheduled_at: str
    items: list[WorkoutPlanItemInput]


class WorkoutComplexInput(BaseModel):
    name: str
    comment: str | None = None
    photos: list[str] = Field(default_factory=list, max_length=6)
    video: str | None = None
    items: list[WorkoutPlanItemInput] = Field(default_factory=list)


class DeleteResponse(BaseModel):
    deleted: bool = True
    id: int


class RecipeDeleteResponse(DeleteResponse):
    deleted_diary_entries: int = 0


def dump_model(model: BaseModel) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    return model.dict()
