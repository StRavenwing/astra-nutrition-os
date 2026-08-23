<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { mealOrder } from '@/constants';
import type { DiaryEntry, ProgressEntry } from '@/types';
import { dayIso, diaryTotals, fmt, localToday } from '@/utils/format';
import CalendarModal from '@/components/modals/CalendarModal.vue';

const props = defineProps<{ refreshKey: number; readOnly?: boolean }>();
const emit = defineEmits<{ edit: [id: number]; add: [mealType?: string] }>();

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
function targetValue(value: number | null | undefined) {
  return value != null && Number.isFinite(Number(value)) ? Number(value) : null;
}

const weightTarget = computed(() => {
  const weight = targetValue(latestProgress.value?.weight_kg);
  return weight != null && weight > 0 ? weight : null;
});
const enteredKcalTarget = computed(() => targetValue(latestProgress.value?.kcal_target));
const proteinTarget = computed(() => targetValue(latestProgress.value?.protein_target_g) ?? (weightTarget.value != null ? weightTarget.value * 2 : null));
const fatTarget = computed(() => targetValue(latestProgress.value?.fat_target_g) ?? weightTarget.value);
const carbsTarget = computed(() => targetValue(latestProgress.value?.carbs_target_g) ?? (weightTarget.value != null ? weightTarget.value * 3 : null));
const calculatedKcalTarget = computed(() => (
  proteinTarget.value != null && fatTarget.value != null && carbsTarget.value != null
    ? proteinTarget.value * 4 + fatTarget.value * 9 + carbsTarget.value * 4
    : null
));
const kcalTarget = computed(() => enteredKcalTarget.value ?? calculatedKcalTarget.value);
const calculatedMacroTargets = computed(() => weightTarget.value != null && (
  targetValue(latestProgress.value?.protein_target_g) == null
  || targetValue(latestProgress.value?.fat_target_g) == null
  || targetValue(latestProgress.value?.carbs_target_g) == null
));
const hasNutritionTargets = computed(() => [kcalTarget.value, proteinTarget.value, fatTarget.value, carbsTarget.value].some((target) => target != null));
const targetSourceNote = computed(() => {
  const notes = [];
  if (calculatedMacroTargets.value) notes.push('для незаданных макронутриентов: белки — 2, жиры — 1, углеводы — 3 г на кг массы тела');
  if (enteredKcalTarget.value == null && calculatedKcalTarget.value != null) notes.push('калории: белки × 4 + жиры × 9 + углеводы × 4');
  return notes.length ? `Расчёт: ${notes.join('; ')}.` : '';
});
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
const averageKcal = computed(() => filledDays.value ? monthTotals.value.kcal / filledDays.value : 0);
const averageProtein = computed(() => filledDays.value ? monthTotals.value.protein / filledDays.value : 0);
const kcalDelta = computed(() => kcalTarget.value == null ? null : Math.round(kcalTarget.value - averageKcal.value));
const proteinDelta = computed(() => proteinTarget.value == null ? null : Math.round(proteinTarget.value - averageProtein.value));

function progressWidth(current: number, target: number | null) {
  return target != null && target > 0 ? Math.min(current / target * 100, 100) : 0;
}

function remaining(current: number, target: number | null) {
  return target == null ? 0 : Math.max(target - current, 0);
}

function isExceeded(current: number, target: number | null) {
  return target != null && current > target;
}

function targetStatus(current: number, target: number | null, doneLabel: string) {
  return target != null && current >= target ? doneLabel : `осталось ${fmt(remaining(current, target))} г`;
}

function dayProgress(day: number) {
  const items = itemsForDay(day);
  if (!items.length) return 'empty';
  const kcal = diaryTotals(items).kcal;
  return kcalTarget.value != null && kcal >= kcalTarget.value * 0.8 ? 'complete' : 'partial';
}

function openMonthChooser() {
  monthInput.value = month.value;
  calendarMode.value = 'month';
}

