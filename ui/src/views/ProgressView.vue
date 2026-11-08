<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { ProgressEntry, SortState } from '@/types';
import { compareValues, formatDate, fmt, fmtValue, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';
import SendToClientButton from '@/components/shared/SendToClientButton.vue';
import SendToTrainerButton from '@/components/shared/SendToTrainerButton.vue';

const props = defineProps<{ refreshKey: number; canManage: boolean; hasTrainer: boolean; readOnly?: boolean }>();
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

const weightDelta = computed(() => {
  if (data.value.length < 2 || data.value[1].weight_kg == null || latest.value?.weight_kg == null) return null;
  return Number(latest.value.weight_kg) - Number(data.value[1].weight_kg);
});
const wellbeingLabel = computed(() => latest.value?.wellbeing_score != null ? `${fmt(latest.value.wellbeing_score)} / 5` : '—');

type ProgressMetricKey = 'weight_kg' | 'waist_cm' | 'hips_cm' | 'chest_cm' | 'bmi' | 'body_fat_pct' | 'muscle_mass_kg' | 'biceps_cm' | 'thigh_cm';
type ProgressMetric = { key: ProgressMetricKey; label: string; unit: string; description: string };

const measurementDefinitions: ProgressMetric[] = [
  { key: 'weight_kg', label: 'Динамика веса', unit: 'кг', description: 'Изменение веса по контрольным точкам' },
  { key: 'waist_cm', label: 'Талия', unit: 'см', description: 'Обхват талии по контрольным точкам' },
  { key: 'hips_cm', label: 'Бёдра', unit: 'см', description: 'Обхват бёдер по контрольным точкам' },
  { key: 'chest_cm', label: 'Грудь', unit: 'см', description: 'Обхват груди по контрольным точкам' },
  { key: 'biceps_cm', label: 'Бицепс', unit: 'см', description: 'Обхват бицепса по контрольным точкам' },
  { key: 'thigh_cm', label: 'Бедро', unit: 'см', description: 'Обхват бедра по контрольным точкам' },
  { key: 'bmi', label: 'ИМТ', unit: '', description: 'Индекс массы тела по контрольным точкам' },
  { key: 'body_fat_pct', label: 'Процент жира', unit: '%', description: 'Доля жировой массы по контрольным точкам' },
  { key: 'muscle_mass_kg', label: 'Мышечная масса', unit: 'кг', description: 'Расчётная мышечная масса по контрольным точкам' },
];

const availableMeasurements = computed(() => measurementDefinitions.filter((metric) => data.value.some((item) => {
  const value = item[metric.key];
  return value != null && Number.isFinite(Number(value));
})));
const activeMeasurement = ref<ProgressMetricKey>('weight_kg');
const activeMeasurementDefinition = computed(() => availableMeasurements.value.find((metric) => metric.key === activeMeasurement.value) || availableMeasurements.value[0] || measurementDefinitions[0]);
const activeMeasurementRows = computed(() => data.value.filter((item) => {
  const value = item[activeMeasurementDefinition.value.key];
  return value != null && Number.isFinite(Number(value));
}));

watch(availableMeasurements, (measurements) => {
  if (!measurements.some((metric) => metric.key === activeMeasurement.value)) {
    activeMeasurement.value = measurements[0]?.key || 'weight_kg';
  }
}, { immediate: true });

function measurementValue(item: ProgressEntry, metric: ProgressMetric) {
  const value = item[metric.key];
  return `${fmtValue(value)}${metric.unit ? ` ${metric.unit}` : ''}`;
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
      <article v-if="latest.biceps_cm != null" class="progress-stat-card">
        <span>БИЦЕПС</span><b>{{ fmtValue(latest.biceps_cm) }}<i> см</i></b><small class="blue-note">Последний замер</small>
      </article>
      <article v-if="latest.thigh_cm != null" class="progress-stat-card">
        <span>БЕДРО</span><b>{{ fmtValue(latest.thigh_cm) }}<i> см</i></b><small class="blue-note">Последний замер</small>
      </article>
      <article class="progress-stat-card wellbeing-stat">
        <span>САМОЧУВСТВИЕ</span><b>{{ wellbeingLabel }}</b><small>сон {{ fmtValue(latest.sleep_score) }} · энергия {{ fmtValue(latest.wellbeing_score) }}</small>
      </article>
    </div>
    <div v-if="latest" class="progress-overview-grid">
      <section class="progress-measurements-card">
        <div class="progress-section-head"><div><h2>{{ activeMeasurementDefinition.label }}</h2><p>{{ activeMeasurementDefinition.description }}</p></div><span v-if="activeMeasurementRows.length">{{ activeMeasurementRows.length }} замеров</span></div>
        <div v-if="availableMeasurements.length" class="progress-measurement-tabs" role="tablist" aria-label="Показатели прогресса">
          <button
            v-for="measurement in availableMeasurements"
            :key="measurement.key"
            type="button"
            class="progress-measurement-tab"
            :class="{ active: measurement.key === activeMeasurement }"
            role="tab"
            :aria-selected="measurement.key === activeMeasurement"
            @click="activeMeasurement = measurement.key"
          >{{ measurement.label }}</button>
        </div>
        <div v-if="activeMeasurementRows.length" class="progress-measurement-table-wrap">
          <table class="progress-measurement-table">
            <thead><tr><th>Дата</th><th>{{ activeMeasurementDefinition.label }}</th></tr></thead>
            <tbody>
              <tr v-for="item in activeMeasurementRows" :key="`${activeMeasurement}-${item.id}`">
                <td>{{ formatDate(item.measured_at) }}</td>
                <td><strong>{{ measurementValue(item, activeMeasurementDefinition) }}</strong></td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="progress-chart-empty">Добавьте замеры, чтобы увидеть показатели прогресса.</div>
      </section>
      <aside class="progress-latest-card">
        <p class="eyebrow">ТЕКУЩИЙ ЗАМЕР</p>
        <h2>{{ formatDate(latest.measured_at) }}</h2>
        <dl>
          <div><dt>Вес</dt><dd>{{ fmtValue(latest.weight_kg) }} кг</dd></div>
          <div><dt>Желаемый вес</dt><dd>{{ fmtValue(latest.desired_weight_kg) }} кг</dd></div>
          <div v-if="latest.waist_cm != null"><dt>Талия</dt><dd>{{ fmtValue(latest.waist_cm) }} см</dd></div>
          <div v-if="latest.hips_cm != null"><dt>Бёдра</dt><dd>{{ fmtValue(latest.hips_cm) }} см</dd></div>
          <div v-if="latest.chest_cm != null"><dt>Грудь</dt><dd>{{ fmtValue(latest.chest_cm) }} см</dd></div>
          <div v-if="latest.biceps_cm != null"><dt>Бицепс</dt><dd>{{ fmtValue(latest.biceps_cm) }} см</dd></div>
          <div v-if="latest.thigh_cm != null"><dt>Бедро</dt><dd>{{ fmtValue(latest.thigh_cm) }} см</dd></div>
          <div v-if="latest.bmi != null"><dt>ИМТ</dt><dd>{{ fmtValue(latest.bmi) }}</dd></div>
          <div v-if="latest.body_fat_pct != null"><dt>Процент жира</dt><dd>{{ fmtValue(latest.body_fat_pct) }}%</dd></div>
          <div v-if="latest.muscle_mass_kg != null"><dt>Мышечная масса</dt><dd>{{ fmtValue(latest.muscle_mass_kg) }} кг</dd></div>
          <div><dt>Самочувствие</dt><dd>{{ wellbeingLabel }}</dd></div>
        </dl>
        <div class="progress-latest-actions">
          <button v-if="!props.readOnly" type="button" class="primary card-primary progress-latest-edit" @click="emit('edit', latest.id)">Редактировать</button>
          <SendToClientButton :item-type="'progress'" :item-id="latest.id" :can-manage="props.canManage" compact />
          <SendToTrainerButton :item-type="'progress'" :item-id="latest.id" :can-send="props.hasTrainer && !props.canManage && !props.readOnly" compact />
        </div>
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
        <option value="hips_cm:1">Бёдра: меньше</option>
        <option value="hips_cm:-1">Бёдра: больше</option>
        <option value="chest_cm:1">Грудь: меньше</option>
        <option value="chest_cm:-1">Грудь: больше</option>
        <option value="biceps_cm:1">Бицепс: меньше</option>
        <option value="biceps_cm:-1">Бицепс: больше</option>
        <option value="thigh_cm:1">Бедро: меньше</option>
        <option value="thigh_cm:-1">Бедро: больше</option>
      </select>
    </Toolbar>

    <div class="progress-grid">
      <article v-for="item in shown" :key="item.id" class="progress-tile">
        <div class="progress-tile-head"><strong>{{ formatDate(item.measured_at) }}</strong><span>ЗАМЕР</span></div>
        <div class="progress-history-rows">
          <div><span>Вес</span><b>{{ fmtValue(item.weight_kg) }} кг</b></div>
          <div><span>Желаемый вес</span><b>{{ fmtValue(item.desired_weight_kg) }} кг</b></div>
          <div v-if="item.waist_cm != null"><span>Талия</span><b>{{ fmtValue(item.waist_cm) }} см</b></div>
          <div v-if="item.hips_cm != null"><span>Бёдра</span><b>{{ fmtValue(item.hips_cm) }} см</b></div>
          <div v-if="item.chest_cm != null"><span>Грудь</span><b>{{ fmtValue(item.chest_cm) }} см</b></div>
          <div v-if="item.biceps_cm != null"><span>Бицепс</span><b>{{ fmtValue(item.biceps_cm) }} см</b></div>
          <div v-if="item.thigh_cm != null"><span>Бедро</span><b>{{ fmtValue(item.thigh_cm) }} см</b></div>
          <div v-if="item.bmi != null"><span>ИМТ</span><b>{{ fmtValue(item.bmi) }}</b></div>
          <div v-if="item.body_fat_pct != null"><span>Процент жира</span><b>{{ fmtValue(item.body_fat_pct) }}%</b></div>
          <div v-if="item.muscle_mass_kg != null"><span>Мышечная масса</span><b>{{ fmtValue(item.muscle_mass_kg) }} кг</b></div>
          <div><span>Самочувствие</span><b>{{ fmtValue(item.wellbeing_score) }} / 5</b></div>
        </div>
        <div class="progress-tile-actions">
          <button type="button" class="primary card-primary progress-open-button" @click="emit('edit', item.id)">Открыть</button>
          <button v-if="!props.readOnly" type="button" class="icon-action edit-progress-tile" aria-label="Изменить замер" title="Изменить замер" @click="emit('edit', item.id)">✎</button>
          <button v-if="!props.readOnly" type="button" class="icon-action danger-icon delete-progress-tile" aria-label="Удалить замер" title="Удалить замер" @click="remove(item.id)">×</button>
          <SendToClientButton :item-type="'progress'" :item-id="item.id" :can-manage="props.canManage" compact />
          <SendToTrainerButton :item-type="'progress'" :item-id="item.id" :can-send="props.hasTrainer && !props.canManage && !props.readOnly" compact />
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

.progress-measurements-card {
  min-height: 420px;
  padding: 32px;
  border: 1px solid #e5eaf2;
  border-radius: 20px;
  background: #fff;
}

.progress-measurement-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 26px;
  padding-bottom: 14px;
  border-bottom: 1px solid #e5eaf2;
}

.progress-measurement-tab {
  min-height: 34px;
  padding: 0 13px;
  border: 1px solid #d9e2ec;
  border-radius: 9px;
  background: #f6f8fc;
  color: #7d879b;
  font-size: 11px;
  font-weight: 800;
  cursor: pointer;
}

.progress-measurement-tab:hover,
.progress-measurement-tab.active {
  border-color: #6f82ff;
  background: #eef0ff;
  color: #6f82ff;
}

.progress-measurement-table-wrap {
  margin-top: 14px;
  overflow-x: auto;
}

.progress-measurement-table {
  width: 100%;
  min-width: 320px;
  border-collapse: collapse;
}

.progress-measurement-table th,
.progress-measurement-table td {
  padding: 13px 12px;
  border-bottom: 1px solid #eef1f6;
  text-align: left;
}

.progress-measurement-table th {
  color: #7d879b;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .08em;
  text-transform: uppercase;
}

.progress-measurement-table td {
  color: #172033;
  font-size: 12px;
}

.progress-measurement-table td:last-child,
.progress-measurement-table th:last-child {
  width: 42%;
  text-align: right;
}

.progress-measurement-table td strong {
  font-size: 14px;
}

@media (max-width: 650px) {
  .progress-measurements-card {
    min-height: 350px;
    padding: 22px;
  }

  .progress-measurement-tabs {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 12px;
  }

  .progress-measurement-tab {
    flex: 0 0 auto;
  }
}
</style>
