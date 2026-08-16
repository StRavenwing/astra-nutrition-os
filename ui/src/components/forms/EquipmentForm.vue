<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { api } from '@/api/client';
import type { WorkoutEquipment } from '@/types';

const props = defineProps<{ equipmentId?: number; kind: 'machine' | 'equipment' }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();

const error = ref('');
const loading = ref(false);
const photoInput = ref<HTMLInputElement | null>(null);
const form = reactive({
  kind: props.kind as 'machine' | 'equipment',
  name: '',
  description: '',
  photo: ''
});

function readFile(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('Не удалось прочитать фото'));
    reader.readAsDataURL(file);
  });
}

async function choosePhoto(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  try {
    form.photo = await readFile(file);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    input.value = '';
  }
}

async function save() {
  error.value = '';
  try {
    const payload = {
      kind: form.kind,
      name: form.name,
      description: form.description || null,
      photo: form.photo || null
    };
    if (props.equipmentId) await api.updateWorkoutEquipment(props.equipmentId, payload);
    else await api.createWorkoutEquipment(payload);
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

onMounted(async () => {
  if (!props.equipmentId) return;
  loading.value = true;
  try {
    const item = (await api.workoutEquipment()).find((candidate) => candidate.id === props.equipmentId) as WorkoutEquipment | undefined;
    if (item) {
      form.kind = item.kind;
      form.name = item.name;
      form.description = item.description || '';
      form.photo = item.photo || '';
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <form class="modal-form-body equipment-form" @submit.prevent="save">
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="grid">
        <div class="field full"><label>Тип</label><select v-model="form.kind"><option value="machine">Тренажёр</option><option value="equipment">Инвентарь</option></select></div>
        <div class="field full"><label>Название</label><input v-model="form.name" required maxlength="160" placeholder="Например, кроссовер"></div>
        <div class="field full"><label>Описание</label><textarea v-model="form.description" rows="5" maxlength="2000" placeholder="Кратко опишите назначение и особенности"></textarea></div>
      </div>

      <section class="equipment-form-media">
        <div class="equipment-form-media-head"><div><p class="eyebrow">МЕДИА</p><h3>Фото</h3></div><button type="button" class="secondary-button" @click="photoInput?.click()">{{ form.photo ? 'Заменить фото' : 'Добавить фото' }}</button></div>
        <input ref="photoInput" class="equipment-file-input" type="file" accept="image/*" @change="choosePhoto">
        <div v-if="form.photo" class="equipment-form-photo"><img :src="form.photo" alt="Фото оборудования"><button type="button" @click="form.photo = ''">Удалить фото</button></div>
      </section>
    </template>
    <p id="form-error">{{ error }}</p>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button type="submit" class="primary" :disabled="loading">Сохранить</button></div>
  </form>
</template>

<style lang="scss">
.equipment-form { width: 100%; }
.equipment-form-media { margin-top: 18px; padding: 16px; border: 1px solid var(--line); border-radius: 13px; background: #fafbfc; }
.equipment-form-media-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.equipment-form-media-head h3 { margin: 0; font-size: 15px; }
.equipment-file-input { display: none; }
.equipment-form-photo { position: relative; width: 180px; margin-top: 14px; }
.equipment-form-photo img { display: block; width: 180px; height: 135px; border-radius: 9px; object-fit: cover; background: #eef1f5; }
.equipment-form-photo button { margin-top: 7px; border: 1px solid #f5a79b; border-radius: 7px; padding: 7px 10px; background: #ffebe6; color: #ae2a19; font-size: 10px; font-weight: 800; cursor: pointer; }
@media (max-width: 600px) { .equipment-form-media-head { align-items: flex-start; flex-direction: column; } }
</style>
