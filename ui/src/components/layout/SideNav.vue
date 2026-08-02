<script setup lang="ts">
import { pages } from '@/constants';
import type { PageId } from '@/types';

defineProps<{ currentPage: PageId }>();
defineEmits<{ navigate: [page: PageId] }>();
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
</style>
