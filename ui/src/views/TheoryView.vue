<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { Article, ArticleSection } from '@/types';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ isAdmin: boolean; refreshKey: number }>();
const emit = defineEmits<{ addArticle: [] }>();
const sections = ref<ArticleSection[]>([]);
const articles = ref<Article[]>([]);
const activeSection = ref<number | null>(null);
const sectionOpen = ref(false);
const sectionName = ref('');
const error = ref('');

async function load() {
  try {
    [sections.value, articles.value] = await Promise.all([api.articleSections(), api.articles()]);
    if (!activeSection.value) activeSection.value = sections.value[0]?.id || null;
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}
onMounted(load);
watch(() => props.refreshKey, load);

function sectionArticles(id: number) { return articles.value.filter((item) => item.section_id === id); }
async function createSection() {
  if (!sectionName.value.trim()) return;
  try { const item = await api.createArticleSection(sectionName.value.trim()); sections.value.push(item); activeSection.value = item.id; sectionName.value = ''; sectionOpen.value = false; }
  catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}
</script>

<template>
  <section class="theory-page">
    <div class="theory-head"><div><p class="eyebrow">ИНФОРМАЦИЯ</p><h2>Статьи и полезные материалы</h2></div><button v-if="props.isAdmin" type="button" class="primary" @click="emit('addArticle')">＋ Добавить статью</button></div>
    <div v-if="error" class="panel empty">{{ error }}</div>
    <div class="article-sections">
      <button v-for="item in sections" :key="item.id" type="button" class="article-section-card" :class="{ active: activeSection === item.id }" @click="activeSection = item.id"><span><b>{{ item.name }}</b><small>{{ item.article_count }} статей</small></span><strong>{{ sectionArticles(item.id).length }}</strong></button>
      <button v-if="props.isAdmin" type="button" class="article-section-card add-section-card" @click="sectionOpen = true"><span><b>＋ Создать раздел</b><small>Новый раздел статей</small></span></button>
    </div>
    <div class="article-grid">
      <article v-for="item in articles.filter((article) => article.section_id === activeSection)" :key="item.id" class="article-card">
        <img v-if="item.photos[0]" :src="item.photos[0]" :alt="item.title">
        <p class="eyebrow">{{ item.section_name }}</p><h3>{{ item.title }}</h3><div class="article-body">{{ item.body }}</div>
        <div v-if="item.links || item.video" class="article-links"><a v-for="link in (item.links || '').split('\n').filter(Boolean)" :key="link" :href="link" target="_blank" rel="noreferrer">Ссылка</a><a v-if="item.video" :href="item.video" target="_blank" rel="noreferrer">Видео</a></div>
      </article>
      <div v-if="!articles.filter((article) => article.section_id === activeSection).length" class="panel empty">В этом разделе пока нет статей.</div>
    </div>
  </section>

  <ModalDialog :open="sectionOpen" title="Создать раздел" eyebrow="СТАТЬИ" @close="sectionOpen = false"><form class="section-form" @submit.prevent="createSection"><div class="field full"><label>Название раздела</label><input v-model="sectionName" required maxlength="120" autofocus></div><div class="actions"><button type="button" @click="sectionOpen = false">Отмена</button><button class="primary" type="submit">Создать</button></div></form></ModalDialog>
</template>

<style scoped lang="scss">
.theory-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 14px; margin-bottom: 18px; }
.theory-head h2 { margin: 0; }
.article-sections { display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 12px; margin-bottom: 20px; }
.article-section-card { display: flex; align-items: flex-start; justify-content: space-between; min-height: 92px; padding: 15px; border: 1px solid var(--line); border-radius: 13px; background: #fff; color: var(--ink); text-align: left; cursor: pointer; }
.article-section-card.active { border-color: var(--blue); box-shadow: 0 0 0 2px #0c66e426; }
.article-section-card b, .article-section-card small { display: block; }.article-section-card small { margin-top: 5px; color: var(--muted); }.article-section-card strong { padding: 4px 8px; border-radius: 99px; background: #e9f2ff; color: var(--blue); }
.add-section-card { border-style: dashed; }
.article-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 15px; }
.article-card { overflow: hidden; padding: 18px; border: 1px solid var(--line); border-radius: 14px; background: #fff; box-shadow: 0 4px 14px #091e4210; }.article-card img { width: calc(100% + 36px); height: 160px; margin: -18px -18px 16px; object-fit: cover; }.article-card h3 { margin: 4px 0 10px; font-size: 20px; }.article-body { white-space: pre-wrap; line-height: 1.65; }.article-links { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 15px; }.article-links a { color: var(--blue); font-weight: 750; }.section-form { display: grid; gap: 12px; }
@media (max-width: 600px) { .theory-head { align-items: flex-start; flex-direction: column; } }
</style>
