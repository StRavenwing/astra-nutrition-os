<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { api } from '@/api/client';
import { localToday } from '@/utils/format';

const props = defineProps<{ initialDate?: string }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();

const loading = ref(false);
const saving = ref(false);
const error = ref('');
const entryDate = ref(props.initialDate || localToday());
const values = reactive({ kcal: '', protein_g: '', fat_g: '', carbs_g: '' });

onMounted(async () => {
  loading.value = true;
  try {
    const entries = await api.diaryDayNutrition();
    const entry = entries.find((item) => item.entry_date === entryDate.value);
    if (entry) {
      values.kcal = String(entry.kcal);
      values.protein_g = String(entry.protein_g);
      values.fat_g = String(entry.fat_g);
      values.carbs_g = String(entry.carbs_g);
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});

async function save() {
  error.value = '';
  const numbers = [values.kcal, values.protein_g, values.fat_g, values.carbs_g].map(Number);
  if (!entryDate.value || numbers.some((value) => !Number.isFinite(value) || value < 0)) {
    error.value = 'Укажите дату и неотрицательные значения КБЖУ.';
    return;
  }

  saving.value = true;
  try {
    await api.saveDiaryDayNutrition({
      entry_date: entryDate.value,
      kcal: numbers[0],
      protein_g: numbers[1],
      fat_g: numbers[2],
      carbs_g: numbers[3],
    });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <form class="modal-form-body diary-day-nutrition-form" @submit.prevent="save">
    <p class="diary-day-nutrition-intro">Запишите итог за день, если не хотите добавлять отдельные блюда и ингредиенты.</p>
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="field diary-date">
        <label>Дата</label>
        <input v-model="entryDate" type="date" required>
      </div>
      <div class="grid diary-day-nutrition-grid">
        <div class="field"><label>Калории, ккал</label><input v-model="values.kcal" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Белки, г</label><input v-model="values.protein_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Жиры, г</label><input v-model="values.fat_g" type="number" min="0" step="0.01" required></div>
        <div class="field"><label>Углеводы, г</label><input v-model="values.carbs_g" type="number" min="0" step="0.01" required></div>
      </div>
      <p class="form-error">{{ error }}</p>
      <div class="actions">
        <button type="button" @click="$emit('cancel')">Отмена</button>
        <button type="submit" class="primary" :disabled="saving">{{ saving ? 'Сохранение…' : 'Сохранить' }}</button>
      </div>
    </template>
  </form>
</template>

<style lang="scss">
.diary-day-nutrition-form { min-width: min(520px, 100%); }
.diary-day-nutrition-intro { margin: 0 0 16px; color: var(--muted); }
.diary-day-nutrition-grid { margin-bottom: 4px; }
</style>
