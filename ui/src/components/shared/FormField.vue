<script setup lang="ts">
withDefaults(
  defineProps<{
    label: string;
    name?: string;
    modelValue?: string | number | null;
    type?: string;
    required?: boolean;
    readonly?: boolean;
    min?: string | number;
    max?: string | number;
    step?: string | number;
    placeholder?: string;
    options?: Array<{ value: string | number; label: string }>;
    full?: boolean;
  }>(),
  {
    type: 'text',
    required: false,
    readonly: false,
    full: false
  }
);

defineEmits<{ 'update:modelValue': [value: string] }>();
</script>

<template>
  <div class="field" :class="{ full }">
    <label>{{ label }}</label>
    <select v-if="options" :name="name" :value="modelValue ?? ''" :required="required" @change="$emit('update:modelValue', ($event.target as HTMLSelectElement).value)">
      <option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option>
    </select>
    <input
      v-else
      :name="name"
      :type="type"
      :value="modelValue ?? ''"
      :required="required"
      :readonly="readonly"
      :min="min"
      :max="max"
      :step="step"
      :placeholder="placeholder"
      @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
    >
  </div>
</template>

<style lang="scss">
.field {
  min-width: 0;
}
</style>
