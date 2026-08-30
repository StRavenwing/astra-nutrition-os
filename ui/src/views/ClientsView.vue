<script setup lang="ts">
import { reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { ClientDetail, ClientSummary, ProgressEntry, TrainerChatMessage } from '@/types';
import { formatDate, formatDateTime, fmt } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import DiaryEntryForm from '@/components/forms/DiaryEntryForm.vue';
import WorkoutBuilderModal from '@/components/modals/WorkoutBuilderModal.vue';

const props = defineProps<{ refreshKey: number; canAccess: boolean; isAdmin: boolean }>();
const emit = defineEmits<{ changed: []; feedback: [] }>();

const clients = ref<ClientSummary[]>([]);
const selected = ref<ClientDetail | null>(null);
const loading = ref(false);
const error = ref('');
const addOpen = ref(false);
const email = ref('');
const addError = ref('');
const diaryOpen = ref(false);
const scheduleOpen = ref(false);
const targetsOpen = ref(false);
const historyOpen = ref(false);
const chatOpen = ref(false);
const chatClient = ref<ClientSummary | null>(null);
const chatMessages = ref<TrainerChatMessage[]>([]);
const chatText = ref('');
const chatError = ref('');
const targets = reactive({ kcal_target: '', protein_target_g: '', fat_target_g: '', carbs_target_g: '' });

async function load() {
  if (!props.canAccess) return;
  loading.value = true;
  error.value = '';
  try { clients.value = await api.clients(); }
  catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { loading.value = false; }
}

async function openClient(id: number) {
  error.value = '';
  try {
    selected.value = await api.client(id);
    const latest: ProgressEntry | undefined = selected.value.progress[0];
    targets.kcal_target = latest?.kcal_target == null ? '' : String(latest.kcal_target);
    targets.protein_target_g = latest?.protein_target_g == null ? '' : String(latest.protein_target_g);
    targets.fat_target_g = latest?.fat_target_g == null ? '' : String(latest.fat_target_g);
    targets.carbs_target_g = latest?.carbs_target_g == null ? '' : String(latest.carbs_target_g);
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

async function refreshSelected() {
  if (selected.value) await openClient(selected.value.id);
  await load();
}

async function addClient() {
  addError.value = '';
  try {
    const client = await api.addClient(email.value.trim());
    clients.value = [...clients.value, client];
    email.value = '';
    addOpen.value = false;
  } catch (err) { addError.value = err instanceof Error ? err.message : String(err); }
}

async function saveTargets() {
  if (!selected.value) return;
  try {
    await api.updateClientTargets(selected.value.id, targets);
    targetsOpen.value = false;
    await refreshSelected();
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

async function openChat(client: ClientSummary) {
  chatError.value = '';
  chatText.value = '';
  chatClient.value = client;
  selected.value = selected.value?.id === client.id ? selected.value : null;
  try {
    chatMessages.value = await api.clientChat(client.id);
    client.unread_messages = 0;
    if (selected.value?.id === client.id) selected.value.unread_messages = 0;
    chatOpen.value = true;
  } catch (err) { chatError.value = err instanceof Error ? err.message : String(err); }
}

async function sendChat() {
  if (!chatClient.value || !chatText.value.trim()) return;
  try {
    chatMessages.value = [...chatMessages.value, await api.sendClientChat(chatClient.value.id, chatText.value.trim())];
    chatText.value = '';
  } catch (err) { chatError.value = err instanceof Error ? err.message : String(err); }
}

function scheduled(value: string | null | undefined) { return value ? formatDateTime(value) : 'Не запланирована'; }
function remaining(value: number | null) { return value == null ? '—' : `${fmt(value)}`; }
function entryCaption(item: { servings: number | null; quantity: number | null; measurement_name: string | null }) {
  if (item.quantity != null) return `${fmt(item.quantity)} ${item.measurement_name || ''}`;
  return `${fmt(item.servings || 1)} порц.`;
}
function latestProgress() { return selected.value?.progress[0] || null; }

watch(() => [props.refreshKey, props.canAccess], () => { void load(); }, { immediate: true });
</script>

<template>
  <section v-if="!props.canAccess" class="clients-page trainer-lock-page">
    <div class="trainer-lock-background" aria-hidden="true">
      <div class="client-card ghost-card" v-for="index in 3" :key="index"><span></span><span></span><span></span></div>
    </div>
    <div class="trainer-lock-overlay">
      <p class="eyebrow">РЕЖИМ ТРЕНЕРА</p>
      <h1>Напишите нам, чтобы стать тренером</h1>
      <p>Откройте доступ к клиентам, планам тренировок и профессиональным инструментам.</p>
      <a href="#feedback" @click.prevent="emit('feedback')">Перейти в обратную связь →</a>
    </div>
  </section>

  <section v-else class="clients-page">
    <div class="clients-head">
      <div><p class="eyebrow">ТРЕНЕРСКИЙ РЕЖИМ</p><h1>Клиенты</h1><p class="clients-lead">Дневник, тренировки и нормы питания под рукой.</p></div>
      <button type="button" class="primary" @click="addOpen = true">＋ Добавить клиента</button>
    </div>
    <div v-if="loading" class="panel">Загрузка клиентов…</div>
    <div v-else-if="error" class="panel form-error">{{ error }}</div>
    <div v-else-if="!clients.length" class="panel clients-empty"><h2>Здесь пока нет клиентов</h2><p>Добавьте зарегистрированного пользователя по email.</p></div>
    <div v-else class="clients-grid">
      <article v-for="client in clients" :key="client.id" class="client-card" tabindex="0" @click="openClient(client.id)" @keydown.enter.prevent="openClient(client.id)">
        <div class="client-next-workout"><span>БЛИЖАЙШАЯ ТРЕНИРОВКА</span><strong>{{ scheduled(client.next_workout?.scheduled_at) }}</strong></div>
        <div class="client-card-body"><div class="client-avatar">{{ client.name.slice(0, 1).toUpperCase() }}</div><div><h2>{{ client.name }}</h2><p>{{ client.email }}</p></div></div>
        <button type="button" class="secondary-button client-chat-button" @click.stop="openChat(client)"><span>💬 Чат с клиентом</span><strong v-if="client.unread_messages" class="chat-unread-badge">{{ client.unread_messages > 99 ? '99+' : client.unread_messages }}</strong></button>
      </article>
    </div>
  </section>

  <ModalDialog :open="Boolean(selected)" :title="selected?.name || 'Клиент'" eyebrow="КАРТОЧКА КЛИЕНТА" wide @close="selected = null">
    <div v-if="selected" class="client-detail">
      <div class="client-detail-head"><div><p>{{ selected.email }}</p><small>Данные доступны тренеру и администратору</small></div><button type="button" class="secondary-button client-detail-chat-button" @click="openChat(selected)"><span>💬 Чат</span><strong v-if="selected.unread_messages" class="chat-unread-badge">{{ selected.unread_messages > 99 ? '99+' : selected.unread_messages }}</strong></button></div>
      <div class="client-detail-grid">
        <section class="client-detail-section"><div class="section-heading"><div><p class="eyebrow">ЗАМЕРЫ</p><h3>Последние показатели</h3></div><button type="button" class="text-button" @click="targetsOpen = true">Редактировать нормы</button></div>
          <div v-if="latestProgress()" class="measure-grid"><div><span>Вес</span><b>{{ fmt(latestProgress()?.weight_kg) }} кг</b></div><div><span>Рост</span><b>{{ fmt(latestProgress()?.height_cm) }} см</b></div><div><span>Жир</span><b>{{ fmt(latestProgress()?.body_fat_pct) }}%</b></div><div><span>Дата</span><b>{{ formatDate(latestProgress()?.measured_at) }}</b></div></div>
          <p v-else class="subtle">Замеры ещё не добавлены.</p>
        </section>
        <section class="client-detail-section"><div class="section-heading"><div><p class="eyebrow">ДНЕВНИК · {{ formatDate(selected.today.date) }}</p><h3>Питание за сегодня</h3></div><button type="button" class="primary small-button" @click="diaryOpen = true">＋ Добавить блюдо</button></div>
          <div v-if="selected.today.entries.length" class="client-diary-list"><div v-for="item in selected.today.entries" :key="item.id" class="client-diary-row"><div><b>{{ item.name || 'Блюдо' }}</b><small>{{ item.meal_type }} · {{ entryCaption(item) }}</small></div><span>{{ fmt(item.kcal_per_serving) }} ккал · Б {{ fmt(item.protein_per_serving_g) }} · Ж {{ fmt(item.fat_per_serving_g) }} · У {{ fmt(item.carbs_per_serving_g) }}</span></div></div><p v-else class="subtle">Сегодня блюд и продуктов пока нет.</p>
          <div class="macro-summary"><div><span>Съедено</span><b>{{ fmt(selected.today.totals.kcal) }} ккал</b></div><div><span>Осталось</span><b>{{ remaining(selected.today.remaining.kcal) }} ккал</b></div><div><span>Б / Ж / У</span><b>{{ fmt(selected.today.totals.protein) }} / {{ fmt(selected.today.totals.fat) }} / {{ fmt(selected.today.totals.carbs) }} г</b></div><div><span>Остаток Б / Ж / У</span><b>{{ remaining(selected.today.remaining.protein) }} / {{ remaining(selected.today.remaining.fat) }} / {{ remaining(selected.today.remaining.carbs) }} г</b></div></div>
        </section>
      </div>
      <div class="client-detail-actions"><button type="button" class="secondary-button" @click="scheduleOpen = true">＋ Запланировать тренировку</button><button type="button" class="secondary-button" @click="historyOpen = true">История тренировок</button><button type="button" class="secondary-button" @click="targetsOpen = true">Параметры и нормы</button></div>
    </div>
  </ModalDialog>

  <ModalDialog :open="addOpen" title="Добавить клиента" eyebrow="КЛИЕНТ" @close="addOpen = false"><form class="client-form" @submit.prevent="addClient"><p>Введите email уже зарегистрированного пользователя.</p><div class="field full"><label>Email клиента</label><input v-model="email" type="email" required autofocus placeholder="client@example.com"></div><p class="form-error">{{ addError }}</p><div class="actions"><button type="button" @click="addOpen = false">Отмена</button><button type="submit" class="primary">Добавить</button></div></form></ModalDialog>
  <ModalDialog :open="diaryOpen" title="Добавить блюдо клиенту" eyebrow="ДНЕВНИК ПИТАНИЯ" wide @close="diaryOpen = false"><DiaryEntryForm v-if="selected" :target-user-id="selected.id" @saved="diaryOpen = false; refreshSelected()" @cancel="diaryOpen = false" /></ModalDialog>
  <WorkoutBuilderModal :open="scheduleOpen" :target-user-id="selected?.id" @close="scheduleOpen = false" @saved="scheduleOpen = false; refreshSelected()" />
  <ModalDialog :open="targetsOpen" title="Нормы питания" eyebrow="ПАРАМЕТРЫ КЛИЕНТА" @close="targetsOpen = false"><form class="client-form" @submit.prevent="saveTargets"><p>Тренер может задать персональные суточные нормы.</p><div class="grid targets-grid"><div class="field"><label>Ккал</label><input v-model="targets.kcal_target" type="number" min="0" step="1"></div><div class="field"><label>Белки, г</label><input v-model="targets.protein_target_g" type="number" min="0" step="0.1"></div><div class="field"><label>Жиры, г</label><input v-model="targets.fat_target_g" type="number" min="0" step="0.1"></div><div class="field"><label>Углеводы, г</label><input v-model="targets.carbs_target_g" type="number" min="0" step="0.1"></div></div><div class="actions"><button type="button" @click="targetsOpen = false">Отмена</button><button type="submit" class="primary">Сохранить нормы</button></div></form></ModalDialog>
  <ModalDialog :open="historyOpen" title="История тренировок" eyebrow="ТРЕНИРОВКИ" wide @close="historyOpen = false"><div class="client-history"><h3>Запланированные</h3><div v-for="plan in selected?.workout_plans" :key="plan.id" class="history-row"><b>{{ formatDate(plan.scheduled_at) }}</b><span>{{ plan.items.length }} упражн. · {{ plan.status === 'planned' ? 'запланирована' : 'завершена' }}</span></div><p v-if="!selected?.workout_plans.length" class="subtle">Планов пока нет.</p><h3>Выполненные упражнения</h3><div v-for="item in selected?.workouts" :key="item.id" class="history-row"><b>{{ item.name }}</b><span>{{ formatDate(item.performed_at) }} · {{ fmt(item.working_weight) }} {{ item.default_unit || '' }}</span></div><p v-if="!selected?.workouts.length" class="subtle">История пока пуста.</p></div></ModalDialog>
  <ModalDialog :open="chatOpen" :title="chatClient?.name ? `Чат · ${chatClient.name}` : 'Чат с клиентом'" eyebrow="СООБЩЕНИЯ" @close="chatOpen = false"><div class="chat-box"><div class="chat-messages"><p v-if="!chatMessages.length" class="subtle">Сообщений пока нет.</p><div v-for="message in chatMessages" :key="message.id" class="chat-message"><b>{{ message.sender_name }}</b><span v-if="!message.shared_item">{{ message.message }}</span><div v-else class="shared-chat-card"><span>ОТПРАВЛЕНО В ЧАТ</span><strong>{{ message.shared_item.name }}</strong><small>{{ message.shared_item.type === 'article' ? 'Статья' : message.shared_item.type === 'recipe' ? 'Блюдо' : message.shared_item.type === 'product' ? 'Продукт' : message.shared_item.type === 'progress' ? 'Показатели' : message.shared_item.type === 'exercise' ? 'Упражнение' : message.shared_item.type === 'workout_complex' ? 'Комплекс тренировки' : 'Тренажёр или инвентарь' }}</small></div><small>{{ formatDateTime(message.created_at) }}</small></div></div><p class="form-error">{{ chatError }}</p><form class="chat-compose" @submit.prevent="sendChat"><input v-model="chatText" maxlength="2000" placeholder="Написать сообщение…"><button type="submit" class="primary">Отправить</button></form></div></ModalDialog>
</template>

<style lang="scss">
.clients-page { padding: 30px 34px 50px; }
.clients-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; margin-bottom: 26px; }
.clients-head h1 { margin: 0; font-size: clamp(30px, 4vw, 48px); }
.clients-lead { margin: 8px 0 0; color: var(--muted); }
.clients-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 24px; }
.client-card { display: flex; box-sizing: border-box; flex-direction: column; height: 300px; min-height: 300px; overflow: hidden; border: 1px solid #dce4ef; border-radius: 18px; background: #fff; box-shadow: 0 8px 24px rgba(34, 62, 105, .08); cursor: pointer; transition: transform .18s, box-shadow .18s; }
.client-card:hover, .client-card:focus { transform: translateY(-2px); box-shadow: 0 14px 34px rgba(34, 62, 105, .12); outline: none; }
.client-next-workout { display: grid; gap: 6px; padding: 13px 16px; background: #eef7ff; color: #326ca5; }
.client-next-workout span { font-size: 9px; font-weight: 850; letter-spacing: .8px; }
.client-next-workout strong { font-size: 13px; }
.client-card-body { display: flex; align-items: center; gap: 13px; padding: 20px 20px 14px; }
.client-avatar { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 14px; background: #e6defe; color: #624eb1; font-size: 20px; font-weight: 850; }
.client-card h2 { margin: 0; font-size: 17px; }.client-card p { margin: 5px 0 0; color: var(--muted); font-size: 12px; }
.client-chat-button { display: flex; align-items: center; justify-content: space-between; margin: auto 20px 20px; width: calc(100% - 40px); }.client-detail-chat-button { display: inline-flex; align-items: center; gap: 8px; }.chat-unread-badge { display: inline-grid; place-items: center; min-width: 20px; height: 20px; padding: 0 5px; border-radius: 99px; background: #6f82ff; color: #fff; font-size: 10px; line-height: 1; }
.trainer-lock-page { position: relative; min-height: calc(100vh - 90px); overflow: hidden; }
.trainer-lock-background { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; opacity: .3; filter: blur(2px); pointer-events: none; }.ghost-card { height: 190px; padding: 20px; border: 1px solid #dce4ef; border-radius: 16px; background: #fff; }.ghost-card span { display: block; height: 13px; margin-bottom: 16px; border-radius: 6px; background: #e6edf6; }.ghost-card span:first-child { width: 70%; height: 55px; background: #eef7ff; }
.trainer-lock-overlay { position: absolute; inset: 0; display: grid; place-content: center; justify-items: center; padding: 30px; background: rgba(248, 250, 253, .68); text-align: center; }.trainer-lock-overlay h1 { max-width: 580px; margin: 0; font-size: clamp(26px, 4vw, 44px); }.trainer-lock-overlay p:not(.eyebrow) { max-width: 480px; color: var(--muted); line-height: 1.5; }.trainer-lock-overlay a { color: var(--blue); font-weight: 800; }
.client-detail-head, .section-heading, .client-detail-actions, .chat-compose { display: flex; align-items: center; justify-content: space-between; gap: 12px; }.client-detail-head { padding-bottom: 16px; border-bottom: 1px solid var(--line); }.client-detail-head p { margin: 0; font-weight: 750; }.client-detail-head small { color: var(--muted); }.client-detail-grid { display: grid; grid-template-columns: .8fr 1.2fr; gap: 16px; margin-top: 16px; }.client-detail-section { padding: 16px; border: 1px solid var(--line); border-radius: 14px; }.section-heading { align-items: flex-start; }.section-heading h3 { margin: 0; font-size: 16px; }.section-heading .eyebrow { margin-bottom: 5px; }.text-button { border: 0; background: transparent; color: var(--blue); cursor: pointer; font-weight: 750; }.measure-grid, .macro-summary { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; margin-top: 15px; }.measure-grid div, .macro-summary div { display: grid; gap: 4px; padding: 10px; border-radius: 10px; background: #f6f8fb; }.measure-grid span, .macro-summary span { color: var(--muted); font-size: 10px; }.measure-grid b, .macro-summary b { font-size: 13px; }.client-diary-list { display: grid; gap: 8px; margin-top: 14px; max-height: 260px; overflow: auto; }.client-diary-row { display: flex; justify-content: space-between; gap: 12px; padding: 10px; border-bottom: 1px solid #edf0f5; }.client-diary-row b, .client-diary-row small { display: block; }.client-diary-row small, .client-diary-row > span { color: var(--muted); font-size: 11px; }.client-diary-row > span { text-align: right; }.client-detail-actions { justify-content: flex-start; flex-wrap: wrap; margin-top: 16px; }.small-button { padding: 8px 10px; font-size: 11px; }.client-form { min-width: min(450px, 100%); }.client-form > p:first-child { margin-top: 0; color: var(--muted); }.targets-grid { grid-template-columns: repeat(2, 1fr); }.client-history { min-width: min(600px, 100%); }.client-history h3 { margin: 18px 0 8px; }.history-row { display: flex; justify-content: space-between; gap: 15px; padding: 11px 0; border-bottom: 1px solid var(--line); }.history-row span { color: var(--muted); font-size: 12px; }.chat-box { min-width: min(520px, 100%); }.chat-messages { display: grid; gap: 8px; max-height: 330px; overflow-y: auto; margin-bottom: 12px; }.chat-message { display: grid; gap: 3px; padding: 10px 12px; border-radius: 10px; background: #f4f7fb; }.chat-message span { white-space: pre-wrap; }.chat-message small { color: var(--muted); font-size: 10px; }.chat-compose input { min-width: 0; flex: 1; }.clients-empty { text-align: center; }.clients-empty h2 { margin-top: 0; }.form-error { min-height: 18px; color: #ae2a19; }
@media (max-width: 850px) { .clients-page { padding: 22px 16px 35px; }.clients-head { align-items: flex-start; flex-direction: column; }.client-detail-grid { grid-template-columns: 1fr; }.trainer-lock-background { grid-template-columns: 1fr; }.trainer-lock-background .ghost-card:not(:first-child) { display: none; } }
@media (max-width: 560px) { .client-diary-row, .history-row { display: grid; }.client-diary-row > span { text-align: left; }.client-detail-head { align-items: flex-start; flex-direction: column; }.targets-grid { grid-template-columns: 1fr; } }
  .shared-chat-card { display: grid; gap: 3px; margin: 4px 0; padding: 10px; border: 1px solid #b8d5ff; border-radius: 9px; background: #eaf3ff; }
  .shared-chat-card span { color: var(--blue); font-size: 9px; font-weight: 850; letter-spacing: .6px; }
  .shared-chat-card strong { font-size: 13px; }
  .shared-chat-card small { color: var(--muted); font-size: 10px; }
</style>
