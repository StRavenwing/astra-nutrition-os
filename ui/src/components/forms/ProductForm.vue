<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { productCategoryOptions, productUnitOptions } from '@/constants';
import { api } from '@/api/client';
import type { ProductMeasure } from '@/types';

const props = defineProps<{ productId?: number }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();

const loading = ref(false);
const error = ref('');
const scanning = ref(false);
const scanMessage = ref('');
const scanError = ref('');
const scanInput = ref<HTMLInputElement | null>(null);
const measures = ref<ProductMeasure[]>([]);
const categories = ref<string[]>([]);
const form = reactive<Record<string, string>>({
  code: 'Автоматически: P-…',
  name: '',
  category: productCategoryOptions[0],
  unit: 'г',
  package_price_rsd: '',
  package_size: '',
  price_per_100_or_unit_rsd: '',
  kcal: '',
  protein_g: '',
  fat_g: '',
  carbs_g: '',
  note: '',
  teaspoon_base_quantity: '',
  tablespoon_base_quantity: '',
  cup_base_quantity: ''
});

const measureSupported = computed(() => form.unit === 'г' || form.unit === 'мл');
const categoryOptions = computed(() => [...new Set([...productCategoryOptions, ...categories.value])]);
const cupName = computed(() => `стакан (200 ${form.unit})`);
const title = computed(() => (props.productId ? 'Редактировать продукт' : 'Добавить продукт'));

function measureMap(list: ProductMeasure[]) {
  return Object.fromEntries(list.map((item) => [item.measure_name, String(item.base_quantity)]));
}

function syncMeasures() {
  if (!measureSupported.value) return;
  const current = measureMap(measures.value);
  if (!form.teaspoon_base_quantity) form.teaspoon_base_quantity = current['ч. л.'] || '5';
  if (!form.tablespoon_base_quantity) form.tablespoon_base_quantity = current['ст. л.'] || '15';
  if (!form.cup_base_quantity) form.cup_base_quantity = current[cupName.value] || '200';
}

function calculatePrice() {
  const packagePrice = Number(form.package_price_rsd);
  const packageSize = Number(form.package_size);
  if (form.package_price_rsd !== '' && form.package_size !== '' && packageSize > 0) {
    const multiplier = measureSupported.value ? 100 : 1;
    form.price_per_100_or_unit_rsd = (packagePrice / packageSize * multiplier).toFixed(2);
  }
}

let automaticKcal = true;
function calculateKcal() {
  if (!automaticKcal) return;
  form.kcal = ((Number(form.protein_g) || 0) * 4 + (Number(form.fat_g) || 0) * 9 + (Number(form.carbs_g) || 0) * 4)
    .toFixed(2)
    .replace(/\.00$/, '');
}

function scanValue(value: number | null) {
  if (value == null) return '';
  return String(Number(value.toFixed(2)));
}

function scanSummary() {
  const values = [
    form.kcal ? `${form.kcal} ккал` : '',
    form.protein_g ? `${form.protein_g} Б` : '',
    form.fat_g ? `${form.fat_g} Ж` : '',
    form.carbs_g ? `${form.carbs_g} У` : ''
  ].filter(Boolean);
  return values.length ? values.join(' · ') : 'Значения не найдены';
}

watch(() => [form.package_price_rsd, form.package_size, form.unit], calculatePrice);
watch(() => [form.protein_g, form.fat_g, form.carbs_g], calculateKcal);
watch(() => form.unit, () => {
  form.teaspoon_base_quantity = '';
  form.tablespoon_base_quantity = '';
  form.cup_base_quantity = '';
  syncMeasures();
});

