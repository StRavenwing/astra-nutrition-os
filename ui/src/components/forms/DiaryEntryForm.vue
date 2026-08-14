<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { mealOrder } from '@/constants';
import { api } from '@/api/client';
import type { DiaryEntry, Product, ProductMeasure, RecipeSummary } from '@/types';
import { localToday } from '@/utils/format';

const props = defineProps<{ diaryId?: number }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();

type RowKind = 'recipe' | 'product';
type DiaryRow = {
  kind: RowKind;
  meal_type: string;
  recipe_id: number;
  servings: string;
  product_id: number;
  quantity: string;
  measurement_name: string;
  comment: string;
};

const loading = ref(false);
const error = ref('');
const entryDate = ref(localToday());
const recipes = ref<RecipeSummary[]>([]);
const products = ref<Product[]>([]);
const measures = ref<ProductMeasure[]>([]);
const rows = ref<DiaryRow[]>([]);

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
      const data = await api.diary();
      const item = data.find((entry) => entry.id === props.diaryId);
      if (item) {
        entryDate.value = item.entry_date;
        rows.value = [rowFromEntry(item)];
      }
    }
    if (!rows.value.length) addRecipeRow('Завтрак');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

function itemPayload(row: DiaryRow) {
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
      await api.post('diary', { entry_date: entryDate.value, items: rows.value.map(itemPayload) });
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
          <select v-else v-model="row.product_id" class="dp" @change="productChanged(row)"><option v-for="product in products" :key="product.id" :value="product.id">{{ product.name }}</option></select>
          <div class="diary-quantity"><input v-if="row.kind === 'recipe'" v-model="row.servings" class="ds" type="number" min="0.25" step="0.25" aria-label="Порций" required><input v-else v-model="row.quantity" class="dq" type="number" min="0.01" step="0.01" aria-label="Количество" required><span v-if="row.kind === 'recipe'">порции</span></div>
          <div class="diary-unit"><select v-if="row.kind === 'product'" v-model="row.measurement_name" class="dmu"><option v-for="measure in measureOptions(row)" :key="measure.measure_name" :value="measure.measure_name">{{ measure.measure_name }}</option></select><span v-else>порция</span></div>
          <input v-model="row.comment" class="dc" placeholder="Комментарий">
          <button type="button" class="remove-diary-row" aria-label="Удалить строку" @click="removeRow(index)">×</button>
        </div>
      </div>

      <div v-if="!props.diaryId" class="diary-add-actions">
        <button type="button" id="add-diary-item" @click="addRecipeRow()">＋ Добавить блюдо</button>
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
</template>

<style lang="scss">
#diary-items {
  margin-bottom: 8px;
}
</style>
