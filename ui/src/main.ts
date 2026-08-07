import { createApp } from 'vue';
import App from './App.vue';
import './pwa';
import { initializePwaInstall } from '@/composables/usePwaInstall';

initializePwaInstall();
createApp(App).mount('#app');
