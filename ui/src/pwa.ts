import { ref } from 'vue';
import { registerSW } from 'virtual:pwa-register';

type UpdateServiceWorker = (reloadPage?: boolean) => Promise<void>;

export const pwaUpdateAvailable = ref(false);
export const pwaOfflineReady = ref(false);

let updateServiceWorker: UpdateServiceWorker | null = null;

if ('serviceWorker' in navigator) {
  updateServiceWorker = registerSW({
    immediate: true,
    onNeedRefresh() {
      pwaUpdateAvailable.value = true;
      pwaOfflineReady.value = false;
    },
    onOfflineReady() {
      if (!pwaUpdateAvailable.value) pwaOfflineReady.value = true;
    },
    onRegisterError(error) {
      console.warn('Service worker:', error);
    }
  });
}

export async function applyPwaUpdate() {
  if (updateServiceWorker) await updateServiceWorker(true);
}

export function dismissPwaStatus() {
  pwaUpdateAvailable.value = false;
  pwaOfflineReady.value = false;
}
