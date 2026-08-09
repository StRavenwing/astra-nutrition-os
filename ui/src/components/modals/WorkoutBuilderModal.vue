<script setup lang="ts">
import { nextTick, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Exercise, WorkoutPlan } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

type BuilderItem = {
  exercise_id: number;
  working_weight: number | '';
  sets: number | '';
  duration_minutes: number | '';
  speed_kmh: number | '';
};

const props = defineProps<{
  open: boolean;
  repeatPlan?: WorkoutPlan | null;
}>();

const emit = defineEmits<{
  close: [];
  saved: [];
}>();

const exercises = ref<Exercise[]>([]);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const form = reactive<{ scheduled_at: string; items: BuilderItem[] }>({
  scheduled_at: today(),
  items: []
});

function today() {
  const now = new Date();
  const offset = now.getTimezoneOffset();
  return new Date(now.getTime() - offset * 60_000).toISOString().slice(0, 10);
}

function resetForm() {
  form.scheduled_at = today();
  form.items = props.repeatPlan?.items.map((item) => ({
    exercise_id: item.exercise_id,
    working_weight: item.working_weight ?? '',
    sets: item.sets ?? '',
    duration_minutes: item.duration_minutes ?? '',
    speed_kmh: item.speed_kmh ?? ''
  })) || [];
  if (!form.items.length && exercises.value[0]) addExercise(exercises.value[0]);
  error.value = '';
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    exercises.value = (await api.exercises()).sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    await nextTick();
    resetForm();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

watch(() => props.open, (open) => {
  if (open) void load();
}, { immediate: true });

watch(() => props.repeatPlan, () => {
  if (props.open && exercises.value.length) resetForm();
});

function addExercise(exercise?: Exercise) {
  const selected = exercise || exercises.value.find((candidate) => !form.items.some((item) => item.exercise_id === candidate.id));
  if (!selected) return;
  form.items.push({
    exercise_id: selected.id,
    working_weight: '',
    sets: selected.default_sets ?? '',
    duration_minutes: '',
    speed_kmh: ''
  });
}

function removeExercise(index: number) {
  form.items.splice(index, 1);
}

function selectedExercise(item: BuilderItem) {
  return exercises.value.find((exercise) => exercise.id === item.exercise_id);
}

function supportsDuration(item: BuilderItem) {
  const name = selectedExercise(item)?.name.toLocaleLowerCase('ru') || '';
  return ['велотренаж', 'ступень', 'эллип', 'греб', 'бегов'].some((word) => name.includes(word));
}

function supportsSpeed(item: BuilderItem) {
  const name = selectedExercise(item)?.name.toLocaleLowerCase('ru') || '';
  return ['велотренаж', 'ступень', 'эллип', 'бегов'].some((word) => name.includes(word));
}

function normalizeItem(item: BuilderItem) {
  if (!supportsDuration(item)) item.duration_minutes = '';
  if (!supportsSpeed(item)) item.speed_kmh = '';
}

async function save() {
  error.value = '';
  if (!form.scheduled_at || !form.items.length) {
    error.value = 'Укажите дату и добавьте хотя бы одно упражнение';
    return;
  }
  saving.value = true;
  try {
    await api.post('workout-plans', {
      scheduled_at: form.scheduled_at,
      items: form.items.map((item) => ({
        exercise_id: item.exercise_id,
        working_weight: item.working_weight || null,
        sets: item.sets || null,
        duration_minutes: item.duration_minutes || null,
        speed_kmh: item.speed_kmh || null
      }))
    });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <ModalDialog :open="open" :title="repeatPlan ? 'Повторить тренировку' : 'Собрать тренировку'" eyebrow="WORKOUT BUILDER" wide @close="$emit('close')">
    <form class="workout-builder" @submit.prevent="save">
      <div v-if="loading" class="panel">Загрузка…</div>
      <template v-else>
        <div class="builder-date field">
          <label for="planned-workout-date">Дата тренировки</label>
          <input id="planned-workout-date" v-model="form.scheduled_at" type="date" required>
          <small v-if="repeatPlan">По умолчанию выбрана текущая дата — её можно изменить.</small>
        </div>

        <div class="builder-items-head">
          <div>
            <b>Упражнения в тренировке</b>
            <small>Настройки ниже необязательны и задаются отдельно для каждого упражнения.</small>
          </div>
          <button type="button" class="secondary-button" @click="addExercise()">＋ Добавить упражнение</button>
        </div>

        <div class="builder-items">
          <article v-for="(item, index) in form.items" :key="index" class="builder-item">
            <div class="builder-item-head">
              <span class="builder-number">{{ index + 1 }}</span>
              <select v-model="item.exercise_id" aria-label="Упражнение" required @change="normalizeItem(item)">
                <option v-for="exercise in exercises" :key="exercise.id" :value="exercise.id">{{ exercise.name }}</option>
              </select>
              <button type="button" class="remove-builder-item" aria-label="Удалить упражнение" @click="removeExercise(index)">×</button>
            </div>
            <div class="builder-item-fields">
              <div class="field"><label>Вес, {{ selectedExercise(item)?.default_unit || 'кг' }}</label><input v-model="item.working_weight" type="number" min="0" step="0.5" placeholder="Опционально"></div>
              <div class="field"><label>Подходы</label><input v-model="item.sets" type="number" min="1" placeholder="Опционально"></div>
              <div v-if="supportsDuration(item)" class="field"><label>Длительность, мин</label><input v-model="item.duration_minutes" type="number" min="1" placeholder="Опционально"></div>
              <div v-if="supportsSpeed(item)" class="field"><label>Скорость, км/ч</label><input v-model="item.speed_kmh" type="number" min="0" step="0.1" placeholder="Опционально"></div>
            </div>
          </article>
          <div v-if="!form.items.length" class="builder-empty">Добавьте первое упражнение, чтобы собрать тренировку.</div>
        </div>

        <p class="builder-hint">После сохранения тренировка появится сверху страницы. Кнопка «Выполнено» переместит её в архив.</p>
        <p id="form-error">{{ error }}</p>
        <div class="actions">
          <button type="button" @click="$emit('close')">Отмена</button>
          <button type="submit" class="primary" :disabled="saving">{{ saving ? 'Сохранение…' : 'Закрепить тренировку' }}</button>
        </div>
      </template>
    </form>
  </ModalDialog>
</template>

<style lang="scss">
.workout-builder {
  display: block;
}

.builder-date {
  max-width: 260px;

  small,
  > small {
    color: var(--muted);
    font-size: 11px;
  }
}

.builder-items-head,
.builder-item-head {
  display: flex;
  align-items: center;
  gap: 10px;
}

.builder-items-head {
  justify-content: space-between;
  margin: 23px 0 11px;

  b,
  small {
    display: block;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 11px;
  }
}

.secondary-button {
  border: 1px solid #85b8ff;
  border-radius: 8px;
  padding: 9px 12px;
  background: #e9f2ff;
  color: var(--blue);
  font-weight: 750;
  cursor: pointer;
}

.builder-items {
  display: grid;
  gap: 10px;
  max-height: 48vh;
  overflow-y: auto;
  padding: 2px;
}

.builder-item {
  padding: 12px;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: #fafbfc;
}

.builder-item-head select {
  min-width: 0;
  flex: 1;
}

.builder-number {
  display: grid;
  place-items: center;
  width: 27px;
  height: 27px;
  flex: 0 0 27px;
  border-radius: 8px;
  background: #e9ddff;
  color: #5e4db2;
  font-weight: 850;
}

.remove-builder-item {
  width: 30px;
  height: 30px;
  border: 0;
  border-radius: 7px;
  background: #ffebe6;
  color: #ae2a19;
  font-size: 20px;
  cursor: pointer;
}

.builder-item-fields {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 9px;
  margin-top: 10px;
}

.builder-item-fields input {
  min-width: 0;
  width: 100%;
}

.builder-empty {
  padding: 25px;
  border: 1px dashed #b7beca;
  border-radius: 10px;
  color: var(--muted);
  text-align: center;
}

.builder-hint {
  margin: 15px 0 0;
  color: var(--muted);
  font-size: 11px;
}

@media (max-width: 700px) {
  .builder-items-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .builder-item-fields {
    grid-template-columns: 1fr 1fr;
  }
}
</style>
