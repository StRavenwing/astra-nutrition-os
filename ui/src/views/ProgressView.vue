<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { ProgressEntry, SortState } from '@/types';
import { compareValues, formatDate, fmt, fmtValue, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';

const props = defineProps<{ refreshKey: number }>();
const emit = defineEmits<{ edit: [id: number] }>();

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
    <section v-if="latest" class="current-progress-card">
      <div class="current-progress-head">
        <div>
          <p class="eyebrow">ТЕКУЩИЕ ПОКАЗАТЕЛИ</p>
          <h2>{{ formatDate(latest.measured_at) }}</h2>
        </div>
        <span class="current-badge">Текущий замер</span>
      </div>
      <div class="current-progress-main">
        <span v-for="item in [metric(latest.weight_kg, 'Вес', 'кг'), metric(latest.height_cm, 'Рост', 'см'), metric(latest.bmi, 'ИМТ'), metric(latest.waist_cm, 'Талия', 'см')]" :key="item.label">
          <b>{{ fmtValue(item.value) }}<i v-if="item.value != null && item.unit"> {{ item.unit }}</i></b>
          <small>{{ item.label }}</small>
        </span>
      </div>
      <div class="current-progress-details">
        <div>
          <h4>Состав тела</h4>
          <div class="progress-metrics body-composition">
            <span v-for="item in [metric(latest.body_fat_pct, 'Жир', '%'), metric(latest.fat_mass_kg, 'Масса жира', 'кг'), metric(latest.muscle_pct, 'Мышцы', '%'), metric(latest.muscle_mass_kg, 'Мышечная масса', 'кг')]" :key="item.label">
              <b>{{ fmtValue(item.value) }}<i v-if="item.value != null && item.unit"> {{ item.unit }}</i></b><small>{{ item.label }}</small>
            </span>
          </div>
        </div>
        <div>
          <h4>Нормы питания</h4>
          <div class="progress-metrics">
            <span v-for="item in [metric(latest.protein_target_g, 'Белок', 'г'), metric(latest.fat_target_g, 'Жиры', 'г')]" :key="item.label">
              <b>{{ fmtValue(item.value) }}<i v-if="item.value != null && item.unit"> {{ item.unit }}</i></b><small>{{ item.label }}</small>
            </span>
          </div>
        </div>
        <div>
          <h4>Замеры и самочувствие</h4>
          <div class="progress-metrics">
            <span v-for="item in [metric(latest.chest_cm, 'Грудь', 'см'), metric(latest.hips_cm, 'Бёдра', 'см'), metric(latest.sleep_score, 'Сон', '/5'), metric(latest.wellbeing_score, 'Самочувствие', '/5')]" :key="item.label">
              <b>{{ fmtValue(item.value) }}<i v-if="item.value != null && item.unit"> {{ item.unit }}</i></b><small>{{ item.label }}</small>
            </span>
          </div>
        </div>
      </div>
      <p v-if="latest.comment" class="progress-comment">{{ latest.comment }}</p>
      <div class="progress-tile-actions current-progress-actions">
        <button type="button" class="edit-progress-tile" @click="emit('edit', latest.id)">✎ Редактировать</button>
        <button type="button" class="delete-progress-tile" @click="remove(latest.id)">Удалить</button>
      </div>
    </section>
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
        <div class="progress-tile-head">
          <span class="progress-date">{{ formatDate(item.measured_at) }}</span>
        </div>
        <div class="progress-primary">
          <span v-for="metricItem in [metric(item.weight_kg, 'Вес', 'кг'), metric(item.height_cm, 'Рост', 'см'), metric(item.bmi, 'ИМТ')]" :key="metricItem.label">
            <b>{{ fmtValue(metricItem.value) }}<i v-if="metricItem.value != null && metricItem.unit"> {{ metricItem.unit }}</i></b><small>{{ metricItem.label }}</small>
          </span>
        </div>
        <h4>Состав тела</h4>
        <div class="progress-metrics body-composition">
          <span v-for="metricItem in [metric(item.body_fat_pct, 'Жир', '%'), metric(item.fat_mass_kg, 'Масса жира', 'кг'), metric(item.muscle_pct, 'Мышцы', '%'), metric(item.muscle_mass_kg, 'Мышечная масса', 'кг')]" :key="metricItem.label">
            <b>{{ fmtValue(metricItem.value) }}<i v-if="metricItem.value != null && metricItem.unit"> {{ metricItem.unit }}</i></b><small>{{ metricItem.label }}</small>
          </span>
        </div>
        <h4>Замеры и самочувствие</h4>
        <div class="progress-metrics">
          <span v-for="metricItem in [metric(item.waist_cm, 'Талия', 'см'), metric(item.chest_cm, 'Грудь', 'см'), metric(item.hips_cm, 'Бёдра', 'см'), metric(item.sleep_score, 'Сон', '/5'), metric(item.wellbeing_score, 'Самочувствие', '/5')]" :key="metricItem.label">
            <b>{{ fmtValue(metricItem.value) }}<i v-if="metricItem.value != null && metricItem.unit"> {{ metricItem.unit }}</i></b><small>{{ metricItem.label }}</small>
          </span>
        </div>
        <p v-if="item.comment" class="progress-comment">{{ item.comment }}</p>
        <div class="progress-tile-actions">
          <button type="button" class="edit-progress-tile" @click="emit('edit', item.id)">✎ Редактировать</button>
          <button type="button" class="delete-progress-tile" @click="remove(item.id)">Удалить</button>
        </div>
      </article>
      <div v-if="!shown.length" class="panel empty">Предыдущих замеров пока нет</div>
    </div>
  </template>
</template>

<style lang="scss">
.progress-grid {
  margin-top: 12px;
}
</style>
