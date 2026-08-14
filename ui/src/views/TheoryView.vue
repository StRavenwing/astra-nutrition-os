<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Article, ArticleSection } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ isAdmin: boolean; refreshKey: number }>();
const emit = defineEmits<{ addArticle: []; editArticle: [article: Article] }>();
const sections = ref<ArticleSection[]>([]);
const articles = ref<Article[]>([]);
const activeSection = ref<number | null>(null);
const selectedArticle = ref<Article | null>(null);
const sectionOpen = ref(false);
const sectionName = ref('');
const error = ref('');

const popularArticles = computed(() => articles.value.filter((article) => article.is_pinned));
const sectionArticleList = computed(() => activeSection.value === null ? [] : articles.value.filter((article) => article.section_id === activeSection.value));
const activeSectionName = computed(() => sections.value.find((section) => section.id === activeSection.value)?.name || '');

async function load() {
  try {
    [sections.value, articles.value] = await Promise.all([api.articleSections(), api.articles()]);
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}
onMounted(load);
watch(() => props.refreshKey, load);

function sectionArticles(id: number) { return articles.value.filter((item) => item.section_id === id); }
function articlePreview(body: string) {
  const text = /<[a-z][\s\S]*>/i.test(body) ? new DOMParser().parseFromString(body, 'text/html').body.textContent || '' : body;
  const clean = text.replace(/\s+/g, ' ').trim();
  return clean.length > 170 ? `${clean.slice(0, 170)}…` : clean;
}
function escapeHtml(value: string) {
  const entities: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return value.replace(/[&<>"']/g, (char) => entities[char] || char);
}
function articleHtml(body: string) {
  if (!/<[a-z][\s\S]*>/i.test(body)) return escapeHtml(body).replace(/\n/g, '<br>');
  const source = new DOMParser().parseFromString(body, 'text/html');
  const allowed = new Set(['P', 'DIV', 'BR', 'STRONG', 'B', 'EM', 'I', 'U', 'UL', 'OL', 'LI', 'A', 'SPAN']);
  source.body.querySelectorAll('*').forEach((node) => {
    if (!allowed.has(node.tagName)) { node.replaceWith(...Array.from(node.childNodes)); return; }
    [...node.attributes].forEach((attribute) => {
      if (node.tagName === 'A' && attribute.name === 'href' && /^(https?:|mailto:)/i.test(attribute.value)) return;
      if (node.tagName === 'SPAN' && attribute.name === 'style' && /^font-size:\s*(12|14|16|18|22|26|30)px;?$/i.test(attribute.value.trim())) return;
      node.removeAttribute(attribute.name);
    });
    if (node.tagName === 'A') { node.setAttribute('target', '_blank'); node.setAttribute('rel', 'noreferrer'); }
  });
  return source.body.innerHTML;
}

function openArticle(article: Article) { selectedArticle.value = article; }
function closeArticle() { selectedArticle.value = null; }
function editArticle(article: Article) { closeArticle(); emit('editArticle', article); }

function replaceArticle(updated: Article) {
  const index = articles.value.findIndex((article) => article.id === updated.id);
  if (index >= 0) articles.value[index] = updated;
  if (selectedArticle.value?.id === updated.id) selectedArticle.value = updated;
}

async function toggleFlag(article: Article, flag: 'is_pinned' | 'is_hidden') {
  if (!props.isAdmin) return;
  try {
    const updated = await api.updateArticleFlags(article.id, { [flag]: !article[flag] });
    replaceArticle(updated);
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

async function createSection() {
  if (!sectionName.value.trim() || !props.isAdmin) return;
  try {
    const item = await api.createArticleSection(sectionName.value.trim());
    sections.value.push(item);
    sectionName.value = '';
    sectionOpen.value = false;
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}
</script>

<template>
  <section class="theory-page">
    <div class="theory-head"><div><p class="eyebrow">ИНФОРМАЦИЯ</p><h2>Статьи и полезные материалы</h2></div><button v-if="props.isAdmin" type="button" class="primary" @click="emit('addArticle')">＋ Добавить статью</button></div>
    <div v-if="error" class="panel empty">{{ error }}</div>

    <section class="popular-articles">
      <div class="content-block-head"><div><p class="eyebrow">ПОПУЛЯРНОЕ</p><h3>Популярные статьи</h3></div><small v-if="props.isAdmin">Закрепляйте статьи, которые должны быть видны сверху</small></div>
      <div v-if="popularArticles.length" class="article-grid">
        <article v-for="item in popularArticles" :key="`popular-${item.id}`" class="article-card" :class="{ hidden: item.is_hidden }" tabindex="0" @click="openArticle(item)" @keydown.enter.prevent="openArticle(item)">
          <img v-if="item.photos[0]" :src="item.photos[0]" :alt="item.title">
          <div class="article-card-head"><p class="eyebrow">{{ item.section_name }}</p><span v-if="item.is_hidden" class="hidden-badge">Скрыта</span></div>
          <h3>{{ item.title }}</h3><p class="article-excerpt">{{ articlePreview(item.body) }}</p>
          <div v-if="props.isAdmin" class="article-card-actions" @click.stop><button type="button" @click="toggleFlag(item, 'is_pinned')">Открепить</button><button type="button" @click="toggleFlag(item, 'is_hidden')">{{ item.is_hidden ? 'Вернуть' : 'Скрыть' }}</button><button type="button" @click="editArticle(item)">Редактировать</button></div>
        </article>
      </div>
      <div v-else class="panel empty">Пока нет закреплённых статей.</div>
    </section>

    <section class="article-sections-block">
      <div class="content-block-head"><div><p class="eyebrow">РАЗДЕЛЫ</p><h3>Выберите раздел</h3></div></div>
      <div class="article-sections">
        <button v-for="item in sections" :key="item.id" type="button" class="article-section-card" :class="{ active: activeSection === item.id }" @click="activeSection = item.id"><span><b>{{ item.name }}</b><small>{{ item.article_count }} статей</small></span><strong>{{ sectionArticles(item.id).length }}</strong></button>
        <button v-if="props.isAdmin" type="button" class="article-section-card add-section-card" @click="sectionOpen = true"><span><b>＋ Создать раздел</b><small>Новый раздел статей</small></span></button>
      </div>
    </section>

    <section v-if="activeSection !== null" class="selected-section">
      <div class="content-block-head"><div><p class="eyebrow">РАЗДЕЛ</p><h3>{{ activeSectionName }}</h3></div></div>
      <div v-if="sectionArticleList.length" class="article-grid">
        <article v-for="item in sectionArticleList" :key="item.id" class="article-card" :class="{ hidden: item.is_hidden }" tabindex="0" @click="openArticle(item)" @keydown.enter.prevent="openArticle(item)">
          <img v-if="item.photos[0]" :src="item.photos[0]" :alt="item.title">
          <div class="article-card-head"><p class="eyebrow">{{ item.section_name }}</p><span v-if="item.is_hidden" class="hidden-badge">Скрыта</span></div>
          <h3>{{ item.title }}</h3><p class="article-excerpt">{{ articlePreview(item.body) }}</p>
          <div v-if="props.isAdmin" class="article-card-actions" @click.stop><button type="button" @click="toggleFlag(item, 'is_pinned')">{{ item.is_pinned ? 'Открепить' : 'Закрепить' }}</button><button type="button" @click="toggleFlag(item, 'is_hidden')">{{ item.is_hidden ? 'Вернуть' : 'Скрыть' }}</button><button type="button" @click="editArticle(item)">Редактировать</button></div>
        </article>
      </div>
      <div v-else class="panel empty">В этом разделе пока нет статей.</div>
    </section>
  </section>

  <ModalDialog :open="Boolean(selectedArticle)" :title="selectedArticle?.title || 'Статья'" eyebrow="СТАТЬЯ" wide @close="closeArticle">
    <article v-if="selectedArticle" class="article-detail">
      <img v-for="photo in selectedArticle.photos" :key="photo" :src="photo" :alt="selectedArticle.title" class="article-detail-photo">
      <p class="eyebrow">{{ selectedArticle.section_name }}</p>
      <div class="article-detail-body" v-html="articleHtml(selectedArticle.body)"></div>
      <div v-if="selectedArticle.links?.length || selectedArticle.video" class="article-links"><a v-for="link in selectedArticle.links" :key="link.url" :href="link.url" target="_blank" rel="noreferrer">{{ link.title }}</a><a v-if="selectedArticle.video" :href="selectedArticle.video" target="_blank" rel="noreferrer">Видео</a></div>
      <div v-if="props.isAdmin" class="article-detail-actions"><button type="button" class="primary" @click="editArticle(selectedArticle)">Редактировать</button><button type="button" @click="toggleFlag(selectedArticle, 'is_pinned')">{{ selectedArticle.is_pinned ? 'Открепить' : 'Закрепить' }}</button><button type="button" @click="toggleFlag(selectedArticle, 'is_hidden')">{{ selectedArticle.is_hidden ? 'Вернуть' : 'Скрыть' }}</button></div>
    </article>
  </ModalDialog>

  <ModalDialog :open="sectionOpen" title="Создать раздел" eyebrow="СТАТЬИ" @close="sectionOpen = false"><form class="section-form" @submit.prevent="createSection"><div class="field full"><label>Название раздела</label><input v-model="sectionName" required maxlength="120" autofocus></div><div class="actions"><button type="button" @click="sectionOpen = false">Отмена</button><button class="primary" type="submit">Создать</button></div></form></ModalDialog>
</template>

<style scoped lang="scss">
.theory-head, .content-block-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 14px; }
.theory-head { margin-bottom: 20px; }.theory-head h2, .content-block-head h3 { margin: 0; }.content-block-head { margin-bottom: 12px; }.content-block-head small { color: var(--muted); font-size: 11px; }
.popular-articles, .article-sections-block, .selected-section { margin-bottom: 24px; }.popular-articles { padding: 18px; border: 1px solid #9f8fef; border-radius: 16px; background: linear-gradient(135deg, #fff, #f5f2ff); }
.article-sections { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 12px; }
.article-section-card { display: flex; align-items: flex-start; justify-content: space-between; min-height: 92px; padding: 15px; border: 1px solid var(--line); border-radius: 13px; background: #fff; color: var(--ink); text-align: left; cursor: pointer; }.article-section-card.active { border-color: var(--blue); box-shadow: 0 0 0 2px #0c66e426; }.article-section-card b, .article-section-card small { display: block; }.article-section-card small { margin-top: 5px; color: var(--muted); }.article-section-card strong { padding: 4px 8px; border-radius: 99px; background: #e9f2ff; color: var(--blue); }.add-section-card { border-style: dashed; }
.article-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 15px; }.article-card { position: relative; overflow: hidden; min-height: 230px; padding: 18px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 4px 14px #091e4210; cursor: pointer; transition: transform .15s ease, box-shadow .15s ease; }.article-card:hover, .article-card:focus-visible { transform: translateY(-2px); box-shadow: 0 9px 22px #091e4220; outline: none; }.article-card.hidden { border-style: dashed; opacity: .82; }.article-card img { width: calc(100% + 36px); height: 145px; margin: -18px -18px 15px; object-fit: cover; }.article-card-head { display: flex; align-items: center; justify-content: space-between; gap: 10px; }.article-card-head .eyebrow { margin: 0; }.article-card h3 { margin: 5px 0 8px; font-size: 19px; }.article-excerpt { display: -webkit-box; overflow: hidden; margin: 0; color: var(--muted); line-height: 1.55; -webkit-box-orient: vertical; -webkit-line-clamp: 4; }.hidden-badge { padding: 3px 7px; border-radius: 99px; background: #ffebe6; color: #ae2a19; font-size: 10px; font-weight: 800; }.article-card-actions, .article-detail-actions { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 15px; }.article-card-actions button, .article-detail-actions button { padding: 7px 9px; border: 1px solid var(--line); border-radius: 7px; background: #fff; color: var(--ink); font-size: 11px; font-weight: 750; cursor: pointer; }.article-card-actions button:hover, .article-detail-actions button:hover { border-color: var(--blue); color: var(--blue); }
.article-detail { max-width: 840px; }.article-detail-photo { width: 100%; max-height: 360px; margin-bottom: 15px; border-radius: 12px; object-fit: cover; }.article-detail-body { line-height: 1.75; }.article-detail-body :deep(ul), .article-detail-body :deep(ol) { padding-left: 24px; }.article-detail-body :deep(p) { margin: 0 0 12px; }.article-detail-actions { padding-top: 14px; border-top: 1px solid var(--line); }.article-links { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 18px; }.article-links a { color: var(--blue); font-weight: 750; }.section-form { display: grid; gap: 12px; }
@media (max-width: 600px) { .theory-head, .content-block-head { align-items: flex-start; flex-direction: column; }.popular-articles { padding: 14px; } }
</style>
