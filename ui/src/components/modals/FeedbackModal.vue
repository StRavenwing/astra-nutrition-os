<script setup lang="ts">
import { ref, watch } from 'vue';
import { api } from '@/api/client';
import type { FeedbackMessage } from '@/types';
import { formatDateTime } from '@/utils/format';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ open: boolean; isAdmin: boolean }>();
const emit = defineEmits<{ close: []; sent: []; read: [] }>();

const message = ref('');
const feedback = ref<FeedbackMessage[]>([]);
const loading = ref(false);
const sending = ref(false);
const error = ref('');

async function loadFeedback() {
  if (!props.open || !props.isAdmin) return;
  loading.value = true;
  error.value = '';
  try {
    feedback.value = await api.feedback();
    await api.markFeedbackRead();
    emit('read');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

watch(() => [props.open, props.isAdmin], loadFeedback, { immediate: true });

async function send() {
  const value = message.value.trim();
  if (!value || sending.value) return;
  sending.value = true;
  error.value = '';
  try {
    await api.sendFeedback(value);
    message.value = '';
    emit('sent');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <ModalDialog :open="open" :title="isAdmin ? 'Обратная связь пользователей' : 'Обратная связь'" eyebrow="FEEDBACK" wide @close="$emit('close')">
    <template v-if="isAdmin">
      <div v-if="loading" class="panel">Загрузка…</div>
      <div v-else-if="error" class="panel empty">{{ error }}</div>
      <div v-else class="feedback-list">
        <article v-for="item in feedback" :key="item.id" class="feedback-card">
          <div class="feedback-card-head">
            <b>{{ item.email }}</b>
            <time>{{ formatDateTime(item.submitted_at) }}</time>
          </div>
          <p>{{ item.message }}</p>
        </article>
        <div v-if="!feedback.length" class="panel empty">Сообщений пока нет</div>
      </div>
    </template>
    <form v-else class="feedback-form" @submit.prevent="send">
      <label class="field full">
        <span>Ваше сообщение</span>
        <textarea v-model="message" maxlength="500" rows="7" placeholder="Напишите сообщение или предложение"></textarea>
      </label>
      <div class="feedback-form-meta">{{ message.length }}/500</div>
      <p v-if="error" class="form-error">{{ error }}</p>
      <div class="feedback-actions">
        <button type="button" @click="$emit('close')">Закрыть</button>
        <button type="submit" class="primary" :disabled="sending || !message.trim()">{{ sending ? 'Отправка…' : 'Отправить' }}</button>
      </div>
    </form>
  </ModalDialog>
</template>

<style lang="scss">
.feedback-form { display: grid; gap: 10px; }
.feedback-form .field { display: grid; gap: 7px; }
.feedback-form .field span { font-size: 12px; font-weight: 750; }
.feedback-form textarea { width: 100%; min-height: 150px; resize: vertical; }
.feedback-form-meta { color: var(--muted); font-size: 11px; text-align: right; }
.form-error { margin: 0; color: #ae2a19; font-size: 12px; }
.feedback-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px; }
.feedback-actions button { min-width: 100px; }
.feedback-list { display: grid; gap: 10px; }
.feedback-card { padding: 14px; border: 1px solid var(--line); border-radius: 11px; background: #fafbfc; }
.feedback-card-head { display: flex; justify-content: space-between; gap: 14px; align-items: center; }
.feedback-card-head time { color: var(--muted); font-size: 11px; white-space: nowrap; }
.feedback-card p { margin: 10px 0 0; color: var(--ink); line-height: 1.55; white-space: pre-wrap; }
@media (max-width: 600px) { .feedback-card-head { align-items: flex-start; flex-direction: column; gap: 4px; } }
</style>
