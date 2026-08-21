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
  readOnly?: boolean;
}>();
const emit = defineEmits<{ edit: [id: number]; addCategory: []; add: [] }>();

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
  const sourcePositions: Record<string, [number, number]> = {
    Белковые: [143, 180], Добавки: [333, 180], Зелень: [523, 180], Крупы: [713, 180], Масла: [903, 180], Молочные: [1093, 180],
    Морепродукты: [143, 340], Мясо: [333, 340], Напитки: [523, 340], Овощи: [713, 340], Основа: [903, 340], Перекусы: [1093, 340],
    Рыба: [143, 500], Соусы: [333, 500], Сыры: [523, 500], Фрукты: [713, 500], Хлеб: [903, 500], Ягоды: [1093, 500]
  };
  const [centerX, centerY] = sourcePositions[item] || sourcePositions['Основа'];
  return { '--icon-x': `${x}%`, '--icon-y': `${y}%`, '--sprite-left': `${-(centerX - 29)}px`, '--sprite-top': `${-(centerY - 29)}px` };
}

function productCoverClass(category: string | null) {
  const toneByCategory: Record<string, string> = {
    'Белковые': 'product-cover-tone-3',
    'Добавки': 'product-cover-tone-4',
    'Зелень': 'product-cover-tone-0',
    'Крупы': 'product-cover-tone-1',
    'Масла': 'product-cover-tone-5',
    'Молочные': 'product-cover-tone-4',
    'Морепродукты': 'product-cover-tone-2',
    'Мясо': 'product-cover-tone-3',
    'Напитки': 'product-cover-tone-1',
    'Орехи': 'product-cover-tone-2',
    'Овощи': 'product-cover-tone-0',
    'Основа': 'product-cover-tone-4',
    'Перекусы': 'product-cover-tone-1',
    'Рыба': 'product-cover-tone-5',
    'Соусы': 'product-cover-tone-5',
    'Сыры': 'product-cover-tone-4',
    'Фрукты': 'product-cover-tone-1',
    'Хлеб': 'product-cover-tone-1',
    'Ягоды': 'product-cover-tone-2'
  };
  if (category && toneByCategory[category]) return toneByCategory[category];
  const index = Object.keys(productSpritePositions).indexOf(category || '');
  return `product-cover-tone-${Math.max(0, index) % 6}`;
}

function productCategoryTone(categoryName: string) {
  const index = Object.keys(productSpritePositions).indexOf(categoryName);
  return `product-category-tone-${Math.max(0, index) % 5}`;
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <p class="products-page-subtitle">База продуктов с быстрым добавлением в дневник</p>
    <div class="product-catalog-layout">
    <section class="product-categories" aria-label="Категории продуктов">
      <button type="button" class="product-category-card all" :class="{ active: category === 'all' }" @click="category = 'all'">
        <span class="product-category-photo all-products-photo"></span>
        <span class="product-category-copy"><b>Все продукты</b><small>Полный каталог</small></span>
        <strong>{{ data.length }}</strong>
      </button>
      <button v-if="!props.readOnly" type="button" class="product-category-card add-category-card" @click="emit('addCategory')">
        <span class="product-category-photo">＋</span>
        <span class="product-category-copy"><b>Добавить категорию</b><small>{{ props.isAdmin ? 'Общая коллекция' : 'Личная коллекция' }}</small></span>
      </button>
      <button
        v-for="item in categories"
        :key="item"
        type="button"
        class="product-category-card"
        :class="[productCategoryTone(item), { active: category === item }]"
        :style="productSpriteStyle(item)"
        @click="category = item"
      >
        <span class="product-category-photo product-sprite"></span>
        <span class="product-category-copy"><b>{{ item }}</b><small>Продукты</small></span>
        <strong>{{ counts[item] || 0 }}</strong>
      </button>
    </section>

    <Toolbar class="product-toolbar" v-model:query="query" placeholder="Поиск по названию…" :count-label="`${shown.length} продуктов`" :reset-disabled="!sort.dir" @reset="resetSort">
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

    <div class="product-results-head"><h2>Карточки продуктов</h2><span>{{ shown.length ? '1–' + shown.length : '0' }} из {{ data.length }}</span></div>
    <div id="product-grid" class="product-grid">
      <div class="product-table-head" aria-hidden="true">
        <span>Название</span><span>Категория</span><span>Ккал</span><span>Белки</span><span>Жиры</span><span>Углеводы</span>
      </div>
      <article v-for="item in shown" :key="item.id" class="product-tile" :class="productCoverClass(item.category)" :tabindex="props.isAdmin ? 0 : undefined" :role="props.isAdmin ? 'button' : undefined" :aria-label="props.isAdmin ? `Редактировать продукт ${item.name}` : undefined" @click="props.isAdmin && emit('edit', item.id)" @keydown.enter.prevent="props.isAdmin && emit('edit', item.id)" @keydown.space.prevent="props.isAdmin && emit('edit', item.id)">
        <div class="product-cover" :class="productCoverClass(item.category)">
          <span class="product-cover-label">{{ item.category || 'Продукты' }}</span>
          <span class="product-cover-icon product-sprite" :style="productSpriteStyle(item.category || 'Основа')"></span>
        </div>
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
          <span>{{ fmt(item.price_per_100_or_unit_rsd) }} RSD / {{ basis(item).slice(3) }}</span>
        </div>
        <div v-if="props.isAdmin" class="product-tile-actions">
          <button type="button" class="card-action edit-product" @click.stop="emit('edit', item.id)">Изменить</button>
          <button type="button" class="icon-action danger-icon delete-product" aria-label="Удалить продукт" title="Удалить продукт" @click.stop="remove(item.id)">×</button>
        </div>
      </article>
      <article v-if="!props.readOnly" class="product-add-card" tabindex="0" role="button" @click="emit('add')" @keydown.enter.prevent="emit('add')">
        <span class="product-add-icon">＋</span><span><b>Добавить продукт</b><small>Создайте продукт с КБЖУ и стоимостью упаковки</small></span><button type="button" class="primary" @click.stop="emit('add')">＋ Новый продукт</button>
      </article>
      <div v-if="!shown.length" class="panel empty">Ничего не найдено</div>
    </div>
    </div>
  </template>
</template>

<style lang="scss">
.product-categories button {
  font: inherit;
}
</style>
