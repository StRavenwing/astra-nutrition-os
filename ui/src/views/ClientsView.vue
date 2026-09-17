<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type {
  ClientDetail,
  ClientSummary,
  DiaryEntry,
  ProgressEntry,
  SharedItemDetail,
  TrainerChatMessage,
  TrainerTask,
  WorkoutPlan
} from '@/types';
import { diaryTotals, formatDateTime, fmt, localToday } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import DiaryEntryForm from '@/components/forms/DiaryEntryForm.vue';
import ProgressForm from '@/components/forms/ProgressForm.vue';
import WorkoutBuilderModal from '@/components/modals/WorkoutBuilderModal.vue';
import SharedItemModal from '@/components/modals/SharedItemModal.vue';

const props = defineProps<{ refreshKey: number; canAccess: boolean; isAdmin: boolean }>();
const emit = defineEmits<{ changed: []; feedback: [] }>();

type TabId = 'overview' | 'progress' | 'nutrition' | 'week' | 'history';
type HistoryFilter = 'all' | 'nutrition' | 'progress' | 'workout' | 'communication';

const clients = ref<ClientSummary[]>([]);
const selectedId = ref<number | null>(null);
const selected = ref<ClientDetail | null>(null);
const diary = ref<DiaryEntry[]>([]);
const tasks = ref<TrainerTask[]>([]);
const loading = ref(false);
const detailLoading = ref(false);
const error = ref('');
const activeTab = ref<TabId>('overview');

const addOpen = ref(false);
const email = ref('');
const addError = ref('');
const diaryOpen = ref(false);
const scheduleOpen = ref(false);
const editingPlan = ref<WorkoutPlan | null>(null);
const progressOpen = ref(false);
const progressFormKey = ref(0);
const editingProgress = ref<ProgressEntry | null>(null);
const targetsOpen = ref(false);
const historyFilter = ref<HistoryFilter>('all');
const chatOpen = ref(false);
const chatClient = ref<ClientSummary | null>(null);
const chatMessages = ref<TrainerChatMessage[]>([]);
const sharedItem = ref<SharedItemDetail | null>(null);
const chatText = ref('');
const chatError = ref('');
const taskOpen = ref(false);
const taskError = ref('');
const taskForm = reactive({ title: '', description: '', due_date: '' });
const rangeOpen = ref(false);
const rangeError = ref('');
const rangeDraft = reactive({ start: '', end: '' });
const range = reactive({ start: weekStart(), end: addDays(weekStart(), 6) });
const targets = reactive({ kcal_target: '', protein_target_g: '', fat_target_g: '', carbs_target_g: '' });

