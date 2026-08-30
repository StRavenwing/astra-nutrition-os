<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { mealOrder } from '@/constants';
import { api } from '@/api/client';
import type { DiaryEntry, Product, ProductMeasure, RecipeSummary } from '@/types';
import { localToday } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ diaryId?: number; initialMealType?: string; targetUserId?: number }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();

type RowKind = 'recipe' | 'product' | 'custom';
type DiaryRow = {
  kind: RowKind;
  meal_type: string;
  recipe_id: number;
  servings: string;
  product_id: number;
  quantity: string;
  measurement_name: string;
  comment: string;
  custom_name?: string;
  custom_kcal?: string;
  custom_protein_g?: string;
  custom_fat_g?: string;
  custom_carbs_g?: string;
};

const loading = ref(false);
const error = ref('');
const entryDate = ref(localToday());
const recipes = ref<RecipeSummary[]>([]);
const products = ref<Product[]>([]);
const measures = ref<ProductMeasure[]>([]);
const rows = ref<DiaryRow[]>([]);
const customDishOpen = ref(false);
const customDishError = ref('');
const customDish = reactive({
  name: '',
  kcal: '',
  protein_g: '',
  fat_g: '',
  carbs_g: ''
});
const customDishMealType = ref(props.initialMealType || mealOrder[1]);

function productById(productId: number) {
  return products.value.find((product) => product.id === productId) || products.value[0];
}

function measureOptions(row: DiaryRow) {
  const product = productById(row.product_id);
  if (!product) return [];
  return [
    { measure_name: product.unit || 'г', base_quantity: 1 },
    ...measures.value.filter((measure) => measure.product_id === product.id)
  ];
}

function defaultRow(kind: RowKind, mealType = 'Завтрак'): DiaryRow {
  const product = products.value[0];
  return {
    kind,
    meal_type: mealType,
    recipe_id: recipes.value[0]?.id || 0,
    servings: '1',
    product_id: product?.id || 0,
    quantity: kind === 'product' ? '100' : '',
    measurement_name: product?.unit || 'г',
    comment: ''
  };
}

function addRecipeRow(mealType = 'Обед') {
  rows.value.push(defaultRow('recipe', mealType));
}

function addProductRow(mealType = 'Перекус') {
  rows.value.push(defaultRow('product', mealType));
}

function openCustomDish(mealType = props.initialMealType || mealOrder[1]) {
  customDish.name = '';
  customDish.kcal = '';
  customDish.protein_g = '';
  customDish.fat_g = '';
  customDish.carbs_g = '';
  customDishError.value = '';
  customDishOpen.value = true;
  customDishMealType.value = mealType;
}

function saveCustomDish() {
  customDishError.value = '';
  const values = [customDish.kcal, customDish.protein_g, customDish.fat_g, customDish.carbs_g].map(Number);
  if (!customDish.name.trim() || values.some((value) => !Number.isFinite(value) || value < 0)) {
    customDishError.value = 'Укажите название и неотрицательные значения КБЖУ.';
    return;
  }
  rows.value.push({
    kind: 'custom',
    meal_type: customDishMealType.value,
    recipe_id: 0,
    servings: '1',
    product_id: 0,
    quantity: '',
    measurement_name: '',
    comment: '',
    custom_name: customDish.name.trim(),
    custom_kcal: customDish.kcal,
    custom_protein_g: customDish.protein_g,
    custom_fat_g: customDish.fat_g,
    custom_carbs_g: customDish.carbs_g
  });
  customDishOpen.value = false;
}

function removeRow(index: number) {
  if (rows.value.length > 1) rows.value.splice(index, 1);
}

function productChanged(row: DiaryRow) {
  row.measurement_name = productById(row.product_id)?.unit || 'г';
}

function rowFromEntry(item: DiaryEntry): DiaryRow {
  const product = productById(item.product_id || 0);
  return {
    kind: item.product_id ? 'product' : 'recipe',
    meal_type: item.meal_type || 'Завтрак',
    recipe_id: item.recipe_id || recipes.value[0]?.id || 0,
    servings: item.servings == null ? '1' : String(item.servings),
    product_id: item.product_id || products.value[0]?.id || 0,
    quantity: item.measurement_quantity != null ? String(item.measurement_quantity) : item.quantity != null ? String(item.quantity) : '100',
    measurement_name: item.measurement_name || product?.unit || item.unit || 'г',
    comment: item.comment || ''
  };
}

