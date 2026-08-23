<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { ProgressEntry, SortState } from '@/types';
import { compareValues, formatDate, fmt, fmtValue, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';

const props = defineProps<{ refreshKey: number; readOnly?: boolean }>();
const emit = defineEmits<{ edit: [id: number]; add: [] }>();

const data = ref<ProgressEntry[]>([]);
const loading = ref(false);
const error = ref('');
const query = ref('');
const sort = ref<SortState>({ key: null, dir: 0 });
const orderValue = ref('');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    data.value = await api.progress();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const latest = computed(() => data.value[0]);
const history = computed(() => data.value.slice(1));
const shown = computed(() => {
  let items = history.value.filter((item) => searchable(item, query.value));
  if (sort.value.dir && sort.value.key) items = [...items].sort((a, b) => compareValues(a[sort.value.key!], b[sort.value.key!]) * sort.value.dir);
  return items;
});

const weightHistory = computed(() => [...data.value].reverse().filter((item) => item.weight_kg != null).slice(-30));
const chartPoints = computed(() => {
  if (!weightHistory.value.length) return '';
  const values = weightHistory.value.map((item) => Number(item.weight_kg));
  const min = Math.min(...values) - 1;
  const max = Math.max(...values) + 1;
  const span = Math.max(max - min, 1);
  return weightHistory.value.map((item, index) => {
    const x = 28 + (index / Math.max(weightHistory.value.length - 1, 1)) * 566;
    const y = 184 - ((Number(item.weight_kg) - min) / span) * 140;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
});
const chartAreaPoints = computed(() => chartPoints.value ? `28,184 ${chartPoints.value} 594,184` : '');
const chartLastPoint = computed(() => {
  const points = chartPoints.value.split(' ');
  return points[points.length - 1] || '';
});
const weightDelta = computed(() => {
  if (data.value.length < 2 || data.value[1].weight_kg == null || latest.value?.weight_kg == null) return null;
  return Number(latest.value.weight_kg) - Number(data.value[1].weight_kg);
});
const wellbeingLabel = computed(() => latest.value?.wellbeing_score != null ? `${fmt(latest.value.wellbeing_score)} / 5` : '—');

function metric(value: unknown, label: string, unit = '') {
  return { value, label, unit };
}

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
  if (props.readOnly) return;
  if (!confirm('Удалить замер прогресса? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`progress/${id}`);
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
    <p class="progress-page-subtitle">Измерения, которые помогают увидеть динамику</p>
    <div v-if="latest" class="progress-stat-grid">
      <article class="progress-stat-card">
        <span>ВЕС</span><b>{{ fmtValue(latest.weight_kg) }}<i v-if="latest.weight_kg != null"> кг</i></b>
        <small v-if="weightDelta != null" :class="weightDelta <= 0 ? 'positive' : 'negative'">{{ weightDelta <= 0 ? '−' : '+' }} {{ fmt(Math.abs(weightDelta)) }} кг за период</small><small v-else>Последний замер</small>
      </article>
      <article class="progress-stat-card">
        <span>ИМТ</span><b>{{ fmtValue(latest.bmi) }}</b><small class="positive">{{ latest.bmi != null && latest.bmi >= 18.5 && latest.bmi <= 24.9 ? 'Здоровый диапазон' : 'Требует внимания' }}</small>
      </article>
      <article class="progress-stat-card">
        <span>ТАЛИЯ</span><b>{{ fmtValue(latest.waist_cm) }}<i v-if="latest.waist_cm != null"> см</i></b><small class="blue-note">Последний замер</small>
      </article>
      <article class="progress-stat-card wellbeing-stat">
        <span>САМОЧУВСТВИЕ</span><b>{{ wellbeingLabel }}</b><small>сон {{ fmtValue(latest.sleep_score) }} · энергия {{ fmtValue(latest.wellbeing_score) }}</small>
      </article>
    </div>
    <div v-if="latest" class="progress-overview-grid">
      <section class="progress-chart-card">
        <div class="progress-section-head"><div><h2>Динамика веса</h2><p>Последние 30 дней</p></div><span v-if="weightHistory.length">{{ weightHistory.length }} замеров</span></div>
        <div v-if="weightHistory.length" class="progress-chart-wrap">
          <div class="progress-chart-y"><span>↑</span><span>Вес</span><span>↓</span></div>
          <svg class="progress-chart" viewBox="0 0 620 220" role="img" aria-label="График динамики веса">
            <path d="M28 44H594M28 114H594M28 184H594" class="chart-grid-line" />
            <polygon :points="chartAreaPoints" class="chart-area" />
            <polyline :points="chartPoints" class="chart-line" />
            <circle v-if="chartLastPoint" :cx="Number(chartLastPoint.split(',')[0])" :cy="Number(chartLastPoint.split(',')[1])" r="6" class="chart-dot" />
          </svg>
          <div class="progress-chart-x"><span>{{ formatDate(weightHistory[0]?.measured_at) }}</span><span>{{ formatDate(weightHistory[weightHistory.length - 1]?.measured_at) }}</span></div>
        </div>
        <div v-else class="progress-chart-empty">Добавьте несколько замеров, чтобы увидеть динамику веса.</div>
      </section>
      <aside class="progress-latest-card">
        <p class="eyebrow">ТЕКУЩИЙ ЗАМЕР</p>
        <h2>{{ formatDate(latest.measured_at) }}</h2>
        <dl>
          <div><dt>Вес</dt><dd>{{ fmtValue(latest.weight_kg) }} кг</dd></div>
          <div><dt>Желаемый вес</dt><dd>{{ fmtValue(latest.desired_weight_kg) }} кг</dd></div>
          <div><dt>Талия</dt><dd>{{ fmtValue(latest.waist_cm) }} см</dd></div>
          <div><dt>ИМТ</dt><dd>{{ fmtValue(latest.bmi) }}</dd></div>
          <div><dt>Самочувствие</dt><dd>{{ wellbeingLabel }}</dd></div>
        </dl>
        <button v-if="!props.readOnly" type="button" class="primary card-primary progress-latest-edit" @click="emit('edit', latest.id)">Редактировать</button>
        <button type="button" class="icon-action progress-details-link" aria-label="Открыть подробности текущего замера" title="Открыть подробности текущего замера" @click="emit('edit', latest.id)">↗</button>
      </aside>
    </div>
    <div v-else class="panel empty">Замеров пока нет</div>

    <div class="progress-history-head">
      <div>
        <p class="eyebrow">ИСТОРИЯ ИЗМЕРЕНИЙ</p>
        <h3>Предыдущие замеры</h3>
      </div>
      <span class="subtle">Замеров: {{ shown.length }}</span>
    </div>
    <Toolbar v-model:query="query" placeholder="Поиск по истории…" :reset-disabled="!sort.dir" @reset="resetSort">
      <select id="progress-order" :value="orderValue" aria-label="Сортировка прогресса" @change="setOrder(($event.target as HTMLSelectElement).value)">
        <option value="">Сначала новые</option>
        <option value="measured_at:1">Дата: сначала старые</option>
        <option value="measured_at:-1">Дата: сначала новые</option>
        <option value="weight_kg:1">Вес: меньше</option>
        <option value="weight_kg:-1">Вес: больше</option>
        <option value="bmi:1">ИМТ: меньше</option>
        <option value="bmi:-1">ИМТ: больше</option>
        <option value="body_fat_pct:1">Процент жира: меньше</option>
        <option value="body_fat_pct:-1">Процент жира: больше</option>
        <option value="muscle_pct:1">Процент мышц: меньше</option>
        <option value="muscle_pct:-1">Процент мышц: больше</option>
        <option value="waist_cm:1">Талия: меньше</option>
        <option value="waist_cm:-1">Талия: больше</option>
      </select>
    </Toolbar>

    <div class="progress-grid">
      <article v-for="item in shown" :key="item.id" class="progress-tile">
        <div class="progress-tile-head"><strong>{{ formatDate(item.measured_at) }}</strong><span>ЗАМЕР</span></div>
        <div class="progress-history-rows">
          <div><span>Вес</span><b>{{ fmtValue(item.weight_kg) }} кг</b></div>
          <div><span>Желаемый вес</span><b>{{ fmtValue(item.desired_weight_kg) }} кг</b></div>
          <div><span>Талия</span><b>{{ fmtValue(item.waist_cm) }} см</b></div>
          <div><span>ИМТ</span><b>{{ fmtValue(item.bmi) }}</b></div>
          <div><span>Самочувствие</span><b>{{ fmtValue(item.wellbeing_score) }} / 5</b></div>
        </div>
        <div class="progress-tile-actions">
          <button type="button" class="primary card-primary progress-open-button" @click="emit('edit', item.id)">Открыть</button>
          <button v-if="!props.readOnly" type="button" class="icon-action edit-progress-tile" aria-label="Изменить замер" title="Изменить замер" @click="emit('edit', item.id)">✎</button>
          <button v-if="!props.readOnly" type="button" class="icon-action danger-icon delete-progress-tile" aria-label="Удалить замер" title="Удалить замер" @click="remove(item.id)">×</button>
        </div>
      </article>
      <article v-if="!props.readOnly" class="progress-add-card" tabindex="0" role="button" @click="emit('add')" @keydown.enter.prevent="emit('add')">
        <span class="progress-add-icon">＋</span><h3>Добавить предыдущий замер</h3><p>Внесите данные за прошлую дату</p><button type="button" class="primary" @click.stop="emit('add')">＋ Добавить замер</button>
      </article>
      <div v-if="!shown.length" class="panel empty">Предыдущих замеров пока нет</div>
    </div>
    <aside class="progress-tip"><span>ПОДСКАЗКА</span><b>Добавляйте замеры примерно в одно и то же время</b><small>Так динамика веса и объёмов будет сравниваться точнее.</small></aside>
  </template>
</template>

<style lang="scss">
.progress-grid {
  margin-top: 12px;
}

.progress-tile-actions {
  margin-top: auto;

  button {
    min-height: 36px;
  }
}
</style>
