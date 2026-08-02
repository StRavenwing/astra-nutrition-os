<script setup lang="ts">
defineProps<{
  label: string;
  value: string | number;
  icon?: string;
  note?: string;
  button?: boolean;
}>();

defineEmits<{ click: [] }>();
</script>

<template>
  <component :is="button ? 'button' : 'div'" type="button" class="card dashboard-link" @click="$emit('click')">
    <span v-if="icon" class="dashboard-card-icon">{{ icon }}</span>
    <span class="label">{{ label }}</span>
    <strong>{{ value }}</strong>
    <small v-if="note">{{ note }}</small>
  </component>
</template>

<style lang="scss">
.dashboard-link {
  width: 100%;
  color: inherit;
  font: inherit;
  text-align: left;
}
</style>
