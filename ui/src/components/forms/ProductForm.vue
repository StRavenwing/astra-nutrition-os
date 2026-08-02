<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { productCategoryOptions, productStatusOptions, productUnitOptions } from '@/constants';
import { api } from '@/api/client';
import type { ProductMeasure } from '@/types';

const props = defineProps<{ productId?: string }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();

const loading = ref(false);
const error = ref('');
const measures = ref<ProductMeasure[]>([]);
const form = reactive<Record<string, string>>({
  product_id: 'Автоматически: P-…',
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
  data_status: productStatusOptions[0],
  note: '',
  teaspoon_base_quantity: '',
  tablespoon_base_quantity: '',
  cup_base_quantity: ''
});

const measureSupported = computed(() => form.unit === 'г' || form.unit === 'мл');
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
    if (props.productId) {
      const [products, allMeasures] = await Promise.all([api.products(), api.productMeasures()]);
      const product = products.find((item) => item.product_id === props.productId);
      if (product) {
        for (const [key, value] of Object.entries(product)) {
          if (key in form) form[key] = value == null ? '' : String(value);
        }
        automaticKcal = form.kcal === '';
      }
      measures.value = allMeasures.filter((item) => item.product_id === props.productId);
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
  delete data.product_id;
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
      <div class="grid">
        <div class="field"><label>ID продукта</label><input v-model="form.product_id" readonly tabindex="-1"></div>
        <div class="field"><label>Название</label><input v-model="form.name" required></div>
        <div class="field"><label>Категория</label><select v-model="form.category"><option v-for="item in productCategoryOptions" :key="item">{{ item }}</option></select></div>
        <div class="field"><label>Единица</label><select v-model="form.unit"><option v-for="item in productUnitOptions" :key="item">{{ item }}</option></select></div>
        <div class="field"><label>Цена упаковки</label><input v-model="form.package_price_rsd" type="number" min="0" step="0.01"></div>
        <div class="field"><label>Размер упаковки</label><input v-model="form.package_size" type="number" min="0.01" step="0.01"></div>
        <div class="field"><label>{{ measureSupported ? `Цена за 100 ${form.unit}` : `Цена за 1 ${form.unit}` }}</label><input v-model="form.price_per_100_or_unit_rsd" type="number" step="0.01" readonly tabindex="-1"></div>
        <div class="field"><label>Ккал</label><input v-model="form.kcal" type="number" step="0.01" placeholder="Рассчитается по БЖУ" @input="automaticKcal = form.kcal === ''; calculateKcal()"></div>
        <div class="field"><label>Белки</label><input v-model="form.protein_g" type="number" step="0.01" required></div>
        <div class="field"><label>Жиры</label><input v-model="form.fat_g" type="number" step="0.01" required></div>
        <div class="field"><label>Углеводы</label><input v-model="form.carbs_g" type="number" step="0.01" required></div>
        <div class="field"><label>Статус данных</label><select v-model="form.data_status"><option v-for="item in productStatusOptions" :key="item">{{ item }}</option></select></div>
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
</style>
