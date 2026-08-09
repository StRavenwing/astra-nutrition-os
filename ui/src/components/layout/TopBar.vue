<script setup lang="ts">
import type { AuthUser } from '@/types';
import PwaInstallButton from '@/components/shared/PwaInstallButton.vue';

defineProps<{
  title: string;
  canAdd: boolean;
  addLabel?: string;
  user: AuthUser;
}>();

defineEmits<{
  add: [];
  logout: [];
}>();
</script>

<template>
  <header>
    <div>
      <p class="eyebrow">PERSONAL WORKSPACE</p>
      <h1>{{ title }}</h1>
    </div>
    <div class="header-actions">
      <PwaInstallButton />
      <button v-if="canAdd" type="button" class="primary" @click="$emit('add')">＋ {{ addLabel || 'Добавить' }}</button>
      <div class="user-chip">
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
</style>
