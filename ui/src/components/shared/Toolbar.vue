<script setup lang="ts">
defineProps<{
  query: string;
  placeholder?: string;
  countLabel?: string;
  resetDisabled?: boolean;
}>();

defineEmits<{
  'update:query': [value: string];
  reset: [];
}>();
</script>

<template>
  <div class="toolbar">
    <input :value="query" :placeholder="placeholder || 'Поиск…'" @input="$emit('update:query', ($event.target as HTMLInputElement).value)">
    <slot />
    <span v-if="countLabel" class="subtle">{{ countLabel }}</span>
    <button type="button" class="reset-sort" :disabled="resetDisabled" @click="$emit('reset')">Сбросить сортировку</button>
  </div>
</template>

<style lang="scss">
.toolbar {
  align-items: center;
}
</style>
