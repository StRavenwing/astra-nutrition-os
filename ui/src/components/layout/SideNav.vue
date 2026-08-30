<script setup lang="ts">
import { pages } from '@/constants';
import type { AuthUser, PageId } from '@/types';
import PwaInstallButton from '@/components/shared/PwaInstallButton.vue';

defineProps<{ currentPage: PageId; feedbackUnread: number; user: AuthUser; canAccessClients: boolean }>();
defineEmits<{ navigate: [page: PageId]; feedback: [] }>();
</script>

<template>
  <aside class="side-nav">
    <div class="brand">
      <img class="brand-mark" src="/assets/astra-app-icon.png" alt="Astra">
      <div>
        Astra
        <small>Nutrition OS</small>
      </div>
    </div>

    <p class="nav-caption">ОСНОВНАЯ НАВИГАЦИЯ</p>
    <nav aria-label="Основная навигация">
      <button
        v-for="item in pages"
        :key="item.id"
        type="button"
        :class="{ active: item.id === currentPage }"
        :disabled="item.id === 'clients' && !(user.is_admin || user.is_trainer)"
        :title="item.id === 'clients' && !(user.is_admin || user.is_trainer) ? 'Доступно только тренерам и администраторам' : undefined"
        @click="item.id !== 'clients' || user.is_admin || user.is_trainer ? $emit('navigate', item.id) : undefined"
      >
        <span v-if="item.id === 'clients'" class="nav-icon clients-nav-icon" aria-hidden="true">👥</span>
        <svg v-else class="nav-icon" aria-hidden="true"><use :href="`/assets/astra-menu-icons.svg#${item.id}`" /></svg>
        {{ item.title }}
      </button>
    </nav>

    <button type="button" class="feedback-link" @click="$emit('feedback')">
      <svg class="nav-icon feedback-icon" aria-hidden="true"><use href="/assets/astra-menu-icons.svg#feedback" /></svg>
      <span class="nav-icon">✉</span>
      <span class="feedback-label">Обратная связь</span>
      <strong v-if="feedbackUnread" class="feedback-count">{{ feedbackUnread > 99 ? '99+' : feedbackUnread }}</strong>
    </button>

    <div class="side-install">
      <PwaInstallButton wide />
    </div>

    <div class="aside-user">
      <span class="avatar">{{ user.email.slice(0, 1).toUpperCase() }}</span>
      <div>
        <b>{{ user.email }}</b>
        <small>{{ user.id === 0 ? 'Режим чтения' : 'Личная база питания · v7' }}</small>
      </div>
    </div>
  </aside>
</template>

<style lang="scss">
nav button {
  display: flex;
  gap: 12px;
  align-items: center;
}

nav button .nav-icon {
  display: block;
  flex: 0 0 24px;
  width: 24px;
  height: 24px;
  color: currentColor;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.feedback-icon {
  display: block;
  flex: 0 0 24px;
  width: 24px;
  height: 24px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}

.feedback-link > .nav-icon:not(.feedback-icon) { display: none; }

.feedback-link {
  display: flex;
  gap: 12px;
  align-items: center;
  width: 100%;
  margin-top: 18px;
  border: 0;
  border-top: 1px solid var(--line);
  padding: 18px 12px 11px;
  background: none;
  color: #44546f;
  text-align: left;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;

  &:hover { color: var(--blue); }
}

.feedback-label { flex: 1; }
.feedback-count {
  min-width: 22px;
  padding: 3px 6px;
  border-radius: 99px;
  background: #de350b;
  color: #fff;
  text-align: center;
  font-size: 10px;
  font-weight: 850;
}

.side-install {
  margin-top: 8px;
  padding: 0 12px;
}

.side-install .install-app {
  justify-content: flex-start;
  gap: 7px;
  box-sizing: border-box;
  min-height: 42px;
  padding: 7px 9px;
  border-color: #8de0b1;
  background: #bdf2d3;
  color: #172033;
  font-size: 11px;
  line-height: 1.15;
  box-shadow: none;
}

.side-install .install-app span {
  white-space: normal;
  overflow-wrap: anywhere;
  text-align: left;
}

.side-install .install-app:hover {
  background: #d5f8e2;
}
</style>
