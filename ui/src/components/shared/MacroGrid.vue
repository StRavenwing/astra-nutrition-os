<script setup lang="ts">
import { fmt } from '@/utils/format';

defineProps<{
  items: Array<{ label: string; value: unknown; unit?: string; class?: string }>;
  className?: string;
}>();
</script>

<template>
  <div :class="className || 'tile-macros'">
    <span v-for="item in items" :key="item.label" :class="item.class">
      <b>{{ fmt(item.value) }}<template v-if="item.unit"> {{ item.unit }}</template></b>
      <small>{{ item.label }}</small>
    </span>
  </div>
</template>

<style lang="scss">
.tile-macros,
.product-macros,
.progress-metrics,
.progress-primary {
  span {
    min-width: 0;
  }
}
</style>
