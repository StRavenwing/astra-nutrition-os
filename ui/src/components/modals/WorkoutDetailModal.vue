<script setup lang="ts">
import { computed } from 'vue';
import type { WorkoutPlan } from '@/types';
import { formatDate, fmt } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ plan: WorkoutPlan | null }>();
const emit = defineEmits<{
  close: [];
  edit: [plan: WorkoutPlan];
  repeat: [plan: WorkoutPlan];
  complete: [plan: WorkoutPlan];
  cancel: [plan: WorkoutPlan];
}>();

const statusLabel = computed(() => {
  if (props.plan?.status === 'planned') return 'Запланирована';
  if (props.plan?.status === 'canceled') return 'Отменена';
  return 'Пройдена';
});
</script>

<template>
  <ModalDialog :open="Boolean(plan)" title="Тренировка" eyebrow="WORKOUT DETAILS" wide @close="$emit('close')">
    <div v-if="plan" class="workout-detail-modal">
      <div class="workout-detail-topline">
        <div>
          <p class="eyebrow">{{ statusLabel }}</p>
          <h3>{{ formatDate(plan.scheduled_at) }}</h3>
        </div>
        <span class="workout-group" :class="plan.status === 'planned' ? 'planned-badge' : plan.status === 'canceled' ? 'canceled-badge' : 'completed-badge'">{{ statusLabel }}</span>
      </div>
      <div class="workout-detail-summary">
        <span><b>{{ plan.items.length }}</b><small>упражнений</small></span>
        <span><b>{{ plan.completed_at ? formatDate(plan.completed_at) : '—' }}</b><small>{{ plan.status === 'planned' ? 'дата создания' : 'дата завершения' }}</small></span>
      </div>
      <div class="workout-detail-items">
        <article v-for="(item, index) in plan.items" :key="item.id || `${item.exercise_id}-${index}`">
          <span class="workout-detail-index">{{ index + 1 }}</span>
          <div>
            <b>{{ item.name }}</b>
            <small>{{ item.muscle_group || 'Без группы' }}</small>
          </div>
          <strong>{{ item.working_weight != null ? `${fmt(item.working_weight)} ${item.default_unit || 'кг'}` : 'Вес не задан' }}</strong>
          <span>{{ item.sets != null ? `${item.sets} подход.` : '' }}<template v-if="item.duration_minutes != null"> · {{ item.duration_minutes }} мин</template><template v-if="item.speed_kmh != null"> · {{ fmt(item.speed_kmh) }} км/ч</template></span>
        </article>
      </div>
      <div class="workout-detail-actions">
        <button v-if="plan.status === 'planned'" type="button" class="edit-workout" @click="emit('edit', plan)">✎ Редактировать</button>
        <button v-if="plan.status === 'planned'" type="button" class="complete-plan" @click="emit('complete', plan)">Выполнено</button>
        <button v-if="plan.status === 'planned'" type="button" class="delete-workout" @click="emit('cancel', plan)">Отменить</button>
        <button v-if="plan.status !== 'planned'" type="button" class="edit-workout" @click="emit('repeat', plan)">↻ Повторить</button>
      </div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.workout-detail-modal { min-width: 0; }
.workout-detail-topline { display: flex; align-items: flex-start; justify-content: space-between; gap: 15px; }
.workout-detail-topline h3 { margin: 0; font-size: 24px; }
.workout-detail-summary { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 9px; margin: 18px 0; }
.workout-detail-summary span { padding: 12px; border-radius: 10px; background: #f5f2ff; text-align: center; }
.workout-detail-summary b, .workout-detail-summary small { display: block; }
.workout-detail-summary b { font-size: 18px; }
.workout-detail-summary small { margin-top: 3px; color: var(--muted); font-size: 10px; }
.workout-detail-items { display: grid; gap: 7px; }
.workout-detail-items article { display: grid; grid-template-columns: 30px minmax(0, 1fr) auto auto; gap: 10px; align-items: center; padding: 10px 11px; border: 1px solid var(--line); border-radius: 10px; background: #fafbfc; }
.workout-detail-items b, .workout-detail-items small { display: block; }
.workout-detail-items small, .workout-detail-items article > span:last-child { color: var(--muted); font-size: 10px; }
.workout-detail-items article > strong { font-size: 12px; white-space: nowrap; }
.workout-detail-index { display: grid; place-items: center; width: 26px; height: 26px; border-radius: 8px; background: #e9ddff; color: var(--purple); font-weight: 850; }
.workout-detail-actions { display: flex; justify-content: flex-end; gap: 7px; margin-top: 18px; }
.workout-detail-actions button { min-width: 120px; }
@media (max-width: 650px) {
  .workout-detail-items article { grid-template-columns: 30px minmax(0, 1fr); }
  .workout-detail-items article > strong, .workout-detail-items article > span:last-child { grid-column: 2; }
  .workout-detail-actions { flex-wrap: wrap; }
}
</style>
