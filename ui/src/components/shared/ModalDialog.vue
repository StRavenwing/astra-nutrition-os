<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue';

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

const popupVariant = computed(() => {
  const value = `${props.eyebrow} ${props.title}`.toLowerCase();
  if (value.includes('стать')) return 'article';
  if (value.includes('рецепт') || value.includes('recipe')) return 'recipe';
  if (value.includes('продукт')) return 'product';
  if (value.includes('инвентар') || value.includes('тренаж')) return 'equipment';
  if (value.includes('упражнен') || value.includes('exercise')) return 'exercise';
  if (value.includes('дневник') || value.includes('запис')) return 'diary';
  if (value.includes('food calendar') || value.includes('день')) return 'food-day';
  if (value.includes('прогресс') || value.includes('замер')) return 'progress';
  if (value.includes('комплекс')) return 'complex';
  if (value.includes('трениров') || value.includes('workout')) return 'workout';
  return 'default';
});

const popupMode = computed(() => {
  const value = `${props.eyebrow} ${props.title}`.toLowerCase();
  if (value.includes('удал')) return 'delete';
  if (value.includes('действ')) return 'actions';
  if (value.includes('подтверж') || value.includes('confirm')) return 'confirm';
  if (props.form || value.includes('добав') || value.includes('редакт') || value.includes('созда') || value.includes('собрать')) return 'form';
  return 'view';
});

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
  <dialog ref="dialog" :class="[`popup-${popupVariant}`, `popup-${popupMode}`, { 'recipe-dialog': wide, 'popup-form': form }]" @cancel="onCancel" @click="closeOnBackdrop">
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
