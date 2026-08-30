<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { DashboardResponse, DiaryEntry, PageId, RegisteredUser, SharedItemDetail, TrainerChatMessage, TrainerChatResponse } from '@/types';
import { mealOrder } from '@/constants';
import { diaryTotals, fmt, formatDate, formatDateTime, localToday } from '@/utils/format';
import MetricCard from '@/components/shared/MetricCard.vue';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import SharedItemModal from '@/components/modals/SharedItemModal.vue';

const props = defineProps<{ refreshKey: number; isAdmin: boolean; canUseTrainerChat: boolean }>();
const emit = defineEmits<{ navigate: [page: PageId]; openRecipe: [id: number] }>();

const data = ref<DashboardResponse | null>(null);
const users = ref<RegisteredUser[]>([]);
const diary = ref<DiaryEntry[]>([]);
const trainerChat = ref<TrainerChatResponse>({ trainer: null, messages: [], unread_count: 0 });
const chatText = ref('');
const chatError = ref('');
const chatSending = ref(false);
const sharedItem = ref<SharedItemDetail | null>(null);
const usersOpen = ref(false);
const loading = ref(false);
const error = ref('');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const [dashboardData, registeredUsers, diaryData, trainerChatData] = await Promise.all([
      api.dashboard(),
      props.isAdmin ? api.users() : Promise.resolve([] as RegisteredUser[]),
      api.diary(),
      props.canUseTrainerChat ? api.myTrainerChat() : Promise.resolve({ trainer: null, messages: [], unread_count: 0 } as TrainerChatResponse)
    ]);
    data.value = dashboardData;
    users.value = registeredUsers;
    diary.value = diaryData;
    trainerChat.value = trainerChatData;
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

const todayEntries = computed(() => diary.value.filter((item) => item.entry_date === localToday()));
const todayTotals = computed(() => diaryTotals(todayEntries.value));
const dayCompletion = computed(() => Math.min(Math.round((todayTotals.value.kcal / 2100) * 100), 100));
const todayLabel = computed(() => new Intl.DateTimeFormat('ru-RU', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()));

onMounted(load);
watch(() => [props.refreshKey, props.canUseTrainerChat], load);

const visibleChatMessages = computed(() => trainerChat.value.messages.slice(-5));

async function sendTrainerChat() {
  const message = chatText.value.trim();
  if (!message || chatSending.value) return;
  chatError.value = '';
  chatSending.value = true;
  try {
    const sent = await api.sendMyTrainerChat(message);
    trainerChat.value.messages = [...trainerChat.value.messages, sent];
    chatText.value = '';
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err);
  } finally {
    chatSending.value = false;
  }
}

