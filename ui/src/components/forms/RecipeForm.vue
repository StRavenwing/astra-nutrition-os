<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { recipeCategories, recipeCategoryMap } from '@/constants';
import { api } from '@/api/client';
import type { Product, ProductMeasure, RecipeIngredient, RecipeSummary } from '@/types';

const props = defineProps<{ recipeId?: number }>();
const emit = defineEmits<{ saved: [recipeId?: number]; cancel: [] }>();

type IngredientRow = {
  product_id: number;
  quantity: string;
  measurement_name: string;
};

const loading = ref(false);
const error = ref('');
const products = ref<Product[]>([]);
const extraCategories = ref<{ key: string; label: string; prefix: string; x: number; y: number }[]>([]);
const measures = ref<ProductMeasure[]>([]);
const original = ref<RecipeSummary | null>(null);
const ingredients = ref<IngredientRow[]>([]);

const form = reactive<Record<string, string>>({
  code: 'Автоматически: M-…',
  category: 'Main',
  name: '',
  subcategory: '',
  version: '1.0',
  servings: '1',
  tags: '',
  manual_price_per_serving_rsd: '',
  manual_kcal_per_serving: '',
  manual_protein_per_serving_g: '',
  manual_fat_per_serving_g: '',
  manual_carbs_per_serving_g: ''
});

const isReady = computed(() => form.category === 'Ready');
const categoryOptions = computed(() => [...recipeCategories, ...extraCategories.value]);
const modalTitle = computed(() => (props.recipeId ? 'Редактировать рецепт' : 'Добавить рецепт'));

function productById(productId: number) {
  return products.value.find((product) => product.id === productId) || products.value[0];
}

function optionsFor(row: IngredientRow) {
  const product = productById(row.product_id);
  if (!product) return [];
  const list = [
    { measure_name: product.unit || 'г', base_quantity: 1 },
    ...measures.value.filter((measure) => measure.product_id === product.id)
  ];
  return list;
}

function syncRecipeId() {
  const prefix = recipeCategoryMap[form.category]?.prefix || 'M';
  if (original.value && original.value.category === form.category) form.code = original.value.code;
  else form.code = `Автоматически: ${prefix}-…`;
}

function addIngredient(item?: Partial<RecipeIngredient>) {
  const productId = item?.product_id || products.value[0]?.id || 0;
  const row: IngredientRow = {
    product_id: productId,
    quantity: item?.measurement_quantity != null ? String(item.measurement_quantity) : item?.quantity != null ? String(item.quantity) : '',
    measurement_name: item?.measurement_name || productById(productId)?.unit || 'г'
  };
  ingredients.value.push(row);
}

function removeIngredient(index: number) {
  if (ingredients.value.length > 1) ingredients.value.splice(index, 1);
}

function productChanged(row: IngredientRow) {
  row.measurement_name = productById(row.product_id)?.unit || 'г';
}

onMounted(async () => {
  loading.value = true;
  try {
    extraCategories.value = (await api.categories('recipe'))
      .filter((item) => !recipeCategoryMap[item.name])
      .map((item) => ({ key: item.name, label: item.name, prefix: 'M', x: 50, y: 50 }));
    const productList = await api.products();
    products.value = [...productList].sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    measures.value = await api.productMeasures();

    if (props.recipeId) {
      const detail = await api.recipe(props.recipeId);
      const recipe = detail.recipe;
      if (recipe) {
        original.value = recipe;
        for (const [key, value] of Object.entries(recipe)) {
          if (key in form) form[key] = value == null ? '' : String(value);
        }
        ingredients.value = [];
        detail.ingredients.forEach((item) => addIngredient(item));
      }
    }

    if (!ingredients.value.length) addIngredient();
    syncRecipeId();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

watch(() => form.category, syncRecipeId);

function payload() {
  return {
    category: form.category,
    name: form.name,
    subcategory: form.subcategory,
    version: form.version,
    status: original.value?.status || 'Draft',
    servings: form.servings,
    tags: form.tags,
    manual_price_per_serving_rsd: form.manual_price_per_serving_rsd,
    manual_kcal_per_serving: form.manual_kcal_per_serving,
    manual_protein_per_serving_g: form.manual_protein_per_serving_g,
    manual_fat_per_serving_g: form.manual_fat_per_serving_g,
    manual_carbs_per_serving_g: form.manual_carbs_per_serving_g,
    ingredients: isReady.value
      ? []
      : ingredients.value.map((row) => ({
          product_id: row.product_id,
          quantity: row.quantity,
          measurement_quantity: row.quantity,
          measurement_name: row.measurement_name,
          unit: productById(row.product_id)?.unit || 'г'
        }))
  };
}

async function save() {
  error.value = '';
  try {
    let result: RecipeSummary | undefined;
    if (props.recipeId) result = await api.put<RecipeSummary>(`recipes/${props.recipeId}`, payload());
    else result = await api.post<RecipeSummary>('recipes', payload());
    emit('saved', result?.id || props.recipeId);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="grid">
        <div class="field"><label>Категория</label><select v-model="form.category"><option v-for="item in categoryOptions" :key="item.key" :value="item.key">{{ item.label }}</option></select></div>
        <div class="field"><label>ID рецепта</label><input v-model="form.code" readonly tabindex="-1"></div>
        <div class="field"><label>Название</label><input v-model="form.name" required></div>
        <div class="field"><label>Подкатегория</label><input v-model="form.subcategory"></div>
        <div class="field"><label>Версия</label><input v-model="form.version"></div>
        <div class="field"><label>Количество порций</label><input v-model="form.servings" type="number" min="1" step="0.1" required></div>
        <div class="field"><label>Теги</label><input v-model="form.tags"></div>
        <div class="field full"><label>Фиксированная цена за порцию, RSD</label><input v-model="form.manual_price_per_serving_rsd" type="number" min="0" step="0.01" placeholder="Пусто = рассчитать по составу"></div>
      </div>

      <div v-if="isReady" class="grid ready-recipe-fields">
        <div class="field"><label>Ккал на порцию</label><input v-model="form.manual_kcal_per_serving" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Белки на порцию, г</label><input v-model="form.manual_protein_per_serving_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Жиры на порцию, г</label><input v-model="form.manual_fat_per_serving_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Углеводы на порцию, г</label><input v-model="form.manual_carbs_per_serving_g" type="number" min="0" step="0.01" required></div>
      </div>

      <div v-else class="field full recipe-ingredients-section">
        <label>Ингредиенты</label>
        <div id="ingredients">
          <div v-for="(row, index) in ingredients" :key="index" class="ingredient-row">
            <select v-model="row.product_id" class="ip" @change="productChanged(row)">
              <option v-for="product in products" :key="product.id" :value="product.id">{{ product.name }}</option>
            </select>
            <input v-model="row.quantity" class="iq" type="number" min="0.01" step="0.01" placeholder="Количество" required>
            <select v-model="row.measurement_name" class="im">
              <option v-for="measure in optionsFor(row)" :key="measure.measure_name" :value="measure.measure_name">{{ measure.measure_name }}</option>
            </select>
            <button type="button" @click="removeIngredient(index)">×</button>
          </div>
        </div>
        <button type="button" id="add-ing" @click="addIngredient()">＋ ингредиент</button>
      </div>

      <p id="form-error">{{ error }}</p>
      <div class="actions">
        <button type="button" @click="$emit('cancel')">Отмена</button>
        <button type="submit" class="primary">Сохранить</button>
      </div>
    </template>
  </form>
</template>

<style lang="scss">
.recipe-ingredients-section {
  margin-top: 16px;
}
</style>
