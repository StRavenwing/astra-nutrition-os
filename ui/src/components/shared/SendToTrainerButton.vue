<script setup lang="ts">
import { ref } from 'vue';
import { api } from '@/api/client';
import type { ShareItemType } from '@/types';

const props = defineProps<{ itemType: ShareItemType; itemId: number; canSend: boolean; compact?: boolean }>();
const sending = ref(false);
const error = ref('');
const sent = ref('');

async function send() {
  if (sending.value) return;
  error.value = '';
  sent.value = '';
  sending.value = true;
  try {
    const result = await api.shareItemToTrainer(props.itemType, props.itemId);
    sent.value = result.already_shared ? 'Уже отправлено тренеру' : 'Отправлено тренеру';
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    sending.value = false;
  }
}
</script>

<template>
  <div v-if="props.canSend" class="send-trainer-control" :class="{ compact: props.compact }">
    <button type="button" class="card-action send-trainer-button" :class="{ compact: props.compact }" :aria-label="props.compact ? 'Отправить тренеру' : undefined" :title="props.compact ? 'Отправить тренеру' : undefined" :disabled="sending" @click.stop="send">↗<span v-if="!props.compact"> {{ sending ? 'Отправка…' : 'Отправить тренеру' }}</span></button>
    <span v-if="sent" class="send-trainer-status" role="status">{{ sent }}</span>
    <span v-if="error" class="send-trainer-error" role="alert">{{ error }}</span>
  </div>
</template>

<style lang="scss">
.send-trainer-control { min-width: 0; position: relative; }
.send-trainer-button { width: 100%; min-height: 36px; border: 1px solid #85b8ff; border-radius: 8px; padding: 8px 9px; background: #e9f2ff; color: var(--blue); font-size: 10px; font-weight: 750; line-height: 1.1; cursor: pointer; }
.send-trainer-button.compact { width: 36px; min-width: 36px; height: 36px; min-height: 36px; padding: 0; font-size: 16px; line-height: 1; }
.send-trainer-button:disabled { cursor: wait; opacity: .7; }
.send-trainer-button:hover:not(:disabled) { background: #dcecff; }
.send-trainer-status, .send-trainer-error { display: block; margin-top: 4px; font-size: 10px; text-align: center; }
.send-trainer-status { color: #216e4e; }.send-trainer-error { color: #ae2a19; }
</style>
