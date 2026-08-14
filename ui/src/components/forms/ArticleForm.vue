<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Article, ArticleLink, ArticleSection } from '@/types';

const props = defineProps<{ article?: Article | null }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();
const sections = ref<ArticleSection[]>([]);
const error = ref('');
const saving = ref(false);
const photos = ref<string[]>(['']);
const bodyEditor = ref<HTMLElement | null>(null);
const emojiOpen = ref(false);
const form = reactive({ section_id: 0, title: '', body: '', video: '' });
const links = ref<ArticleLink[]>([{ title: '', url: '' }]);
const editing = computed(() => Boolean(props.article));

onMounted(async () => {
  try {
    sections.value = await api.articleSections();
    loadArticle();
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
});

watch(() => props.article, loadArticle);

function loadArticle() {
  const article = props.article;
  form.section_id = article?.section_id || sections.value[0]?.id || 0;
  form.title = article?.title || '';
  form.body = article?.body || '';
  form.video = article?.video || '';
  links.value = article?.links?.length ? article.links.map((link) => ({ ...link })) : [{ title: '', url: '' }];
  photos.value = article?.photos?.length ? [...article.photos] : [''];
  void nextTick(() => { if (bodyEditor.value) bodyEditor.value.innerHTML = form.body; });
}

function addPhoto() { if (photos.value.length < 6) photos.value.push(''); }
function removePhoto(index: number) { if (photos.value.length > 1) photos.value.splice(index, 1); }
function addLink() { links.value.push({ title: '', url: '' }); }
function removeLink(index: number) { if (links.value.length > 1) links.value.splice(index, 1); }
function readFile(file: File) { return new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result || '')); reader.onerror = () => reject(reader.error); reader.readAsDataURL(file); }); }
async function choosePhotos(event: Event) {
  const files = [...((event.target as HTMLInputElement).files || [])].slice(0, 6);
  try { photos.value = files.length ? await Promise.all(files.map(readFile)) : ['']; } catch (err) { error.value = err instanceof Error ? err.message : 'Не удалось прочитать фото'; }
}
async function chooseVideo(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  try { form.video = await readFile(file); } catch (err) { error.value = err instanceof Error ? err.message : 'Не удалось прочитать видео'; }
}

function syncBody() { form.body = bodyEditor.value?.innerHTML || ''; }

function normalizeFontTags() {
  bodyEditor.value?.querySelectorAll('font[size]').forEach((node) => {
    const font = node as HTMLElement;
    const sizes: Record<string, string> = { '1': '12px', '2': '14px', '3': '16px', '4': '18px', '5': '22px', '6': '26px', '7': '30px' };
    font.style.fontSize = sizes[font.getAttribute('size') || '3'] || '16px';
    font.removeAttribute('size');
  });
  syncBody();
}

function format(command: 'bold' | 'italic' | 'insertUnorderedList' | 'insertOrderedList') {
  bodyEditor.value?.focus();
  document.execCommand(command, false);
  syncBody();
}

function setFontSize(event: Event) {
  const size = (event.target as HTMLSelectElement).value;
  if (!size) return;
  bodyEditor.value?.focus();
  document.execCommand('fontSize', false, size);
  normalizeFontTags();
  (event.target as HTMLSelectElement).value = '';
}

function insertEmoji(emoji: string) {
  bodyEditor.value?.focus();
  document.execCommand('insertText', false, emoji);
  syncBody();
  emojiOpen.value = false;
}

const emojis = ['🙂', '😊', '🥗', '🍎', '🥑', '💪', '🔥', '✅', '⭐', '❤️', '💡', '👏'];

async function save() {
  syncBody();
  const bodyText = bodyEditor.value?.innerText.trim() || '';
  if (!form.section_id || !form.title.trim() || !bodyText || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      ...form,
      links: links.value.map((link) => ({ title: link.title.trim(), url: link.url.trim() })).filter((link) => link.title && link.url),
      photos: photos.value.map((item) => item.trim()).filter(Boolean)
    };
    if (props.article) await api.updateArticle(props.article.id, payload);
    else await api.createArticle(payload);
    emit('saved');
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { saving.value = false; }
}
</script>