onMounted(async () => {
  loading.value = true;
  try {
    categories.value = (await api.categories('product')).map((item) => item.name);
    if (props.productId) {
      const products = await api.products();
      const product = products.find((item) => item.id === props.productId);
      if (product) {
        for (const [key, value] of Object.entries(product)) {
          if (key in form && key !== 'measures') form[key] = value == null ? '' : String(value);
        }
        automaticKcal = form.kcal === '';
        measures.value = product.measures || [];
      }
    }
    syncMeasures();
    calculatePrice();
    calculateKcal();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

function payload() {
  const data: Record<string, unknown> = { ...form };
  if (measureSupported.value) {
    data.measures = [
      { measure_name: 'ч. л.', base_quantity: form.teaspoon_base_quantity },
      { measure_name: 'ст. л.', base_quantity: form.tablespoon_base_quantity },
      { measure_name: cupName.value, base_quantity: form.cup_base_quantity }
    ];
  } else {
    data.measures = [];
  }
  delete data.code;
  delete data.teaspoon_base_quantity;
  delete data.tablespoon_base_quantity;
  delete data.cup_base_quantity;
  return data;
}

async function save() {
  error.value = '';
  try {
    if (props.productId) await api.put(`products/${props.productId}`, payload());
    else await api.post('products', payload());
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

async function scanNutrition(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;

  scanError.value = '';
  scanMessage.value = '';
  scanning.value = true;
  try {
    const result = await api.scanProductNutrition(file);
    if (result.kcal != null) {
      form.kcal = scanValue(result.kcal);
      automaticKcal = false;
    }
    if (result.protein_g != null) form.protein_g = scanValue(result.protein_g);
    if (result.fat_g != null) form.fat_g = scanValue(result.fat_g);
    if (result.carbs_g != null) form.carbs_g = scanValue(result.carbs_g);
    if (result.kcal == null) calculateKcal();
    scanMessage.value = `${scanSummary()} · ${Math.round(result.confidence * 100)}%`;
    if (result.warnings.length) scanMessage.value += ` · ${result.warnings[0]}`;
  } catch (err) {
    scanError.value = err instanceof Error ? err.message : String(err);
  } finally {
    scanning.value = false;
    input.value = '';
  }
}

async function remove() {
  if (!props.productId || !confirm('Удалить продукт? Это действие нельзя отменить.')) return;
  error.value = '';
  try {
    await api.delete(`products/${props.productId}`);
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
      <section v-if="!props.productId" class="product-scan-fields">
        <div class="product-scan-head">
          <div>
            <p class="eyebrow">СКАН УПАКОВКИ</p>
            <h3>КБЖУ с этикетки</h3>
          </div>
          <button type="button" class="scan-button" :disabled="scanning" @click="scanInput?.click()">
            {{ scanning ? 'Сканирование…' : 'Выбрать фото' }}
          </button>
        </div>
        <input
          ref="scanInput"
          class="product-scan-input"
          type="file"
          accept="image/*"
          capture="environment"
          @change="scanNutrition"
        >
        <p v-if="scanMessage" class="scan-status">{{ scanMessage }}</p>
        <p v-if="scanError" class="scan-status error">{{ scanError }}</p>
      </section>

      <div class="grid">
        <div class="field"><label>ID продукта</label><input v-model="form.code" readonly tabindex="-1"></div>
        <div class="field"><label>Название</label><input v-model="form.name" required></div>
        <div class="field"><label>Категория</label><select v-model="form.category"><option v-for="item in categoryOptions" :key="item">{{ item }}</option></select></div>
        <div class="field"><label>Единица</label><select v-model="form.unit"><option v-for="item in productUnitOptions" :key="item">{{ item }}</option></select></div>
        <div class="field"><label>Цена упаковки</label><input v-model="form.package_price_rsd" type="number" min="0" step="0.01"></div>
        <div class="field"><label>Размер упаковки</label><input v-model="form.package_size" type="number" min="0.01" step="0.01"></div>
        <div class="field"><label>{{ measureSupported ? `Цена за 100 ${form.unit}` : `Цена за 1 ${form.unit}` }}</label><input v-model="form.price_per_100_or_unit_rsd" type="number" step="0.01" readonly tabindex="-1"></div>
        <div class="field"><label>Ккал</label><input v-model="form.kcal" type="number" step="0.01" placeholder="Рассчитается по БЖУ" @input="automaticKcal = form.kcal === ''; calculateKcal()"></div>
        <div class="field"><label>Белки</label><input v-model="form.protein_g" type="number" step="0.01" required></div>
        <div class="field"><label>Жиры</label><input v-model="form.fat_g" type="number" step="0.01" required></div>
        <div class="field"><label>Углеводы</label><input v-model="form.carbs_g" type="number" step="0.01" required></div>
        <div class="field full"><label>Примечание</label><input v-model="form.note"></div>
      </div>

      <section v-if="measureSupported" class="product-measure-fields">
        <div class="product-measure-head">
          <div>
            <p class="eyebrow">ДОМАШНИЕ МЕРЫ</p>
            <h3>Вес или объём одной меры</h3>
          </div>
          <small>Можно изменить для конкретного продукта</small>
        </div>
        <div class="grid">
          <div class="field"><label>1 ч. л. — количество, {{ form.unit }}</label><input v-model="form.teaspoon_base_quantity" type="number" min="0.01" step="0.01"></div>
          <div class="field"><label>1 ст. л. — количество, {{ form.unit }}</label><input v-model="form.tablespoon_base_quantity" type="number" min="0.01" step="0.01"></div>
          <div class="field full"><label>1 стакан — количество, {{ form.unit }}</label><input v-model="form.cup_base_quantity" type="number" min="0.01" step="0.01"></div>
        </div>
        <p class="subtle">Для жидкостей: 1 ч. л. = 5 мл, 1 ст. л. = 15 мл. Для продуктов в граммах значения являются оценочными и их можно уточнить.</p>
      </section>

      <div v-if="props.productId" class="destructive-zone">
        <button type="button" class="danger-button" @click="remove">Удалить продукт</button>
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
.modal-form-body {
  margin: 0;
}

.product-scan-fields {
  margin-bottom: 17px;
  padding: 14px;
  border: 1px solid #b9d8ce;
  border-radius: 13px;
  background: #f5fbf8;
}

.product-scan-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;

  h3 {
    margin: 0;
    font-size: 15px;
  }
}

.product-scan-input {
  display: none;
}

.scan-button {
  border: 0;
  border-radius: 8px;
  background: #176f5c;
  color: #fff;
  cursor: pointer;
  font-weight: 800;
  padding: 9px 13px;

  &:disabled {
    cursor: wait;
    opacity: .72;
  }
}

.scan-status {
  color: #246554;
  font-size: 12px;
  font-weight: 700;
  margin: 10px 0 0;

  &.error {
    color: #c43b3b;
  }
}
</style>