onMounted(async () => {
  loading.value = true;
  try {
    const [recipeList, productList, measureList] = await Promise.all([api.recipes(), api.products(), api.productMeasures()]);
    recipes.value = [...recipeList].sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    products.value = [...productList].sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    measures.value = measureList;

    if (props.diaryId) {
      const data = props.targetUserId ? await api.clientDiary(props.targetUserId) : await api.diary();
      const item = data.find((entry) => entry.id === props.diaryId);
      if (item) {
        entryDate.value = item.entry_date;
        rows.value = [rowFromEntry(item)];
      }
    }
    if (!rows.value.length) addRecipeRow(props.initialMealType || mealOrder[0]);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

function itemPayload(row: DiaryRow) {
  if (row.kind === 'custom') {
    return {
      meal_type: row.meal_type,
      servings: row.servings,
      comment: row.comment,
      custom_dish: {
        name: row.custom_name,
        kcal: row.custom_kcal,
        protein_g: row.custom_protein_g,
        fat_g: row.custom_fat_g,
        carbs_g: row.custom_carbs_g
      }
    };
  }
  if (row.kind === 'product') {
    return {
      meal_type: row.meal_type,
      product_id: row.product_id,
      quantity: row.quantity,
      measurement_quantity: row.quantity,
      measurement_name: row.measurement_name,
      servings: 1,
      comment: row.comment
    };
  }
  return {
    meal_type: row.meal_type,
    recipe_id: row.recipe_id,
    servings: row.servings,
    comment: row.comment
  };
}

async function save() {
  error.value = '';
  try {
    if (props.diaryId) {
      await api.put(`diary/${props.diaryId}`, { entry_date: entryDate.value, ...itemPayload(rows.value[0]) });
    } else {
      const payload = { entry_date: entryDate.value, items: rows.value.map(itemPayload) };
      if (props.targetUserId) await api.addClientDiary(props.targetUserId, payload);
      else await api.post('diary', payload);
    }
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

async function remove() {
  if (!props.diaryId || !confirm('Удалить запись из дневника? Это действие нельзя отменить.')) return;
  error.value = '';
  try {
    await api.delete(`diary/${props.diaryId}`);
    emit('deleted');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="field diary-date">
        <label>Дата</label>
        <input v-model="entryDate" type="date" required>
      </div>

      <div class="diary-form-labels">
        <span>Приём пищи</span>
        <span>Блюдо или ингредиент</span>
        <span>Количество</span>
        <span>Единица</span>
        <span>Комментарий</span>
        <span></span>
      </div>

      <div id="diary-items">
        <div v-for="(row, index) in rows" :key="index" class="diary-form-row">
          <select v-model="row.meal_type" class="dm"><option v-for="meal in mealOrder" :key="meal">{{ meal }}</option></select>
          <select v-if="row.kind === 'recipe'" v-model="row.recipe_id" class="dr"><option v-for="recipe in recipes" :key="recipe.id" :value="recipe.id">{{ recipe.name }}</option></select>
          <select v-else-if="row.kind === 'product'" v-model="row.product_id" class="dp" @change="productChanged(row)"><option v-for="product in products" :key="product.id" :value="product.id">{{ product.name }}</option></select>
          <div v-else class="diary-custom-selected"><b>{{ row.custom_name }}</b><small>{{ row.custom_kcal }} ккал · Б {{ row.custom_protein_g }} г · Ж {{ row.custom_fat_g }} г · У {{ row.custom_carbs_g }} г</small></div>
          <div class="diary-quantity"><input v-if="row.kind !== 'product'" v-model="row.servings" class="ds" type="number" min="0.25" step="0.25" aria-label="Порций" required><input v-else v-model="row.quantity" class="dq" type="number" min="0.01" step="0.01" aria-label="Количество" required><span v-if="row.kind !== 'product'">порции</span></div>
          <div class="diary-unit"><select v-if="row.kind === 'product'" v-model="row.measurement_name" class="dmu"><option v-for="measure in measureOptions(row)" :key="measure.measure_name" :value="measure.measure_name">{{ measure.measure_name }}</option></select><span v-else>порция</span></div>
          <input v-model="row.comment" class="dc" placeholder="Комментарий">
          <button type="button" class="remove-diary-row" aria-label="Удалить строку" @click="removeRow(index)">×</button>
        </div>
      </div>

      <div v-if="!props.diaryId" class="diary-add-actions">
        <button type="button" id="add-diary-item" @click="addRecipeRow()">＋ Добавить блюдо</button>
        <button type="button" id="add-diary-custom" @click="openCustomDish()">＋ Добавить новое блюдо</button>
        <button type="button" id="add-diary-product" @click="addProductRow()">＋ Добавить ингредиент</button>
      </div>

      <div v-if="props.diaryId" class="destructive-zone">
        <button type="button" class="danger-button" @click="remove">Удалить запись</button>
      </div>
      <p id="form-error">{{ error }}</p>
      <div class="actions">
        <button type="button" @click="$emit('cancel')">Отмена</button>
        <button type="submit" class="primary">Сохранить</button>
      </div>
    </template>
  </form>
  <ModalDialog :open="customDishOpen" title="Добавить новое блюдо" eyebrow="ДНЕВНИК ПИТАНИЯ" @close="customDishOpen = false">
    <div class="custom-dish-form">
      <p class="custom-dish-intro">Блюдо сохранится в дневнике и появится в личных рецептах.</p>
      <div class="field full"><label>Название блюда</label><input v-model="customDish.name" maxlength="200" required autofocus></div>
      <div class="grid custom-dish-macros">
        <div class="field"><label>Ккал</label><input v-model="customDish.kcal" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Белки, г</label><input v-model="customDish.protein_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Жиры, г</label><input v-model="customDish.fat_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Углеводы, г</label><input v-model="customDish.carbs_g" type="number" min="0" step="0.01" required></div>
      </div>
      <div class="field full"><label>Приём пищи</label><select v-model="customDishMealType"><option v-for="meal in mealOrder" :key="meal">{{ meal }}</option></select></div>
      <p class="form-error">{{ customDishError }}</p>
      <div class="actions"><button type="button" @click="customDishOpen = false">Отмена</button><button type="button" class="primary" @click="saveCustomDish">Добавить в дневник</button></div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
#diary-items {
  margin-bottom: 8px;
}

.diary-custom-selected { min-width: 0; display: grid; gap: 3px; padding: 8px 10px; border: 1px solid #c8d8f7; border-radius: 8px; background: #f7faff; }
.diary-custom-selected b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.diary-custom-selected small { color: var(--muted); font-size: 10px; }
.custom-dish-form { min-width: min(520px, 100%); }
.custom-dish-intro { margin: 0 0 16px; color: var(--muted); }
.custom-dish-macros { margin-bottom: 14px; }
.form-error { min-height: 18px; color: #ae2a19; }
</style>
