from __future__ import annotations

from pathlib import Path

from peewee import (
    AutoField,
    BooleanField,
    CharField,
    Check,
    DatabaseProxy,
    FloatField,
    ForeignKeyField,
    IntegerField,
    Model,
    SqliteDatabase,
    TextField,
)


database_proxy = DatabaseProxy()


def make_database(path: Path | str) -> SqliteDatabase:
    return SqliteDatabase(
        str(path),
        pragmas={
            "foreign_keys": 1,
        },
    )


def initialize_database(path: Path | str) -> SqliteDatabase:
    try:
        existing = database_proxy.obj
        if existing is not None and not existing.is_closed():
            existing.close()
    except Exception:
        pass
    database = make_database(path)
    database_proxy.initialize(database)
    # Keep normalized installations forward-compatible when a new model is added.
    # The full schema migrations still handle structural upgrades; this creates
    # newly introduced tables safely on existing databases.
    database.connect(reuse_if_open=True)
    database.create_tables(MODELS, safe=True)
    database.close()
    return database


def current_database() -> SqliteDatabase:
    return database_proxy.obj


class BaseModel(Model):
    class Meta:
        database = database_proxy


class AppMeta(BaseModel):
    key = CharField(primary_key=True)
    value = TextField()

    class Meta:
        table_name = "app_meta"


class IdSequence(BaseModel):
    prefix = CharField(primary_key=True)
    next_number = IntegerField(constraints=[Check("next_number > 0")])

    class Meta:
        table_name = "id_sequences"


class Changelog(BaseModel):
    id = AutoField(column_name="change_id")
    changed_at = CharField()
    object_code = CharField(null=True)
    version = CharField(null=True)
    status = CharField(null=True)
    change_type = CharField(null=True)
    description = TextField(null=True)
    author = CharField(null=True)
    next_action = TextField(null=True)

    class Meta:
        table_name = "changelog"


class User(BaseModel):
    id = AutoField()
    email = CharField(unique=True, index=True)
    password_hash = CharField()
    is_admin = BooleanField(default=False)
    created_at = CharField()

    class Meta:
        table_name = "users"


class FeedbackMessage(BaseModel):
    id = AutoField()
    user = ForeignKeyField(User, backref="feedback_messages", on_delete="CASCADE")
    message = TextField()
    submitted_at = CharField(index=True)

    class Meta:
        table_name = "feedback_messages"


class OAuthClient(BaseModel):
    client_id = CharField(primary_key=True)
    client_secret_hash = CharField(null=True)
    client_secret_expires_at = IntegerField(null=True)
    client_id_issued_at = IntegerField()
    redirect_uris = TextField()
    token_endpoint_auth_method = CharField()
    grant_types = TextField()
    response_types = TextField()
    scope = TextField(null=True)
    client_name = TextField(null=True)
    metadata_json = TextField(null=True)

    class Meta:
        table_name = "oauth_clients"


class OAuthPendingAuthorization(BaseModel):
    request_id = CharField(primary_key=True)
    client = ForeignKeyField(OAuthClient, backref="pending_authorizations", on_delete="CASCADE")
    redirect_uri = TextField()
    scopes = TextField()
    state = TextField(null=True)
    code_challenge = TextField()
    resource = TextField(null=True)
    expires_at = IntegerField()
    created_at = IntegerField()

    class Meta:
        table_name = "oauth_pending_authorizations"
        indexes = ((("expires_at",), False),)


class OAuthAuthorizationCode(BaseModel):
    code_hash = CharField(primary_key=True)
    client = ForeignKeyField(OAuthClient, backref="authorization_codes", on_delete="CASCADE")
    user = ForeignKeyField(User, backref="oauth_authorization_codes", on_delete="CASCADE")
    scopes = TextField()
    code_challenge = TextField()
    redirect_uri = TextField()
    resource = TextField(null=True)
    expires_at = IntegerField()
    created_at = IntegerField()
    used_at = IntegerField(null=True)

    class Meta:
        table_name = "oauth_authorization_codes"
        indexes = (
            (("client",), False),
            (("user",), False),
            (("expires_at",), False),
        )


class OAuthRefreshToken(BaseModel):
    token_hash = CharField(primary_key=True)
    client = ForeignKeyField(OAuthClient, backref="refresh_tokens", on_delete="CASCADE")
    user = ForeignKeyField(User, backref="oauth_refresh_tokens", on_delete="CASCADE")
    scopes = TextField()
    expires_at = IntegerField()
    created_at = IntegerField()
    revoked_at = IntegerField(null=True)
    replaced_by_hash = CharField(null=True)

    class Meta:
        table_name = "oauth_refresh_tokens"
        indexes = (
            (("client",), False),
            (("user",), False),
            (("expires_at",), False),
        )


class Product(BaseModel):
    id = AutoField()
    code = CharField(unique=True)
    name = CharField()
    category = CharField(null=True)
    unit = CharField()
    package_price_rsd = FloatField(null=True)
    package_size = FloatField(null=True)
    price_per_100_or_unit_rsd = FloatField(null=True)
    kcal = FloatField(constraints=[Check("kcal >= 0")])
    protein_g = FloatField(constraints=[Check("protein_g >= 0")])
    fat_g = FloatField(constraints=[Check("fat_g >= 0")])
    carbs_g = FloatField(constraints=[Check("carbs_g >= 0")])
    data_status = CharField()
    note = TextField(null=True)

    class Meta:
        table_name = "products"


class ProductMeasure(BaseModel):
    id = AutoField()
    product = ForeignKeyField(Product, backref="measures", on_delete="CASCADE")
    measure_name = CharField()
    base_quantity = FloatField(constraints=[Check("base_quantity > 0")])

    class Meta:
        table_name = "product_measures"
        indexes = ((("product", "measure_name"), True),)


