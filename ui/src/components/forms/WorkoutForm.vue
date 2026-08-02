<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { api } from '@/api/client';
import type { Exercise } from '@/types';

const props = defineProps<{ workoutLogId?: number }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();

const loading = ref(false);
const error = ref('');
const exercises = ref<Exercise[]>([]);
const form = reactive<Record<string, string | number>>({
  performed_at: '',
  exercise_id: 0,
  working_weight: '',
  sets: '3',
  reps: '12',
  rir: '0–2',
  machine_location: '',
  comment: ''
});

onMounted(async () => {
  loading.value = true;
  try {
    exercises.value = (await api.exercises()).sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    form.exercise_id = exercises.value[0]?.id || 0;
    if (props.workoutLogId) {
      const data = await api.workouts();
      const item = data.find((workout) => workout.id === props.workoutLogId);
      if (item) {
        for (const [key, value] of Object.entries(item)) {
          if (key in form) form[key] = key === 'exercise_id' ? Number(value) : value == null ? '' : String(value);
        }
      }
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

async function save() {
  error.value = '';
  try {
    if (props.workoutLogId) await api.put(`workouts/${props.workoutLogId}`, { ...form });
    else await api.post('workouts', { ...form });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

async function remove() {
  if (!props.workoutLogId || !confirm('Удалить запись тренировки? Это действие нельзя отменить.')) return;
  error.value = '';
  try {
    await api.delete(`workouts/${props.workoutLogId}`);
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
        <div class="field"><label>Дата</label><input v-model="form.performed_at" type="date" required></div>
        <div class="field"><label>Упражнение</label><select v-model="form.exercise_id" required><option v-for="exercise in exercises" :key="exercise.id" :value="exercise.id">{{ exercise.name }}</option></select></div>
        <div class="field"><label>Рабочий вес</label><input v-model="form.working_weight" type="number" min="0" step="0.5"></div>
        <div class="field"><label>Подходы</label><input v-model="form.sets" type="number" min="1"></div>
        <div class="field"><label>Повторы</label><input v-model="form.reps" type="number" min="1"></div>
        <div class="field"><label>RIR</label><input v-model="form.rir"></div>
        <div class="field"><label>Тренажёр / филиал</label><input v-model="form.machine_location"></div>
        <div class="field"><label>Комментарий</label><input v-model="form.comment"></div>
      </div>
      <div v-if="props.workoutLogId" class="destructive-zone">
        <button type="button" class="danger-button" @click="remove">Удалить тренировку</button>
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
  display: block;
}
</style>
