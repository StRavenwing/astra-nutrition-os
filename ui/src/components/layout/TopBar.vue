<script setup lang="ts">
import type { AuthUser } from '@/types';

defineProps<{
  title: string;
  canAdd: boolean;
  canAddCategory?: boolean;
  addLabel?: string;
  showDiaryMenuActions?: boolean;
  user: AuthUser;
  guest?: boolean;
}>();

defineEmits<{
  add: [];
  collectDayMenu: [];
  collectWeekMenu: [];
  addCategory: [];
  logout: [];
  login: [];
}>();
</script>

<template>
  <header>
    <div>
      <p class="eyebrow">PERSONAL WORKSPACE</p>
      <h1>{{ title }}</h1>
    </div>
    <div class="header-actions">
      <span v-if="guest" class="guest-badge">Режим чтения</span>
      <button v-if="guest" type="button" class="login-button" @click="$emit('login')">Войти</button>
      <button v-if="canAddCategory" type="button" class="secondary-header-action" @click="$emit('addCategory')">＋ Категория</button>
      <button v-if="canAdd" type="button" class="primary" @click="$emit('add')">＋ {{ addLabel || 'Добавить' }}</button>
      <template v-if="showDiaryMenuActions">
        <button type="button" class="secondary-header-action" @click="$emit('collectDayMenu')">Собрать дневное меню</button>
        <button type="button" class="secondary-header-action" @click="$emit('collectWeekMenu')">Собрать недельное меню</button>
      </template>
      <div v-if="!guest" class="user-chip">
        <span>{{ user.email }}</span>
        <button type="button" title="Выйти" @click="$emit('logout')">Выйти</button>
      </div>
    </div>
  </header>
</template>

<style lang="scss">
.header-actions {
  display: flex;
  align-items: center;
  gap: 9px;
}

.user-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 38px;
  padding: 4px 5px 4px 12px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fff;
  color: #44546f;
  font-size: 12px;
  font-weight: 700;

  button {
    border: 0;
    border-radius: 6px;
    padding: 7px 9px;
    background: #f1f2f4;
    color: #44546f;
    cursor: pointer;
  }
}

.secondary-header-action {
  min-height: 44px;
  padding: 0 14px;
  border: 0;
  border-radius: 12px;
  background: #e2f7eb;
  color: #329a63;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}

.secondary-header-action:hover {
  background: #d1f8df;
}
</style>
