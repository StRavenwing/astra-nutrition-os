<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Exercise, WorkoutComplex, WorkoutPlan } from '@/types';
import { formatDate, fmt } from '@/utils/format';

const props = defineProps<{
  refreshKey: number;
  isAdmin: boolean;
}>();

const emit = defineEmits<{
  edit: [id: number];
  editExercise: [id: number];
  addExercise: [];
  manageExercises: [];
  build: [];
  openPlan: [plan: WorkoutPlan];
  openExercise: [exercise: Exercise];
  buildComplex: [payload: { complex: WorkoutComplex | null; mode: 'create' | 'edit' }];
  editPlan: [plan: WorkoutPlan];
  repeat: [plan: WorkoutPlan];
}>();

const plans = ref<WorkoutPlan[]>([]);
const exercises = ref<Exercise[]>([]);
const workoutComplexes = ref<WorkoutComplex[]>([]);
const loading = ref(false);
const error = ref('');
const section = ref<'none' | 'workouts' | 'exercises' | 'archive'>('none');
const exerciseGroup = ref('all');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const [workoutPlans, exerciseList, complexList] = await Promise.all([api.workoutPlans(), api.exercises(), api.workoutComplexes()]);
    plans.value = workoutPlans;
    exercises.value = exerciseList.sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    workoutComplexes.value = complexList;
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const plannedPlans = computed(() => plans.value.filter((plan) => plan.status === 'planned'));
const archivedPlans = computed(() => plans.value.filter((plan) => plan.status === 'archived' || plan.status === 'canceled'));
const completedPlans = computed(() => plans.value.filter((plan) => plan.status === 'archived'));
const canceledPlans = computed(() => plans.value.filter((plan) => plan.status === 'canceled'));
const workoutCount = computed(() => workoutComplexes.value.length);
const exerciseGroups = computed(() => [...new Set(exercises.value.map((exercise) => exercise.muscle_group || 'Другое'))].sort((a, b) => a.localeCompare(b, 'ru')));
const visibleExercises = computed(() => exercises.value.filter((exercise) => exerciseGroup.value === 'all' || (exercise.muscle_group || 'Другое') === exerciseGroup.value));

function planSummary(plan: WorkoutPlan) {
  return plan.items.map((item) => item.name).join(' · ');
}

function planMetric(item: WorkoutPlan['items'][number]) {
  const values: string[] = [];
  if (item.working_weight != null) values.push(`${fmt(item.working_weight)} ${item.default_unit || 'кг'}`);
  if (item.sets != null) values.push(`${item.sets} подх.`);
  if (item.duration_minutes != null) values.push(`${item.duration_minutes} мин`);
  if (item.speed_kmh != null) values.push(`${fmt(item.speed_kmh)} км/ч`);
  return values.join(' · ') || 'Параметры не заданы';
}

