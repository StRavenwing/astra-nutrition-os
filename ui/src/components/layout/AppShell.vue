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
  guestMode: boolean;
  feedbackUnread: number;
}>();

defineEmits<{
  navigate: [page: PageId];
  add: [];
  logout: [];
  feedback: [];
  login: [];
}>();
</script>

<template>
  <div class="app-shell">
    <SideNav :current-page="currentPage" :feedback-unread="feedbackUnread" :user="user" @navigate="$emit('navigate', $event)" @feedback="$emit('feedback')" />
    <main>
    <TopBar :title="title" :can-add="canAdd" :add-label="addLabel" :user="user" :guest="guestMode" @add="$emit('add')" @logout="$emit('logout')" @login="$emit('login')" />
      <slot />
    </main>
  </div>
</template>

<style lang="scss">
.app-shell {
  min-height: 100vh;
}
</style>
