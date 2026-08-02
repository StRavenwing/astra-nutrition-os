<script setup lang="ts">
import type { PageId } from '@/types';
import SideNav from './SideNav.vue';
import TopBar from './TopBar.vue';

defineProps<{
  currentPage: PageId;
  title: string;
  canAdd: boolean;
}>();

defineEmits<{
  navigate: [page: PageId];
  add: [];
}>();
</script>

<template>
  <div class="app-shell">
    <SideNav :current-page="currentPage" @navigate="$emit('navigate', $event)" />
    <main>
      <TopBar :title="title" :can-add="canAdd" @add="$emit('add')" />
      <slot />
    </main>
  </div>
</template>

<style lang="scss">
.app-shell {
  min-height: 100vh;
}
</style>
