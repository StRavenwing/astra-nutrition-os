<script setup lang="ts">
import ModalDialog from '@/components/shared/ModalDialog.vue';

defineProps<{
  open: boolean;
  title: string;
}>();

defineEmits<{ close: [] }>();
</script>

<template>
  <ModalDialog :open="open" :title="title" eyebrow="FOOD CALENDAR" wide @close="$emit('close')">
    <div class="calendar-shell">
      <slot />
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.calendar-shell {
  padding: 0;
}
</style>
