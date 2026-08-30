<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { ClientSummary, ShareItemType } from '@/types';

const props = defineProps<{ itemType: ShareItemType; itemId: number; canManage: boolean }>();
const root = ref<HTMLElement | null>(null);
const open = ref(false);
const loading = ref(false);
const clients = ref<ClientSummary[]>([]);
const error = ref('');
const sent = ref('');

function closeOnOutside(event: MouseEvent) {
  if (root.value && !root.value.contains(event.target as Node)) open.value = false;
}

async function toggle() {
  sent.value = '';
  error.value = '';
  open.value = !open.value;
  if (!open.value || clients.value.length) return;
  loading.value = true;
  try { clients.value = await api.clients(); }
  catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { loading.value = false; }
}

async function send(client: ClientSummary) {
  error.value = '';
  try {
    const result = await api.shareItem(client.id, props.itemType, props.itemId);
    sent.value = result.already_shared ? `Уже отправлено: ${client.name}` : `Отправлено: ${client.name}`;
    open.value = false;
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

watch(() => props.canManage, (canManage) => { if (!canManage) open.value = false; });
document.addEventListener('click', closeOnOutside);
onBeforeUnmount(() => document.removeEventListener('click', closeOnOutside));
</script>

<template>
  <div v-if="props.canManage" ref="root" class="send-client-control">
    <button type="button" class="card-action send-client-button" :aria-expanded="open" aria-haspopup="menu" @click.stop="toggle">↗ Отправить клиенту</button>
    <div v-if="open" class="send-client-menu" role="menu">
      <p class="send-client-menu-title">Выберите клиента</p>
      <p v-if="loading" class="send-client-muted">Загрузка…</p>
      <p v-else-if="error" class="send-client-error">{{ error }}</p>
      <p v-else-if="!clients.length" class="send-client-muted">Сначала добавьте клиента в разделе «Клиенты».</p>
      <button v-for="client in clients" :key="client.id" type="button" role="menuitem" class="send-client-option" @click="send(client)"><b>{{ client.name }}</b><small>{{ client.email }}</small></button>
    </div>
    <span v-if="sent" class="send-client-status" role="status">{{ sent }}</span>
  </div>
</template>

<style lang="scss">
.send-client-control { position: relative; min-width: 0; }
.product-tile-actions > .send-client-control,
.recipe-tile-actions > .send-client-control,
.workout-complex-actions > .send-client-control,
.equipment-card-actions > .send-client-control,
.progress-tile-actions > .send-client-control { grid-column: 1 / -1; }
.progress-latest-card > .send-client-control { margin-top: 18px; }
.send-client-button { width: 100%; min-height: 36px; border: 1px solid #85b8ff; border-radius: 8px; padding: 8px 9px; background: #e9f2ff; color: var(--blue); font-size: 10px; font-weight: 750; line-height: 1.1; cursor: pointer; }
.send-client-button:hover { background: #dcecff; }
.send-client-menu { position: absolute; z-index: 20; right: 0; bottom: calc(100% + 8px); display: grid; min-width: 230px; max-width: min(280px, 80vw); max-height: 280px; overflow-y: auto; padding: 8px; border: 1px solid #cbd8e8; border-radius: 10px; background: #fff; box-shadow: 0 12px 30px rgba(23, 43, 77, .18); }
.send-client-menu-title { margin: 2px 5px 6px; color: var(--muted); font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: .5px; }
.send-client-muted, .send-client-error { margin: 6px; color: var(--muted); font-size: 11px; }.send-client-error { color: #ae2a19; }
.send-client-option { display: grid; gap: 2px; width: 100%; border: 0; border-radius: 7px; padding: 9px 8px; background: transparent; color: var(--ink); text-align: left; cursor: pointer; }.send-client-option:hover { background: #eef5ff; }.send-client-option small { color: var(--muted); font-size: 10px; }
.send-client-status { display: block; margin-top: 4px; color: #216e4e; font-size: 10px; text-align: center; }
</style>
