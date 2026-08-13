<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { mealOrder } from '@/constants';
import type { DiaryEntry, ProgressEntry } from '@/types';
import { dayIso, diaryTotals, fmt, localToday } from '@/utils/format';
import CalendarModal from '@/components/modals/CalendarModal.vue';

const props = defineProps<{ refreshKey: number }>();
const emit = defineEmits<{ edit: [id: number] }>();

const data = ref<DiaryEntry[]>([]);
const progress = ref<ProgressEntry[]>([]);
const loading = ref(false);
const error = ref('');
const now = new Date();
const currentMonthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
const month = ref(currentMonthKey);
const calendarMode = ref<'month' | 'day' | null>(null);
const selectedDate = ref(localToday());
const monthInput = ref(currentMonthKey);

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const [diaryData, progressData] = await Promise.all([api.diary(), api.progress()]);
    data.value = diaryData;
    progress.value = progressData;
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const todayIso = computed(() => localToday());
const todayItems = computed(() => data.value.filter((item) => item.entry_date === todayIso.value));
const todayTotals = computed(() => diaryTotals(todayItems.value));
const latestProgress = computed(() => progress.value[0]);
const proteinTarget = computed(() => Number(latestProgress.value?.protein_target_g) || 0);
const fatTarget = computed(() => Number(latestProgress.value?.fat_target_g) || 0);
const todayLabel = computed(() => new Intl.DateTimeFormat('ru-RU', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()));

const monthKeys = computed(() => {
  const keys = new Set([currentMonthKey, ...data.value.map((item) => item.entry_date.slice(0, 7)), month.value]);
  return [...keys].sort().reverse();
});

const monthDate = computed(() => {
  const [year, monthNumber] = month.value.split('-').map(Number);
  return { year, monthIndex: monthNumber - 1 };
});

const monthLabel = computed(() => new Intl.DateTimeFormat('ru-RU', { month: 'long', year: 'numeric' }).format(new Date(monthDate.value.year, monthDate.value.monthIndex, 1)));
const monthItems = computed(() => data.value.filter((item) => item.entry_date.startsWith(month.value)));
const monthTotals = computed(() => diaryTotals(monthItems.value));
const filledDays = computed(() => new Set(monthItems.value.map((item) => item.entry_date)).size);
const monthDays = computed(() => new Date(monthDate.value.year, monthDate.value.monthIndex + 1, 0).getDate());
const monthOffset = computed(() => (new Date(monthDate.value.year, monthDate.value.monthIndex, 1).getDay() + 6) % 7);

const selectedDayItems = computed(() => data.value.filter((item) => item.entry_date === selectedDate.value));
const selectedDayTotals = computed(() => diaryTotals(selectedDayItems.value));
const selectedDayLabel = computed(() => new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(`${selectedDate.value}T12:00:00`)));

function openMonthChooser() {
  monthInput.value = month.value;
  calendarMode.value = 'month';
}

function selectMonth(key: string) {
  if (!key) return;
  month.value = key;
  calendarMode.value = null;
}

function openDay(iso: string) {
  selectedDate.value = iso;
  calendarMode.value = 'day';
}

function itemsForDay(day: number) {
  const iso = dayIso(monthDate.value.year, monthDate.value.monthIndex, day);
  return monthItems.value.filter((item) => item.entry_date === iso);
}

function entryCaption(item: DiaryEntry) {
  if (item.product_id) {
    const quantity = item.measurement_quantity != null && item.measurement_name
      ? `${fmt(item.measurement_quantity)} ${item.measurement_name}`
      : `${fmt(item.quantity)} ${item.unit || ''}`;
    return `${quantity}${item.comment ? ` · ${item.comment}` : ''}`;
  }
  return `${fmt(item.servings)} порц.${item.comment ? ` · ${item.comment}` : ''}`;
}

function mealTotal(meal: string) {
  return diaryTotals(selectedDayItems.value.filter((item) => item.meal_type === meal));
}