function isoDate(date: Date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function parseDate(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(`${value.slice(0, 10)}T12:00:00`);
  return Number.isNaN(date.getTime()) ? null : date;
}

function addDays(value: string, amount: number) {
  const date = parseDate(value) || new Date();
  date.setDate(date.getDate() + amount);
  return isoDate(date);
}

function weekStart(value = new Date()) {
  const date = new Date(value);
  date.setHours(12, 0, 0, 0);
  date.setDate(date.getDate() - ((date.getDay() + 6) % 7));
  return isoDate(date);
}

function formatShortDate(value: string | null | undefined) {
  const date = parseDate(value);
  return date ? date.toLocaleDateString('ru-RU', { day: '2-digit', month: 'short' }).replace('.', '') : '—';
}

function formatRangeDate(value: string) {
  const date = parseDate(value);
  return date ? date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' }) : value;
}

function formatRangeLabel(value: string) {
  const date = parseDate(value);
  return date ? date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' }).replace('.', '') : value;
}

function firstDate(value: string | null | undefined) {
  return value?.slice(0, 10) || '';
}

function displayName(client: ClientSummary) {
  return client.name || client.email.split('@')[0];
}

function initials(value: string) {
  return value.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase();
}

const selectedClient = computed(() => clients.value.find((client) => client.id === selectedId.value) || null);
const selectedName = computed(() => selected.value ? displayName(selected.value) : selectedClient.value ? displayName(selectedClient.value) : 'Клиент');
const dateRangeLabel = computed(() => `${formatRangeLabel(range.start)}–${formatRangeLabel(range.end)}`);
const sortedProgress = computed(() => [...(selected.value?.progress || [])].sort((a, b) => firstDate(a.measured_at).localeCompare(firstDate(b.measured_at))));
const startProgress = computed(() => sortedProgress.value[0] || null);
const currentProgress = computed(() => sortedProgress.value[sortedProgress.value.length - 1] || null);
const latestProgress = computed(() => currentProgress.value);

function targetValue(key: 'kcal' | 'protein' | 'fat' | 'carbs') {
  return selected.value?.today.targets[key] ?? null;
}

function metricValue(value: number | null | undefined, unit: string) {
  return value == null ? '—' : `${fmt(value)} ${unit}`;
}

function changeValue(current: number | null | undefined, start: number | null | undefined, unit: string) {
  if (current == null || start == null) return '—';
  const delta = Number(current) - Number(start);
  if (delta === 0) return `0 ${unit}`;
  return `${delta < 0 ? '−' : '+'}${fmt(Math.abs(delta))} ${unit}`;
}

const comparison = computed(() => [
  { label: 'Вес', start: startProgress.value?.weight_kg, current: currentProgress.value?.weight_kg, unit: 'кг' },
  { label: 'Грудь', start: startProgress.value?.chest_cm, current: currentProgress.value?.chest_cm, unit: 'см' },
  { label: 'Живот', start: startProgress.value?.waist_cm, current: currentProgress.value?.waist_cm, unit: 'см' },
  { label: 'Таз', start: startProgress.value?.hips_cm, current: currentProgress.value?.hips_cm, unit: 'см' },
  { label: 'Процент жира', start: startProgress.value?.body_fat_pct, current: currentProgress.value?.body_fat_pct, unit: '%' }
]);

const doneTasks = computed(() => tasks.value.filter((task) => task.status === 'done').length);
const taskProgress = computed(() => tasks.value.length ? Math.round(doneTasks.value / tasks.value.length * 100) : 0);
const nextCheckpoint = computed(() => currentProgress.value?.measured_at ? addDays(firstDate(currentProgress.value.measured_at), 14) : null);

function taskStatus(task: TrainerTask) {
  return task.status === 'done' ? 'готово' : task.due_date && task.due_date < localToday() ? 'просрочено' : task.due_date ? formatShortDate(task.due_date) : 'в работе';
}

function entriesForDate(date: string) {
  return diary.value.filter((entry) => firstDate(entry.entry_date) === date);
}

function plansForDate(date: string) {
  return (selected.value?.workout_plans || []).filter((plan) => firstDate(plan.scheduled_at) === date);
}

function logsForDate(date: string) {
  return (selected.value?.workouts || []).filter((workout) => firstDate(workout.performed_at) === date);
}

function workoutLabel(date: string) {
  const plans = plansForDate(date);
  const logs = logsForDate(date);
  const names = [...plans.map((plan) => plan.name || plan.items.map((item) => item.name || item.exercise_name).filter(Boolean).join(', ') || 'Тренировка'), ...logs.map((item) => item.name)];
  return names.length ? names.slice(0, 2).join(' · ') : '—';
}

function workoutDuration(date: string) {
  const duration = plansForDate(date).reduce((sum, plan) => sum + Number(plan.duration_minutes || 0), 0);
  return duration ? ` · ${duration} мин` : '';
}

const nutritionRows = computed(() => {
  const result: Array<{ date: string; entries: DiaryEntry[]; totals: ReturnType<typeof diaryTotals>; plan: number | null; workouts: string; review: 'done' | 'open' }> = [];
  let date = range.start;
  while (date <= range.end) {
    const entries = entriesForDate(date);
    const totals = diaryTotals(entries);
    const plan = targetValue('kcal');
    const hasWorkout = plansForDate(date).length > 0 || logsForDate(date).length > 0;
    const hasData = entries.length > 0 || hasWorkout;
    const review: 'done' | 'open' = hasData && (!plan || Math.abs(totals.kcal - plan) <= 250) ? 'done' : 'open';
    result.push({ date, entries, totals, plan, workouts: `${workoutLabel(date)}${workoutDuration(date)}`, review });
    date = addDays(date, 1);
  }
  return result;
});

const weekDays = computed(() => nutritionRows.value.map((row) => {
  const isToday = row.date === localToday();
  const complete = row.entries.length > 0 || plansForDate(row.date).some((plan) => plan.status !== 'planned') || logsForDate(row.date).length > 0;
  return { ...row, isToday, complete, caption: complete ? 'готово' : isToday ? 'сегодня' : 'план' };
}));

function chartY(value: number, min: number, max: number) {
  return max === min ? 82 : 132 - ((value - min) / (max - min)) * 96;
}

const chartPoints = computed(() => {
  const values = sortedProgress.value.filter((entry) => entry.weight_kg != null);
  if (!values.length) return '';
  const numbers = values.map((entry) => Number(entry.weight_kg));
  const min = Math.min(...numbers);
  const max = Math.max(...numbers);
  const padding = max === min ? 1 : Math.max((max - min) * 0.12, 0.4);
  const lower = min - padding;
  const upper = max + padding;
  return values.map((entry, index) => `${55 + (values.length === 1 ? 270 : index * 540 / (values.length - 1))},${chartY(Number(entry.weight_kg), lower, upper).toFixed(1)}`).join(' ');
});

const chartDots = computed(() => chartPoints.value.split(' ').filter(Boolean).map((point) => {
  const [cx, cy] = point.split(',').map(Number);
  return { cx, cy };
}));

const chartLabels = computed(() => {
  const values = sortedProgress.value.filter((entry) => entry.weight_kg != null);
  if (!values.length) return { first: '—', middle: '', last: '—', firstWeight: '—', lastWeight: '—' };
  const middle = values[Math.floor((values.length - 1) / 2)];
  return { first: formatShortDate(values[0].measured_at), middle: values.length > 2 ? formatShortDate(middle.measured_at) : '', last: formatShortDate(values[values.length - 1].measured_at), firstWeight: fmt(values[0].weight_kg), lastWeight: `${fmt(values[values.length - 1].weight_kg)} кг` };
});

type HistoryEvent = { id: string; date: string; title: string; detail: string; pill: string; category: HistoryFilter };

const historyEvents = computed<HistoryEvent[]>(() => {
  const events: HistoryEvent[] = [];
  const days = new Set(diary.value.map((entry) => firstDate(entry.entry_date)));
  days.forEach((date) => {
    const entries = entriesForDate(date);
    const totals = diaryTotals(entries);
    events.push({ id: `diary-${date}`, date, title: `Клиент внесла дневник за ${formatShortDate(date)}`, detail: `КБЖУ ${fmt(totals.kcal)} ккал · ${entries.length} ${entries.length === 1 ? 'запись' : 'записей'}`, pill: 'Питание', category: 'nutrition' });
  });
  sortedProgress.value.slice().reverse().forEach((entry) => {
    events.push({ id: `progress-${entry.id}`, date: firstDate(entry.measured_at), title: 'Добавлена контрольная точка', detail: [metricValue(entry.weight_kg, 'кг'), metricValue(entry.waist_cm, 'см талии'), entry.wellbeing_score ? `самочувствие ${entry.wellbeing_score}/5` : ''].filter(Boolean).join(' · '), pill: 'Замеры', category: 'progress' });
  });
  (selected.value?.workout_plans || []).forEach((plan) => {
    events.push({ id: `plan-${plan.id}`, date: firstDate(plan.scheduled_at), title: `${plan.status === 'planned' ? 'Запланирована' : 'Завершена'} тренировка`, detail: `${plan.name || 'Тренировка'} · ${plan.items.length} упражн.`, pill: 'Тренировки', category: 'workout' });
  });
  chatMessages.value.forEach((message) => {
    events.push({ id: `chat-${message.id}`, date: firstDate(message.created_at), title: `${message.sender_name} оставил(а) сообщение`, detail: message.message, pill: 'Комментарий', category: 'communication' });
  });
  if (selected.value?.created_at) events.push({ id: 'created', date: firstDate(selected.value.created_at), title: 'Создан план клиента', detail: 'Стартовые данные и цели питания сохранены', pill: 'Старт', category: 'progress' });
  return events.filter((event) => historyFilter.value === 'all' || event.category === historyFilter.value).sort((a, b) => b.date.localeCompare(a.date));
});

function fillTargets() {
  const latest = latestProgress.value;
  targets.kcal_target = latest?.kcal_target == null ? '' : String(latest.kcal_target);
  targets.protein_target_g = latest?.protein_target_g == null ? '' : String(latest.protein_target_g);
  targets.fat_target_g = latest?.fat_target_g == null ? '' : String(latest.fat_target_g);
  targets.carbs_target_g = latest?.carbs_target_g == null ? '' : String(latest.carbs_target_g);
}

async function loadClient(id: number) {
  detailLoading.value = true;
  error.value = '';
  try {
    const [detail, fullDiary, clientTasks] = await Promise.all([api.client(id), api.clientDiary(id), api.clientTasks(id, range.start)]);
    selected.value = detail;
    diary.value = fullDiary;
    tasks.value = clientTasks;
    fillTargets();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
    selected.value = null;
  } finally {
    detailLoading.value = false;
  }
}

async function load() {
  if (!props.canAccess) return;
  loading.value = true;
  error.value = '';
  try {
    clients.value = await api.clients();
    if (!clients.value.length) {
      selectedId.value = null;
      selected.value = null;
      return;
    }
    if (!selectedId.value || !clients.value.some((client) => client.id === selectedId.value)) selectedId.value = clients.value[0].id;
    await loadClient(selectedId.value);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

async function chooseClient(id: number) {
  if (id === selectedId.value && selected.value) return;
  selectedId.value = id;
  activeTab.value = 'overview';
  chatOpen.value = false;
  chatClient.value = null;
  chatMessages.value = [];
  await loadClient(id);
}

async function refreshSelected() {
  await load();
}

async function addClient() {
  addError.value = '';
  try {
    const client = await api.addClient(email.value.trim());
    clients.value = [...clients.value, client];
    email.value = '';
    addOpen.value = false;
    selectedId.value = client.id;
    await loadClient(client.id);
  } catch (err) {
    addError.value = err instanceof Error ? err.message : String(err);
  }
}

async function saveTargets() {
  if (!selected.value) return;
  try {
    await api.updateClientTargets(selected.value.id, targets);
    targetsOpen.value = false;
    await refreshSelected();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

function openTargets() {
  fillTargets();
  targetsOpen.value = true;
}

async function openChat(client: ClientSummary, draft = '') {
  chatError.value = '';
  chatText.value = draft;
  chatClient.value = client;
  try {
    chatMessages.value = await api.clientChat(client.id);
    const item = clients.value.find((candidate) => candidate.id === client.id);
    if (item) item.unread_messages = 0;
    if (selected.value?.id === client.id) selected.value.unread_messages = 0;
    chatOpen.value = true;
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err);
  }
}

async function sendChat() {
  if (!chatClient.value || !chatText.value.trim()) return;
  try {
    chatMessages.value = [...chatMessages.value, await api.sendClientChat(chatClient.value.id, chatText.value.trim())];
    chatText.value = '';
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err);
  }
}

async function openSharedItem(message: TrainerChatMessage) {
  if (!message.shared_item || !chatClient.value) return;
  chatError.value = '';
  try {
    sharedItem.value = await api.clientSharedItem(chatClient.value.id, message.shared_item.type, message.shared_item.id);
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err);
  }
}

function reportDraft() {
  return `Отчёт по ${selectedName.value}: вес ${metricValue(currentProgress.value?.weight_kg, 'кг')}, выполнение задач ${doneTasks.value}/${tasks.value.length}. Готов обсудить следующие шаги.`;
}

function openProgress(entry: ProgressEntry | null = null) {
  editingProgress.value = entry;
  progressFormKey.value += 1;
  progressOpen.value = true;
}

function openTask() {
  taskError.value = '';
  taskForm.title = '';
  taskForm.description = '';
  taskForm.due_date = '';
  taskOpen.value = true;
}

async function addTask() {
  if (!selected.value || !taskForm.title.trim()) return;
  taskError.value = '';
  try {
    const task = await api.addClientTask(selected.value.id, { week_start: range.start, title: taskForm.title.trim(), description: taskForm.description.trim() || null, due_date: taskForm.due_date || null });
    tasks.value = [...tasks.value, task];
    taskOpen.value = false;
  } catch (err) {
    taskError.value = err instanceof Error ? err.message : String(err);
  }
}

async function toggleTask(task: TrainerTask) {
  if (!selected.value) return;
  const previous = task.status;
  task.status = previous === 'done' ? 'open' : 'done';
  try {
    const updated = await api.updateClientTask(selected.value.id, task.id, task.status as 'open' | 'done');
    Object.assign(task, updated);
  } catch (err) {
    task.status = previous;
    error.value = err instanceof Error ? err.message : String(err);
  }
}

function openRange() {
  rangeDraft.start = range.start;
  rangeDraft.end = range.end;
  rangeError.value = '';
  rangeOpen.value = true;
}

async function applyRange() {
  rangeError.value = '';
  if (!rangeDraft.start || !rangeDraft.end || rangeDraft.end < rangeDraft.start) {
    rangeError.value = 'Укажите корректный период';
    return;
  }
  range.start = rangeDraft.start;
  range.end = rangeDraft.end;
  rangeOpen.value = false;
  if (selectedId.value) {
    try { tasks.value = await api.clientTasks(selectedId.value, range.start); } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  }
}

function exportNutrition() {
  const header = ['Дата', 'Ккал план', 'Ккал факт', 'Белки', 'Жиры', 'Углеводы', 'Тренировка', 'Статус'];
  const rows = nutritionRows.value.map((row) => [row.date, row.plan ?? '', row.totals.kcal, row.totals.protein, row.totals.fat, row.totals.carbs, row.workouts, row.review === 'done' ? 'Проверено' : 'Нужен комментарий']);
  const csv = [header, ...rows].map((row) => row.map((value) => `"${String(value).replaceAll('"', '""')}"`).join(';')).join('\n');
  const link = document.createElement('a');
  link.href = URL.createObjectURL(new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8' }));
  link.download = `astra-${selectedName.value.toLocaleLowerCase('ru').replaceAll(/\s+/g, '-')}-nutrition.csv`;
  link.click();
  URL.revokeObjectURL(link.href);
}

function setTab(tab: TabId) {
  activeTab.value = tab;
}

watch(() => [props.refreshKey, props.canAccess], () => { void load(); }, { immediate: true });
</script>

<template>
  <section v-if="!props.canAccess" class="clients-page trainer-lock-page">
    <div class="trainer-lock-background" aria-hidden="true"><div class="ghost-card" v-for="index in 3" :key="index"><span></span><span></span><span></span></div></div>
    <div class="trainer-lock-overlay"><p class="eyebrow">РЕЖИМ ТРЕНЕРА</p><h1>Напишите нам, чтобы стать тренером</h1><p>Откройте доступ к клиентам, планам тренировок и профессиональным инструментам.</p><a href="#feedback" @click.prevent="emit('feedback')">Перейти в обратную связь →</a></div>
  </section>

  <section v-else class="clients-page trainer-workspace">
    <div v-if="loading" class="panel trainer-state">Загрузка рабочего места…</div>
    <div v-else-if="error && !selected" class="panel form-error trainer-state">{{ error }}</div>
    <div v-else-if="!clients.length" class="panel clients-empty trainer-state"><p class="eyebrow">ТРЕНЕРСКИЙ РЕЖИМ</p><h1>Добавьте первого клиента</h1><p>Введите email зарегистрированного пользователя, чтобы открыть его дневник, прогресс и план недели.</p><button type="button" class="primary" @click="addOpen = true">＋ Добавить клиента</button></div>
    <template v-else-if="selected">
      <div class="trainer-topbar"><div class="trainer-breadcrumb">Клиенты <span aria-hidden="true">/</span> <strong>{{ selectedName }}</strong></div><div class="trainer-actions"><button type="button" class="trainer-button" @click="openRange">{{ dateRangeLabel }}</button><button type="button" class="trainer-button trainer-button-primary" @click="openTask">＋ Создать задачу</button></div></div>
      <div class="trainer-client-switcher" aria-label="Выбор клиента"><div class="switcher-label"><span>КЛИЕНТЫ</span><button type="button" class="quiet-button" @click="addOpen = true">＋ Добавить</button></div><div class="switcher-list"><button v-for="client in clients" :key="client.id" type="button" class="switcher-client" :class="{ active: client.id === selected.id }" @click="chooseClient(client.id)"><span class="switcher-avatar">{{ initials(displayName(client)) }}</span><span><strong>{{ displayName(client) }}</strong><small>{{ client.unread_messages ? `${client.unread_messages} новых сообщений` : 'Рабочий план' }}</small></span><b v-if="client.unread_messages" class="unread-dot">{{ client.unread_messages > 99 ? '99+' : client.unread_messages }}</b></button></div></div>
      <div class="trainer-profile"><div class="trainer-profile-main"><span class="trainer-profile-avatar" aria-hidden="true">{{ initials(selectedName) }}</span><div><p class="eyebrow">КАРТОЧКА КЛИЕНТА</p><h1>{{ selectedName }} <span class="active-status">Активный план</span></h1><div class="profile-meta">{{ selected.email }} · Клиент с {{ formatShortDate(selected.created_at) }}</div></div></div><div class="trainer-actions"><button type="button" class="trainer-button" @click="openTargets">Нормы питания</button><button type="button" class="trainer-button" @click="editingPlan = null; scheduleOpen = true">＋ Тренировка</button><button type="button" class="trainer-button" @click="openChat(selected)">Написать</button><button type="button" class="trainer-button trainer-button-primary" @click="openChat(selected, reportDraft())">Отправить отчёт</button></div></div>
      <div class="trainer-tabs" role="tablist" aria-label="Разделы карточки клиента"><button v-for="tab in ([['overview', 'Обзор'], ['progress', 'Точка А → Б'], ['nutrition', 'Питание и активность'], ['week', 'План недели'], ['history', 'История']] as const)" :key="tab[0]" type="button" role="tab" class="trainer-tab" :aria-selected="activeTab === tab[0]" @click="setTab(tab[0])">{{ tab[1] }}</button></div>

      <div v-if="detailLoading" class="panel trainer-state">Загрузка данных клиента…</div>
      <template v-else>
        <section v-if="activeTab === 'overview'" class="trainer-panel" aria-label="Обзор клиента">
          <div class="trainer-stat-grid"><div class="trainer-stat positive"><span>Вес от старта</span><strong>{{ changeValue(currentProgress?.weight_kg, startProgress?.weight_kg, 'кг') }}</strong><small>{{ metricValue(startProgress?.weight_kg, 'кг') }} → {{ metricValue(currentProgress?.weight_kg, 'кг') }}</small></div><div class="trainer-stat positive"><span>Талия от старта</span><strong>{{ changeValue(currentProgress?.waist_cm, startProgress?.waist_cm, 'см') }}</strong><small>{{ metricValue(startProgress?.waist_cm, 'см') }} → {{ metricValue(currentProgress?.waist_cm, 'см') }}</small></div><div class="trainer-stat"><span>Выполнение недели</span><strong>{{ taskProgress }}%</strong><small>{{ doneTasks }} из {{ tasks.length }} задач</small></div><div class="trainer-stat attention"><span>Следующая точка</span><strong>{{ formatShortDate(nextCheckpoint) }}</strong><small>замеры и обратная связь</small></div></div>
          <div class="trainer-two-col"><section class="trainer-section"><div class="trainer-section-head"><div><h2>Точка А → Точка Б</h2><p>Сравнение старта и последнего контрольного замера</p></div><button type="button" class="quiet-button" @click="setTab('progress')">Открыть всё</button></div><div class="trainer-section-body"><div v-if="startProgress" class="table-wrap"><table><thead><tr><th>Параметр</th><th>Старт</th><th>Сейчас</th><th>Изменение</th></tr></thead><tbody><tr v-for="item in comparison" :key="item.label"><td>{{ item.label }}</td><td>{{ metricValue(item.start, item.unit) }}</td><td><strong>{{ metricValue(item.current, item.unit) }}</strong></td><td class="change-down">{{ changeValue(item.current, item.start, item.unit) }}</td></tr></tbody></table></div><p v-else class="empty-message">Контрольных замеров пока нет.</p><div class="section-actions"><button type="button" class="trainer-button" @click="openProgress()">＋ Внести замеры</button><span class="muted-note">{{ currentProgress ? `Последний замер: ${formatShortDate(currentProgress.measured_at)}` : 'Добавьте первую точку' }}</span></div></div></section><section class="trainer-section"><div class="trainer-section-head"><div><h2>Задачи на эту неделю</h2><p>{{ formatRangeDate(range.start) }}–{{ formatRangeDate(range.end) }} · дедлайны и подтверждения</p></div><button type="button" class="quiet-button" @click="setTab('week')">Настроить</button></div><div class="trainer-section-body"><div class="progress-line"><div class="progress-track" role="progressbar" aria-label="Выполнение задач недели" :aria-valuenow="taskProgress" aria-valuemin="0" aria-valuemax="100"><span :style="{ width: `${taskProgress}%` }"></span></div><strong>{{ doneTasks }} / {{ tasks.length }}</strong></div><div class="task-list"><div v-for="task in tasks.slice(0, 5)" :key="task.id" class="task-row"><input :id="`overview-task-${task.id}`" type="checkbox" :checked="task.status === 'done'" @change="toggleTask(task)"><label :for="`overview-task-${task.id}`">{{ task.title }}<span>{{ task.description || 'Задача недели' }}</span></label><small :class="{ overdue: taskStatus(task) === 'просрочено' }">{{ taskStatus(task) }}</small></div></div><div class="week-strip" aria-label="Статус по дням недели"><div v-for="day in weekDays" :key="day.date" class="week-day" :class="{ done: day.complete, today: day.isToday }"><strong>{{ parseDate(day.date)?.toLocaleDateString('ru-RU', { weekday: 'short' }).replace('.', '') }}</strong><span>{{ day.caption }}</span></div></div></div></section></div>
          <div class="trainer-lower"><section class="trainer-full-section"><div class="trainer-section-head"><div><h2>Питание и активность</h2><p>План и факт за выбранный период — повод для быстрой проверки</p></div><button type="button" class="quiet-button" @click="setTab('nutrition')">Открыть дневник</button></div><div class="trainer-section-body"><div class="table-wrap"><table><thead><tr><th>День</th><th>Ккал план</th><th>Ккал факт</th><th>Б / Ж / У, г</th><th>Шаги</th><th>Тренировка</th><th>Проверка</th></tr></thead><tbody><tr v-for="row in nutritionRows" :key="row.date"><td>{{ formatShortDate(row.date) }}</td><td>{{ fmt(row.plan) }}</td><td>{{ row.entries.length ? fmt(row.totals.kcal) : '—' }}</td><td>{{ row.entries.length ? `${fmt(row.totals.protein)} / ${fmt(row.totals.fat)} / ${fmt(row.totals.carbs)}` : '—' }}</td><td class="muted-note">—</td><td>{{ row.workouts }}</td><td><span class="review-status" :class="{ open: row.review === 'open' }">{{ row.review === 'done' ? 'Проверено' : row.entries.length ? 'Нужен комментарий' : 'Ожидается' }}</span></td></tr></tbody></table></div></div></section></div>
        </section>

        <section v-else-if="activeTab === 'progress'" class="trainer-panel" aria-label="Контрольные точки"><div class="trainer-two-col"><section class="trainer-section"><div class="trainer-section-head"><div><h2>Динамика веса</h2><p>Контрольные точки каждые 14 дней</p></div><button type="button" class="trainer-button trainer-button-primary" @click="openProgress()">＋ Добавить точку</button></div><div class="trainer-section-body"><div v-if="chartPoints" class="chart-wrap"><svg class="weight-chart" viewBox="0 0 620 180" role="img" aria-label="Динамика веса клиента"><path class="chart-grid" d="M50 32H600M50 82H600M50 132H600"/><polyline class="chart-line" :points="chartPoints"/><circle v-for="(dot, index) in chartDots" :key="index" class="chart-dot" :cx="dot.cx" :cy="dot.cy" r="6"/><text x="50" y="168">{{ chartLabels.first }}</text><text x="270" y="168">{{ chartLabels.middle }}</text><text x="560" y="168">{{ chartLabels.last }}</text><text x="55" y="25">{{ chartLabels.firstWeight }}</text><text x="570" y="121">{{ chartLabels.lastWeight }}</text></svg></div><p v-else class="empty-message">Добавьте контрольные точки, чтобы увидеть динамику.</p><div class="trainer-callout"><p class="eyebrow">РЕКОМЕНДАЦИЯ ТРЕНЕРА</p><p>{{ currentProgress ? 'Темп изменений можно оценить по следующей точке. Проверьте самочувствие и не меняйте калорийность без необходимости.' : 'После первого замера здесь появится подсказка для следующего шага.' }}</p></div></div></section><section class="trainer-section"><div class="trainer-section-head"><div><h2>История контрольных точек</h2><p>Данные и подтверждающие материалы</p></div></div><div class="trainer-section-body"><div v-for="entry in sortedProgress.slice().reverse()" :key="entry.id" class="checkpoint-row"><span class="checkpoint-date">{{ formatShortDate(entry.measured_at) }}</span><div><strong>{{ entry.id === startProgress?.id ? 'Точка А · старт' : entry.id === currentProgress?.id ? 'Последний замер' : 'Контрольная точка' }}</strong><span>{{ [metricValue(entry.weight_kg, 'кг'), metricValue(entry.waist_cm, 'см талии'), entry.comment || 'Замеры и самочувствие'].filter(Boolean).join(' · ') }}</span></div><span class="checkpoint-pill">Проверено</span></div><p v-if="!sortedProgress.length" class="empty-message">Контрольные точки пока не добавлены.</p><div v-if="nextCheckpoint" class="checkpoint-row upcoming"><span class="checkpoint-date">{{ formatShortDate(nextCheckpoint) }}</span><div><strong>Следующая точка</strong><span>Замеры и обратная связь</span></div><span class="checkpoint-pill">Ожидается</span></div></div></section></div></section>

        <section v-else-if="activeTab === 'nutrition'" class="trainer-panel" aria-label="Питание и активность"><section class="trainer-full-section"><div class="trainer-section-head"><div><h2>Питание и активность</h2><p>План, факт, источник данных и проверка тренера в одной строке</p></div><div class="trainer-actions"><button type="button" class="trainer-button" @click="exportNutrition">Экспорт</button><button type="button" class="trainer-button trainer-button-primary" @click="diaryOpen = true">＋ Добавить день</button></div></div><div class="trainer-section-body"><div class="table-wrap"><table><thead><tr><th>Дата</th><th>КБЖУ план</th><th>КБЖУ факт</th><th>Источник</th><th>Шаги</th><th>Тренировка</th><th>Статус</th></tr></thead><tbody><tr v-for="row in nutritionRows" :key="row.date"><td>{{ formatShortDate(row.date) }}</td><td>{{ targetValue('kcal') ? `${fmt(targetValue('kcal'))} / ${fmt(targetValue('protein'))} / ${fmt(targetValue('fat'))} / ${fmt(targetValue('carbs'))}` : '—' }}</td><td>{{ row.entries.length ? `${fmt(row.totals.kcal)} / ${fmt(row.totals.protein)} / ${fmt(row.totals.fat)} / ${fmt(row.totals.carbs)}` : 'Нет данных' }}</td><td :class="row.entries.length ? 'change-down' : 'muted-note'">{{ row.entries.length ? 'Данные дневника' : 'Ожидается' }}</td><td class="muted-note">—</td><td>{{ row.workouts }}</td><td><span class="review-status" :class="{ open: row.review === 'open' }">{{ row.review === 'done' ? 'Проверено' : row.entries.length ? 'Нужен комментарий' : 'Ожидается' }}</span></td></tr></tbody></table></div></div></section></section>

        <section v-else-if="activeTab === 'week'" class="trainer-panel" aria-label="План недели"><div class="trainer-two-col"><section class="trainer-section"><div class="trainer-section-head"><div><h2>План недели</h2><p>{{ formatRangeDate(range.start) }}–{{ formatRangeDate(range.end) }} · договорённости с клиентом</p></div><button type="button" class="trainer-button trainer-button-primary" @click="openTask">＋ Добавить задачу</button></div><div class="trainer-section-body"><div class="task-list"><div v-for="task in tasks" :key="task.id" class="task-row"><input :id="`week-task-${task.id}`" type="checkbox" :checked="task.status === 'done'" @change="toggleTask(task)"><label :for="`week-task-${task.id}`">{{ task.title }}<span>{{ task.description || 'Без дополнительного описания' }}</span></label><small :class="{ overdue: taskStatus(task) === 'просрочено' }">{{ taskStatus(task) }}</small></div></div><p v-if="!tasks.length" class="empty-message">Задач на эту неделю пока нет.</p></div></section><section class="trainer-section"><div class="trainer-section-head"><div><h2>Правила контроля</h2><p>Что система отслеживает автоматически</p></div></div><div class="trainer-section-body"><div class="review-row"><div><strong>Ниже 5 000 шагов</strong><span>Создать мягкое напоминание</span></div><span class="review-status open">Включено</span></div><div class="review-row"><div><strong>Контрольная точка каждые 14 дней</strong><span>Замеры и обратная связь</span></div><span class="review-status">Включено</span></div><div class="review-row"><div><strong>Отчёт клиента</strong><span>Уведомить тренера, если готов</span></div><span class="review-status">Включено</span></div></div></section></div></section>

        <section v-else class="trainer-panel" aria-label="История клиента"><section class="trainer-full-section"><div class="trainer-section-head"><div><h2>История взаимодействия</h2><p>Замеры, задачи, тренировки, отчёты и комментарии в одной ленте</p></div><select v-model="historyFilter" class="history-filter" aria-label="Фильтр событий"><option value="all">Все события</option><option value="nutrition">Питание</option><option value="progress">Замеры</option><option value="workout">Тренировки</option><option value="communication">Комментарии</option></select></div><div class="trainer-section-body"><div v-for="event in historyEvents" :key="event.id" class="checkpoint-row"><span class="checkpoint-date">{{ event.date === localToday() ? 'Сегодня' : formatShortDate(event.date) }}</span><div><strong>{{ event.title }}</strong><span>{{ event.detail }}</span></div><span class="checkpoint-pill">{{ event.pill }}</span></div><p v-if="!historyEvents.length" class="empty-message">Событий по выбранному фильтру пока нет.</p></div></section></section>
      </template>
    </template>
  </section>

  <ModalDialog :open="addOpen" title="Добавить клиента" eyebrow="КЛИЕНТ" @close="addOpen = false"><form class="client-form" @submit.prevent="addClient"><p>Введите email уже зарегистрированного пользователя.</p><div class="field full"><label>Email клиента</label><input v-model="email" type="email" required autofocus placeholder="client@example.com"></div><p class="form-error">{{ addError }}</p><div class="actions"><button type="button" @click="addOpen = false">Отмена</button><button type="submit" class="primary">Добавить</button></div></form></ModalDialog>
  <ModalDialog :open="diaryOpen" title="Добавить блюдо клиенту" eyebrow="ДНЕВНИК ПИТАНИЯ" wide @close="diaryOpen = false"><DiaryEntryForm v-if="selected" :target-user-id="selected.id" @saved="diaryOpen = false; refreshSelected()" @cancel="diaryOpen = false" /></ModalDialog>
  <WorkoutBuilderModal :open="scheduleOpen" :edit-plan="editingPlan" :target-user-id="selected?.id" @close="scheduleOpen = false; editingPlan = null" @saved="scheduleOpen = false; editingPlan = null; refreshSelected()" />
  <ModalDialog :open="progressOpen" :title="editingProgress ? 'Редактировать замер' : 'Добавить контрольную точку'" eyebrow="ТОЧКА А → Б" wide @close="progressOpen = false; editingProgress = null"><ProgressForm v-if="selected" :key="progressFormKey" :target-user-id="selected.id" :progress-id="editingProgress?.id" @saved="progressOpen = false; editingProgress = null; refreshSelected()" @cancel="progressOpen = false; editingProgress = null" /></ModalDialog>
  <ModalDialog :open="targetsOpen" title="Нормы питания" eyebrow="ПАРАМЕТРЫ КЛИЕНТА" @close="targetsOpen = false"><form class="client-form" @submit.prevent="saveTargets"><p>Персональные суточные нормы клиента.</p><div class="form-grid targets-grid"><div class="field"><label>Ккал</label><input v-model="targets.kcal_target" type="number" min="0" step="1"></div><div class="field"><label>Белки, г</label><input v-model="targets.protein_target_g" type="number" min="0" step="0.1"></div><div class="field"><label>Жиры, г</label><input v-model="targets.fat_target_g" type="number" min="0" step="0.1"></div><div class="field"><label>Углеводы, г</label><input v-model="targets.carbs_target_g" type="number" min="0" step="0.1"></div></div><div class="actions"><button type="button" @click="targetsOpen = false">Отмена</button><button type="submit" class="primary">Сохранить нормы</button></div></form></ModalDialog>
  <ModalDialog :open="taskOpen" title="Задача на неделю" eyebrow="ПЛАН НЕДЕЛИ" @close="taskOpen = false"><form class="client-form" @submit.prevent="addTask"><div class="field full"><label>Название</label><input v-model="taskForm.title" required maxlength="240" placeholder="Например, прислать фото замеров"></div><div class="field full"><label>Описание <small>необязательно</small></label><textarea v-model="taskForm.description" maxlength="1000" rows="3" placeholder="Что нужно проверить или подтвердить"></textarea></div><div class="field full"><label>Дедлайн <small>необязательно</small></label><input v-model="taskForm.due_date" type="date" :min="range.start" :max="range.end"></div><p class="form-error">{{ taskError }}</p><div class="actions"><button type="button" @click="taskOpen = false">Отмена</button><button type="submit" class="primary">Создать задачу</button></div></form></ModalDialog>
  <ModalDialog :open="rangeOpen" title="Период отчёта" eyebrow="ПИТАНИЕ И АКТИВНОСТЬ" @close="rangeOpen = false"><form class="client-form" @submit.prevent="applyRange"><p>Выберите период, который будет показан в дневнике и планировании.</p><div class="form-grid"><div class="field"><label>С</label><input v-model="rangeDraft.start" type="date" required></div><div class="field"><label>По</label><input v-model="rangeDraft.end" type="date" required></div></div><p class="form-error">{{ rangeError }}</p><div class="actions"><button type="button" @click="rangeOpen = false">Отмена</button><button type="submit" class="primary">Применить</button></div></form></ModalDialog>
  <ModalDialog :open="chatOpen" :title="chatClient?.name ? `Чат · ${chatClient.name}` : 'Чат с клиентом'" eyebrow="СООБЩЕНИЯ" @close="chatOpen = false"><div class="chat-box"><div class="chat-messages"><p v-if="!chatMessages.length" class="empty-message">Сообщений пока нет.</p><div v-for="message in chatMessages" :key="message.id" class="chat-message"><b>{{ message.sender_name }}</b><span v-if="!message.shared_item">{{ message.message }}</span><button v-else type="button" class="shared-chat-card" @click="openSharedItem(message)"><span>ОТПРАВЛЕНО В ЧАТ</span><strong>{{ message.shared_item.name }}</strong><small>{{ message.shared_item.type === 'article' ? 'Статья' : message.shared_item.type === 'recipe' ? 'Блюдо' : message.shared_item.type === 'product' ? 'Продукт' : 'Материал' }}</small></button><small>{{ formatDateTime(message.created_at) }}</small></div></div><p class="form-error">{{ chatError }}</p><form class="chat-compose" @submit.prevent="sendChat"><input v-model="chatText" maxlength="2000" placeholder="Написать сообщение…"><button type="submit" class="primary">Отправить</button></form></div></ModalDialog>
  <SharedItemModal :item="sharedItem" @close="sharedItem = null" />
</template>

<style lang="scss">
.clients-page { padding: 26px 30px 50px; }
.trainer-workspace { --trainer-surface: #fff; --trainer-soft: #f1f3f8; --trainer-ink: #172033; --trainer-muted: #7d879b; --trainer-line: #e3e8f1; --trainer-purple: #6f82ff; --trainer-mint: #bdf2d3; max-width: 1500px; margin: 0 auto; color: var(--trainer-ink); }
.trainer-topbar, .trainer-profile, .trainer-actions, .section-actions, .chat-compose { display: flex; align-items: center; justify-content: space-between; gap: 12px; }.trainer-topbar { margin-bottom: 15px; }.trainer-breadcrumb { color: var(--trainer-muted); font-size: 12px; }.trainer-breadcrumb strong { color: var(--trainer-ink); font-weight: 650; }.trainer-actions { justify-content: flex-end; flex-wrap: wrap; }
.trainer-button { min-height: 38px; border: 1px solid var(--trainer-line); border-radius: 10px; padding: 0 13px; background: var(--trainer-surface); color: var(--trainer-ink); font: inherit; font-size: 12px; font-weight: 650; cursor: pointer; }.trainer-button:hover { border-color: var(--trainer-purple); color: var(--trainer-purple); }.trainer-button-primary { border-color: var(--trainer-ink); background: var(--trainer-ink); color: #fff; }.trainer-button-primary:hover { border-color: var(--trainer-purple); background: var(--trainer-purple); color: #fff; }.quiet-button { border: 0; padding: 5px 0; background: transparent; color: var(--trainer-purple); font: inherit; font-size: 11px; font-weight: 700; cursor: pointer; }.quiet-button:hover { color: var(--trainer-ink); }
.trainer-client-switcher { display: flex; align-items: center; gap: 15px; margin: 0 0 20px; padding: 9px 11px; border: 1px solid var(--trainer-line); border-radius: 14px; background: var(--trainer-surface); }.switcher-label { display: flex; min-width: 106px; flex-direction: column; gap: 3px; color: var(--trainer-muted); font-size: 9px; font-weight: 800; letter-spacing: .12em; }.switcher-label .quiet-button { letter-spacing: normal; text-align: left; }.switcher-list { display: flex; min-width: 0; gap: 7px; overflow-x: auto; }.switcher-client { display: flex; min-width: 205px; align-items: center; gap: 8px; border: 1px solid transparent; border-radius: 10px; padding: 7px 9px; background: transparent; color: var(--trainer-ink); text-align: left; cursor: pointer; }.switcher-client:hover, .switcher-client.active { border-color: #ccd4ff; background: #f0f1ff; }.switcher-avatar { display: grid; flex: 0 0 31px; width: 31px; height: 31px; place-items: center; border-radius: 10px; background: #e7e3ff; color: #6254bd; font-size: 11px; font-weight: 800; }.switcher-client > span:nth-child(2) { min-width: 0; flex: 1; }.switcher-client strong, .switcher-client small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }.switcher-client strong { font-size: 11px; }.switcher-client small { margin-top: 2px; color: var(--trainer-muted); font-size: 9px; }.unread-dot { display: grid; min-width: 19px; height: 19px; place-items: center; border-radius: 99px; background: var(--trainer-purple); color: #fff; font-size: 9px; }
.trainer-profile { align-items: flex-start; margin-bottom: 18px; }.trainer-profile-main { display: flex; min-width: 0; align-items: center; gap: 14px; }.trainer-profile-avatar { display: grid; flex: 0 0 54px; width: 54px; height: 54px; place-items: center; border-radius: 17px; background: #e7e3ff; color: #6254bd; font-size: 19px; font-weight: 750; }.trainer-profile h1 { margin: 0 0 3px; font-size: clamp(24px, 3vw, 32px); letter-spacing: -.04em; line-height: 1.05; }.active-status { display: inline-flex; align-items: center; gap: 5px; margin-left: 7px; color: #2e9962; font-size: 11px; font-weight: 700; letter-spacing: normal; vertical-align: middle; }.active-status::before { width: 6px; height: 6px; border-radius: 50%; background: #45bd7a; content: ''; }.profile-meta { color: var(--trainer-muted); font-size: 12px; }.eyebrow { margin: 0 0 4px; color: var(--trainer-purple); font-size: 9px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; }
.trainer-tabs { display: flex; gap: 18px; overflow-x: auto; border-bottom: 1px solid var(--trainer-line); }.trainer-tab { flex: 0 0 auto; min-height: 42px; border: 0; border-bottom: 2px solid transparent; padding: 0 1px; background: transparent; color: var(--trainer-muted); font: inherit; font-size: 12px; font-weight: 650; cursor: pointer; }.trainer-tab:hover, .trainer-tab[aria-selected="true"] { border-bottom-color: var(--trainer-purple); color: var(--trainer-ink); }.trainer-panel { padding-top: 20px; }
.trainer-stat-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-bottom: 16px; }.trainer-stat { min-width: 0; padding: 13px 14px; border: 1px solid var(--trainer-line); border-radius: 14px; background: var(--trainer-surface); }.trainer-stat span, .trainer-stat small { display: block; color: var(--trainer-muted); font-size: 10px; }.trainer-stat strong { display: block; margin: 5px 0 2px; font-size: 20px; letter-spacing: -.04em; }.trainer-stat.positive strong { color: #329a63; }.trainer-stat.attention strong { color: #e99642; }.trainer-two-col { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(300px, .9fr); gap: 16px; }.trainer-section, .trainer-full-section { min-width: 0; border: 1px solid var(--trainer-line); border-radius: 16px; background: var(--trainer-surface); }.trainer-section-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 16px 17px 13px; border-bottom: 1px solid var(--trainer-line); }.trainer-section-head h2 { margin: 0 0 2px; font-size: 15px; letter-spacing: -.02em; }.trainer-section-head p { margin: 0; color: var(--trainer-muted); font-size: 11px; }.trainer-section-body { padding: 0 17px 17px; }.trainer-lower { margin-top: 16px; }
.table-wrap { overflow-x: auto; }.trainer-workspace table { width: 100%; border-collapse: collapse; font-size: 12px; }.trainer-workspace th { padding: 12px 9px 9px; color: var(--trainer-muted); font-size: 9px; font-weight: 700; letter-spacing: .08em; text-align: left; text-transform: uppercase; white-space: nowrap; }.trainer-workspace td { padding: 11px 9px; border-top: 1px solid var(--trainer-line); white-space: nowrap; }.trainer-workspace th:first-child, .trainer-workspace td:first-child { padding-left: 0; }.trainer-workspace th:last-child, .trainer-workspace td:last-child { padding-right: 0; text-align: right; }.change-down { color: #329a63; font-weight: 700; }.muted-note { color: var(--trainer-muted); font-size: 10px; }.review-status, .checkpoint-pill { display: inline-block; border-radius: 99px; padding: 4px 7px; background: #f0fbf4; color: #329a63; font-size: 9px; font-weight: 700; white-space: nowrap; }.review-status.open { background: #fff5e7; color: #b96f16; }.empty-message { margin: 0; padding: 24px 0 8px; color: var(--trainer-muted); font-size: 12px; }.section-actions { justify-content: flex-start; margin-top: 13px; }
.progress-line { display: flex; align-items: center; gap: 10px; margin: 14px 0 10px; }.progress-track { height: 7px; flex: 1; overflow: hidden; border-radius: 99px; background: var(--trainer-soft); }.progress-track span { display: block; height: 100%; border-radius: inherit; background: var(--trainer-purple); transition: width .2s ease; }.progress-line strong { font-size: 12px; white-space: nowrap; }.task-list { display: grid; }.task-row { display: flex; align-items: flex-start; gap: 9px; padding: 11px 0; border-top: 1px solid var(--trainer-line); }.task-row:first-child { border-top: 0; }.task-row input { width: 16px; height: 16px; margin-top: 1px; accent-color: var(--trainer-purple); }.task-row label { flex: 1; min-width: 0; font-size: 12px; }.task-row label span, .task-row small { display: block; color: var(--trainer-muted); font-size: 10px; }.task-row input:checked + label { color: var(--trainer-muted); text-decoration: line-through; }.task-row small { color: #e99642; white-space: nowrap; }.task-row small.overdue { color: #d56666; }.week-strip { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 6px; margin-top: 14px; }.week-day { min-width: 0; padding: 9px 5px; border: 1px solid var(--trainer-line); border-radius: 10px; text-align: center; }.week-day strong, .week-day span { display: block; }.week-day strong { font-size: 11px; }.week-day span { margin-top: 3px; color: var(--trainer-muted); font-size: 9px; }.week-day.done { border-color: #a8dfbd; background: #f0fbf4; }.week-day.done strong { color: #329a63; }.week-day.today { border-color: var(--trainer-purple); background: #f0f1ff; }
.chart-wrap { padding-top: 8px; }.weight-chart { display: block; width: 100%; height: 180px; }.weight-chart text { fill: var(--trainer-muted); font-size: 10px; }.chart-grid { stroke: var(--trainer-line); stroke-width: 1; }.chart-line { fill: none; stroke: var(--trainer-purple); stroke-linecap: round; stroke-linejoin: round; stroke-width: 3; }.chart-dot { fill: var(--trainer-purple); stroke: var(--trainer-surface); stroke-width: 3; }.trainer-callout { margin-top: 16px; border-radius: 13px; padding: 13px 14px; background: #172033; color: #fff; }.trainer-callout .eyebrow { color: var(--trainer-mint); }.trainer-callout p:last-child { margin: 0; color: #dce4ef; font-size: 11px; line-height: 1.5; }.checkpoint-row, .review-row { display: grid; grid-template-columns: 52px minmax(0, 1fr) auto; align-items: center; gap: 12px; padding: 13px 0; border-top: 1px solid var(--trainer-line); }.checkpoint-row:first-child, .review-row:first-child { border-top: 0; }.checkpoint-date { color: var(--trainer-muted); font-size: 11px; }.checkpoint-row strong, .checkpoint-row div > span, .review-row strong, .review-row div > span { display: block; }.checkpoint-row strong, .review-row strong { font-size: 12px; }.checkpoint-row div > span, .review-row div > span { margin-top: 2px; color: var(--trainer-muted); font-size: 10px; }.checkpoint-pill { background: #f0f1ff; color: #6254bd; }.checkpoint-row.upcoming .checkpoint-pill { background: #fff5e7; color: #b96f16; }.review-row { grid-template-columns: minmax(0, 1fr) auto; }.history-filter { min-height: 34px; border: 1px solid var(--trainer-line); border-radius: 8px; padding: 0 9px; background: var(--trainer-surface); color: var(--trainer-ink); font: inherit; font-size: 11px; font-weight: 650; }
.trainer-state { margin-top: 20px; text-align: center; }.clients-empty { padding: 52px 25px; }.clients-empty h1 { margin: 0 0 8px; font-size: clamp(28px, 4vw, 42px); }.clients-empty p:not(.eyebrow) { max-width: 500px; margin: 0 auto 20px; color: var(--trainer-muted); line-height: 1.5; }.client-form { min-width: min(450px, 100%); }.client-form > p:first-child { margin-top: 0; color: var(--trainer-muted); }.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }.targets-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }.chat-box { min-width: min(520px, 100%); }.chat-messages { display: grid; gap: 8px; max-height: 360px; overflow-y: auto; margin-bottom: 12px; }.chat-message { display: grid; gap: 3px; padding: 10px 12px; border-radius: 10px; background: #f4f7fb; }.chat-message span { white-space: pre-wrap; }.chat-message small { color: var(--trainer-muted); font-size: 10px; }.chat-compose input { min-width: 0; flex: 1; }.shared-chat-card { display: grid; gap: 3px; width: 100%; box-sizing: border-box; margin: 4px 0; padding: 10px; border: 1px solid #b8d5ff; border-radius: 9px; background: #eaf3ff; color: var(--ink); text-align: left; cursor: pointer; }.shared-chat-card span { color: var(--blue); font-size: 9px; font-weight: 850; letter-spacing: .6px; }.shared-chat-card strong { font-size: 13px; }.shared-chat-card small { color: var(--muted); font-size: 10px; }.trainer-lock-page { position: relative; min-height: calc(100vh - 90px); overflow: hidden; }.trainer-lock-background { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; opacity: .3; filter: blur(2px); pointer-events: none; }.ghost-card { height: 190px; padding: 20px; border: 1px solid #dce4ef; border-radius: 16px; background: #fff; }.ghost-card span { display: block; height: 13px; margin-bottom: 16px; border-radius: 6px; background: #e6edf6; }.ghost-card span:first-child { width: 70%; height: 55px; background: #eef7ff; }.trainer-lock-overlay { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; padding: 30px; background: rgba(248, 250, 253, .68); text-align: center; }.trainer-lock-overlay h1 { max-width: 580px; margin: 0; font-size: clamp(26px, 4vw, 44px); }.trainer-lock-overlay p:not(.eyebrow) { max-width: 480px; color: var(--muted); line-height: 1.5; }.trainer-lock-overlay a { color: var(--blue); font-weight: 800; }
@media (max-width: 1050px) { .trainer-stat-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }.trainer-client-switcher { align-items: flex-start; flex-direction: column; }.switcher-label { min-width: 0; flex-direction: row; align-items: center; justify-content: space-between; width: 100%; }.switcher-label .quiet-button { text-align: right; }.switcher-list { width: 100%; } }
@media (max-width: 850px) { .clients-page { padding: 22px 16px 35px; }.trainer-two-col { grid-template-columns: 1fr; }.trainer-topbar, .trainer-profile { align-items: flex-start; flex-direction: column; }.trainer-profile { margin-bottom: 12px; }.trainer-actions { justify-content: flex-start; }.trainer-lock-background { grid-template-columns: 1fr; }.trainer-lock-background .ghost-card:not(:first-child) { display: none; } }
@media (max-width: 560px) { .trainer-stat-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }.trainer-stat strong { font-size: 18px; }.trainer-profile-main { align-items: flex-start; }.trainer-profile h1 { font-size: 25px; }.active-status { display: flex; margin: 7px 0 0; margin-left: 0; width: fit-content; }.trainer-section-head { flex-direction: column; }.trainer-section-head > .quiet-button, .trainer-section-head > .trainer-button { align-self: flex-start; }.form-grid, .targets-grid { grid-template-columns: 1fr; }.checkpoint-row { grid-template-columns: 45px minmax(0, 1fr); }.checkpoint-pill { grid-column: 2; justify-self: start; }.chat-compose { align-items: stretch; }.week-strip { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
</style>
