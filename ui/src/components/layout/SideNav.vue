<script setup lang="ts">
import { pages } from '@/constants';
import type { PageId } from '@/types';

defineProps<{ currentPage: PageId }>();
defineEmits<{ navigate: [page: PageId]; feedback: [] }>();
</script>

<template>
  <aside>
    <div class="brand">
      <span>✦</span>
      <div>
        Astra
        <small>Nutrition OS</small>
      </div>
    </div>

    <nav aria-label="Основная навигация">
      <button
        v-for="item in pages"
        :key="item.id"
        type="button"
        :class="{ active: item.id === currentPage }"
        @click="$emit('navigate', item.id)"
      >
        <span>{{ item.icon }}</span>
        {{ item.title }}
      </button>
    </nav>

    <button type="button" class="feedback-link" @click="$emit('feedback')">
      <span>✉</span>
      Обратная связь
    </button>

    <div class="aside-note">
      Личная база питания<br>
      <b>v7 · SQLite</b>
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
</style>
