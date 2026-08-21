<script setup lang="ts">
import { pages } from '@/constants';
import type { AuthUser, PageId } from '@/types';

defineProps<{ currentPage: PageId; feedbackUnread: number; user: AuthUser }>();
defineEmits<{ navigate: [page: PageId]; feedback: [] }>();
</script>

<template>
  <aside class="side-nav">
    <div class="brand">
      <span class="brand-mark">✦</span>
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
        @click="$emit('navigate', item.id)"
      >
        <svg class="nav-icon" aria-hidden="true"><use :href="`/assets/astra-menu-icons.svg#${item.id}`" /></svg>
        {{ item.title }}
      </button>
    </nav>

    <button type="button" class="feedback-link" @click="$emit('feedback')">
      <svg class="nav-icon feedback-icon" aria-hidden="true"><use href="/assets/astra-menu-icons.svg#feedback" /></svg>
      <span class="nav-icon">✉</span>
      <span class="feedback-label">Обратная связь</span>
      <strong v-if="feedbackUnread" class="feedback-count">{{ feedbackUnread > 99 ? '99+' : feedbackUnread }}</strong>
    </button>

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
</style>
