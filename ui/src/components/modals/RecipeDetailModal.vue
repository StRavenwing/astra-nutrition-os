<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { RecipeDetail, RecipeSummary } from '@/types';
import { fmt } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{
  recipeId: number | null;
  isAdmin: boolean;
}>();
const emit = defineEmits<{
  close: [];
  edit: [id: number];
  deleted: [];
  changed: [];
}>();

const loading = ref(false);
const error = ref('');
const detail = ref<RecipeDetail | null>(null);
const recipe = computed<RecipeSummary | null>(() => detail.value?.recipe || null);
const canManage = computed(() => Boolean(recipe.value && (props.isAdmin || recipe.value.collection === 'local')));

watch(
  () => props.recipeId,
  async (id) => {
    detail.value = null;
    error.value = '';
    if (!id) return;
    loading.value = true;
    try {
      detail.value = await api.recipe(id);
    } catch (err) {
      error.value = err instanceof Error ? err.message : String(err);
    } finally {
      loading.value = false;
    }
  },
  { immediate: true }
);

async function removeRecipe() {
  if (!props.recipeId || !confirm('Удалить рецепт? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`recipes/${props.recipeId}`);
    emit('deleted');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

async function resubmit() {
  if (!recipe.value) return;
  try {
    const updated = await api.requestRecipeSubmission(recipe.value.id);
    if (detail.value) detail.value.recipe = updated;
    emit('changed');
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

async function cancelSubmission() {
  if (!recipe.value) return;
  try {
    const updated = await api.cancelRecipeSubmission(recipe.value.id);
    if (detail.value) detail.value.recipe = updated;
    emit('changed');
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

function macroItems(values: { kcal: unknown; protein: unknown; fat: unknown; carbs: unknown }) {
  return [
    { label: 'Калории', value: `${fmt(values.kcal)} ккал` },
    { label: 'Белки', value: `${fmt(values.protein)} г` },
    { label: 'Жиры', value: `${fmt(values.fat)} г` },
    { label: 'Углеводы', value: `${fmt(values.carbs)} г` }
  ];
}
</script>

<template>
  <ModalDialog
    :open="Boolean(recipeId)"
    :title="recipe?.name || 'Рецепт'"
    :eyebrow="'RECIPE DETAILS'"
    wide
    @close="$emit('close')"
  >
    <p v-if="recipe" class="subtle recipe-meta">{{ recipe.code }} · {{ recipe.category }}<template v-if="recipe.subcategory"> / {{ recipe.subcategory }}</template> · v{{ recipe.version }} · {{ fmt(recipe.servings) }} порц.</p>
    <div v-if="loading" class="panel">Загрузка…</div>
    <div v-else-if="error" class="panel empty">{{ error }}</div>
    <div v-else-if="recipe && detail" class="recipe-body">
      <div v-if="recipe.moderation_status === 'revision' && recipe.is_submitter" class="revision-note">
        <b>Комментарий администратора</b>
        <p>{{ recipe.moderation_note }}</p>
        <div class="review-actions">
          <button type="button" class="primary" @click="resubmit">Отправить повторно</button>
          <button type="button" @click="cancelSubmission">Отменить отправку</button>
        </div>
      </div>
      <div v-if="canManage" class="recipe-actions">
        <button type="button" class="edit-recipe" @click="$emit('edit', recipe.id)">✎ Редактировать</button>
        <button type="button" class="danger-button" @click="removeRecipe">Удалить</button>
      </div>

      <h3 class="macro-heading">КБЖУ на порцию</h3>
      <div class="recipe-kpis">
        <div v-for="item in macroItems({ kcal: recipe.kcal_per_serving, protein: recipe.protein_per_serving_g, fat: recipe.fat_per_serving_g, carbs: recipe.carbs_per_serving_g })" :key="item.label">
          <span>{{ item.label }}</span>
          <b>{{ item.value }}</b>
        </div>
      </div>
      <div class="portion-price">
        <span>Цена одной порции {{ recipe.manual_price_per_serving_rsd != null ? '· фиксированная' : '' }}</span>
        <b>{{ fmt(recipe.cost_per_serving_rsd) }} RSD</b>
      </div>

      <h3 class="macro-heading">КБЖУ всего рецепта</h3>
      <div class="recipe-kpis recipe-total">
        <div v-for="item in macroItems({ kcal: recipe.kcal, protein: recipe.protein_g, fat: recipe.fat_g, carbs: recipe.carbs_g })" :key="item.label">
          <span>{{ item.label }}</span>
          <b>{{ item.value }}</b>
        </div>
      </div>

      <h3 class="ingredients-heading">{{ recipe.category === 'Ready' ? 'Готовое блюдо' : 'Состав всего рецепта' }}</h3>
      <div v-if="recipe.category === 'Ready'" class="ready-recipe-note">
        <b>КБЖУ указано вручную</b>
        <span>Для готового блюда состав по ингредиентам не используется.</span>
      </div>
      <div v-else class="recipe-table">
        <table>
          <thead>
            <tr>
              <th>Продукт</th>
              <th>Количество</th>
              <th>Ккал</th>
              <th>Белки</th>
              <th>Жиры</th>
              <th>Углеводы</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="ingredient in detail.ingredients" :key="ingredient.id">
              <td><b>{{ ingredient.name }}</b><small>{{ ingredient.portion_description || ingredient.product_code }}</small></td>
              <td class="number">{{ fmt(ingredient.quantity) }} {{ ingredient.unit }}</td>
              <td class="number">{{ fmt(ingredient.kcal) }}</td>
              <td class="number">{{ fmt(ingredient.protein_g) }}</td>
              <td class="number">{{ fmt(ingredient.fat_g) }}</td>
              <td class="number">{{ fmt(ingredient.carbs_g) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.recipe-meta {
  margin-top: -12px;
}
.revision-note { margin-bottom: 18px; padding: 15px; border: 1px solid #f0b429; border-radius: 11px; background: #fff7d6; }
.revision-note p { margin: 7px 0 12px; white-space: pre-wrap; }
</style>
