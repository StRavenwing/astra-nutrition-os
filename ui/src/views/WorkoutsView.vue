<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { workoutIcons } from '@/constants';
import type { SortState, WorkoutEntry, WorkoutPlan } from '@/types';
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
  build: [];
  repeat: [plan: WorkoutPlan];
}>();

const data = ref<WorkoutEntry[]>([]);
const loading = ref(false);
const error = ref('');
const category = ref('all');
const query = ref('');
const sort = ref<SortState>({ key: null, dir: 0 });
const orderValue = ref('');
const plans = ref<WorkoutPlan[]>([]);
const section = ref<'workouts' | 'archive'>('workouts');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const [workouts, workoutPlans] = await Promise.all([api.workouts(), api.workoutPlans()]);
    data.value = workouts;
    plans.value = workoutPlans;
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

const activePlans = computed(() => plans.value.filter((plan) => plan.status === 'planned'));
const archivedPlans = computed(() => plans.value.filter((plan) => plan.status === 'archived'));

function planSummary(plan: WorkoutPlan) {
  return plan.items.map((item) => item.name).join(' · ');
}

function planMetric(item: WorkoutPlan['items'][number]) {
  const values = [];
  if (item.working_weight != null) values.push(`${fmt(item.working_weight)} ${item.default_unit || 'кг'}`);
  if (item.sets != null) values.push(`${item.sets} подх.`);
  if (item.duration_minutes != null) values.push(`${item.duration_minutes} мин`);
  if (item.speed_kmh != null) values.push(`${fmt(item.speed_kmh)} км/ч`);
  return values.join(' · ') || 'Параметры не заданы';
}