async function openSharedItem(message: TrainerChatMessage) {
  if (!message.shared_item) return;
  chatError.value = '';
  try {
    sharedItem.value = await api.mySharedItem(message.shared_item.type, message.shared_item.id);
  } catch (err) {
    chatError.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else-if="data">
    <div class="dashboard-layout">
      <section class="dashboard-hero">
        <div>
          <p class="eyebrow">СЕГОДНЯ</p>
          <h2>{{ dayCompletion ? `Ваш ритм уже собран на ${dayCompletion}%` : 'Начните с одного простого шага' }}</h2>
          <p>{{ todayEntries.length ? 'Завтрак добавлен. Следующий шаг — отметить следующий приём пищи и выпить воды.' : 'Добавьте первый приём пищи — этого достаточно, чтобы начать видеть свой ритм.' }}</p>
          <button type="button" class="mint-button" @click="emit('navigate', 'diary')">Открыть дневник</button>
        </div>
        <div class="dashboard-ring" :style="{ '--progress': `${dayCompletion}%` }"><strong>{{ dayCompletion }}%</strong><span>дня</span></div>
      </section>

      <section v-if="trainerChat.trainer" class="dashboard-trainer-chat dashboard-span">
        <div class="dashboard-trainer-chat-head">
          <div><p class="eyebrow">ВАШ ТРЕНЕР</p><h3>Чат с {{ trainerChat.trainer.name }}</h3><span>{{ trainerChat.trainer.email }}</span></div>
          <span v-if="trainerChat.unread_count" class="trainer-chat-unread">{{ trainerChat.unread_count > 99 ? '99+' : trainerChat.unread_count }} новых</span>
          <span class="trainer-chat-status">На связи</span>
        </div>
        <div class="dashboard-chat-messages">
          <p v-if="!visibleChatMessages.length" class="subtle">Напишите тренеру первый вопрос.</p>
          <div v-for="message in visibleChatMessages" :key="message.id" class="dashboard-chat-message">
            <b>{{ message.sender_name }}</b>
            <button v-if="message.shared_item" type="button" class="dashboard-chat-shared" @click="openSharedItem(message)"><strong>{{ message.shared_item.name }}</strong><small>Открыть отправленный материал · {{ message.shared_item.type === 'article' ? 'статья' : message.shared_item.type === 'recipe' ? 'блюдо' : message.shared_item.type === 'product' ? 'продукт' : message.shared_item.type === 'exercise' ? 'упражнение' : message.shared_item.type === 'progress' ? 'показатели' : message.shared_item.type === 'workout_complex' ? 'комплекс тренировки' : 'тренажёр или инвентарь' }}</small></button>
            <span v-else>{{ message.message }}</span>
            <time>{{ formatDateTime(message.created_at) }}</time>
          </div>
        </div>
        <form class="dashboard-chat-compose" @submit.prevent="sendTrainerChat"><input v-model="chatText" maxlength="2000" placeholder="Написать тренеру…"><button type="submit" class="mint-button" :disabled="chatSending">Отправить</button></form>
        <p v-if="chatError" class="dashboard-chat-error">{{ chatError }}</p>
      </section>

      <section class="dashboard-database">
        <p class="eyebrow">ВАША БАЗА</p>
        <strong>{{ data.products }}</strong>
        <span>продуктов</span>
        <hr>
        <b>{{ data.recipes }} рецепта</b>
        <button type="button" @click="emit('navigate', 'products')">Открыть каталог →</button>
      </section>

      <section class="dashboard-quick dashboard-span">
        <h3>Быстрый доступ</h3>
        <div class="dashboard-quick-grid">
          <MetricCard label="Продукты" :value="data.products" note="Открыть каталог →" button @click="emit('navigate', 'products')" />
          <MetricCard label="Рецепты" :value="data.recipes" note="Открыть рецепты →" button @click="emit('navigate', 'recipes')" />
          <MetricCard label="Текущие показатели" :value="`${data.latest?.weight_kg || '—'} кг`" :note="`${data.latest?.waist_cm ? `Талия ${fmt(data.latest.waist_cm)} см · ` : ''}Открыть прогресс →`" button @click="emit('navigate', 'progress')" />
          <MetricCard v-if="props.isAdmin" label="Пользователи" :value="users.length" note="Открыть список →" button @click="usersOpen = true" />
        </div>
      </section>

      <section class="dashboard-diary dashboard-span">
        <h3>Дневник питания</h3>
        <p class="subtle">{{ todayLabel }} · что уже записано</p>
        <div class="dashboard-meal-list">
          <div v-for="meal in mealOrder.slice(0, 3)" :key="meal" class="dashboard-meal-row">
            <span class="meal-dot">●</span>
            <div><b>{{ meal }}</b><small>{{ todayEntries.filter((item) => item.meal_type === meal).map((item) => item.name).join(', ') || 'Ещё не записан' }}</small></div>
            <strong v-if="todayEntries.some((item) => item.meal_type === meal)">{{ fmt(diaryTotals(todayEntries.filter((item) => item.meal_type === meal)).kcal) }} ккал</strong>
            <button v-else type="button" @click="emit('navigate', 'diary')">Записать</button>
          </div>
        </div>
        <button type="button" class="text-link" @click="emit('navigate', 'diary')">Открыть весь дневник →</button>
      </section>

      <section class="dashboard-protein">
        <h3>Самые белковые порции</h3>
        <p class="subtle">Из вашей коллекции рецептов</p>
        <button v-for="recipe in data.top.slice(0, 3)" :key="recipe.id" type="button" class="dashboard-protein-row" @click="emit('openRecipe', recipe.id)">
          <span><b>{{ recipe.name }}</b><i><em :style="{ width: `${Math.min((Number(recipe.protein_per_serving_g) || 0) / 55 * 100, 100)}%` }"></em></i></span>
          <strong>{{ fmt(recipe.protein_per_serving_g) }} г</strong>
        </button>
      </section>
    </div>
  </template>

  <ModalDialog :open="usersOpen" title="Зарегистрированные пользователи" eyebrow="USERS" wide @close="usersOpen = false">
    <div class="registered-users-list">
      <div v-for="user in users" :key="user.id" class="registered-user-row">
        <div><b>{{ user.email }}</b><small>ID {{ user.id }} · {{ user.is_admin ? 'Администратор' : 'Пользователь' }}</small></div>
        <time>{{ formatDate(user.created_at) }}</time>
      </div>
      <div v-if="!users.length" class="empty">Зарегистрированных пользователей пока нет</div>
    </div>
  </ModalDialog>
  <SharedItemModal :item="sharedItem" @close="sharedItem = null" />
</template>

<style lang="scss">
.dashboard-layout { display: grid; grid-template-columns: minmax(0, 3fr) minmax(230px, 1fr); gap: 24px; }
.dashboard-layout h3 { margin: 0 0 8px; font-size: 18px; }
.dashboard-span { grid-column: 1 / -1; }
.dashboard-hero { display: flex; align-items: center; justify-content: space-between; gap: 24px; min-height: 212px; padding: 32px; border-radius: 22px; background: var(--nav); color: #fff; }
.dashboard-hero .eyebrow { color: var(--mint); }
.dashboard-hero h2 { max-width: 640px; margin: 0 0 10px; font-size: clamp(23px, 3vw, 30px); letter-spacing: -.04em; }
.dashboard-hero p:not(.eyebrow) { max-width: 650px; margin: 0 0 22px; color: #aab6c8; }
.mint-button { border: 0; border-radius: 10px; padding: 11px 16px; background: var(--mint); color: var(--ink); font-weight: 800; cursor: pointer; }
.dashboard-ring { --progress: 0%; display: grid; flex: 0 0 145px; place-items: center; align-content: center; width: 145px; height: 145px; border-radius: 50%; background: radial-gradient(circle at center, var(--nav) 64%, transparent 65%), conic-gradient(var(--mint) var(--progress), #34445b 0); }
.dashboard-ring strong, .dashboard-ring span { display: block; }
.dashboard-ring strong { font-size: 25px; }
.dashboard-ring span { color: #aab6c8; font-size: 12px; }
.dashboard-database { padding: 28px; border-radius: 22px; background: #e2f7eb; }
.dashboard-database .eyebrow { color: #329a63; }
.dashboard-database > strong { display: block; margin-top: 10px; font-size: 31px; }
.dashboard-database > span { color: var(--muted); }
.dashboard-database hr { border: 0; border-top: 1px solid #cfead9; margin: 19px 0; }
.dashboard-database b, .dashboard-database button { display: block; }
.dashboard-database button, .text-link { margin-top: 10px; border: 0; padding: 0; background: none; color: var(--blue); font-size: 12px; font-weight: 800; cursor: pointer; }
.dashboard-quick { margin-top: 4px; }
.dashboard-quick-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
.dashboard-quick-grid .card { min-height: 126px; }
.dashboard-quick-grid .card strong { font-size: 28px; }
.dashboard-diary, .dashboard-protein { padding: 28px; border: 1px solid var(--line); border-radius: 20px; background: #fff; }
.dashboard-diary { grid-column: 1; }
.dashboard-protein { grid-column: 2; }
.dashboard-meal-list { margin-top: 24px; }
.dashboard-meal-row { display: grid; grid-template-columns: 26px minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 15px 0; border-top: 1px solid #edf0f5; }
.meal-dot { color: #58bc83; }
.dashboard-meal-row b, .dashboard-meal-row small { display: block; }
.dashboard-meal-row small { margin-top: 3px; color: var(--muted); font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.dashboard-meal-row strong { color: #329a63; font-size: 12px; white-space: nowrap; }
.dashboard-meal-row button { border: 0; border-radius: 8px; padding: 8px 10px; background: #e2f7eb; color: #329a63; font-size: 11px; font-weight: 800; cursor: pointer; }
.dashboard-protein-row { display: flex; align-items: flex-end; justify-content: space-between; width: 100%; gap: 10px; margin-top: 22px; border: 0; padding: 0; background: none; color: var(--ink); text-align: left; cursor: pointer; }
.dashboard-protein-row > span { flex: 1; min-width: 0; }
.dashboard-protein-row b { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; }
.dashboard-protein-row i { display: block; height: 8px; margin-top: 10px; border-radius: 99px; background: #e6e7ff; overflow: hidden; }
.dashboard-protein-row em { display: block; height: 100%; border-radius: inherit; background: var(--blue); }
.dashboard-protein-row strong { font-size: 12px; white-space: nowrap; }
.dashboard-trainer-chat { padding: 24px 28px; border: 1px solid #cfe0ff; border-radius: 20px; background: #f4f8ff; }
.dashboard-trainer-chat-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; }
.dashboard-trainer-chat-head h3 { margin: 0 0 4px; }.dashboard-trainer-chat-head span:not(.trainer-chat-status) { color: var(--muted); font-size: 12px; }
.trainer-chat-unread { border-radius: 99px; padding: 6px 9px; background: #fff0dc; color: #b56a16 !important; font-size: 10px !important; font-weight: 800; white-space: nowrap; }
.trainer-chat-status { border-radius: 99px; padding: 6px 9px; background: #e2f7eb; color: #329a63; font-size: 10px; font-weight: 800; }
.dashboard-chat-messages { display: grid; gap: 8px; max-height: 230px; overflow: auto; margin-top: 18px; }
.dashboard-chat-message { display: grid; gap: 4px; max-width: 80%; padding: 10px 12px; border-radius: 11px; background: #fff; }.dashboard-chat-message:nth-child(even) { justify-self: end; background: #e2f7eb; }.dashboard-chat-message b { font-size: 11px; }.dashboard-chat-message > span { white-space: pre-wrap; }.dashboard-chat-message time { color: var(--muted); font-size: 10px; }
.dashboard-chat-shared { display: grid; gap: 3px; border: 1px solid #b8d5ff; border-radius: 9px; padding: 9px; background: #eaf3ff; color: var(--ink); text-align: left; cursor: pointer; }.dashboard-chat-shared:hover { background: #dcecff; }.dashboard-chat-shared small { color: var(--blue); font-size: 10px; }
.dashboard-chat-compose { display: flex; gap: 10px; margin-top: 16px; }.dashboard-chat-compose input { min-width: 0; flex: 1; }.dashboard-chat-compose .mint-button { border: 0; }.dashboard-chat-error { margin: 8px 0 0; color: #ae2a19; font-size: 11px; }
@media (max-width: 900px) { .dashboard-layout { grid-template-columns: 1fr; } .dashboard-database, .dashboard-diary, .dashboard-protein { grid-column: 1; } .dashboard-quick-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px) { .dashboard-hero { align-items: flex-start; flex-direction: column; padding: 24px; } .dashboard-ring { align-self: center; } .dashboard-quick-grid { grid-template-columns: 1fr; } }
.registered-users-list { display: grid; gap: 8px; }
.registered-user-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 13px; border: 1px solid var(--line); border-radius: 10px; background: #fafbfc; }
.registered-user-row b, .registered-user-row small { display: block; }
.registered-user-row small, .registered-user-row time { color: var(--muted); font-size: 11px; }
.registered-user-row time { white-space: nowrap; }
@media (max-width: 600px) { .registered-user-row { align-items: flex-start; flex-direction: column; gap: 4px; } }
</style>
