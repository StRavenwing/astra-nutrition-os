<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { api } from '@/api/client';
import type { ArticleSection } from '@/types';

const emit = defineEmits<{ saved: []; cancel: [] }>();
const sections = ref<ArticleSection[]>([]);
const error = ref('');
const saving = ref(false);
const photos = ref<string[]>(['']);
const form = reactive({ section_id: 0, title: '', body: '', links: '', video: '' });

onMounted(async () => {
  try {
    sections.value = await api.articleSections();
    form.section_id = sections.value[0]?.id || 0;
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
});

function addPhoto() { if (photos.value.length < 6) photos.value.push(''); }
function removePhoto(index: number) { if (photos.value.length > 1) photos.value.splice(index, 1); }
function readFile(file: File) { return new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result || '')); reader.onerror = () => reject(reader.error); reader.readAsDataURL(file); }); }
async function choosePhotos(event: Event) {
  const files = [...((event.target as HTMLInputElement).files || [])].slice(0, 6);
  try { photos.value = await Promise.all(files.map(readFile)); } catch (err) { error.value = err instanceof Error ? err.message : 'Не удалось прочитать фото'; }
}
async function chooseVideo(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  try { form.video = await readFile(file); } catch (err) { error.value = err instanceof Error ? err.message : 'Не удалось прочитать видео'; }
}

async function save() {
  if (!form.section_id || !form.title.trim() || !form.body.trim() || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    await api.createArticle({ ...form, photos: photos.value.map((item) => item.trim()).filter(Boolean) });
    emit('saved');
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { saving.value = false; }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div class="grid">
      <div class="field"><label>Раздел</label><select v-model="form.section_id" required><option v-for="item in sections" :key="item.id" :value="item.id">{{ item.name }}</option></select></div>
      <div class="field"><label>Заголовок</label><input v-model="form.title" required maxlength="240"></div>
      <div class="field full"><label>Статья</label><textarea v-model="form.body" rows="10" required></textarea></div>
      <div class="field full"><label>Ссылки</label><textarea v-model="form.links" rows="3" placeholder="По одной ссылке в строке"></textarea></div>
    </div>
    <section class="media-editor">
      <div class="media-editor-head"><b>Фото (до 6 шт.)</b><label class="file-button">Выбрать файлы<input type="file" accept="image/*" multiple @change="choosePhotos"></label><button type="button" class="secondary-button" :disabled="photos.length >= 6" @click="addPhoto">＋ Ссылка</button></div>
      <div v-for="(_, index) in photos" :key="index" class="media-row"><input v-model="photos[index]" type="url" placeholder="Ссылка на фото"><button type="button" @click="removePhoto(index)">Удалить</button></div>
      <div class="field full"><label>Видео (до 1 шт.)</label><input v-model="form.video" type="url" placeholder="Ссылка на видео"><label class="file-button">Выбрать видео<input type="file" accept="video/*" @change="chooseVideo"></label></div>
    </section>
    <p v-if="error" class="form-error">{{ error }}</p>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button class="primary" type="submit" :disabled="saving || !form.section_id">Сохранить статью</button></div>
  </form>
</template>

<style scoped lang="scss">
.media-editor { display: grid; gap: 8px; margin-top: 16px; padding: 14px; border: 1px solid var(--line); border-radius: 12px; background: #fafbfc; }
.media-editor-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.media-row { display: grid; grid-template-columns: 1fr auto; gap: 7px; }
.media-row button { border: 1px solid var(--line); border-radius: 7px; background: #fff; cursor: pointer; }
.file-button { display: inline-flex; align-items: center; gap: 6px; width: fit-content; padding: 7px 10px; border: 1px solid var(--line); border-radius: 7px; background: #fff; cursor: pointer; font-size: 12px; font-weight: 750; }.file-button input { display: none; }
</style>
