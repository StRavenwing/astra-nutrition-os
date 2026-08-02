<script setup lang="ts">
import ModalDialog from './ModalDialog.vue';

defineProps<{
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
}>();

defineEmits<{
  close: [];
  confirm: [];
}>();
</script>

<template>
  <ModalDialog :open="open" :title="title" eyebrow="CONFIRM" @close="$emit('close')">
    <p class="confirm-message">{{ message }}</p>
    <div class="actions">
      <button type="button" @click="$emit('close')">Отмена</button>
      <button type="button" class="danger-button" @click="$emit('confirm')">{{ confirmLabel || 'Удалить' }}</button>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.confirm-message {
  margin: 0;
  color: var(--ink);
}
</style>