async function completePlan(id: number) {
  try {
    await api.completeWorkoutPlan(id);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

async function cancelPlan(id: number) {
  if (!confirm('Отменить собранную тренировку?')) return;
  try {
    await api.cancelWorkoutPlan(id);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
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
    <section class="workout-menu" aria-label="Разделы тренировок">
      <button type="button" class="workout-menu-card" :class="{ active: section === 'workouts' }" @click="section = 'workouts'">
        <span class="workout-menu-icon">🏋️</span>
        <span><b>Упражнения и тренировки</b><small>Справочник и журнал занятий</small></span>
        <strong>{{ data.length }}</strong>
      </button>
      <button type="button" class="workout-menu-card archive" :class="{ active: section === 'archive' }" @click="section = 'archive'">
        <span class="workout-menu-icon">📦</span>
        <span><b>Архив тренировок</b><small>Выполненные занятия и повторение</small></span>
        <strong>{{ archivedPlans.length }}</strong>
      </button>
    </section>

    <section v-if="activePlans.length" class="planned-workouts">
      <div class="section-heading"><div><span class="eyebrow">ЗАКРЕПЛЕНО СВЕРХУ</span><h2>Тренировка в плане</h2></div><button type="button" class="primary" @click="emit('build')">＋ Собрать тренировку</button></div>
      <article v-for="plan in activePlans" :key="plan.id" class="planned-workout-card">
        <div class="planned-workout-head"><div><span class="planned-badge">Запланировано</span><h3>{{ formatDate(plan.scheduled_at) }}</h3><p>{{ planSummary(plan) }}</p></div><div class="planned-actions"><button type="button" class="cancel-plan" @click="cancelPlan(plan.id)">Отменить</button><button type="button" class="complete-plan" @click="completePlan(plan.id)">Выполнено</button></div></div>
        <div class="planned-items"><div v-for="item in plan.items" :key="item.id || item.exercise_id"><b>{{ item.name }}</b><span>{{ planMetric(item) }}</span></div></div>
      </article>
    </section>

    <section v-if="section === 'archive'" class="archive-section">
      <div class="section-heading"><div><span class="eyebrow">ИСТОРИЯ</span><h2>Архив тренировок</h2></div><button type="button" class="primary" @click="emit('build')">＋ Собрать тренировку</button></div>
      <div class="archive-grid">
        <article v-for="plan in archivedPlans" :key="plan.id" class="archive-card">
          <div class="archive-card-head"><span>{{ formatDate(plan.scheduled_at) }}</span><span class="archive-badge">Выполнено</span></div>
          <h3>Тренировка</h3>
          <p>{{ planSummary(plan) }}</p>
          <div class="archive-items"><div v-for="item in plan.items" :key="item.id || item.exercise_id"><b>{{ item.name }}</b><small>{{ planMetric(item) }}</small></div></div>
          <button type="button" class="repeat-plan" @click="emit('repeat', plan)">↻ Повторить</button>
        </article>
        <div v-if="!archivedPlans.length" class="panel empty">Выполненные собранные тренировки появятся здесь.</div>
      </div>
    </section>

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
</template>

<style lang="scss">
.workout-menu {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-bottom: 22px;
}

.workout-menu-card {
  display: grid;
  grid-template-columns: 48px 1fr auto;
  gap: 12px;
  align-items: center;
  min-height: 94px;
  padding: 15px;
  border: 1px solid var(--line);
  border-radius: 15px;
  background: linear-gradient(135deg, #fff, #f4f1ff);
  color: var(--ink);
  text-align: left;
  box-shadow: 0 2px 5px #091e4214;
  cursor: pointer;
  transition: transform .18s ease, border-color .18s ease, box-shadow .18s ease;

  &:hover,
  &.active {
    border-color: var(--purple);
    box-shadow: 0 0 0 2px #6e5dc626, 0 9px 24px #091e4218;
    transform: translateY(-2px);
  }

  &.archive {
    background: linear-gradient(135deg, #fff, #eef7ff);

    &:hover,
    &.active {
      border-color: var(--blue);
      box-shadow: 0 0 0 2px #0c66e426, 0 9px 24px #091e4218;
    }
  }

  b,
  small {
    display: block;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 10px;
  }

  strong {
    align-self: start;
    padding: 3px 8px;
    border-radius: 99px;
    background: #fff;
    color: var(--blue);
    font-size: 12px;
  }
}

.workout-menu-icon {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 13px;
  background: linear-gradient(135deg, #e9ddff, #d9e7fd);
  font-size: 23px;
}

.planned-workouts,
.archive-section {
  margin-bottom: 23px;
}

.section-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 12px;

  h2 {
    font-size: 22px;
  }
}

.planned-workout-card {
  padding: 18px;
  border: 1px solid #9f8fef;
  border-radius: 16px;
  background: linear-gradient(135deg, #fff, #f4f1ff 60%, #edf7ff);
  box-shadow: 0 9px 25px #091e4220;
}

.planned-workout-head {
  display: flex;
  justify-content: space-between;
  gap: 14px;

  h3 {
    margin: 7px 0 2px;
    font-size: 21px;
  }

  p {
    margin: 0;
    color: var(--muted);
    font-size: 12px;
  }
}

.planned-badge,
.archive-badge {
  display: inline-block;
  padding: 4px 8px;
  border-radius: 99px;
  background: #e9ddff;
  color: #5e4db2;
  font-size: 10px;
  font-weight: 850;
  text-transform: uppercase;
}

.planned-actions {
  display: flex;
  align-items: flex-start;
  gap: 8px;

  button,
  .repeat-plan {
    border-radius: 8px;
    padding: 9px 12px;
    font-size: 11px;
    font-weight: 800;
    cursor: pointer;
  }
}

.cancel-plan {
  border: 1px solid #f5a79b;
  background: #ffebe6;
  color: #ae2a19;
}

.complete-plan {
  border: 0;
  background: var(--green);
  color: #fff;
}

.planned-items {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 8px;
  margin-top: 16px;

  div {
    padding: 10px 11px;
    border: 1px solid #ffffffc4;
    border-radius: 10px;
    background: #ffffffa8;
  }

  b,
  span {
    display: block;
  }

  span {
    margin-top: 3px;
    color: var(--muted);
    font-size: 10px;
  }
}

.archive-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(255px, 1fr));
  gap: 14px;
}

.archive-card {
  display: flex;
  flex-direction: column;
  min-height: 230px;
  padding: 17px;
  border: 1px solid var(--line);
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 2px 5px #091e4214;

  h3 {
    margin: 12px 0 4px;
    font-size: 18px;
  }

  > p {
    min-height: 32px;
    margin: 0;
    color: var(--muted);
    font-size: 11px;
  }
}

.archive-card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  color: var(--muted);
  font-size: 12px;
  font-weight: 800;
}

.archive-badge {
  background: #e3fcef;
  color: #216e4e;
}

.archive-items {
  display: grid;
  gap: 6px;
  margin-top: 10px;

  div {
    padding: 7px 9px;
    border-radius: 8px;
    background: #f7f8fa;
  }

  b,
  small {
    display: block;
  }

  small {
    margin-top: 2px;
    color: var(--muted);
    font-size: 10px;
  }
}

.repeat-plan {
  width: 100%;
  margin-top: auto;
  border: 1px solid #85b8ff;
  border-radius: 8px;
  padding: 9px 12px;
  background: #e9f2ff;
  color: var(--blue);
  font-weight: 800;
  cursor: pointer;
}

.workout-grid {
  margin-top: 0;
}

@media (max-width: 700px) {
  .workout-menu {
    grid-template-columns: 1fr;
  }

  .section-heading,
  .planned-workout-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .planned-actions {
    width: 100%;

    button {
      flex: 1;
    }
  }
}
</style>
