<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { api } from '@/api/client';
import type { Exercise } from '@/types';

const props = defineProps<{ exerciseId?: number }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();

const error = ref('');
const loading = ref(false);
const photos = ref<string[]>([]);
const video = ref<string | null>(null);
const photoInput = ref<HTMLInputElement | null>(null);
const videoInput = ref<HTMLInputElement | null>(null);
const form = reactive({
  name: '',
  muscle_group: '',
  default_unit: 'кг',
  default_sets: '3',
  default_reps: '12',
  target_rir: '0–2',
  description: ''
});

function readFile(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('Не удалось прочитать файл'));
    reader.readAsDataURL(file);
  });
}

async function addPhotos(event: Event) {
  const input = event.target as HTMLInputElement;
  const files = Array.from(input.files || []).slice(0, 6 - photos.value.length);
  try {
    photos.value.push(...await Promise.all(files.map(readFile)));
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    input.value = '';
  }
}

async function addVideo(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  try {
    video.value = await readFile(file);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    (event.target as HTMLInputElement).value = '';
  }
}

function removePhoto(index: number) {
  photos.value.splice(index, 1);
}

async function save() {
  error.value = '';
  try {
    const payload = { ...form, photos: photos.value, video: video.value };
    if (props.exerciseId) await api.put(`exercises/${props.exerciseId}`, payload);
    else await api.post('exercises', payload);
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  }
}

onMounted(async () => {
  if (!props.exerciseId) return;
  loading.value = true;
  try {
    const exercise = (await api.exercises()).find((item) => item.id === props.exerciseId) as Exercise | undefined;
    if (exercise) {
      form.name = exercise.name;
      form.muscle_group = exercise.muscle_group || '';
      form.default_unit = exercise.default_unit || 'кг';
      form.default_sets = exercise.default_sets == null ? '' : String(exercise.default_sets);
      form.default_reps = exercise.default_reps == null ? '' : String(exercise.default_reps);
      form.target_rir = exercise.target_rir || '';
      form.description = exercise.description || exercise.note || '';
      photos.value = [...(exercise.photos || [])];
      video.value = exercise.video || null;
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div v-if="loading" class="panel">Загрузка…</div>
    <template v-else>
      <div class="grid">
        <div class="field"><label>Название</label><input v-model="form.name" required></div>
        <div class="field"><label>Группа мышц</label><input v-model="form.muscle_group" required></div>
        <div class="field full"><label>Описание</label><textarea v-model="form.description" rows="4" placeholder="Техника, важные подсказки и ограничения"></textarea></div>
        <div class="field"><label>Единица по умолчанию</label><select v-model="form.default_unit"><option>кг</option><option>уровень</option><option>без веса</option></select></div>
        <div class="field"><label>Целевой RIR</label><input v-model="form.target_rir"></div>
      </div>

      <section class="exercise-media-fields">
        <div class="exercise-media-head">
          <div><p class="eyebrow">МЕДИА</p><h3>Фото и видео упражнения</h3></div>
          <div class="exercise-media-buttons">
            <button type="button" class="secondary-button" :disabled="photos.length >= 6" @click="photoInput?.click()">Добавить фото ({{ photos.length }}/6)</button>
            <button type="button" class="secondary-button" :disabled="Boolean(video)" @click="videoInput?.click()">Добавить видео ({{ video ? 1 : 0 }}/1)</button>
          </div>
        </div>
        <input ref="photoInput" class="exercise-file-input" type="file" accept="image/*" multiple @change="addPhotos">
        <input ref="videoInput" class="exercise-file-input" type="file" accept="video/*" @change="addVideo">
        <div v-if="photos.length" class="exercise-photo-preview">
          <div v-for="(photo, index) in photos" :key="photo" class="exercise-photo-item">
            <img :src="photo" alt="Фото упражнения">
            <button type="button" aria-label="Удалить фото" @click="removePhoto(index)">×</button>
          </div>
        </div>
        <div v-if="video" class="exercise-video-preview">
          <video :src="video" controls></video>
          <button type="button" class="delete-exercise-media" @click="video = null">Удалить видео</button>
        </div>
      </section>
    </template>
    <p id="form-error">{{ error }}</p>
    <div class="actions">
      <button type="button" @click="$emit('cancel')">Отмена</button>
      <button type="submit" class="primary" :disabled="loading">Сохранить</button>
    </div>
  </form>
</template>

<style lang="scss">
.modal-form-body { width: 100%; }
.exercise-file-input { display: none; }
.exercise-media-fields { margin-top: 18px; padding: 16px; border: 1px solid var(--line); border-radius: 13px; background: #fafbfc; }
.exercise-media-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.exercise-media-head h3 { margin: 0; font-size: 15px; }
.exercise-media-buttons { display: flex; flex-wrap: wrap; gap: 7px; }
.exercise-photo-preview { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 8px; margin-top: 14px; }
.exercise-photo-item { position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 9px; background: #eef1f5; }
.exercise-photo-item img { width: 100%; height: 100%; object-fit: cover; }
.exercise-photo-item button { position: absolute; top: 4px; right: 4px; width: 24px; height: 24px; border: 0; border-radius: 50%; background: #fff; color: #ae2a19; cursor: pointer; }
.exercise-video-preview { display: flex; align-items: center; gap: 10px; margin-top: 14px; }
.exercise-video-preview video { width: 150px; max-height: 100px; border-radius: 8px; background: #172b4d; }
.delete-exercise-media { border: 1px solid #f5a79b; border-radius: 7px; padding: 7px 10px; background: #ffebe6; color: #ae2a19; font-size: 10px; font-weight: 800; cursor: pointer; }
@media (max-width: 600px) {
  .exercise-media-head { align-items: flex-start; flex-direction: column; }
  .exercise-photo-preview { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
</style>
