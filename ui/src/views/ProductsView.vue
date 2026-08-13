<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { productSpritePositions } from '@/constants';
import type { Product, SortState } from '@/types';
import { compareValues, fmt, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';

const props = defineProps<{
  refreshKey: number;
  isAdmin: boolean;
}>();
const emit = defineEmits<{ edit: [id: number]; addCategory: [] }>();

const data = ref<Product[]>([]);
const loading = ref(false);
const error = ref('');
const category = ref('all');
const query = ref('');
const sort = ref<SortState>({ key: null, dir: 0 });
const orderValue = ref('');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    data.value = await api.products();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const counts = computed(() => data.value.reduce<Record<string, number>>((acc, item) => {
  const key = item.category || 'Без категории';
  acc[key] = (acc[key] || 0) + 1;
  return acc;
}, {}));

const categories = computed(() => [...new Set(['Фрукты', ...Object.keys(counts.value)])].sort((a, b) => a.localeCompare(b, 'ru')));

const shown = computed(() => {
  let items = data.value.filter((item) => (category.value === 'all' || item.category === category.value) && searchable(item, query.value));
  if (sort.value.dir && sort.value.key) {
    items = [...items].sort((a, b) => compareValues(a[sort.value.key!], b[sort.value.key!]) * sort.value.dir);
  }
  return items;
});

function basis(item: Product) {
  if (item.unit === 'г') return 'на 100 г';
  if (item.unit === 'мл') return 'на 100 мл';
  return `на 1 ${item.unit || 'ед.'}`;
}

function setOrder(value: string) {
  orderValue.value = value;
  if (!value) sort.value = { key: null, dir: 0 };
  else {
    const [key, dir] = value.split(':');
    sort.value = { key, dir: Number(dir) as 1 | -1 };
  }
}

function resetSort() {
  sort.value = { key: null, dir: 0 };
  orderValue.value = '';
}

async function remove(id: number) {
  if (!confirm('Удалить продукт? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`products/${id}`);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

function productSpriteStyle(item: string) {
  const [x, y] = productSpritePositions[item] || productSpritePositions['Основа'];
  return { '--icon-x': `${x}%`, '--icon-y': `${y}%` };
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <section class="product-categories" aria-label="Категории продуктов">
      <button type="button" class="product-category-card all" :class="{ active: category === 'all' }" @click="category = 'all'">
        <span class="product-category-photo all-products-photo"></span>
        <span class="product-category-copy"><b>Все продукты</b><small>Полный каталог</small></span>
        <strong>{{ data.length }}</strong>
      </button>
      <button type="button" class="product-category-card add-category-card" @click="emit('addCategory')">
        <span class="product-category-photo">＋</span>
        <span class="product-category-copy"><b>Добавить категорию</b><small>{{ props.isAdmin ? 'Общая коллекция' : 'Личная коллекция' }}</small></span>
      </button>
      <button
        v-for="item in categories"
        :key="item"
        type="button"
        class="product-category-card"
        :class="{ active: category === item }"
        :style="productSpriteStyle(item)"
        @click="category = item"
      >
        <span class="product-category-photo product-sprite"></span>
        <span class="product-category-copy"><b>{{ item }}</b><small>Продукты</small></span>
        <strong>{{ counts[item] || 0 }}</strong>
      </button>
    </section>

    <Toolbar v-model:query="query" placeholder="Поиск продукта…" :count-label="`Продуктов: ${shown.length}`" :reset-disabled="!sort.dir" @reset="resetSort">
      <select id="product-order" :value="orderValue" aria-label="Сортировка продуктов" @change="setOrder(($event.target as HTMLSelectElement).value)">
        <option value="">Исходный порядок</option>
        <option value="name:1">Название: А–Я</option>
        <option value="name:-1">Название: Я–А</option>
        <option value="category:1">Категория: А–Я</option>
        <option value="kcal:1">Калории: меньше</option>
        <option value="kcal:-1">Калории: больше</option>
        <option value="protein_g:-1">Белок: больше</option>
        <option value="protein_g:1">Белок: меньше</option>
        <option value="fat_g:1">Жиры: меньше</option>
        <option value="fat_g:-1">Жиры: больше</option>
        <option value="carbs_g:1">Углеводы: меньше</option>
        <option value="carbs_g:-1">Углеводы: больше</option>
        <option value="price_per_100_or_unit_rsd:1">Цена: меньше</option>
        <option value="price_per_100_or_unit_rsd:-1">Цена: больше</option>
      </select>
    </Toolbar>

    <div id="product-grid" class="product-grid">
      <article v-for="item in shown" :key="item.id" class="product-tile">
        <div class="product-tile-head">
          <span class="recipe-id">{{ item.code }}</span>
        </div>
        <div class="product-tile-category">{{ item.category || 'Без категории' }}</div>
        <h3>{{ item.name }}</h3>
        <p>{{ basis(item) }}<template v-if="item.note"> · {{ item.note }}</template></p>
        <div class="product-macros">
          <span><b>{{ fmt(item.kcal) }}</b><small>ккал</small></span>
          <span><b>{{ fmt(item.protein_g) }}</b><small>белки</small></span>
          <span><b>{{ fmt(item.fat_g) }}</b><small>жиры</small></span>
          <span><b>{{ fmt(item.carbs_g) }}</b><small>углев.</small></span>
        </div>
        <div class="product-tile-foot">
          <span>{{ item.package_size ? `${fmt(item.package_size)} ${item.unit || ''} в упаковке` : 'Цена за расчётную единицу' }}</span>
          <b>{{ fmt(item.price_per_100_or_unit_rsd) }} RSD</b>
        </div>
        <div v-if="props.isAdmin" class="product-tile-actions">
          <button type="button" class="edit-product" @click="emit('edit', item.id)">✎ Редактировать</button>
          <button type="button" class="delete-product" @click="remove(item.id)">Удалить</button>
        </div>
      </article>
      <div v-if="!shown.length" class="panel empty">Ничего не найдено</div>
    </div>
  </template>
</template>

<style lang="scss">
.product-categories button {
  font: inherit;
}
</style>
