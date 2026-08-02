<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';

defineProps<{
  title: string;
  canAdd: boolean;
}>();

defineEmits<{ add: [] }>();

const installVisible = ref(false);
let deferredPrompt: any = null;
const isStandalone = window.matchMedia('(display-mode: standalone)').matches || (window.navigator as any).standalone === true;
const isAppleMobile = /iphone|ipad|ipod/i.test(navigator.userAgent);

function beforeInstallPrompt(event: Event) {
  event.preventDefault();
  deferredPrompt = event;
  installVisible.value = true;
}

function appInstalled() {
  deferredPrompt = null;
  installVisible.value = false;
}

async function installApp() {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
    installVisible.value = false;
    return;
  }
  if (isAppleMobile) {
    alert('Чтобы установить Astra: нажмите «Поделиться» в Safari, затем «На экран Домой».');
    return;
  }
  alert('Откройте меню браузера и выберите «Установить Astra Nutrition OS» или «Установить приложение».');
}

function registerServiceWorker() {
  navigator.serviceWorker.register('/service-worker.js').catch((error) => console.warn('Service worker:', error));
}

onMounted(() => {
  if ('serviceWorker' in navigator) {
    if (document.readyState === 'complete') registerServiceWorker();
    else window.addEventListener('load', registerServiceWorker, { once: true });
  }
  if (isAppleMobile && !isStandalone) installVisible.value = true;
  window.addEventListener('beforeinstallprompt', beforeInstallPrompt);
  window.addEventListener('appinstalled', appInstalled);
});

onBeforeUnmount(() => {
  window.removeEventListener('load', registerServiceWorker);
  window.removeEventListener('beforeinstallprompt', beforeInstallPrompt);
  window.removeEventListener('appinstalled', appInstalled);
});
</script>

<template>
  <header>
    <div>
      <p class="eyebrow">PERSONAL WORKSPACE</p>
      <h1>{{ title }}</h1>
    </div>
    <div class="header-actions">
      <button v-if="installVisible" type="button" class="install-app" @click="installApp">
        <img src="/assets/app-icon-192.png" alt="">
        Установить приложение
      </button>
      <button v-if="canAdd" type="button" class="primary" @click="$emit('add')">＋ Добавить</button>
    </div>
  </header>
</template>

<style lang="scss">
.header-actions {
  display: flex;
  align-items: center;
  gap: 9px;
}
</style>