function planStatus(plan: WorkoutPlan) {
  return plan.status === 'canceled' ? 'Отменена' : 'Пройдена';
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
  if (!confirm('Отменить запланированную тренировку? Она попадёт в архив.')) return;
  try {
    await api.cancelWorkoutPlan(id);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

async function removeExercise(id: number) {
  if (!confirm('Удалить упражнение из справочника? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`exercises/${id}`);
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
    <section class="scheduled-workouts">
      <div class="scheduled-workouts-head">
        <div>
          <p class="eyebrow">ПЛАН ТРЕНИРОВОК</p>
          <h2>Запланированные тренировки</h2>
        </div>
        <button type="button" class="primary" @click="emit('build')">＋ Собрать тренировку</button>
      </div>

      <div v-if="plannedPlans.length" class="workout-grid scheduled-grid">
        <article v-for="plan in plannedPlans" :key="plan.id" class="workout-tile planned-plan-tile" tabindex="0" @click="emit('openPlan', plan)" @keydown.enter.prevent="emit('openPlan', plan)" @keydown.space.prevent="emit('openPlan', plan)">
          <button type="button" class="complete-plan workout-complete-action" @click.stop="completePlan(plan.id)">Выполнено</button>
          <div class="workout-tile-head">
            <span class="workout-date">{{ formatDate(plan.scheduled_at) }}</span>
            <span class="workout-group planned-badge">Запланирована</span>
          </div>
          <h3>Тренировка</h3>
          <p>{{ planSummary(plan) }}</p>
          <div class="planned-plan-items">
            <div v-for="item in plan.items" :key="item.id || item.exercise_id">
              <b>{{ item.name }}</b>
              <small>{{ planMetric(item) }}</small>
            </div>
          </div>
          <div class="workout-tile-actions workout-card-actions planned-tile-actions">
            <button type="button" class="edit-workout" @click.stop="emit('editPlan', plan)">✎ Редактировать</button>
            <button type="button" class="delete-workout" @click.stop="cancelPlan(plan.id)">Отменить</button>
          </div>
        </article>
      </div>
      <div v-else class="scheduled-empty">Запланированных тренировок нет</div>
    </section>

    <section class="workout-section-menu" aria-label="Разделы тренировок">
      <button type="button" class="workout-section-tile" :class="{ active: section === 'workouts' }" @click="section = 'workouts'">
        <span class="workout-section-icon">🏋️</span>
        <span><b>Тренировки</b><small>Комплексы и программы</small></span><strong>{{ workoutCount }}</strong>
      </button>
      <button type="button" class="workout-section-tile" :class="{ active: section === 'exercises' }" @click="section = 'exercises'">
        <span class="workout-section-icon">💪</span>
        <span><b>Упражнения</b><small>Справочник упражнений</small></span><strong>{{ exercises.length }}</strong>
      </button>
      <button type="button" class="workout-section-tile archive" :class="{ active: section === 'archive' }" @click="section = 'archive'">
        <span class="workout-section-icon">📦</span>
        <span><b>История тренировок</b><small>Пройденные и отменённые</small></span><strong>{{ archivedPlans.length }}</strong>
      </button>
    </section>

    <section v-if="section === 'workouts'" class="workout-subsection">
      <div class="subsection-heading"><p class="eyebrow">ТРЕНИРОВКИ</p><h2>Комплексы</h2></div>
      <div class="recipe-categories workout-complex-grid">
        <article v-for="complex in workoutComplexes" :key="complex.id" class="category-card workout-complex-card">
          <span class="workout-complex-photo">🏋️</span>
          <span class="category-copy"><b>{{ complex.name }}</b><small>{{ complex.comment || 'Комплекс тренировок' }}</small></span>
          <div class="workout-complex-actions">
            <button v-if="props.isAdmin" type="button" class="create-complex-button" @click="emit('buildComplex', { complex: null, mode: 'create' })">＋ Создать тренировку</button>
            <button v-if="props.isAdmin" type="button" class="edit-complex-button" @click="emit('buildComplex', { complex, mode: 'edit' })">✎ Редактировать</button>
          </div>
        </article>
      </div>
    </section>

    <section v-else-if="section === 'exercises'" class="workout-subsection">
      <div class="subsection-heading">
        <div><p class="eyebrow">СПРАВОЧНИК</p><h2>Упражнения</h2></div>
        <div v-if="props.isAdmin" class="exercise-actions"><button type="button" class="secondary-button" @click="emit('addExercise')">＋ Добавить</button><button type="button" class="secondary-button" @click="emit('manageExercises')">Управление</button></div>
      </div>
      <div class="exercise-categories" aria-label="Категории упражнений по группе мышц">
        <button type="button" class="exercise-category-card" :class="{ active: exerciseGroup === 'all' }" @click="exerciseGroup = 'all'"><span><b>Все группы</b><small>Все упражнения</small></span><strong>{{ exercises.length }}</strong></button>
        <button v-for="group in exerciseGroups" :key="group" type="button" class="exercise-category-card" :class="{ active: exerciseGroup === group }" @click="exerciseGroup = group"><span><b>{{ group }}</b><small>Группа мышц</small></span><strong>{{ exercises.filter((item) => (item.muscle_group || 'Другое') === group).length }}</strong></button>
      </div>
      <div class="exercise-grid">
        <article v-for="exercise in visibleExercises" :key="exercise.id" class="workout-tile exercise-card" tabindex="0" @click="emit('openExercise', exercise)" @keydown.enter.prevent="emit('openExercise', exercise)" @keydown.space.prevent="emit('openExercise', exercise)">
          <div class="workout-tile-head"><span class="workout-group">{{ exercise.muscle_group || 'Другое' }}</span><span class="exercise-code">{{ exercise.code }}</span></div>
          <h3>{{ exercise.name }}</h3>
          <p>{{ exercise.description || exercise.note || 'Описание упражнения пока не добавлено' }}</p>
          <div v-if="exercise.photos?.length || exercise.video" class="exercise-media-strip">
            <img v-if="exercise.photos?.[0]" :src="exercise.photos[0]" alt="Фото упражнения">
            <span v-if="exercise.photos?.length">Фото: {{ exercise.photos.length }}</span>
            <span v-if="exercise.video">Видео</span>
          </div>
          <div v-if="props.isAdmin" class="workout-tile-actions workout-card-actions exercise-card-actions">
            <button type="button" class="edit-workout" @click.stop="emit('editExercise', exercise.id)">✎ Редактировать</button>
            <button type="button" class="delete-workout" @click.stop="removeExercise(exercise.id)">Удалить</button>
          </div>
        </article>
        <div v-if="!visibleExercises.length" class="panel empty">Упражнений в этой группе пока нет</div>
      </div>
    </section>

    <section v-else-if="section === 'archive'" class="workout-subsection">
      <div class="subsection-heading"><p class="eyebrow">ИСТОРИЯ</p><h2>История тренировок</h2></div>
      <div class="archive-group">
        <div class="archive-group-head"><div><p class="eyebrow">ЗАВЕРШЕНО</p><h3>Пройденные тренировки</h3></div><span class="subtle">{{ completedPlans.length }}</span></div>
        <div class="workout-grid archive-workout-grid">
        <article v-for="plan in completedPlans" :key="plan.id" class="workout-tile archive-plan-tile" tabindex="0" @click="emit('openPlan', plan)" @keydown.enter.prevent="emit('openPlan', plan)" @keydown.space.prevent="emit('openPlan', plan)">
          <div class="workout-tile-head"><span class="workout-date">{{ formatDate(plan.scheduled_at) }}</span><span class="workout-group" :class="plan.status === 'canceled' ? 'canceled-badge' : 'completed-badge'">{{ planStatus(plan) }}</span></div>
          <h3>Тренировка</h3>
          <p>{{ planSummary(plan) }}</p>
          <div class="planned-plan-items"><div v-for="item in plan.items" :key="item.id || item.exercise_id"><b>{{ item.name }}</b><small>{{ planMetric(item) }}</small></div></div>
          <div class="workout-tile-actions workout-card-actions"><button type="button" class="edit-workout" @click.stop="emit('repeat', plan)">↻ Повторить</button></div>
        </article>
        <div v-if="!completedPlans.length" class="panel empty">Пройденных тренировок пока нет</div>
        </div>
      </div>
      <div class="archive-group canceled-archive-group">
        <div class="archive-group-head"><div><p class="eyebrow">ОТМЕНЕНО</p><h3>Отменённые тренировки</h3></div><span class="subtle">{{ canceledPlans.length }}</span></div>
        <div class="workout-grid archive-workout-grid">
        <article v-for="plan in canceledPlans" :key="plan.id" class="workout-tile archive-plan-tile" tabindex="0" @click="emit('openPlan', plan)" @keydown.enter.prevent="emit('openPlan', plan)" @keydown.space.prevent="emit('openPlan', plan)">
          <div class="workout-tile-head"><span class="workout-date">{{ formatDate(plan.scheduled_at) }}</span><span class="workout-group canceled-badge">Отменена</span></div>
          <h3>Тренировка</h3>
          <p>{{ planSummary(plan) }}</p>
          <div class="planned-plan-items"><div v-for="item in plan.items" :key="item.id || item.exercise_id"><b>{{ item.name }}</b><small>{{ planMetric(item) }}</small></div></div>
          <div class="workout-tile-actions workout-card-actions"><button type="button" class="edit-workout" @click.stop="emit('repeat', plan)">↻ Повторить</button></div>
        </article>
        <div v-if="!canceledPlans.length" class="panel empty">Отменённых тренировок пока нет</div>
        </div>
      </div>
    </section>
  </template>
</template>

<style lang="scss">
.scheduled-workouts {
  margin-bottom: 24px;
}

.scheduled-workouts-head,
.subsection-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 13px;
}

.scheduled-workouts-head h2,
.subsection-heading h2 {
  margin: 0;
  font-size: 24px;
}

.scheduled-grid,
.archive-workout-grid,
.exercise-grid {
  margin-top: 0;
}

.planned-plan-tile,
.archive-plan-tile {
  display: flex;
  flex-direction: column;
  min-height: 300px;

  .workout-tile-head {
    min-height: 24px;
  }

  h3 {
    display: flex;
    align-items: flex-start;
    min-height: 46px;
    margin: 6px 0 5px;
  }

  > p {
    min-height: 35px;
  }

  .planned-plan-items {
    flex: 1 1 auto;
    min-height: 108px;
    max-height: 108px;
    overflow-y: auto;
  }

  .workout-tile-actions {
    margin-top: auto;
  }
}

.workout-tile h3 {
  font-size: 20px;
}

.planned-plan-items {
  display: grid;
  gap: 6px;
  margin: 14px 0;

  div {
    padding: 7px 9px;
    border-radius: 8px;
    background: #f7f8fa;
  }

  b,
  small {
    display: block;
  }

  b {
    font-size: 12px;
  }

  small {
    margin-top: 2px;
    color: var(--muted);
    font-size: 10px;
  }
}

.planned-tile-actions {
  grid-template-columns: minmax(0, 1fr) 82px;
}

.planned-plan-tile {
  padding-top: 56px;
}

.workout-card-actions {
  min-height: 36px;
}

.archive-plan-tile .workout-card-actions {
  grid-template-columns: 1fr;
}

.workout-complete-action {
  position: absolute;
  top: 15px;
  right: 15px;
  z-index: 1;
  min-width: 100px;
}

.planned-badge {
  background: #e9ddff;
  color: #5e4db2;
}

.complete-plan {
  border: 0;
  border-radius: 8px;
  padding: 7px 9px;
  background: var(--green);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  cursor: pointer;
}

.scheduled-empty {
  padding: 25px 20px;
  border: 1px dashed #b7beca;
  border-radius: 13px;
  background: #fff;
  color: var(--muted);
  text-align: center;
}

.workout-section-menu {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 13px;
  margin-bottom: 23px;
}

.workout-section-tile {
  display: grid;
  grid-template-columns: 45px 1fr auto;
  gap: 11px;
  align-items: start;
  min-height: 132px;
  padding: 14px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: linear-gradient(145deg, #fff, #f4f1ff);
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
    background: linear-gradient(145deg, #fff, #eef7ff);

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

  b {
    font-size: 16px;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 11px;
  }

  > strong {
    padding: 4px 8px;
    border-radius: 99px;
    background: #fff;
    color: var(--purple);
    font-size: 12px;
    box-shadow: 0 1px 3px #091e4220;
  }
}

.workout-section-icon {
  display: grid;
  place-items: center;
  width: 45px;
  height: 45px;
  border-radius: 12px;
  background: linear-gradient(135deg, #e9ddff, #d9e7fd);
  font-size: 22px;
}

.workout-subsection {
  scroll-margin-top: 18px;
}

.workout-complex-card {
  display: flex;
  min-height: 260px;
  flex-direction: column;
  cursor: default;
}

.workout-complex-photo {
  display: grid;
  place-items: center;
  height: 125px;
  background: linear-gradient(135deg, #e9ddff, #d9e7fd);
  font-size: 28px;
  filter: grayscale(.2);
}

.workout-complex-card .category-copy {
  flex: 1 1 auto;
}

.workout-complex-card .category-copy b {
  font-size: 16px;
}

.workout-complex-actions {
  display: grid;
  gap: 7px;
  margin-top: auto;
  padding: 0 18px 18px;
}

.create-complex-button,
.edit-complex-button {
  width: 100%;
  height: 36px;
  min-height: 36px;
  border-radius: 8px;
  padding: 9px 10px;
  font-size: 11px;
  font-weight: 800;
  cursor: pointer;
}

.create-complex-button {
  border: 1px solid var(--blue);
  background: var(--blue);
  color: #fff;
}

.edit-complex-button {
  border: 1px solid #85b8ff;
  background: #e9f2ff;
  color: var(--blue);
}

.exercise-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(255px, 1fr));
  gap: 15px;
}

.exercise-card {
  min-height: 235px;
  cursor: pointer;

  > p {
    min-height: 52px;
    display: -webkit-box;
    overflow: hidden;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 3;
  }
}

.exercise-categories {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: 10px;
  margin: 0 0 16px;
}

.exercise-category-card {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
  min-height: 78px;
  padding: 13px;
  border: 1px solid var(--line);
  border-radius: 13px;
  background: #fff;
  color: var(--ink);
  text-align: left;
  cursor: pointer;

  &:hover,
  &.active {
    border-color: var(--purple);
    background: #f5f2ff;
    box-shadow: 0 0 0 2px #6e5dc626;
  }

  b,
  small { display: block; }
  small { margin-top: 4px; color: var(--muted); font-size: 9px; text-transform: uppercase; }
  strong { padding: 3px 8px; border-radius: 99px; background: #e9ddff; color: var(--purple); font-size: 12px; }
}

.exercise-media-strip {
  display: flex;
  align-items: center;
  gap: 7px;
  min-height: 42px;
  margin: 4px 0 0;
  color: var(--muted);
  font-size: 10px;
  font-weight: 750;
}

.exercise-media-strip img {
  width: 42px;
  height: 42px;
  border-radius: 8px;
  object-fit: cover;
}

.exercise-card-actions {
  grid-template-columns: minmax(0, 1fr) 82px;
}

.exercise-code {
  color: var(--muted);
  font: 750 10px/1.2 ui-monospace, SFMono-Regular, Consolas, monospace;
}

.exercise-meta {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  margin-top: auto;

  span {
    padding: 8px 4px;
    border-radius: 8px;
    background: #f7f8fa;
    text-align: center;
  }

  b,
  small {
    display: block;
  }

  b {
    font-size: 16px;
  }

  small {
    margin-top: 2px;
    color: var(--muted);
    font-size: 9px;
  }
}

.exercise-actions {
  display: flex;
  gap: 7px;
}

.secondary-button {
  border: 1px solid #85b8ff;
  border-radius: 8px;
  padding: 8px 11px;
  background: #e9f2ff;
  color: var(--blue);
  font-size: 11px;
  font-weight: 800;
  cursor: pointer;
}

.completed-badge {
  background: #e3fcef;
  color: #216e4e;
}

.canceled-badge {
  background: #ffebe6;
  color: #ae2a19;
}

.archive-group + .archive-group {
  margin-top: 24px;
}

.archive-group-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;

  h3 { margin: 0; font-size: 18px; }
}

.canceled-archive-group .archive-group-head h3 { color: #ae2a19; }

@media (max-width: 850px) {
  .workout-section-menu {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 560px) {
  .scheduled-workouts-head,
  .subsection-heading {
    align-items: flex-start;
    flex-direction: column;
  }

  .workout-section-menu {
    gap: 9px;
  }

  .planned-tile-actions {
    grid-template-columns: 1fr;
  }
}
</style>
