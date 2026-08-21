<script setup lang="ts">
import type { WorkoutComplex, WorkoutPlanItem } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{
  open: boolean;
  complex: WorkoutComplex | null;
  isAdmin: boolean;
  readOnly?: boolean;
}>();

const emit = defineEmits<{
  close: [];
  edit: [complex: WorkoutComplex];
}>();

function itemMetric(item: WorkoutPlanItem) {
  const parts: string[] = [];
  if (item.sets) parts.push(`${item.sets} подхода`);
  if (item.duration_minutes) parts.push(`${item.duration_minutes} мин`);
  if (item.speed_kmh) parts.push(`${item.speed_kmh} км/ч`);
  if (item.working_weight) parts.push(`${item.working_weight} ${item.default_unit || 'кг'}`);
  return parts.join(' · ') || 'Параметры не заданы';
}
</script>

<template>
  <ModalDialog
    :open="open && Boolean(complex)"
    :title="complex?.name || 'Комплекс тренировок'"
    eyebrow="КОМПЛЕКС"
    wide
    @close="emit('close')"
  >
    <div v-if="complex" class="workout-complex-detail">
      <div class="workout-complex-detail-intro">
        <div>
          <p class="eyebrow">ОПИСАНИЕ</p>
          <p class="workout-complex-detail-comment">{{ complex.comment || 'Описание комплекса пока не добавлено.' }}</p>
        </div>
        <div class="workout-complex-detail-count"><b>{{ complex.items?.length || 0 }}</b><span>упражнений</span></div>
      </div>

      <section class="workout-complex-detail-section">
        <div class="workout-complex-detail-heading">
          <div><p class="eyebrow">СОСТАВ</p><h3>Упражнения комплекса</h3></div>
          <span class="subtle">{{ complex.items?.length || 0 }}</span>
        </div>
        <div v-if="complex.items?.length" class="workout-complex-detail-items">
          <div v-for="(item, index) in complex.items" :key="item.id || `${item.exercise_id}-${index}`" class="workout-complex-detail-item">
            <span class="workout-complex-detail-number">{{ index + 1 }}</span>
            <div><b>{{ item.name || `Упражнение ${item.exercise_id}` }}</b><small>{{ itemMetric(item) }}</small></div>
          </div>
        </div>
        <div v-else class="workout-complex-detail-empty">В комплекс пока не добавлены упражнения.</div>
      </section>

      <div v-if="complex.photos?.length || complex.video" class="workout-complex-detail-media">
        <p class="eyebrow">МЕДИА</p>
        <span v-if="complex.photos?.length">Фото: {{ complex.photos.length }}</span>
        <span v-if="complex.video">Видео добавлено</span>
      </div>

      <div class="actions">
        <button type="button" @click="emit('close')">Закрыть</button>
        <button v-if="props.isAdmin && !props.readOnly" type="button" class="primary" @click="emit('edit', complex)">Редактировать</button>
      </div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.workout-complex-detail { width: 100%; }
.workout-complex-detail-intro { display: flex; align-items: flex-start; justify-content: space-between; gap: 20px; padding: 16px 0 20px; border-bottom: 1px solid #edf0f5; }
.workout-complex-detail-comment { max-width: 610px; margin: 8px 0 0; color: var(--muted); line-height: 1.55; }
.workout-complex-detail-count { display: grid; min-width: 92px; padding: 12px 14px; border-radius: 12px; background: #e2f7eb; color: #329a63; text-align: center; }
.workout-complex-detail-count b { font-size: 22px; line-height: 1.1; }
.workout-complex-detail-count span { margin-top: 4px; font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: .7px; }
.workout-complex-detail-section { padding: 20px 0 0; }
.workout-complex-detail-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.workout-complex-detail-heading h3 { margin: 0; font-size: 17px; }
.workout-complex-detail-heading .eyebrow { margin-bottom: 5px; }
.workout-complex-detail-items { display: grid; gap: 0; margin-top: 14px; border: 1px solid #dde3ec; border-radius: 12px; overflow: hidden; }
.workout-complex-detail-item { display: flex; align-items: center; gap: 16px; min-height: 64px; padding: 12px 16px; background: #fff; }
.workout-complex-detail-item + .workout-complex-detail-item { border-top: 1px solid #edf0f5; }
.workout-complex-detail-number { display: grid; place-items: center; width: 28px; height: 28px; flex: 0 0 28px; border-radius: 50%; background: #eef0ff; color: #6f82ff; font-size: 12px; font-weight: 800; }
.workout-complex-detail-item b, .workout-complex-detail-item small { display: block; }
.workout-complex-detail-item b { font-size: 14px; }
.workout-complex-detail-item small { margin-top: 5px; color: var(--muted); font-size: 11px; }
.workout-complex-detail-empty { margin-top: 14px; padding: 18px; border: 1px dashed #cfd8e5; border-radius: 12px; color: var(--muted); font-size: 12px; }
.workout-complex-detail-media { display: flex; align-items: center; gap: 8px; margin-top: 18px; padding-top: 14px; border-top: 1px solid #edf0f5; color: var(--muted); font-size: 12px; }
.workout-complex-detail-media .eyebrow { margin: 0 8px 0 0; }
.workout-complex-detail .actions { margin-top: 22px; }
@media (max-width: 620px) { .workout-complex-detail-intro { flex-direction: column; } .workout-complex-detail-count { width: 100%; } }
</style>
