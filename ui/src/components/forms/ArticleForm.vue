<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Article, ArticleLink, ArticleSection } from '@/types';

const props = defineProps<{ article?: Article | null }>();
const emit = defineEmits<{ saved: []; deleted: []; cancel: [] }>();
const sections = ref<ArticleSection[]>([]);
const error = ref('');
const saving = ref(false);
const photos = ref<string[]>(['']);
const bodyEditor = ref<HTMLElement | null>(null);
const imageInput = ref<HTMLInputElement | null>(null);
let savedSelection: Range | null = null;
const emojiOpen = ref(false);
const form = reactive({ section_id: 0, title: '', body: '', tags: '', video: '' });
const links = ref<ArticleLink[]>([{ title: '', url: '' }]);
const editing = computed(() => Boolean(props.article));
const generatedTags = computed(() => {
  const source = `${form.title} ${new DOMParser().parseFromString(form.body || '', 'text/html').body.textContent || ''}`;
  const stopwords = new Set(['этот', 'этого', 'статья', 'статьи', 'когда', 'чтобы', 'который', 'которая', 'главный', 'главная', 'для', 'или', 'при', 'как', 'the', 'this', 'with']);
  const tags: string[] = [];
  (source.match(/#[\p{L}\p{N}_-]+/gu) || []).forEach((value) => { const tag = value.toLocaleLowerCase(); if (!tags.includes(tag)) tags.push(tag); });
  (form.title.toLocaleLowerCase().match(/[\p{L}\p{N}]{4,}/gu) || []).forEach((value) => { const tag = `#${value}`; if (!stopwords.has(value) && !tags.includes(tag) && tags.length < 6) tags.push(tag); });
  return tags.slice(0, 6).join(' ');
});

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
  void nextTick(() => { if (bodyEditor.value) { bodyEditor.value.innerHTML = form.body; normalizeFontTags(); } });
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

function rememberSelection() {
  const selection = window.getSelection();
  if (!selection?.rangeCount || !bodyEditor.value) return;
  const range = selection.getRangeAt(0);
  if (bodyEditor.value.contains(range.commonAncestorContainer)) savedSelection = range.cloneRange();
}

function openImagePicker() {
  rememberSelection();
  imageInput.value?.click();
}

function restoreSelection() {
  if (!savedSelection) return;
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(savedSelection);
}

async function insertImage(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  (event.target as HTMLInputElement).value = '';
  if (!file || !file.type.startsWith('image/')) return;
  try {
    const src = await readFile(file);
    bodyEditor.value?.focus();
    restoreSelection();
    const entities: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    const alt = file.name.replace(/[&<>"']/g, (char) => entities[char] || char);
    document.execCommand('insertHTML', false, `<img src="${src}" alt="${alt}">`);
    syncBody();
  } catch (err) { error.value = err instanceof Error ? err.message : 'Не удалось вставить фото'; }
}

function normalizeFontTags() {
  bodyEditor.value?.querySelectorAll('font').forEach((node) => {
    const font = node as HTMLElement;
    const sizes: Record<string, string> = { '1': '12px', '2': '14px', '3': '16px', '4': '18px', '5': '22px', '6': '26px', '7': '30px' };
    const span = document.createElement('span');
    const size = sizes[font.getAttribute('size') || ''] || font.style.fontSize;
    if (size) span.style.fontSize = size;
    if (font.style.fontWeight) span.style.fontWeight = font.style.fontWeight;
    if (font.style.fontStyle) span.style.fontStyle = font.style.fontStyle;
    if (font.style.textDecoration) span.style.textDecoration = font.style.textDecoration;
    span.innerHTML = font.innerHTML;
    font.replaceWith(span);
  });
  syncBody();
}

function format(command: 'bold' | 'italic' | 'insertUnorderedList' | 'insertOrderedList' | 'indent' | 'outdent') {
  rememberSelection();
  bodyEditor.value?.focus();
  restoreSelection();
  if (command === 'bold' || command === 'italic') document.execCommand('styleWithCSS', false, 'true');
  document.execCommand(command, false);
  if (command === 'bold' || command === 'italic') document.execCommand('styleWithCSS', false, 'false');
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
  normalizeFontTags();
  const bodyText = bodyEditor.value?.innerText.trim() || '';
  if (!form.section_id || !form.title.trim() || !bodyText || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const payload = {
      ...form,
      tags: generatedTags.value,
      links: links.value.map((link) => ({ title: link.title.trim(), url: link.url.trim() })).filter((link) => link.title && link.url),
      photos: photos.value.map((item) => item.trim()).filter(Boolean)
    };
    if (props.article) await api.updateArticle(props.article.id, payload);
    else await api.createArticle(payload);
    emit('saved');
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
  finally { saving.value = false; }
}
async function removeArticle() {
  if (!props.article || saving.value || !confirm("Удалить статью? Это действие нельзя отменить.")) return;

  saving.value = true;
  error.value = '';
  try {
    await api.deleteArticle(props.article.id);
    emit('deleted');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <form class="modal-form-body article-form" @submit.prevent="save">
    <div class="grid">
      <div class="field"><label>Раздел</label><select v-model="form.section_id" required><option v-for="item in sections" :key="item.id" :value="item.id">{{ item.name }}</option></select></div>
      <div class="field"><label>Заголовок</label><input v-model="form.title" required maxlength="240"></div>
      <div class="field full"><label>Хэштеги</label><input :value="generatedTags" readonly placeholder="Будут созданы автоматически"><small class="field-hint">Формируются автоматически из заголовка и текста статьи</small></div>
      <div class="field full"><label>Статья</label>
        <div class="rich-editor">
          <div class="editor-toolbar" aria-label="Форматирование текста">
            <button type="button" title="Жирный" @mousedown.prevent="rememberSelection" @click="format('bold')"><b>B</b></button>
            <button type="button" title="Курсив" @mousedown.prevent="rememberSelection" @click="format('italic')"><i>I</i></button>
            <select aria-label="Размер шрифта" @change="setFontSize"><option value="">Размер</option><option value="2">Маленький</option><option value="3">Обычный</option><option value="5">Крупный</option><option value="7">Очень крупный</option></select>
            <button type="button" title="Маркированный список" @mousedown.prevent="rememberSelection" @click="format('insertUnorderedList')">• Список</button>
            <button type="button" title="Нумерованный список" @mousedown.prevent="rememberSelection" @click="format('insertOrderedList')">1. Список</button>
            <button type="button" title="Увеличить отступ" @mousedown.prevent="rememberSelection" @click="format('indent')">↦ Отступ</button>
            <button type="button" title="Уменьшить отступ" @mousedown.prevent="rememberSelection" @click="format('outdent')">↤ Убрать</button>
            <button type="button" title="Вставить фото" @mousedown.prevent="rememberSelection" @click="openImagePicker">▧ Фото</button>
            <input ref="imageInput" class="hidden-file-input" type="file" accept="image/png,image/jpeg,image/gif,image/webp" @change="insertImage">
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
    <div v-if="editing" class="article-delete-row">
      <button type="button" class="danger-button article-delete-button" :disabled="saving" @click="removeArticle">Удалить статью</button>
    </div>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button class="primary" type="submit" :disabled="saving || !form.section_id">{{ editing ? 'Сохранить изменения' : 'Сохранить статью' }}</button></div>
  </form>
</template>

<style scoped lang="scss">
.article-form { display: grid; gap: 16px; }
.article-delete-row { display: flex; justify-content: flex-start; }
.article-delete-button { min-height: 36px; }
.field-hint { display: block; margin-top: 4px; color: var(--muted); font-size: 11px; }
.rich-editor { overflow: hidden; border: 1px solid var(--line); border-radius: 10px; background: #fff; }
.editor-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; padding: 7px; border-bottom: 1px solid var(--line); background: #f7f8fa; }
.editor-toolbar button, .editor-toolbar select { min-height: 31px; padding: 5px 8px; border: 1px solid var(--line); border-radius: 6px; background: #fff; color: var(--ink); cursor: pointer; }
.editor-toolbar button:hover { border-color: var(--blue); color: var(--blue); }
.editor-toolbar select { font-size: 12px; }
.editor-content { min-height: 220px; padding: 13px; outline: none; line-height: 1.6; }
.editor-content:empty::before { content: attr(data-placeholder); color: var(--muted); pointer-events: none; }
.editor-content :deep(ul), .editor-content :deep(ol) { padding-left: 24px; }
.editor-content :deep(blockquote) { margin: 12px 0 12px 32px; padding-left: 12px; border-left: 3px solid #c8d8f7; }
.editor-content :deep(img) { display: block; max-width: 100%; height: auto; margin: 10px 0; border-radius: 8px; }
.hidden-file-input { display: none; }
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
