<script setup lang="ts">
import ModalDialog from './ModalDialog.vue';
import { usePwaInstall } from '@/composables/usePwaInstall';

withDefaults(
  defineProps<{
    wide?: boolean;
  }>(),
  {
    wide: false
  }
);

const {
  canInstall,
  nativePromptReady,
  instructionsOpen,
  installInstructions,
  install,
  closeInstructions
} = usePwaInstall();
</script>

<template>
  <button
    v-if="canInstall"
    type="button"
    class="install-app"
    :class="{ wide }"
    :title="nativePromptReady ? 'Установить Astra' : 'Показать инструкцию установки'"
    @click="install"
  >
    <img src="/assets/app-icon-192.png" alt="">
    <span>Установить приложение</span>
  </button>

  <ModalDialog
    :open="instructionsOpen"
    :title="installInstructions.title"
    eyebrow="PWA"
    @close="closeInstructions"
  >
    <div class="pwa-install-body">
      <p>{{ installInstructions.lead }}</p>
      <ol>
        <li v-for="step in installInstructions.steps" :key="step">{{ step }}</li>
      </ol>
      <div class="actions">
        <button type="button" class="primary" @click="closeInstructions">Готово</button>
      </div>
    </div>
  </ModalDialog>
</template>

<style scoped lang="scss">
.install-app {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 42px;
  border: 1px solid #9f8fef;
  border-radius: 9px;
  background: linear-gradient(135deg, #fff, #f3f0ff);
  color: #5e4db2;
  padding: 7px 12px;
  font-weight: 800;
  cursor: pointer;
  box-shadow: 0 2px 7px #091e4212;

  &.wide {
    width: 100%;
  }

  img {
    flex: 0 0 auto;
    width: 27px;
    height: 27px;
    border-radius: 7px;
  }

  span {
    min-width: 0;
    white-space: nowrap;
  }
}

.pwa-install-body {
  color: #172b4d;

  p {
    margin: 0 0 14px;
    color: #44546f;
  }

  ol {
    display: grid;
    gap: 10px;
    margin: 0;
    padding-left: 22px;
  }

  li {
    padding-left: 4px;
  }
}

@media (max-width: 560px) {
  .install-app {
    width: 100%;
  }
}
</style>
