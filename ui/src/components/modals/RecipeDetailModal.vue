<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { api } from '@/api/client';
import { recipeCategoryLabels } from '@/constants';
import type { RecipeDetail, RecipeSummary } from '@/types';
import { fmt } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import SendToClientButton from '@/components/shared/SendToClientButton.vue';

const props = defineProps<{
  recipeId: number | null;
  isAdmin: boolean;
  canManage: boolean;
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
const canEdit = computed(() => Boolean(recipe.value && (props.isAdmin || recipe.value.collection === 'local')));
const selectedServings = ref(1);
const originalServings = computed(() => {
  const value = Number(recipe.value?.servings);
  return Number.isFinite(value) && value > 0 ? value : 1;
});
const servingOptions = computed(() => [...new Set([
  0.5,
  ...Array.from({ length: 20 }, (_, index) => index + 1),
  originalServings.value,
])].sort((left, right) => left - right));
const servingScale = computed(() => selectedServings.value / originalServings.value);

function scaledValue(value: number | null | undefined) {
  return value == null ? null : value * servingScale.value;
}

const scaledIngredients = computed(() => (detail.value?.ingredients || []).map((ingredient) => ({
  ...ingredient,
  quantity: scaledValue(ingredient.quantity),
  measurement_quantity: scaledValue(ingredient.measurement_quantity),
  kcal: scaledValue(ingredient.kcal),
  protein_g: scaledValue(ingredient.protein_g),
  fat_g: scaledValue(ingredient.fat_g),
  carbs_g: scaledValue(ingredient.carbs_g),
  cost_rsd: scaledValue(ingredient.cost_rsd),
})));

watch(
  () => props.recipeId,
  async (id, _previousId, onCleanup) => {
    let active = true;
    onCleanup(() => { active = false; });
    detail.value = null;
    error.value = '';
    selectedServings.value = 1;
    loading.value = Boolean(id);
    if (!id) return;
    try {
      const loaded = await api.recipe(id);
      if (active) detail.value = loaded;
    } catch (err) {
      if (active) error.value = err instanceof Error ? err.message : String(err);
    } finally {
      if (active) loading.value = false;
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
    <p v-if="recipe" class="subtle recipe-meta">{{ recipe.code }} · {{ recipeCategoryLabels[recipe.category] || recipe.category }}<template v-if="recipe.subcategory"> / {{ recipe.subcategory }}</template> · v{{ recipe.version }}</p>
    <div v-if="loading" class="panel">Загрузка…</div>
    <div v-else-if="error" class="panel empty">{{ error }}</div>
    <div v-else-if="recipe && detail" class="recipe-body">
      <div class="recipe-servings-control">
        <label for="recipe-detail-servings">Количество порций</label>
        <select id="recipe-detail-servings" v-model.number="selectedServings">
          <option v-for="count in servingOptions" :key="count" :value="count">{{ fmt(count) }} порц.</option>
        </select>
        <span v-if="recipe.yield_g != null" class="recipe-selected-yield">Выход: {{ fmt(scaledValue(recipe.yield_g)) }} г</span>
        <small>Исходный рецепт: {{ fmt(originalServings) }} порц.</small>
      </div>
      <div v-if="recipe.moderation_status === 'revision' && recipe.is_submitter" class="revision-note">
        <b>Комментарий администратора</b>
        <p>{{ recipe.moderation_note }}</p>
        <div class="review-actions">
          <button type="button" class="primary" @click="resubmit">Отправить повторно</button>
          <button type="button" @click="cancelSubmission">Отменить отправку</button>
        </div>
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

      <h3 class="macro-heading">КБЖУ на {{ fmt(selectedServings) }} порц.</h3>
      <div class="recipe-kpis recipe-total">
        <div v-for="item in macroItems({ kcal: scaledValue(recipe.kcal), protein: scaledValue(recipe.protein_g), fat: scaledValue(recipe.fat_g), carbs: scaledValue(recipe.carbs_g) })" :key="item.label">
          <span>{{ item.label }}</span>
          <b>{{ item.value }}</b>
        </div>
      </div>

      <h3 class="ingredients-heading">{{ recipe.is_ready ? 'Готовое блюдо' : `Состав на ${fmt(selectedServings)} порц.` }}</h3>
      <div v-if="recipe.is_ready" class="ready-recipe-note">
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
            <tr v-for="ingredient in scaledIngredients" :key="`${ingredient.component_type}-${ingredient.id}`">
              <td><b>{{ ingredient.name }}</b><small>{{ ingredient.portion_description ? `${servingScale !== 1 ? 'В исходном рецепте: ' : ''}${ingredient.portion_description}` : ingredient.product_code || (ingredient.component_type === 'recipe' ? 'Готовое блюдо' : '') }}</small></td>
              <td class="number">{{ fmt(ingredient.quantity) }} {{ ingredient.unit }}</td>
              <td class="number">{{ fmt(ingredient.kcal) }}</td>
              <td class="number">{{ fmt(ingredient.protein_g) }}</td>
              <td class="number">{{ fmt(ingredient.fat_g) }}</td>
              <td class="number">{{ fmt(ingredient.carbs_g) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="props.canManage" class="modal-extra-actions">
        <SendToClientButton :item-type="'recipe'" :item-id="recipe.id" :can-manage="props.canManage" />
      </div>
      <div class="actions recipe-detail-actions">
        <button v-if="canEdit" type="button" class="danger-button" @click="removeRecipe">Удалить</button>
        <button type="button" @click="$emit('close')">Закрыть</button>
        <button v-if="canEdit" type="button" @click="$emit('edit', recipe.id)">✎ Редактировать</button>
      </div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.recipe-meta {
  margin-top: -12px;
}
.recipe-servings-control {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px 14px;
  margin-bottom: 20px;
  padding: 14px 16px;
  border: 1px solid #e5eaf2;
  border-radius: 12px;
  background: #f6f8fc;
}
.recipe-servings-control label {
  font-size: 13px;
  font-weight: 700;
}
body dialog .recipe-servings-control select {
  width: auto;
  min-width: 100px;
  max-width: 100%;
  min-height: 40px;
  padding: 8px 12px;
}
.recipe-servings-control .recipe-selected-yield {
  font-size: 13px;
  font-weight: 600;
}
.recipe-servings-control small {
  flex-basis: 100%;
  color: #7d879b;
  font-size: 11px;
}
.revision-note { margin-bottom: 18px; padding: 15px; border: 1px solid #f0b429; border-radius: 11px; background: #fff7d6; }
.revision-note p { margin: 7px 0 12px; white-space: pre-wrap; }
</style>