async function removeEntry(id: number) {
  if (!confirm('Удалить запись из дневника? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`diary/${id}`);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

function editEntry(id: number) {
  calendarMode.value = null;
  emit('edit', id);
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <button type="button" class="current-day-card" @click="openDay(todayIso)">
      <div class="current-day-head">
        <div>
          <p class="eyebrow">СЕГОДНЯ</p>
          <h2>{{ todayLabel }}</h2>
        </div>
        <span>Открыть день →</span>
      </div>
      <div class="current-day-body">
        <div class="today-meals">
          <template v-for="meal in mealOrder" :key="meal">
            <div v-if="todayItems.filter((item) => item.meal_type === meal).length" class="today-meal-row">
              <span>{{ meal }}</span>
              <b>{{ todayItems.filter((item) => item.meal_type === meal).map((item) => item.name).join(', ') }}</b>
              <small>{{ fmt(diaryTotals(todayItems.filter((item) => item.meal_type === meal)).kcal) }} ккал</small>
            </div>
          </template>
          <div v-if="!todayItems.length" class="today-empty">
            <b>Записей пока нет</b>
            <small>Добавь блюда через кнопку «Добавить»</small>
          </div>
        </div>
        <div class="today-kbju">
          <span><b>{{ fmt(todayTotals.kcal) }}</b><small>ккал</small></span>
          <span :class="{ 'goal-met': proteinTarget && todayTotals.protein >= proteinTarget }">
            <b>{{ fmt(todayTotals.protein) }}</b>
            <small class="goal-label">
              <template v-if="proteinTarget">{{ fmt(Math.max(proteinTarget - todayTotals.protein, 0)) }} г осталось до нормы</template>
              <template v-else>белки</template>
            </small>
          </span>
          <span :class="{ 'goal-exceeded': fatTarget && todayTotals.fat > fatTarget }">
            <b>{{ fmt(todayTotals.fat) }}</b>
            <small class="goal-label">
              <template v-if="fatTarget && todayTotals.fat <= fatTarget">{{ fmt(fatTarget - todayTotals.fat) }} г осталось до максимума</template>
              <template v-else-if="fatTarget">{{ fmt(todayTotals.fat - fatTarget) }} г выше максимума</template>
              <template v-else>жиры</template>
            </small>
          </span>
          <span><b>{{ fmt(todayTotals.carbs) }}</b><small>углеводы</small></span>
          <span class="today-cost"><b>{{ fmt(todayTotals.cost) }} RSD</b><small>стоимость дня</small></span>
        </div>
      </div>
    </button>

    <div class="diary-month-head">
      <div>
        <p class="eyebrow">ДНЕВНИК ПИТАНИЯ</p>
        <h2>{{ monthLabel }}</h2>
      </div>
      <button type="button" class="change-month" @click="openMonthChooser">▦ Сменить месяц</button>
    </div>

    <div class="diary-summary month-summary">
      <div><span>Заполненных дней</span><b>{{ filledDays }}</b></div>
      <div><span>Средний белок в день</span><b>{{ filledDays ? `${fmt(monthTotals.protein / filledDays)} г` : '—' }}</b></div>
      <div><span>Средние жиры в день</span><b>{{ filledDays ? `${fmt(monthTotals.fat / filledDays)} г` : '—' }}</b></div>
      <div><span>Калории за месяц</span><b>{{ fmt(monthTotals.kcal) }}</b></div>
      <div><span>Среднее за заполненный день</span><b>{{ filledDays ? fmt(monthTotals.kcal / filledDays) : '—' }}</b></div>
    </div>

    <section class="diary-days-panel">
      <div class="diary-weekdays">
        <span>Пн</span><span>Вт</span><span>Ср</span><span>Чт</span><span>Пт</span><span>Сб</span><span>Вс</span>
      </div>
      <div class="diary-day-grid">
        <span v-for="blank in monthOffset" :key="`blank-${blank}`" class="diary-day-blank"></span>
        <button
          v-for="day in monthDays"
          :key="day"
          type="button"
          class="diary-day-card"
          :class="{ filled: itemsForDay(day).length }"
          @click="openDay(dayIso(monthDate.year, monthDate.monthIndex, day))"
        >
          <span class="diary-day-number">{{ day }}</span>
          <span class="diary-day-copy">
            <b>{{ itemsForDay(day).length ? `${itemsForDay(day).length} ${itemsForDay(day).length === 1 ? 'запись' : 'записи'}` : 'Нет записей' }}</b>
            <small>{{ itemsForDay(day).length ? `${new Set(itemsForDay(day).map((item) => item.meal_type)).size} приём. · ${fmt(diaryTotals(itemsForDay(day)).kcal)} ккал` : 'Открыть день' }}</small>
          </span>
          <span class="diary-day-arrow">→</span>
        </button>
      </div>
    </section>
  </template>

  <CalendarModal :open="calendarMode === 'month'" title="Выберите месяц" @close="calendarMode = null">
    <div class="month-picker-row">
      <input v-model="monthInput" type="month" aria-label="Месяц">
      <button type="button" class="primary" @click="selectMonth(monthInput)">Показать</button>
    </div>
    <p class="subtle month-choice-label">Месяцы с сохранёнными записями</p>
    <div class="month-choice-grid">
      <button v-for="key in monthKeys" :key="key" type="button" class="month-choice" :class="{ active: key === month }" @click="selectMonth(key)">
        <span>{{ new Intl.DateTimeFormat('ru-RU', { month: 'long', year: 'numeric' }).format(new Date(`${key}-01T12:00:00`)) }}</span>
        <b>{{ new Set(data.filter((item) => item.entry_date.startsWith(key)).map((item) => item.entry_date)).size }}</b>
        <small>{{ fmt(diaryTotals(data.filter((item) => item.entry_date.startsWith(key))).kcal) }} ккал</small>
      </button>
    </div>
  </CalendarModal>

  <CalendarModal :open="calendarMode === 'day'" :title="selectedDayLabel" @close="calendarMode = null">
    <button type="button" class="calendar-back" @click="calendarMode = null">← Закрыть день</button>
    <template v-for="meal in mealOrder" :key="meal">
      <section v-if="selectedDayItems.filter((item) => item.meal_type === meal).length" class="meal-group">
        <h3>{{ meal }} <span class="meal-cost">{{ fmt(mealTotal(meal).cost) }} RSD</span></h3>
        <template v-for="item in selectedDayItems.filter((entry) => entry.meal_type === meal)" :key="item.id">
          <button type="button" class="meal-entry" @click="editEntry(item.id)">
            <span><b>{{ item.name }}</b><small>{{ entryCaption(item) }}</small></span>
            <strong>{{ fmt((Number(item.kcal_per_serving) || 0) * (Number(item.servings) || 0)) }} ккал</strong>
          </button>
          <div class="diary-entry-actions">
            <button type="button" class="edit-diary-entry" @click="editEntry(item.id)">Редактировать</button>
            <button type="button" class="delete-diary-entry" @click="removeEntry(item.id)">Удалить</button>
          </div>
        </template>
      </section>
    </template>
    <div v-if="!selectedDayItems.length" class="empty day-empty">В этот день записей пока нет</div>
    <div class="day-total">
      <h3>Итого за день</h3>
      <div>
        <span><b>{{ fmt(selectedDayTotals.kcal) }}</b><small>ккал</small></span>
        <span><b>{{ fmt(selectedDayTotals.protein) }}</b><small>белки</small></span>
        <span><b>{{ fmt(selectedDayTotals.fat) }}</b><small>жиры</small></span>
        <span><b>{{ fmt(selectedDayTotals.carbs) }}</b><small>углеводы</small></span>
        <span class="day-cost"><b>{{ fmt(selectedDayTotals.cost) }} RSD</b><small>стоимость дня</small></span>
      </div>
    </div>
  </CalendarModal>
</template>

<style lang="scss">
.diary-day-grid {
  align-items: stretch;
}
</style>
