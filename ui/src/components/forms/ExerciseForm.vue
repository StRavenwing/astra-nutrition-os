<script setup lang="ts">
import { reactive, ref } from 'vue';
import { api } from '@/api/client';

const emit = defineEmits<{ saved: []; cancel: [] }>();

const error = ref('');
const form = reactive({
  name: '',
  muscle_group: '',
  default_unit: 'кг',
  default_sets: '3',
  default_reps: '12',
  target_rir: '0–2',
  note: ''
});

async function save() {
  error.value = '';
  try {
    await api.post('exercises', { ...form });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div class="grid">
      <div class="field"><label>Название</label><input v-model="form.name" required></div>
      <div class="field"><label>Мышечная группа</label><input v-model="form.muscle_group" required></div>
      <div class="field"><label>Единица</label><select v-model="form.default_unit"><option>кг</option><option>уровень</option><option>без веса</option></select></div>
      <div class="field"><label>Подходов</label><input v-model="form.default_sets" type="number" min="1" required></div>
      <div class="field"><label>Повторов</label><input v-model="form.default_reps" type="number" min="1" required></div>
      <div class="field"><label>Целевой RIR</label><input v-model="form.target_rir"></div>
      <div class="field full"><label>Примечание</label><input v-model="form.note"></div>
    </div>
    <p id="form-error">{{ error }}</p>
    <div class="actions">
      <button type="button" @click="$emit('cancel')">Отмена</button>
      <button type="submit" class="primary">Сохранить</button>
    </div>
  </form>
</template>

<style lang="scss">
.modal-form-body {
  width: 100%;
}
</style>
