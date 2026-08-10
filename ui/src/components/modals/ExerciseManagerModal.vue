<script setup lang="ts">
import { ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Exercise } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ open: boolean }>();
const emit = defineEmits<{
  close: [];
  add: [];
  edit: [id: number];
  changed: [];
}>();

const loading = ref(false);
const error = ref('');
const exercises = ref<Exercise[]>([]);

async function load() {
  loading.value = true;
  error.value = '';
  try {
    exercises.value = (await api.exercises()).sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

watch(() => props.open, (open) => {
  if (open) void load();
}, { immediate: true });

async function removeExercise(id: number) {
  if (!confirm('Удалить упражнение из справочника?')) return;
  try {
    await api.delete(`exercises/${id}`);
    await load();
    emit('changed');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <ModalDialog :open="open" title="Упражнения" eyebrow="EXERCISES" wide @close="$emit('close')">
    <div class="exercise-manager-head">
      <span>{{ exercises.length }} упражнений</span>
      <button type="button" class="primary" @click="$emit('add')">＋ Добавить упражнение</button>
    </div>
    <div v-if="loading" class="panel">Загрузка…</div>
    <div v-else-if="error" class="panel empty">{{ error }}</div>
    <div v-else class="exercise-manager-list">
      <div v-for="exercise in exercises" :key="exercise.id" class="exercise-manager-row">
        <div>
          <b>{{ exercise.name }}</b>
          <small>{{ exercise.code }} · {{ exercise.muscle_group || 'Без группы' }}</small>
        </div>
        <div class="exercise-manager-actions">
          <button type="button" class="edit-exercise" @click="$emit('edit', exercise.id)">✎ Редактировать</button>
          <button type="button" class="delete-exercise" @click="removeExercise(exercise.id)">Удалить</button>
        </div>
      </div>
      <div v-if="!exercises.length" class="empty">Упражнений пока нет</div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.exercise-manager-list {
  min-height: 120px;
}

.exercise-manager-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 6px;
}

.edit-exercise {
  border: 1px solid #85b8ff;
  border-radius: 7px;
  padding: 7px 10px;
  background: #e9f2ff;
  color: var(--blue);
  font-size: 10px;
  font-weight: 800;
  cursor: pointer;
}
</style>
