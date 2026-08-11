<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Exercise, WorkoutComplex } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

type ComplexItem = {
  exercise_id: number;
  working_weight: number | '';
  sets: number | '';
  duration_minutes: number | '';
  speed_kmh: number | '';
};

const props = defineProps<{
  open: boolean;
  complex: WorkoutComplex | null;
  mode: 'create' | 'edit';
}>();

const emit = defineEmits<{
  close: [];
  saved: [];
  openExercise: [exercise: Exercise];
}>();

const exercises = ref<Exercise[]>([]);
const photos = ref<string[]>([]);
const video = ref<string | null>(null);
const photoInput = ref<HTMLInputElement | null>(null);
const videoInput = ref<HTMLInputElement | null>(null);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const form = reactive({ name: '', comment: '' });
const items = ref<ComplexItem[]>([]);

function readFile(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('Не удалось прочитать файл'));
    reader.readAsDataURL(file);
  });
}

function resetForm() {
  const source = props.mode === 'edit' ? props.complex : null;
  form.name = source?.name || '';
  form.comment = source?.comment || '';
  photos.value = [...(source?.photos || [])];
  video.value = source?.video || null;
  items.value = (source?.items || []).map((item) => ({
    exercise_id: item.exercise_id,
    working_weight: item.working_weight ?? '',
    sets: item.sets ?? '',
    duration_minutes: item.duration_minutes ?? '',
    speed_kmh: item.speed_kmh ?? ''
  }));
  error.value = '';
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    exercises.value = (await api.exercises()).sort((a, b) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
    resetForm();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

watch(() => props.open, (open) => { if (open) void load(); });
watch(() => [props.complex, props.mode], () => { if (props.open && exercises.value.length) resetForm(); });
onMounted(() => { if (props.open) void load(); });

function addExercise() {
  const exercise = exercises.value.find((candidate) => !items.value.some((item) => item.exercise_id === candidate.id));
  if (!exercise) return;
  items.value.push({ exercise_id: exercise.id, working_weight: '', sets: exercise.default_sets ?? '', duration_minutes: '', speed_kmh: '' });
}

function removeExercise(index: number) { items.value.splice(index, 1); }
function selectedExercise(item: ComplexItem) { return exercises.value.find((exercise) => exercise.id === item.exercise_id); }
function openSelectedExercise(item: ComplexItem) {
  const exercise = selectedExercise(item);
  if (exercise) emit('openExercise', exercise);
}

async function addPhotos(event: Event) {
  const input = event.target as HTMLInputElement;
  const files = Array.from(input.files || []).slice(0, 6 - photos.value.length);
  try { photos.value.push(...await Promise.all(files.map(readFile))); }
  catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { input.value = ''; }
}

async function addVideo(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  try { video.value = await readFile(file); }
  catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { input.value = ''; }
}

async function save() {
  error.value = '';
  if (!form.name.trim()) { error.value = 'Укажите название комплекса'; return; }
  saving.value = true;
  const payload = {
    name: form.name,
    comment: form.comment,
    photos: photos.value,
    video: video.value,
    items: items.value.map((item) => ({
      exercise_id: item.exercise_id,
      working_weight: item.working_weight || null,
      sets: item.sets || null,
      duration_minutes: item.duration_minutes || null,
      speed_kmh: item.speed_kmh || null
    }))
  };
  try {
    if (props.mode === 'edit' && props.complex) await api.updateWorkoutComplex(props.complex.id, payload);
    else await api.createWorkoutComplex(payload);
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally { saving.value = false; }
}
</script>

<template>
  <ModalDialog :open="open" :title="mode === 'edit' ? 'Редактировать комплекс' : 'Создать комплекс'" eyebrow="WORKOUT COMPLEX" wide @close="$emit('close')">
    <form class="complex-form" @submit.prevent="save">
      <div v-if="loading" class="panel">Загрузка…</div>
      <template v-else>
        <div class="grid">
          <div class="field full"><label>Название комплекса</label><input v-model="form.name" required></div>
          <div class="field full"><label>Комментарий</label><textarea v-model="form.comment" rows="4" placeholder="Описание комплекса, рекомендации и важные замечания"></textarea></div>
        </div>

        <section class="complex-exercises-section">
          <div class="complex-section-head">
            <div><p class="eyebrow">СОСТАВ</p><h3>Упражнения комплекса</h3></div>
            <button type="button" class="secondary-button" @click="addExercise">＋ Добавить упражнение</button>
          </div>
          <div class="complex-items">
            <article v-for="(item, index) in items" :key="index" class="complex-item">
              <div class="complex-item-head">
                <span class="builder-number">{{ index + 1 }}</span>
                <button v-if="selectedExercise(item)" type="button" class="complex-exercise-link" @click="openSelectedExercise(item)">
                  {{ selectedExercise(item)?.name }} ↗
                </button>
                <select v-model="item.exercise_id" aria-label="Упражнение">
                  <option v-for="exercise in exercises" :key="exercise.id" :value="exercise.id">{{ exercise.name }}</option>
                </select>
                <button type="button" class="remove-builder-item" aria-label="Удалить упражнение" @click="removeExercise(index)">×</button>
              </div>
              <div class="complex-item-fields">
                <div class="field"><label>Вес, {{ selectedExercise(item)?.default_unit || 'кг' }}</label><input v-model="item.working_weight" type="number" min="0" step="0.5"></div>
                <div class="field"><label>Подходы</label><input v-model="item.sets" type="number" min="1"></div>
                <div class="field"><label>Длительность, мин</label><input v-model="item.duration_minutes" type="number" min="1"></div>
                <div class="field"><label>Скорость, км/ч</label><input v-model="item.speed_kmh" type="number" min="0" step="0.1"></div>
              </div>
            </article>
            <div v-if="!items.length" class="builder-empty">Добавьте упражнения в комплекс.</div>
          </div>
        </section>

        <section class="complex-media-section">
          <div class="complex-section-head">
            <div><p class="eyebrow">МЕДИА</p><h3>Фото и видео комплекса</h3></div>
            <div class="complex-media-buttons">
              <button type="button" class="secondary-button" :disabled="photos.length >= 6" @click="photoInput?.click()">Добавить фото ({{ photos.length }}/6)</button>
              <button type="button" class="secondary-button" :disabled="Boolean(video)" @click="videoInput?.click()">Добавить видео ({{ video ? 1 : 0 }}/1)</button>
            </div>
          </div>
          <input ref="photoInput" class="complex-file-input" type="file" accept="image/*" multiple @change="addPhotos">
          <input ref="videoInput" class="complex-file-input" type="file" accept="video/*" @change="addVideo">
          <div v-if="photos.length" class="complex-photo-preview">
            <div v-for="(photo, index) in photos" :key="photo" class="complex-photo-item"><img :src="photo" alt="Фото комплекса"><button type="button" @click="photos.splice(index, 1)">×</button></div>
          </div>
          <div v-if="video" class="complex-video-preview"><video :src="video" controls></video><button type="button" @click="video = null">Удалить видео</button></div>
        </section>
      </template>
      <p class="form-error">{{ error }}</p>
      <div class="actions"><button type="button" @click="$emit('close')">Закрыть</button><button type="submit" class="primary" :disabled="saving">{{ saving ? 'Сохранение…' : 'Сохранить' }}</button></div>
    </form>
  </ModalDialog>
</template>

<style lang="scss">
.complex-form { width: 100%; }
.complex-exercises-section,
.complex-media-section { margin-top: 18px; padding: 16px; border: 1px solid var(--line); border-radius: 13px; background: #fafbfc; }
.complex-section-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.complex-section-head h3 { margin: 0; font-size: 15px; }
.complex-section-head p { margin-bottom: 4px; }
.complex-items { display: grid; gap: 10px; margin-top: 12px; }
.complex-item { padding: 12px; border: 1px solid var(--line); border-radius: 11px; background: #fff; }
.complex-item-head { display: flex; align-items: center; gap: 9px; }
.complex-item-head select { flex: 1; min-width: 150px; }
.complex-exercise-link { border: 0; padding: 0; background: none; color: var(--blue); font: inherit; font-weight: 800; cursor: pointer; text-align: left; }
.complex-exercise-link:hover { text-decoration: underline; }
.complex-item-fields { display: grid; grid-template-columns: repeat(4, 1fr); gap: 9px; margin-top: 10px; }
.complex-item-fields input { width: 100%; min-width: 0; }
.complex-media-buttons { display: flex; flex-wrap: wrap; gap: 7px; }
.complex-file-input { display: none; }
.complex-photo-preview { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 8px; margin-top: 14px; }
.complex-photo-item { position: relative; aspect-ratio: 1; overflow: hidden; border-radius: 9px; background: #eef1f5; }
.complex-photo-item img { width: 100%; height: 100%; object-fit: cover; }
.complex-photo-item button { position: absolute; top: 4px; right: 4px; width: 24px; height: 24px; border: 0; border-radius: 50%; background: #fff; color: #ae2a19; cursor: pointer; }
.complex-video-preview { display: flex; align-items: center; gap: 10px; margin-top: 14px; }
.complex-video-preview video { width: 180px; max-height: 120px; border-radius: 8px; background: #172b4d; }
.complex-video-preview button { border: 1px solid #f5a79b; border-radius: 7px; padding: 7px 10px; background: #ffebe6; color: #ae2a19; font-size: 10px; font-weight: 800; cursor: pointer; }
.form-error { min-height: 18px; margin: 10px 0 0; color: #ae2a19; font-size: 12px; }
@media (max-width: 700px) { .complex-section-head { align-items: flex-start; flex-direction: column; } .complex-item-head { flex-wrap: wrap; } .complex-exercise-link { order: 2; width: calc(100% - 40px); } .complex-item-head select { order: 3; width: 100%; } .complex-item-fields { grid-template-columns: 1fr 1fr; } .complex-photo-preview { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
</style>
