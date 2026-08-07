<script setup lang="ts">
import { computed } from 'vue';
import { applyPwaUpdate, dismissPwaStatus, pwaOfflineReady, pwaUpdateAvailable } from '@/pwa';

const visible = computed(() => pwaUpdateAvailable.value || pwaOfflineReady.value);
const title = computed(() => (pwaUpdateAvailable.value ? 'Доступно обновление' : 'Готово к запуску'));
const message = computed(() => (
  pwaUpdateAvailable.value
    ? 'Новая версия Astra уже загружена. Обновите приложение, когда удобно.'
    : 'Интерфейс Astra сохранён браузером для быстрого запуска.'
));
</script>

<template>
  <div v-if="visible" class="pwa-toast" role="status" aria-live="polite">
    <div>
      <strong>{{ title }}</strong>
      <p>{{ message }}</p>
    </div>
    <div class="pwa-toast-actions">
      <button v-if="pwaUpdateAvailable" type="button" class="primary" @click="applyPwaUpdate">Обновить</button>
      <button type="button" @click="dismissPwaStatus">{{ pwaUpdateAvailable ? 'Позже' : 'ОК' }}</button>
    </div>
  </div>
</template>

<style scoped lang="scss">
.pwa-toast {
  position: fixed;
  right: 18px;
  bottom: 18px;
  z-index: 20;
  width: min(380px, calc(100vw - 36px));
  padding: 14px;
  border: 1px solid #b3d4ff;
  border-radius: 10px;
  background: #fff;
  box-shadow: 0 16px 42px #091e4224;

  strong,
  p {
    display: block;
    margin: 0;
  }

  p {
    margin-top: 4px;
    color: #44546f;
    font-size: 12px;
  }
}

.pwa-toast-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 12px;

  button {
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 8px 12px;
    font-weight: 700;
    cursor: pointer;
  }

  .primary {
    border: 0;
  }
}
</style>
