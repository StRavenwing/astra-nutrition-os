<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { idLegend, recipeCategories, recipeCategoryMap } from '@/constants';
import type { RecipeSummary, SortState } from '@/types';
import { compareValues, fmt, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';

const props = defineProps<{ refreshKey: number }>();
const emit = defineEmits<{ openRecipe: [id: number] }>();

const data = ref<RecipeSummary[]>([]);
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
    data.value = await api.recipes();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const counts = computed(() => data.value.reduce<Record<string, number>>((acc, item) => {
  acc[item.category] = (acc[item.category] || 0) + 1;
  return acc;
}, {}));

const visibleCategories = computed(() => recipeCategories.filter((item) => counts.value[item.key]));

const shown = computed(() => {
  let items = data.value.filter((item) => (category.value === 'all' || item.category === category.value) && searchable(item, query.value));
  if (sort.value.dir && sort.value.key) {
    items = [...items].sort((a, b) => compareValues(a[sort.value.key!], b[sort.value.key!]) * sort.value.dir);
  }
  return items;
});

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
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <section class="recipe-categories visual" aria-label="Типы рецептов">
      <button type="button" class="category-card all" :class="{ active: category === 'all' }" @click="category = 'all'">
        <span class="category-photo all-photo"></span>
        <span class="category-copy"><b>Все рецепты</b><small>Полный каталог</small></span>
        <strong>{{ data.length }}</strong>
      </button>
      <button
        v-for="item in visibleCategories"
        :key="item.key"
        type="button"
        class="category-card"
        :class="[`category-${item.key.toLowerCase()}`, { active: category === item.key }]"
        :style="{ '--icon-x': `${item.x}%`, '--icon-y': `${item.y}%` }"
        @click="category = item.key"
      >
        <span class="category-photo recipe-sprite"></span>
        <span class="category-copy"><b>{{ item.label }}</b><small>{{ item.key }}</small></span>
        <strong>{{ counts[item.key] }}</strong>
      </button>
    </section>

    <details class="legend">
      <summary>Что означают ID рецептов?</summary>
      <div>
        <span v-for="(value, key) in idLegend" :key="key"><b>{{ key }}-</b> {{ value }}</span>
      </div>
      <p>Цифры после дефиса — последовательный номер рецепта в категории.</p>
    </details>

    <Toolbar v-model:query="query" :count-label="`Записей: ${shown.length}`" :reset-disabled="!sort.dir" @reset="resetSort">
      <select id="recipe-order" :value="orderValue" aria-label="Сортировка рецептов" @change="setOrder(($event.target as HTMLSelectElement).value)">
        <option value="">Исходный порядок</option>
        <option value="name:1">Название: А–Я</option>
        <option value="name:-1">Название: Я–А</option>
        <option value="category:1">Категория: А–Я</option>
        <option value="status:1">Статус: А–Я</option>
        <option value="version:1">Версия: по возрастанию</option>
        <option value="version:-1">Версия: по убыванию</option>
        <option value="kcal_per_serving:1">Калории: меньше</option>
        <option value="kcal_per_serving:-1">Калории: больше</option>
        <option value="protein_per_serving_g:-1">Белок: больше</option>
        <option value="protein_per_serving_g:1">Белок: меньше</option>
        <option value="cost_per_serving_rsd:1">Цена: меньше</option>
        <option value="cost_per_serving_rsd:-1">Цена: больше</option>
      </select>
    </Toolbar>

    <div id="recipe-grid" class="recipe-grid">
      <article v-for="item in shown" :key="item.id" class="recipe-tile" tabindex="0" title="Открыть рецепт" @click="emit('openRecipe', item.id)" @keydown.enter.prevent="emit('openRecipe', item.id)" @keydown.space.prevent="emit('openRecipe', item.id)">
        <div class="recipe-tile-head">
          <span class="recipe-id">{{ item.code }}</span>
          <span class="pill">{{ item.status }}</span>
        </div>
        <div class="recipe-category">{{ recipeCategoryMap[item.category]?.label || item.category }}</div>
        <h3>{{ item.name }}</h3>
        <p>{{ item.subcategory || item.tags || 'Рецепт из личной коллекции' }}</p>
        <div class="tile-macros">
          <span><b>{{ fmt(item.kcal_per_serving) }}</b><small>ккал</small></span>
          <span><b>{{ fmt(item.protein_per_serving_g) }}</b><small>белки</small></span>
          <span><b>{{ fmt(item.fat_per_serving_g) }}</b><small>жиры</small></span>
          <span><b>{{ fmt(item.carbs_per_serving_g) }}</b><small>углев.</small></span>
        </div>
        <div class="recipe-tile-foot">
          <span>v{{ item.version }}</span>
          <b>{{ fmt(item.cost_per_serving_rsd) }} RSD <small v-if="item.manual_price_per_serving_rsd != null">фикс.</small></b>
        </div>
      </article>
      <div v-if="!shown.length" class="panel empty">Ничего не найдено</div>
    </div>
  </template>
</template>

<style lang="scss">
.recipe-grid {
  margin-top: 0;
}
</style>
