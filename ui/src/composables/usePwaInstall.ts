import { computed, ref, shallowRef } from 'vue';

type BeforeInstallPromptOutcome = 'accepted' | 'dismissed';

interface BeforeInstallPromptChoice {
  outcome: BeforeInstallPromptOutcome;
  platform: string;
}

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[];
  readonly userChoice: Promise<BeforeInstallPromptChoice>;
  prompt(): Promise<void>;
}

interface NavigatorWithStandalone extends Navigator {
  standalone?: boolean;
}

interface InstallInstructions {
  title: string;
  lead: string;
  steps: string[];
}

const installPrompt = shallowRef<BeforeInstallPromptEvent | null>(null);
const installed = ref(false);
const standalone = ref(false);
const instructionsOpen = ref(false);
let initialized = false;

function isIosDevice() {
  const userAgent = navigator.userAgent.toLowerCase();
  const touchMac = navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
  return /iphone|ipad|ipod/.test(userAgent) || touchMac;
}

function getPlatform() {
  const userAgent = navigator.userAgent.toLowerCase();
  const isIos = isIosDevice();
  const isAndroid = /android/.test(userAgent);
  const isMac = !isIos && /macintosh|mac os x/.test(userAgent);
  const isWindows = /windows/.test(userAgent);
  const isSafari = /^((?!chrome|chromium|crios|fxios|edg|opr|opera|android).)*safari/.test(userAgent);

  return { isIos, isAndroid, isMac, isWindows, isSafari };
}

function detectStandalone() {
  const navigatorWithStandalone = window.navigator as NavigatorWithStandalone;
  return window.matchMedia('(display-mode: standalone)').matches
    || window.matchMedia('(display-mode: fullscreen)').matches
    || navigatorWithStandalone.standalone === true;
}

function refreshStandalone() {
  standalone.value = detectStandalone();
}

function onBeforeInstallPrompt(event: Event) {
  event.preventDefault();
  installPrompt.value = event as BeforeInstallPromptEvent;
}

function onAppInstalled() {
  installPrompt.value = null;
  installed.value = true;
  instructionsOpen.value = false;
}

export function initializePwaInstall() {
  if (initialized) return;
  initialized = true;
  refreshStandalone();

  window.addEventListener('beforeinstallprompt', onBeforeInstallPrompt);
  window.addEventListener('appinstalled', onAppInstalled);

  const displayMode = window.matchMedia('(display-mode: standalone)');
  if (typeof displayMode.addEventListener === 'function') {
    displayMode.addEventListener('change', refreshStandalone);
  } else {
    displayMode.addListener(refreshStandalone);
  }
}

export function usePwaInstall() {
  initializePwaInstall();

  const canInstall = computed(() => !standalone.value && !installed.value);
  const nativePromptReady = computed(() => Boolean(installPrompt.value));
  const installInstructions = computed<InstallInstructions>(() => {
    const platform = getPlatform();

    if (platform.isIos) {
      return {
        title: 'Установка на iPhone или iPad',
        lead: 'iOS устанавливает web app через системное меню браузера.',
        steps: [
          'Откройте сайт в Safari или другом браузере на iOS/iPadOS.',
          'Нажмите Share или «Поделиться».',
          'Выберите «На экран Домой» или Add to Home Screen.',
          'Оставьте включённым Open as Web App и нажмите Add.'
        ]
      };
    }

    if (platform.isMac && platform.isSafari) {
      return {
        title: 'Установка в Safari на macOS',
        lead: 'Safari добавляет сайт как отдельное приложение через Dock.',
        steps: [
          'Откройте сайт в Safari.',
          'В меню выберите File -> Add to Dock или Share -> Add to Dock.',
          'Проверьте название Astra и нажмите Add.'
        ]
      };
    }

    if (platform.isAndroid) {
      return {
        title: 'Установка на Android',
        lead: 'Если системное окно установки не открылось, используйте меню браузера.',
        steps: [
          'Откройте меню Chrome, Edge или Samsung Internet.',
          'Выберите «Установить приложение» или «Добавить на главный экран».',
          'Подтвердите установку Astra.'
        ]
      };
    }

    if (platform.isWindows) {
      return {
        title: 'Установка на Windows',
        lead: 'Chrome и Edge устанавливают PWA через адресную строку или меню браузера.',
        steps: [
          'Нажмите значок установки в адресной строке, если он появился.',
          'Или откройте меню браузера и выберите «Установить Astra Nutrition OS».',
          'Подтвердите установку.'
        ]
      };
    }

    if (platform.isMac) {
      return {
        title: 'Установка на macOS',
        lead: 'Chrome и Edge устанавливают PWA через адресную строку или меню браузера.',
        steps: [
          'Нажмите значок установки в адресной строке, если он появился.',
          'Или откройте меню браузера и выберите «Установить Astra Nutrition OS».',
          'Подтвердите установку.'
        ]
      };
    }

    return {
      title: 'Установка приложения',
      lead: 'Если браузер не открыл системную установку, используйте его меню установки.',
      steps: [
        'Откройте меню браузера.',
        'Выберите «Установить приложение», Add to Dock или Add to Home Screen.',
        'Подтвердите установку Astra.'
      ]
    };
  });

  async function install() {
    if (!canInstall.value) return;

    if (!installPrompt.value) {
      instructionsOpen.value = true;
      return;
    }

    const prompt = installPrompt.value;
    await prompt.prompt();
    const choice = await prompt.userChoice;
    installPrompt.value = null;
    if (choice.outcome === 'accepted') installed.value = true;
    else instructionsOpen.value = true;
  }

  function closeInstructions() {
    instructionsOpen.value = false;
  }

  return {
    canInstall,
    nativePromptReady,
    instructionsOpen,
    installInstructions,
    install,
    closeInstructions
  };
}
