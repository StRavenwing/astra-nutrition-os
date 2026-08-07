<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { workoutIcons } from '@/constants';
import type { SortState, WorkoutEntry } from '@/types';
import { compareValues, formatDate, fmt, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';

const props = defineProps<{
  refreshKey: number;
  isAdmin: boolean;
}>();
const emit = defineEmits<{
  edit: [id: number];
  addExercise: [];
  manageExercises: [];
}>();

const data = ref<WorkoutEntry[]>([]);
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
    data.value = await api.workouts();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const counts = computed(() => data.value.reduce<Record<string, number>>((acc, item) => {
  const key = item.muscle_group || 'Другое';
  acc[key] = (acc[key] || 0) + 1;
  return acc;
}, {}));

const categories = computed(() => Object.keys(counts.value).sort((a, b) => a.localeCompare(b, 'ru')));
const shown = computed(() => {
  let items = data.value.filter((item) => (category.value === 'all' || (item.muscle_group || 'Другое') === category.value) && searchable(item, query.value));
  if (sort.value.dir && sort.value.key) items = [...items].sort((a, b) => compareValues(a[sort.value.key!], b[sort.value.key!]) * sort.value.dir);
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

async function remove(id: number) {
  if (!confirm('Удалить запись тренировки? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`workouts/${id}`);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <div v-if="props.isAdmin" class="exercise-toolbar">
      <div>
        <span class="eyebrow">СПРАВОЧНИК</span>
        <b>Управление упражнениями</b>
      </div>
      <div>
        <button type="button" id="quick-add-exercise" @click="emit('addExercise')">＋ Добавить упражнение</button>
        <button type="button" id="manage-exercises" @click="emit('manageExercises')">Все упражнения</button>
      </div>
    </div>

    <section class="workout-categories" aria-label="Группы тренировок">
      <button type="button" class="workout-category-card all" :class="{ active: category === 'all' }" @click="category = 'all'">
        <span class="workout-category-icon">⚡</span>
        <span><b>Все тренировки</b><small>Полный журнал</small></span>
        <strong>{{ data.length }}</strong>
      </button>
      <button v-for="item in categories" :key="item" type="button" class="workout-category-card" :class="{ active: category === item }" @click="category = item">
        <span class="workout-category-icon">{{ workoutIcons[item] || '○' }}</span>
        <span><b>{{ item }}</b><small>Мышечная группа</small></span>
        <strong>{{ counts[item] }}</strong>
      </button>
    </section>

    <Toolbar v-model:query="query" placeholder="Поиск тренировки…" :count-label="`Записей: ${shown.length}`" :reset-disabled="!sort.dir" @reset="resetSort">
      <select id="workout-order" :value="orderValue" aria-label="Сортировка тренировок" @change="setOrder(($event.target as HTMLSelectElement).value)">
        <option value="">Сначала новые</option>
        <option value="performed_at:1">Дата: сначала старые</option>
        <option value="performed_at:-1">Дата: сначала новые</option>
        <option value="name:1">Название: А–Я</option>
        <option value="name:-1">Название: Я–А</option>
        <option value="working_weight:1">Вес: меньше</option>
        <option value="working_weight:-1">Вес: больше</option>
        <option value="sets:1">Подходы: меньше</option>
        <option value="sets:-1">Подходы: больше</option>
        <option value="reps:1">Повторы: меньше</option>
        <option value="reps:-1">Повторы: больше</option>
      </select>
    </Toolbar>

    <div class="workout-grid">
      <article v-for="item in shown" :key="item.id" class="workout-tile">
        <div class="workout-tile-head">
          <span class="workout-date">{{ formatDate(item.performed_at) }}</span>
          <span class="workout-group">{{ item.muscle_group || 'Другое' }}</span>
        </div>
        <h3>{{ item.name }}</h3>
        <p>{{ item.machine_location || 'Тренажёр не указан' }}<template v-if="item.comment"> · {{ item.comment }}</template></p>
        <div class="workout-stats">
          <span><b>{{ fmt(item.working_weight) }}</b><small>{{ item.default_unit || 'кг' }}</small></span>
          <span><b>{{ fmt(item.sets) }}</b><small>подхода</small></span>
          <span><b>{{ fmt(item.reps) }}</b><small>повторов</small></span>
          <span><b>{{ item.rir || '—' }}</b><small>RIR</small></span>
        </div>
        <div class="workout-tile-actions">
          <button type="button" class="edit-workout" @click="emit('edit', item.id)">✎ Редактировать</button>
          <button type="button" class="delete-workout" @click="remove(item.id)">Удалить</button>
        </div>
      </article>
      <div v-if="!shown.length" class="panel empty">Ничего не найдено</div>
    </div>
  </template>
</template>

<style lang="scss">
.workout-grid {
  margin-top: 0;
}
</style>
