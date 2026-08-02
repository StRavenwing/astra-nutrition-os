<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';

const props = defineProps<{ progressId?: number }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();

const error = ref('');
const loading = ref(false);
const form = reactive<Record<string, string>>({
  measured_at: '',
  weight_kg: '',
  height_cm: '169',
  bmi: '',
  body_fat_pct: '',
  fat_mass_kg: '',
  muscle_pct: '',
  muscle_mass_kg: '',
  protein_target_g: '',
  fat_target_g: '',
  waist_cm: '',
  chest_cm: '',
  hips_cm: '',
  sleep_score: '',
  wellbeing_score: '',
  comment: ''
});

function calculate() {
  const weight = Number(form.weight_kg);
  const height = Number(form.height_cm);
  const fat = Number(form.body_fat_pct);
  const muscle = Number(form.muscle_pct);
  form.bmi = form.weight_kg !== '' && form.height_cm !== '' && height > 0 ? (weight / ((height / 100) ** 2)).toFixed(2) : '';
  form.fat_mass_kg = form.weight_kg !== '' && form.body_fat_pct !== '' ? (weight * fat / 100).toFixed(2) : '';
  form.muscle_mass_kg = form.weight_kg !== '' && form.muscle_pct !== '' ? (weight * muscle / 100).toFixed(2) : '';
}

watch(() => [form.weight_kg, form.height_cm, form.body_fat_pct, form.muscle_pct], calculate);

onMounted(async () => {
  if (!props.progressId) return;
  loading.value = true;
  try {
    const data = await api.progress();
    const item = data.find((progress) => progress.progress_id === props.progressId);
    if (item) {
      for (const [key, value] of Object.entries(item)) {
        if (key in form) form[key] = value == null ? '' : String(value);
      }
    }
    calculate();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

async function save() {
  error.value = '';
  try {
    if (props.progressId) await api.put(`progress/${props.progressId}`, { ...form });
    else await api.post('progress', { ...form });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="grid">
        <div class="field"><label>Дата</label><input v-model="form.measured_at" type="date" required></div>
        <div class="field"><label>Вес, кг</label><input v-model="form.weight_kg" type="number" min="0" step="0.1"></div>
        <div class="field"><label>Рост, см</label><input v-model="form.height_cm" type="number" min="50" max="250" step="0.1"></div>
        <div class="field"><label>ИМТ</label><input v-model="form.bmi" type="number" step="0.01" readonly tabindex="-1"></div>
        <div class="field"><label>Процент жира</label><input v-model="form.body_fat_pct" type="number" min="0" max="100" step="0.1"></div>
        <div class="field"><label>Масса жира, кг</label><input v-model="form.fat_mass_kg" type="number" step="0.01" readonly tabindex="-1"></div>
        <div class="field"><label>Процент мышечной массы</label><input v-model="form.muscle_pct" type="number" min="0" max="100" step="0.1"></div>
        <div class="field"><label>Мышечная масса, кг</label><input v-model="form.muscle_mass_kg" type="number" step="0.01" readonly tabindex="-1"></div>
        <div class="field"><label>Норма белка, г</label><input v-model="form.protein_target_g" type="number" min="0" step="1"></div>
        <div class="field"><label>Норма жиров, г</label><input v-model="form.fat_target_g" type="number" min="0" step="1"></div>
        <div class="field"><label>Талия, см</label><input v-model="form.waist_cm" type="number" step="0.1"></div>
        <div class="field"><label>Грудь, см</label><input v-model="form.chest_cm" type="number" step="0.1"></div>
        <div class="field"><label>Бёдра, см</label><input v-model="form.hips_cm" type="number" step="0.1"></div>
        <div class="field"><label>Сон (1–5)</label><input v-model="form.sleep_score" type="number" min="1" max="5"></div>
        <div class="field"><label>Самочувствие (1–5)</label><input v-model="form.wellbeing_score" type="number" min="1" max="5"></div>
        <div class="field full"><label>Комментарий</label><input v-model="form.comment"></div>
      </div>
      <p id="form-error">{{ error }}</p>
      <div class="actions">
        <button type="button" @click="$emit('cancel')">Отмена</button>
        <button type="submit" class="primary">Сохранить</button>
      </div>
    </template>
  </form>
</template>

<style lang="scss">
.modal-form-body input[readonly] {
  background: #f1f2f4;
}
</style>
