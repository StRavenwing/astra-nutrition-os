<script setup lang="ts">
import { nextTick, ref, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    open: boolean;
    title: string;
    eyebrow?: string;
    wide?: boolean;
    form?: boolean;
  }>(),
  {
    eyebrow: 'NEW RECORD',
    wide: false,
    form: false
  }
);

const emit = defineEmits<{
  close: [];
  submit: [];
}>();

const dialog = ref<HTMLDialogElement | null>(null);

watch(
  () => props.open,
  async (open) => {
    await nextTick();
    if (!dialog.value) return;
    if (open && !dialog.value.open) dialog.value.showModal();
    if (!open && dialog.value.open) dialog.value.close();
  },
  { immediate: true }
);

function onCancel(event: Event) {
  event.preventDefault();
  emit('close');
}

function closeOnBackdrop(event: MouseEvent) {
  if (event.target === dialog.value) emit('close');
}
</script>

<template>
  <dialog ref="dialog" :class="{ 'recipe-dialog': wide }" @cancel="onCancel" @click="closeOnBackdrop">
    <form v-if="form" method="dialog" @submit.prevent="$emit('submit')">
      <div class="modal-head">
        <div>
          <p class="eyebrow">{{ eyebrow }}</p>
          <h2>{{ title }}</h2>
        </div>
        <button type="button" class="icon" aria-label="Закрыть" @click="$emit('close')">×</button>
      </div>
      <slot />
    </form>
    <div v-else class="dialog-panel">
      <div class="modal-head">
        <div>
          <p class="eyebrow">{{ eyebrow }}</p>
          <h2>{{ title }}</h2>
        </div>
        <button type="button" class="icon" aria-label="Закрыть" @click="$emit('close')">×</button>
      </div>
      <slot />
    </div>
  </dialog>
</template>

<style lang="scss">
.dialog-panel {
  padding: 24px;
}
</style>
