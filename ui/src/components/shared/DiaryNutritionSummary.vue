<script setup lang="ts">
import type { DiaryTotals } from '@/types';
import { fmt } from '@/utils/format';

type Nutrition = Pick<DiaryTotals, 'kcal' | 'protein' | 'fat' | 'carbs'>;
defineProps<{ totals: Nutrition; averages: Nutrition }>();

const metrics = [
  { key: 'kcal', label: 'Ккал' },
  { key: 'protein', label: 'Б, г' },
  { key: 'fat', label: 'Ж, г' },
  { key: 'carbs', label: 'У, г' },
] as const;
</script>

<template>
  <span class="diary-nutrition-summary">
    <span class="nutrition-row nutrition-heading" aria-hidden="true">
      <span></span><span v-for="metric in metrics" :key="metric.key">{{ metric.label }}</span>
    </span>
    <span v-for="row in [{ label: 'Всего', values: totals }, { label: 'В среднем за день', values: averages }]" :key="row.label" class="nutrition-row">
      <span class="nutrition-label">{{ row.label }}</span>
      <strong v-for="metric in metrics" :key="metric.key" :aria-label="`${metric.label}: ${fmt(row.values[metric.key])}`">{{ fmt(row.values[metric.key]) }}</strong>
    </span>
  </span>
</template>

<style scoped>
.diary-nutrition-summary {
  display: grid;
  gap: 8px;
  min-width: 0;
  font-size: 12px;
  line-height: 1.4;
  font-variant-numeric: tabular-nums;
}

.nutrition-row {
  display: grid;
  grid-template-columns: minmax(50px, .9fr) repeat(4, minmax(0, 1fr));
  align-items: baseline;
  gap: 6px;
}

.nutrition-row > * {
  min-width: 0;
  overflow-wrap: anywhere;
  text-align: right;
}

.nutrition-heading,
.nutrition-label {
  color: #7d879b;
  font-size: 10px;
  font-weight: 500;
}

.nutrition-heading {
  font-weight: 700;
}

.nutrition-label {
  text-align: left;
}

.nutrition-row strong {
  color: #172033;
  font-weight: 650;
}

.nutrition-row:last-child {
  padding-top: 8px;
  border-top: 1px solid #e5eaf2;
}
</style>