class Recipe(BaseModel):
    id = AutoField()
    code = CharField(unique=True)
    name = CharField()
    category = CharField()
    subcategory = CharField(null=True)
    version = CharField()
    status = CharField()
    servings = FloatField(constraints=[Check("servings > 0")])
    tags = TextField(null=True)
    manual_price_per_serving_rsd = FloatField(null=True)
    manual_kcal_per_serving = FloatField(null=True)
    manual_protein_per_serving_g = FloatField(null=True)
    manual_fat_per_serving_g = FloatField(null=True)
    manual_carbs_per_serving_g = FloatField(null=True)
    owner = ForeignKeyField(User, backref="local_recipes", null=True, on_delete="CASCADE")
    submitted_by = ForeignKeyField(User, backref="submitted_recipes", null=True, on_delete="SET NULL")
    submission_requested = BooleanField(default=False)
    moderation_status = CharField(default="none")
    moderation_note = TextField(null=True)

    class Meta:
        table_name = "recipes"
        indexes = ((('owner',), False),)


class RecipeIngredient(BaseModel):
    id = AutoField()
    recipe = ForeignKeyField(Recipe, backref="ingredients", on_delete="CASCADE")
    product = ForeignKeyField(Product, backref="recipe_ingredients")
    quantity = FloatField(constraints=[Check("quantity >= 0")])
    unit = CharField()
    portion_description = TextField(null=True)
    measurement_name = CharField(null=True)
    measurement_quantity = FloatField(null=True)

    class Meta:
        table_name = "recipe_ingredients"
        indexes = (
            (("recipe",), False),
            (("product",), False),
        )


class DiaryEntry(BaseModel):
    id = AutoField()
    user = ForeignKeyField(User, backref="diary_entries", on_delete="CASCADE")
    entry_date = CharField(index=True)
    meal_type = CharField(null=True)
    recipe = ForeignKeyField(Recipe, backref="diary_entries", null=True, on_delete="SET NULL")
    product = ForeignKeyField(Product, backref="diary_entries", null=True, on_delete="SET NULL")
    servings = FloatField(default=1, constraints=[Check("servings > 0")])
    quantity = FloatField(null=True)
    measurement_name = CharField(null=True)
    measurement_quantity = FloatField(null=True)
    comment = TextField(null=True)

    class Meta:
        table_name = "diary_entries"


class ProgressEntry(BaseModel):
    id = AutoField()
    user = ForeignKeyField(User, backref="progress_entries", on_delete="CASCADE")
    measured_at = CharField()
    weight_kg = FloatField(null=True)
    height_cm = FloatField(null=True)
    bmi = FloatField(null=True)
    body_fat_pct = FloatField(null=True)
    fat_mass_kg = FloatField(null=True)
    muscle_pct = FloatField(null=True)
    muscle_mass_kg = FloatField(null=True)
    protein_target_g = FloatField(null=True)
    fat_target_g = FloatField(null=True)
    waist_cm = FloatField(null=True)
    chest_cm = FloatField(null=True)
    hips_cm = FloatField(null=True)
    sleep_score = IntegerField(null=True)
    wellbeing_score = IntegerField(null=True)
    comment = TextField(null=True)

    class Meta:
        table_name = "progress_entries"
        indexes = ((("user", "measured_at"), True),)


class Exercise(BaseModel):
    id = AutoField()
    code = CharField(unique=True)
    muscle_group = CharField(null=True)
    name = CharField()
    default_unit = CharField(null=True)
    default_sets = IntegerField(null=True)
    default_reps = IntegerField(null=True)
    target_rir = CharField(null=True)
    note = TextField(null=True)
    description = TextField(null=True)
    photo_urls = TextField(null=True)
    video_url = TextField(null=True)

    class Meta:
        table_name = "exercises"


class WorkoutLog(BaseModel):
    id = AutoField()
    user = ForeignKeyField(User, backref="workout_logs", on_delete="CASCADE")
    performed_at = CharField(index=True)
    exercise = ForeignKeyField(Exercise, backref="workout_logs")
    working_weight = FloatField(null=True)
    sets = IntegerField(null=True)
    reps = IntegerField(null=True)
    rir = CharField(null=True)
    machine_location = CharField(null=True)
    comment = TextField(null=True)

    class Meta:
        table_name = "workout_logs"


class WorkoutPlan(BaseModel):
    id = AutoField()
    user = ForeignKeyField(User, backref="workout_plans", on_delete="CASCADE")
    scheduled_at = CharField(index=True)
    status = CharField(default="planned", index=True)
    completed_at = CharField(null=True)

    class Meta:
        table_name = "workout_plans"
        indexes = ((('user', 'status'), False), (('user', 'scheduled_at'), False))


class WorkoutPlanItem(BaseModel):
    id = AutoField()
    plan = ForeignKeyField(WorkoutPlan, backref="items", on_delete="CASCADE")
    exercise = ForeignKeyField(Exercise, backref="workout_plan_items")
    working_weight = FloatField(null=True)
    sets = IntegerField(null=True)
    duration_minutes = IntegerField(null=True)
    speed_kmh = FloatField(null=True)

    class Meta:
        table_name = "workout_plan_items"
        indexes = ((('plan', 'id'), False),)


MODELS = [
    AppMeta,
    IdSequence,
    Changelog,
    User,
    FeedbackMessage,
    OAuthClient,
    OAuthPendingAuthorization,
    OAuthAuthorizationCode,
    OAuthRefreshToken,
    Product,
    Recipe,
    Exercise,
    ProductMeasure,
    RecipeIngredient,
    DiaryEntry,
    ProgressEntry,
    WorkoutLog,
    WorkoutPlan,
    WorkoutPlanItem,
]
