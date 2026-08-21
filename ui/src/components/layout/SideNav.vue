<script setup lang="ts">
import { pages } from '@/constants';
import type { AuthUser, PageId } from '@/types';

defineProps<{ currentPage: PageId; feedbackUnread: number; user: AuthUser }>();
defineEmits<{ navigate: [page: PageId]; feedback: [] }>();
</script>

<template>
  <aside>
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
        <span class="nav-icon">{{ item.icon }}</span>
        {{ item.title }}
      </button>
    </nav>

    <button type="button" class="feedback-link" @click="$emit('feedback')">
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