<template>
  <form class="modal-form-body article-form" @submit.prevent="save">
    <div class="grid">
      <div class="field"><label>Раздел</label><select v-model="form.section_id" required><option v-for="item in sections" :key="item.id" :value="item.id">{{ item.name }}</option></select></div>
      <div class="field"><label>Заголовок</label><input v-model="form.title" required maxlength="240"></div>
      <div class="field full"><label>Статья</label>
        <div class="rich-editor">
          <div class="editor-toolbar" aria-label="Форматирование текста">
            <button type="button" title="Жирный" @mousedown.prevent @click="format('bold')"><b>B</b></button>
            <button type="button" title="Курсив" @mousedown.prevent @click="format('italic')"><i>I</i></button>
            <select aria-label="Размер шрифта" @change="setFontSize"><option value="">Размер</option><option value="2">Маленький</option><option value="3">Обычный</option><option value="5">Крупный</option><option value="7">Очень крупный</option></select>
            <button type="button" title="Маркированный список" @mousedown.prevent @click="format('insertUnorderedList')">• Список</button>
            <button type="button" title="Нумерованный список" @mousedown.prevent @click="format('insertOrderedList')">1. Список</button>
            <div class="emoji-control">
              <button type="button" title="Вставить эмодзи" @click="emojiOpen = !emojiOpen">😊</button>
              <div v-if="emojiOpen" class="emoji-picker"><button v-for="emoji in emojis" :key="emoji" type="button" @click="insertEmoji(emoji)">{{ emoji }}</button></div>
            </div>
          </div>
          <div ref="bodyEditor" class="editor-content" contenteditable="true" role="textbox" aria-multiline="true" data-placeholder="Напишите текст статьи…" @input="syncBody"></div>
        </div>
      </div>
    </div>

    <section class="link-editor">
      <div class="section-editor-head"><div><b>Ссылки</b><small>Добавьте название и адрес ссылки</small></div><button type="button" class="secondary-button" @click="addLink">＋ Добавить ссылку</button></div>
      <div v-for="(link, index) in links" :key="index" class="link-row"><input v-model="link.title" placeholder="Название ссылки"><input v-model="link.url" type="url" placeholder="https://example.com"><button type="button" aria-label="Удалить ссылку" @click="removeLink(index)">×</button></div>
    </section>

    <section class="media-editor">
      <div class="media-editor-head"><b>Фото (до 6 шт.)</b><label class="file-button">Выбрать файлы<input type="file" accept="image/*" multiple @change="choosePhotos"></label><button type="button" class="secondary-button" :disabled="photos.length >= 6" @click="addPhoto">＋ Ссылка</button></div>
      <div v-for="(_, index) in photos" :key="index" class="media-row"><input v-model="photos[index]" type="url" placeholder="Ссылка на фото"><button type="button" @click="removePhoto(index)">Удалить</button></div>
      <div class="field full"><label>Видео (до 1 шт.)</label><input v-model="form.video" type="url" placeholder="Ссылка на видео"><label class="file-button">Выбрать видео<input type="file" accept="video/*" @change="chooseVideo"></label></div>
    </section>
    <p v-if="error" class="form-error">{{ error }}</p>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button class="primary" type="submit" :disabled="saving || !form.section_id">{{ editing ? 'Сохранить изменения' : 'Сохранить статью' }}</button></div>
  </form>
</template>

<style scoped lang="scss">
.article-form { display: grid; gap: 16px; }
.rich-editor { overflow: hidden; border: 1px solid var(--line); border-radius: 10px; background: #fff; }
.editor-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; padding: 7px; border-bottom: 1px solid var(--line); background: #f7f8fa; }
.editor-toolbar button, .editor-toolbar select { min-height: 31px; padding: 5px 8px; border: 1px solid var(--line); border-radius: 6px; background: #fff; color: var(--ink); cursor: pointer; }
.editor-toolbar button:hover { border-color: var(--blue); color: var(--blue); }
.editor-toolbar select { font-size: 12px; }
.editor-content { min-height: 220px; padding: 13px; outline: none; line-height: 1.6; }
.editor-content:empty::before { content: attr(data-placeholder); color: var(--muted); pointer-events: none; }
.editor-content :deep(ul), .editor-content :deep(ol) { padding-left: 24px; }
.emoji-control { position: relative; }
.emoji-picker { position: absolute; z-index: 2; top: calc(100% + 5px); left: 0; display: grid; grid-template-columns: repeat(4, 1fr); width: 152px; padding: 6px; border: 1px solid var(--line); border-radius: 8px; background: #fff; box-shadow: 0 8px 22px #091e4226; }
.emoji-picker button { border: 0; font-size: 19px; }
.link-editor, .media-editor { display: grid; gap: 8px; padding: 14px; border: 1px solid var(--line); border-radius: 12px; background: #fafbfc; }
.section-editor-head, .media-editor-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.section-editor-head small { display: block; margin-top: 3px; color: var(--muted); font-size: 11px; }
.link-row { display: grid; grid-template-columns: minmax(130px, .7fr) minmax(180px, 1.3fr) 34px; gap: 7px; }
.link-row button, .media-row button { border: 1px solid var(--line); border-radius: 7px; background: #fff; cursor: pointer; }
.media-row { display: grid; grid-template-columns: 1fr auto; gap: 7px; }
.file-button { display: inline-flex; align-items: center; gap: 6px; width: fit-content; padding: 7px 10px; border: 1px solid var(--line); border-radius: 7px; background: #fff; cursor: pointer; font-size: 12px; font-weight: 750; }.file-button input { display: none; }
@media (max-width: 600px) { .section-editor-head, .media-editor-head { align-items: flex-start; flex-direction: column; } .link-row { grid-template-columns: 1fr 34px; }.link-row input:first-child { grid-column: 1 / -1; } }
</style>
