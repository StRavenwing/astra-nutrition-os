<script setup lang="ts">
import type { Exercise } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

defineProps<{ exercise: Exercise | null }>();
defineEmits<{ close: [] }>();
</script>

<template>
  <ModalDialog :open="Boolean(exercise)" :title="exercise?.name || 'Упражнение'" eyebrow="EXERCISE DETAILS" wide @close="$emit('close')">
    <div v-if="exercise" class="exercise-detail-modal">
      <div class="exercise-detail-head">
        <span class="workout-group">{{ exercise.muscle_group || 'Другое' }}</span>
        <span class="exercise-code">{{ exercise.code }}</span>
      </div>

      <section class="exercise-detail-section">
        <h3>Описание</h3>
        <p>{{ exercise.description || exercise.note || 'Описание упражнения пока не добавлено.' }}</p>
      </section>

      <section class="exercise-detail-section">
        <h3>Техника и вариации</h3>
        <p class="exercise-detail-placeholder">Техника и вариации будут добавлены в следующих обновлениях.</p>
      </section>

      <section v-if="exercise.photos?.length" class="exercise-detail-section">
        <h3>Фото</h3>
        <div class="exercise-detail-photos">
          <img v-for="(photo, index) in exercise.photos" :key="photo" :src="photo" :alt="`Фото упражнения ${index + 1}`">
        </div>
      </section>

      <section v-if="exercise.video" class="exercise-detail-section">
        <h3>Видео</h3>
        <video :src="exercise.video" controls></video>
      </section>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.exercise-detail-modal { min-width: 0; }
.exercise-detail-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 18px; }
.exercise-detail-section { margin-top: 16px; }
.exercise-detail-section h3 { margin: 0 0 7px; font-size: 15px; }
.exercise-detail-section p { margin: 0; color: var(--muted); line-height: 1.6; }
.exercise-detail-placeholder { padding: 12px; border-radius: 9px; background: #f7f8fa; font-size: 12px; }
.exercise-detail-photos { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 8px; }
.exercise-detail-photos img { width: 100%; aspect-ratio: 1; border-radius: 9px; object-fit: cover; background: #f1f2f4; }
.exercise-detail-section video { display: block; width: min(100%, 560px); max-height: 330px; border-radius: 10px; background: #172b4d; }
@media (max-width: 650px) { .exercise-detail-photos { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
</style>
