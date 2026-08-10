<script setup lang="ts">
import type { AuthUser, PageId } from '@/types';
import SideNav from './SideNav.vue';
import TopBar from './TopBar.vue';

defineProps<{
  currentPage: PageId;
  title: string;
  canAdd: boolean;
  addLabel?: string;
  user: AuthUser;
}>();

defineEmits<{
  navigate: [page: PageId];
  add: [];
  logout: [];
  feedback: [];
}>();
</script>

<template>
  <div class="app-shell">
    <SideNav :current-page="currentPage" @navigate="$emit('navigate', $event)" @feedback="$emit('feedback')" />
    <main>
      <TopBar :title="title" :can-add="canAdd" :add-label="addLabel" :user="user" @add="$emit('add')" @logout="$emit('logout')" />
      <slot />
    </main>
  </div>
</template>

<style lang="scss">
.app-shell {
  min-height: 100vh;
}
</style>
