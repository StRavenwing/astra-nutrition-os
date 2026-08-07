from __future__ import annotations

from typing import Any

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

from backend.mcp.auth import require_mcp_user
from backend.models import Recipe
from backend.services.errors import NotFoundError
from backend.services.recipes import create_recipe, delete_recipe, get_recipe_detail, list_recipes, update_recipe


READ_ANNOTATIONS = ToolAnnotations(readOnlyHint=True, destructiveHint=False, idempotentHint=True, openWorldHint=False)
WRITE_ANNOTATIONS = ToolAnnotations(readOnlyHint=False, destructiveHint=False, idempotentHint=False, openWorldHint=False)
DELETE_ANNOTATIONS = ToolAnnotations(readOnlyHint=False, destructiveHint=True, idempotentHint=False, openWorldHint=False)


def _find_recipe(id: int | None = None, code: str | None = None) -> Recipe:
    if id is not None:
        recipe = Recipe.get_or_none(Recipe.id == id)
    elif code:
        recipe = Recipe.get_or_none(Recipe.code == code.strip())
    else:
        raise ValueError("Нужно указать id или code рецепта")
    if recipe is None:
        raise NotFoundError("Рецепт не найден")
    return recipe


def _matches_text(recipe: dict[str, Any], query: str) -> bool:
    haystack = " ".join(
        str(recipe.get(field) or "")
        for field in ("code", "name", "category", "subcategory", "status", "tags")
    ).lower()
    return query.lower() in haystack


def _ingredient_payload(ingredient: dict[str, Any]) -> dict[str, Any]:
    return {
        "product_id": ingredient["product_id"],
        "quantity": ingredient.get("quantity"),
        "unit": ingredient.get("unit"),
        "measurement_name": ingredient.get("measurement_name"),
        "measurement_quantity": ingredient.get("measurement_quantity"),
        "portion_description": ingredient.get("portion_description"),
    }


def _recipe_update_payload(current: dict[str, Any], updates: dict[str, Any]) -> dict[str, Any]:
    recipe = current["recipe"]
    payload = {
        "category": recipe["category"],
        "name": recipe["name"],
        "subcategory": recipe.get("subcategory"),
        "version": recipe.get("version", "1.0"),
        "status": recipe.get("status", "Draft"),
        "servings": recipe.get("servings", 1),
        "tags": recipe.get("tags"),
        "manual_price_per_serving_rsd": recipe.get("manual_price_per_serving_rsd"),
        "manual_kcal_per_serving": recipe.get("manual_kcal_per_serving"),
        "manual_protein_per_serving_g": recipe.get("manual_protein_per_serving_g"),
        "manual_fat_per_serving_g": recipe.get("manual_fat_per_serving_g"),
        "manual_carbs_per_serving_g": recipe.get("manual_carbs_per_serving_g"),
        "ingredients": [_ingredient_payload(ingredient) for ingredient in current["ingredients"]],
    }
    for key, value in updates.items():
        if value is not None:
            payload[key] = value
    return payload


