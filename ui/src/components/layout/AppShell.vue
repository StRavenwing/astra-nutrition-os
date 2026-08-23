<script setup lang="ts">
import type { AuthUser, PageId } from '@/types';
import SideNav from './SideNav.vue';
import TopBar from './TopBar.vue';

defineProps<{
  currentPage: PageId;
  title: string;
  canAdd: boolean;
  canAddCategory?: boolean;
  addLabel?: string;
  showDiaryMenuActions?: boolean;
  user: AuthUser;
  guestMode: boolean;
  feedbackUnread: number;
}>();

defineEmits<{
  navigate: [page: PageId];
  add: [];
  collectDayMenu: [];
  collectWeekMenu: [];
  addCategory: [];
  logout: [];
  feedback: [];
  login: [];
}>();
</script>

<template>
  <div class="app-shell">
    <SideNav :current-page="currentPage" :feedback-unread="feedbackUnread" :user="user" @navigate="$emit('navigate', $event)" @feedback="$emit('feedback')" />
    <main>
    <TopBar :title="title" :can-add="canAdd" :can-add-category="canAddCategory" :add-label="addLabel" :show-diary-menu-actions="showDiaryMenuActions" :user="user" :guest="guestMode" @add="$emit('add')" @collect-day-menu="$emit('collectDayMenu')" @collect-week-menu="$emit('collectWeekMenu')" @add-category="$emit('addCategory')" @logout="$emit('logout')" @login="$emit('login')" />
      <slot />
    </main>
  </div>
</template>

<style lang="scss">
.app-shell {
  min-height: 100vh;
}
</style>
