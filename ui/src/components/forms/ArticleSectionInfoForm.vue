<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue';
import { api } from '@/api/client';
import type { ArticleSection } from '@/types';

const props = defineProps<{ section: ArticleSection }>();
const emit = defineEmits<{ saved: [section: ArticleSection]; cancel: [] }>();
const bodyEditor = ref<HTMLElement | null>(null);
const imageInput = ref<HTMLInputElement | null>(null);
const body = ref('');
const error = ref('');
const saving = ref(false);
const emojiOpen = ref(false);
let savedSelection: Range | null = null;

const emojis = ['🙂', '😊', '🥗', '🍎', '🥑', '💪', '🔥', '✅', '⭐', '❤️', '💡', '👍'];

onMounted(() => {
  body.value = props.section.description || '';
  void nextTick(() => {
    if (bodyEditor.value) bodyEditor.value.innerHTML = body.value;
    normalizeFontTags();
  });
});

function syncBody() {
  body.value = bodyEditor.value?.innerHTML || '';
}

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
  const select = event.target as HTMLSelectElement;
  if (!select.value) return;
  bodyEditor.value?.focus();
  document.execCommand('fontSize', false, select.value);
  normalizeFontTags();
  select.value = '';
}

function rememberSelection() {
  const selection = window.getSelection();
  if (!selection?.rangeCount || !bodyEditor.value) return;
  const range = selection.getRangeAt(0);
  if (bodyEditor.value.contains(range.commonAncestorContainer)) savedSelection = range.cloneRange();
}

function restoreSelection() {
  if (!savedSelection) return;
  const selection = window.getSelection();
  selection?.removeAllRanges();
  selection?.addRange(savedSelection);
}

function readFile(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ''));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

function openImagePicker() {
  rememberSelection();
  imageInput.value?.click();
}

async function insertImage(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file || !file.type.startsWith('image/')) return;
  try {
    const src = await readFile(file);
    bodyEditor.value?.focus();
    restoreSelection();
    const entities: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    const alt = file.name.replace(/[&<>"']/g, (char) => entities[char] || char);
    document.execCommand('insertHTML', false, `<img src="${src}" alt="${alt}">`);
    syncBody();
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Не удалось вставить фото';
  }
}

function insertEmoji(emoji: string) {
  bodyEditor.value?.focus();
  document.execCommand('insertText', false, emoji);
  syncBody();
  emojiOpen.value = false;
}

async function save() {
  if (saving.value) return;
  normalizeFontTags();
  saving.value = true;
  error.value = '';
  try {
    const updated = await api.updateArticleSection(props.section.id, { description: body.value.trim() || null });
    emit('saved', updated);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <form class="modal-form-body section-info-form" @submit.prevent="save">
    <div class="field full">
      <label>Информация о разделе</label>
      <div class="rich-editor">
        <div class="editor-toolbar" aria-label="Форматирование текста">
          <button type="button" title="Жирный" @mousedown.prevent @click="format('bold')"><b>B</b></button>
          <button type="button" title="Курсив" @mousedown.prevent @click="format('italic')"><i>I</i></button>
          <select aria-label="Размер шрифта" @change="setFontSize"><option value="">Размер</option><option value="2">Маленький</option><option value="3">Обычный</option><option value="5">Крупный</option><option value="7">Очень крупный</option></select>
          <button type="button" title="Маркированный список" @mousedown.prevent @click="format('insertUnorderedList')">• Список</button>
          <button type="button" title="Нумерованный список" @mousedown.prevent @click="format('insertOrderedList')">1. Список</button>
          <button type="button" title="Вставить фото" @mousedown.prevent="rememberSelection" @click="openImagePicker">▧ Фото</button>
          <input ref="imageInput" class="hidden-file-input" type="file" accept="image/png,image/jpeg,image/gif,image/webp" @change="insertImage">
          <div class="emoji-control">
            <button type="button" title="Вставить эмодзи" @click="emojiOpen = !emojiOpen">😊</button>
            <div v-if="emojiOpen" class="emoji-picker"><button v-for="emoji in emojis" :key="emoji" type="button" @click="insertEmoji(emoji)">{{ emoji }}</button></div>
          </div>
        </div>
        <div ref="bodyEditor" class="editor-content" contenteditable="true" role="textbox" aria-multiline="true" data-placeholder="Напишите информацию о разделе…" @input="syncBody"></div>
      </div>
    </div>
    <p v-if="error" class="form-error">{{ error }}</p>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button class="primary" type="submit" :disabled="saving">{{ saving ? 'Сохранение…' : 'Сохранить' }}</button></div>
  </form>
</template>

<style scoped lang="scss">
.section-info-form { display: grid; gap: 16px; }
.rich-editor { overflow: hidden; border: 1px solid var(--line); border-radius: 10px; background: #fff; }
.editor-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; padding: 7px; border-bottom: 1px solid var(--line); background: #f7f8fa; }
.editor-toolbar button, .editor-toolbar select { min-height: 31px; padding: 5px 8px; border: 1px solid var(--line); border-radius: 6px; background: #fff; color: var(--ink); cursor: pointer; }
.editor-toolbar button:hover { border-color: var(--blue); color: var(--blue); }
.editor-toolbar select { font-size: 12px; }
.editor-content { min-height: 220px; padding: 13px; outline: none; line-height: 1.6; }
.editor-content:empty::before { content: attr(data-placeholder); color: var(--muted); pointer-events: none; }
.editor-content :deep(ul), .editor-content :deep(ol) { padding-left: 24px; }
.editor-content :deep(img) { display: block; max-width: 100%; height: auto; margin: 10px 0; border-radius: 8px; }
.hidden-file-input { display: none; }
.emoji-control { position: relative; }
.emoji-picker { position: absolute; z-index: 2; top: calc(100% + 5px); left: 0; display: grid; grid-template-columns: repeat(4, 1fr); width: 152px; padding: 6px; border: 1px solid var(--line); border-radius: 8px; background: #fff; box-shadow: 0 8px 22px #091e4226; }
.emoji-picker button { border: 0; font-size: 19px; }
</style>