def register_recipe_tools(mcp: FastMCP) -> None:
    @mcp.tool(
        name="recipes.search",
        title="Search recipes",
        description="Search Astra recipes and return calculated recipe summaries.",
        annotations=READ_ANNOTATIONS,
        structured_output=True,
    )
    def recipes_search(
        query: str | None = None,
        category: str | None = None,
        status: str | None = None,
        tags: str | None = None,
        limit: int = 20,
        include_archived: bool = False,
    ) -> list[dict[str, Any]]:
        require_mcp_user("recipes:read")
        max_items = min(max(int(limit or 20), 1), 100)
        recipes = list_recipes()
        if not include_archived:
            recipes = [recipe for recipe in recipes if recipe.get("status") != "Archived"]
        if query:
            recipes = [recipe for recipe in recipes if _matches_text(recipe, query)]
        if category:
            recipes = [recipe for recipe in recipes if recipe.get("category") == category]
        if status:
            recipes = [recipe for recipe in recipes if recipe.get("status") == status]
        if tags:
            expected_tags = [item.strip().lower() for item in tags.split(",") if item.strip()]
            recipes = [
                recipe
                for recipe in recipes
                if all(tag in str(recipe.get("tags") or "").lower() for tag in expected_tags)
            ]
        return recipes[:max_items]

    @mcp.tool(
        name="recipes.get",
        title="Get recipe",
        description="Return a recipe card with ingredients and calculated nutrition/cost values.",
        annotations=READ_ANNOTATIONS,
        structured_output=True,
    )
    def recipes_get(id: int | None = None, code: str | None = None) -> dict[str, Any]:
        require_mcp_user("recipes:read")
        recipe = _find_recipe(id=id, code=code)
        return get_recipe_detail(recipe.id)

    @mcp.tool(
        name="recipes.create",
        title="Create recipe",
        description="Create a recipe in the shared Astra recipe catalog.",
        annotations=WRITE_ANNOTATIONS,
        structured_output=True,
    )
    def recipes_create(
        category: str,
        name: str,
        subcategory: str | None = None,
        version: str = "1.0",
        status: str = "Draft",
        servings: float = 1,
        tags: str | None = None,
        manual_price_per_serving_rsd: float | None = None,
        manual_kcal_per_serving: float | None = None,
        manual_protein_per_serving_g: float | None = None,
        manual_fat_per_serving_g: float | None = None,
        manual_carbs_per_serving_g: float | None = None,
        ingredients: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        require_mcp_user("recipes:write", admin=True)
        return create_recipe(
            {
                "category": category,
                "name": name,
                "subcategory": subcategory,
                "version": version,
                "status": status,
                "servings": servings,
                "tags": tags,
                "manual_price_per_serving_rsd": manual_price_per_serving_rsd,
                "manual_kcal_per_serving": manual_kcal_per_serving,
                "manual_protein_per_serving_g": manual_protein_per_serving_g,
                "manual_fat_per_serving_g": manual_fat_per_serving_g,
                "manual_carbs_per_serving_g": manual_carbs_per_serving_g,
                "ingredients": ingredients or [],
            }
        )

    @mcp.tool(
        name="recipes.update",
        title="Update recipe",
        description="Patch a recipe. Omitted fields stay unchanged; provided ingredients replace the full ingredient list.",
        annotations=WRITE_ANNOTATIONS,
        structured_output=True,
    )
    def recipes_update(
        id: int | None = None,
        code: str | None = None,
        category: str | None = None,
        name: str | None = None,
        subcategory: str | None = None,
        version: str | None = None,
        status: str | None = None,
        servings: float | None = None,
        tags: str | None = None,
        manual_price_per_serving_rsd: float | None = None,
        manual_kcal_per_serving: float | None = None,
        manual_protein_per_serving_g: float | None = None,
        manual_fat_per_serving_g: float | None = None,
        manual_carbs_per_serving_g: float | None = None,
        ingredients: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        require_mcp_user("recipes:write", admin=True)
        recipe = _find_recipe(id=id, code=code)
        updates = {
            "category": category,
            "name": name,
            "subcategory": subcategory,
            "version": version,
            "status": status,
            "servings": servings,
            "tags": tags,
            "manual_price_per_serving_rsd": manual_price_per_serving_rsd,
            "manual_kcal_per_serving": manual_kcal_per_serving,
            "manual_protein_per_serving_g": manual_protein_per_serving_g,
            "manual_fat_per_serving_g": manual_fat_per_serving_g,
            "manual_carbs_per_serving_g": manual_carbs_per_serving_g,
        }
        payload = _recipe_update_payload(get_recipe_detail(recipe.id), updates)
        if ingredients is not None:
            payload["ingredients"] = ingredients
        return update_recipe(recipe.id, payload)

    @mcp.tool(
        name="recipes.delete",
        title="Delete recipe",
        description="Delete a recipe from the shared Astra recipe catalog.",
        annotations=DELETE_ANNOTATIONS,
        structured_output=True,
    )
    def recipes_delete(id: int | None = None, code: str | None = None) -> dict[str, Any]:
        require_mcp_user("recipes:write", admin=True)
        recipe = _find_recipe(id=id, code=code)
        return delete_recipe(recipe.id)