function selectMonth(key: string) {
  if (!key) return;
  month.value = key;
  calendarMode.value = null;
}

function shiftMonth(delta: number) {
  const date = new Date(monthDate.value.year, monthDate.value.monthIndex + delta, 1);
  month.value = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

function selectCurrentMonth() {
  month.value = currentMonthKey;
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
  if (props.readOnly) return;
  if (!confirm('Удалить запись из дневника? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`diary/${id}`);
    await load();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

function editEntry(id: number) {
  if (props.readOnly) return;
  calendarMode.value = null;
  emit('edit', id);
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <p class="diary-page-subtitle">Food Calendar помогает увидеть ритм без лишнего контроля</p>
    <section class="diary-current-day">
      <div class="diary-current-banner">
        <div>
          <p class="eyebrow">FOOD CALENDAR</p>
          <h2>{{ todayLabel }}</h2>
        </div>
        <div class="diary-current-stats">
          <span><small>Заполнено дней в месяце</small><b>{{ filledDays }}</b></span>
          <span><small>Средняя стоимость дня</small><b>{{ fmt(filledDays ? monthTotals.cost / filledDays : 0) }} RSD</b></span>
        </div>
        <button type="button" class="today-badge" @click="openDay(todayIso)">Сегодня</button>
      </div>
    </section>

    <div class="diary-widget-heading">
      <h2>Виджет текущего дня</h2>
      <p>Список блюд по приёмам пищи и состояние дневной нормы</p>
    </div>

    <div class="diary-current-grid">
      <section class="diary-meals-card">
        <p class="eyebrow">{{ todayLabel }}</p>
        <h2>Сегодня</h2>
        <div class="diary-meal-list">
          <template v-for="meal in mealOrder" :key="meal">
            <article v-if="todayItems.filter((item) => item.meal_type === meal).length" class="diary-meal-card">
              <span class="diary-meal-icon">{{ meal.slice(0, 1) }}</span>
              <div>
                <b>{{ meal }}</b>
                <small>{{ todayItems.filter((item) => item.meal_type === meal).length }} блюда · {{ fmt(diaryTotals(todayItems.filter((item) => item.meal_type === meal)).kcal) }} ккал</small>
                <p>{{ todayItems.filter((item) => item.meal_type === meal).map((item) => item.name).join(' · ') }}</p>
              </div>
              <strong>{{ fmt(diaryTotals(todayItems.filter((item) => item.meal_type === meal)).kcal) }} ккал<small>белок {{ fmt(diaryTotals(todayItems.filter((item) => item.meal_type === meal)).protein) }} г</small></strong>
            </article>
          </template>
          <template v-for="meal in mealOrder" :key="`empty-${meal}`">
            <article v-if="!todayItems.filter((item) => item.meal_type === meal).length && (meal === 'Ужин' || meal === 'Перекус')" class="diary-meal-card diary-meal-empty">
              <span class="diary-meal-icon">{{ meal.slice(0, 1) }}</span>
              <div><b>{{ meal }}</b><small>Ещё не добавлен</small></div>
              <button v-if="!props.readOnly" type="button" class="diary-add-meal" @click="emit('add', meal)">＋ Добавить</button>
            </article>
          </template>
          <div v-if="!todayItems.length" class="today-empty"><b>Записей пока нет</b><small>Добавьте блюдо через кнопку «Запись»</small></div>
        </div>
      </section>

      <aside v-if="hasNutritionTargets" class="diary-norm-card">
        <h2>Норма за день</h2>
        <p>Остаток показывается при наличии нормы</p>
        <div v-if="kcalTarget != null" class="diary-norm-item norm-kcal"><span>КАЛОРИИ</span><b>{{ fmt(todayTotals.kcal) }} / {{ fmt(kcalTarget) }} ккал</b><small>Осталось {{ fmt(remaining(todayTotals.kcal, kcalTarget)) }} ккал</small><i><em :style="{ width: `${progressWidth(todayTotals.kcal, kcalTarget)}%` }"></em></i></div>
        <div v-if="proteinTarget != null" class="diary-norm-item norm-protein"><span>БЕЛОК</span><b>{{ fmt(todayTotals.protein) }} / {{ fmt(proteinTarget) }} г</b><small>Осталось {{ fmt(remaining(todayTotals.protein, proteinTarget)) }} г</small><i><em :style="{ width: `${progressWidth(todayTotals.protein, proteinTarget)}%` }"></em></i></div>
        <div v-if="fatTarget != null" class="diary-norm-item norm-fat" :class="{ exceeded: isExceeded(todayTotals.fat, fatTarget) }"><span>ЖИРЫ · МАКСИМУМ</span><b>{{ fmt(todayTotals.fat) }} / {{ fmt(fatTarget) }} г</b><small>{{ isExceeded(todayTotals.fat, fatTarget) ? `Превышено на ${fmt(todayTotals.fat - (fatTarget || 0))} г` : `Осталось ${fmt(remaining(todayTotals.fat, fatTarget))} г` }}</small><i><em :style="{ width: `${progressWidth(todayTotals.fat, fatTarget)}%` }"></em></i></div>
        <div v-if="carbsTarget != null" class="diary-norm-item norm-carbs"><span>УГЛЕВОДЫ</span><b>{{ fmt(todayTotals.carbs) }} / {{ fmt(carbsTarget) }} г</b><small>Осталось {{ fmt(remaining(todayTotals.carbs, carbsTarget)) }} г</small><i><em :style="{ width: `${progressWidth(todayTotals.carbs, carbsTarget)}%` }"></em></i></div>
        <small v-if="targetSourceNote" class="diary-norm-note">{{ targetSourceNote }}</small>
      </aside>
    </div>

    <div class="diary-average-heading">
      <div><h2>Средние показатели месяца</h2><p>Отдельно от виджета текущего дня · по заполненным дням</p></div>
      <span>{{ filledDays }} заполненных дней</span>
    </div>
    <div class="diary-average-grid">
      <article v-if="kcalTarget != null" class="diary-average-card average-kcal">
        <span>СРЕДНЯЯ КАЛОРИЙНОСТЬ</span><b>{{ fmt(averageKcal) }} ккал</b><small>в день · цель {{ fmt(kcalTarget) }} ккал</small><strong>{{ kcalDelta != null && kcalDelta >= 0 ? '−' : '+' }}{{ fmt(Math.abs(kcalDelta || 0)) }}</strong>
        <svg viewBox="0 0 420 64" aria-hidden="true"><path d="M2 48H418M2 26H418"/><polyline points="2,38 32,28 62,36 92,22 122,31 152,25 182,16 212,30 242,19 272,25 302,12 332,22 362,8 392,18 418,6"/></svg>
      </article>
      <article v-if="proteinTarget != null" class="diary-average-card average-protein">
        <span>СРЕДНИЙ БЕЛОК</span><b>{{ fmt(averageProtein) }} г</b><small>в день · цель {{ fmt(proteinTarget) }} г</small><strong>{{ proteinDelta != null && proteinDelta >= 0 ? '−' : '+' }}{{ fmt(Math.abs(proteinDelta || 0)) }} г</strong>
        <svg viewBox="0 0 420 64" aria-hidden="true"><path d="M2 48H418M2 26H418"/><polyline points="2,42 32,35 62,29 92,38 122,24 152,33 182,18 212,28 242,16 272,23 302,12 332,20 362,8 392,16 418,5"/></svg>
      </article>
    </div>

    <div class="diary-month-head diary-calendar-heading">
      <div>
        <h2>Календарь питания</h2>
        <p>Нажмите на день, чтобы открыть подробное содержание</p>
      </div>
      <div class="diary-calendar-actions">
        <button type="button" class="change-month" aria-label="Предыдущий месяц" @click="shiftMonth(-1)">‹</button>
        <button type="button" class="change-month" @click="openMonthChooser">{{ monthLabel }}</button>
        <button type="button" class="primary" @click="selectCurrentMonth">Сегодня</button>
      </div>
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
          :class="[dayProgress(day), { filled: itemsForDay(day).length, today: dayIso(monthDate.year, monthDate.monthIndex, day) === todayIso }]"
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
    <div class="diary-day-summary">
      <div><span>ИТОГ ЗА ДЕНЬ</span><b>{{ selectedDayItems.length }} приёма · {{ fmt(selectedDayTotals.kcal) }} ккал · белок {{ fmt(selectedDayTotals.protein) }} г · жиры {{ fmt(selectedDayTotals.fat) }} г</b></div>
      <button v-if="!props.readOnly" type="button" class="diary-day-edit" @click="emit('add'); calendarMode = null">Изменить день</button>
    </div>
    <template v-for="meal in mealOrder" :key="meal">
      <section class="meal-group diary-popup-meal-group">
        <h3>{{ meal }} <span class="meal-cost">{{ fmt(mealTotal(meal).cost) }} RSD</span></h3>
        <template v-for="item in selectedDayItems.filter((entry) => entry.meal_type === meal)" :key="item.id">
          <button type="button" class="meal-entry" :disabled="props.readOnly" @click="editEntry(item.id)">
            <span><b>{{ item.name }}</b><small>{{ entryCaption(item) }}</small></span>
            <strong>{{ fmt((Number(item.kcal_per_serving) || 0) * (Number(item.servings) || 0)) }} ккал</strong>
          </button>
          <div v-if="!props.readOnly" class="diary-entry-actions">
            <button type="button" class="edit-diary-entry" @click="editEntry(item.id)">Редактировать</button>
            <button type="button" class="delete-diary-entry" @click="removeEntry(item.id)">Удалить</button>
          </div>
        </template>
        <button v-if="!props.readOnly" type="button" class="diary-calendar-add" @click="emit('add', meal); calendarMode = null">＋ Добавить блюдо в {{ meal.toLowerCase() }}</button>
      </section>
    </template>
    <div v-if="!selectedDayItems.length" class="empty day-empty">В этот день записей пока нет</div>
    <div v-if="hasNutritionTargets" class="day-total diary-popup-nutrients">
      <h3>Нутриенты дня</h3>
      <div>
        <span v-if="kcalTarget != null"><b>{{ fmt(selectedDayTotals.kcal) }} / {{ fmt(kcalTarget) }}</b><small>калории · осталось {{ fmt(remaining(selectedDayTotals.kcal, kcalTarget)) }}</small></span>
        <span v-if="proteinTarget != null" class="nutrient-protein"><b>{{ fmt(selectedDayTotals.protein) }} / {{ fmt(proteinTarget) }} г</b><small>белок · {{ targetStatus(selectedDayTotals.protein, proteinTarget, 'норма достигнута') }}</small></span>
        <span v-if="fatTarget != null" class="nutrient-fat"><b>{{ fmt(selectedDayTotals.fat) }} / {{ fmt(fatTarget) }} г</b><small>жиры · {{ targetStatus(selectedDayTotals.fat, fatTarget, 'максимум достигнут') }}</small></span>
        <span v-if="carbsTarget != null" class="nutrient-carbs"><b>{{ fmt(selectedDayTotals.carbs) }} / {{ fmt(carbsTarget) }} г</b><small>углеводы · {{ targetStatus(selectedDayTotals.carbs, carbsTarget, 'норма достигнута') }}</small></span>
      </div>
      <small v-if="targetSourceNote" class="diary-norm-note">{{ targetSourceNote }}</small>
    </div>
    <div class="diary-popup-footer">
      <button type="button" class="secondary-button" @click="calendarMode = null">Отмена</button>
      <button v-if="!props.readOnly" type="button" class="primary" @click="emit('add'); calendarMode = null">＋ Добавить запись</button>
    </div>
  </CalendarModal>
</template>

<style lang="scss">
.diary-day-grid {
  align-items: stretch;
}
</style>
