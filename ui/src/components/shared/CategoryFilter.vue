<script setup lang="ts">
defineProps<{
  items: Array<{ key: string; label: string; count: number; icon?: string; className?: string; style?: Record<string, string> }>;
  active: string;
  allLabel: string;
  allCount: number;
  className: string;
  allClass?: string;
}>();

defineEmits<{ select: [key: string] }>();
</script>

<template>
  <section :class="className" aria-label="Фильтр категорий">
    <button type="button" :class="[allClass || 'all', { active: active === 'all' }]" data-category="all" @click="$emit('select', 'all')">
      <slot name="all-icon">
        <span class="category-icon">▦</span>
      </slot>
      <span>
        <b>{{ allLabel }}</b>
        <small>Полный каталог</small>
      </span>
      <strong>{{ allCount }}</strong>
    </button>
    <button
      v-for="item in items"
      :key="item.key"
      type="button"
      :class="[item.className, { active: active === item.key }]"
      :style="item.style"
      @click="$emit('select', item.key)"
    >
      <slot name="item-icon" :item="item">
        <span class="category-icon">{{ item.icon || '○' }}</span>
      </slot>
      <span>
        <b>{{ item.label }}</b>
        <small>{{ item.key }}</small>
      </span>
      <strong>{{ item.count }}</strong>
    </button>
  </section>
</template>

<style lang="scss">
.category-filter-placeholder {
  display: contents;
}
</style>
