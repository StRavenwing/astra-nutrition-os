<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import { idLegend, recipeCategories, recipeCategoryMap } from '@/constants';
import type { RecipeSummary, SortState } from '@/types';
import { compareValues, fmt, searchable } from '@/utils/format';
import Toolbar from '@/components/shared/Toolbar.vue';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ refreshKey: number; isAdmin: boolean }>();
const emit = defineEmits<{ openRecipe: [id: number]; edit: [id: number] }>();

const data = ref<RecipeSummary[]>([]);
const loading = ref(false);
const error = ref('');
const category = ref('all');
const query = ref('');
const sort = ref<SortState>({ key: null, dir: 0 });
const orderValue = ref('');
const collection = ref<'common' | 'local'>('common');
const submissionRecipe = ref<RecipeSummary | null>(null);
const submitting = ref(false);
const moderationRecipe = ref<RecipeSummary | null>(null);
const moderationNote = ref('');
const notices = ref<RecipeSummary[]>([]);

async function load() {
  loading.value = true;
  error.value = '';
  try {
    data.value = await api.recipes();
    if (!props.isAdmin) {
      notices.value = data.value.filter((item) => {
        if (!item.is_submitter || !['accepted', 'rejected', 'revision'].includes(item.moderation_status)) return false;
        const key = `recipe-moderation-${item.id}-${item.moderation_status}`;
        if (sessionStorage.getItem(key)) return false;
        sessionStorage.setItem(key, 'seen');
        return true;
      });
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);

const collectionItems = computed(() => data.value.filter((item) => item.collection === collection.value));
const counts = computed(() => collectionItems.value.reduce<Record<string, number>>((acc, item) => {
  acc[item.category] = (acc[item.category] || 0) + 1;
  return acc;
}, {}));

const visibleCategories = computed(() => recipeCategories.filter((item) => counts.value[item.key]));
const commonCount = computed(() => data.value.filter((item) => item.collection === 'common').length);
const localCount = computed(() => data.value.filter((item) => item.collection === 'local').length);
const reviewRecipes = computed(() => data.value.filter((item) => props.isAdmin ? item.moderation_status === 'pending' : ['pending', 'revision'].includes(item.moderation_status)));

const shown = computed(() => {
  let items = collectionItems.value.filter((item) => (category.value === 'all' || item.category === category.value) && searchable(item, query.value));
  if (sort.value.dir && sort.value.key) {
    items = [...items].sort((a, b) => compareValues(a[sort.value.key!], b[sort.value.key!]) * sort.value.dir);
  }
  return items;
});

function setOrder(value: string) {
  orderValue.value = value;
  if (!value) sort.value = { key: null, dir: 0 };
  else {
    const [key, dir] = value.split(':');
    sort.value = { key, dir: Number(dir) as 1 | -1 };
  }
}

function resetSort() {
  sort.value = { key: null, dir: 0 };
  orderValue.value = '';
}

async function confirmSubmission() {
  if (!submissionRecipe.value) return;
  submitting.value = true;
  error.value = '';
  try {
    const updated = await api.requestRecipeSubmission(submissionRecipe.value.id);
    const index = data.value.findIndex((item) => item.id === updated.id);
    if (index >= 0) data.value[index] = updated;
    submissionRecipe.value = null;
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    submitting.value = false;
  }
}

function replaceRecipe(updated: RecipeSummary) {
  const index = data.value.findIndex((item) => item.id === updated.id);
  if (index >= 0) data.value[index] = updated;
  else data.value.push(updated);
}

async function cancelSubmission(item: RecipeSummary) {
  try {
    replaceRecipe(await api.cancelRecipeSubmission(item.id));
    notices.value = notices.value.filter((notice) => notice.id !== item.id);
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

async function moderate(item: RecipeSummary, action: 'accept' | 'reject' | 'revision', note?: string) {
  try {
    const updated = await api.moderateRecipe(item.id, action, note);
    data.value = data.value.filter((recipe) => recipe.id !== item.id);
    if (updated.collection === 'common') data.value.push(updated);
    moderationRecipe.value = null;
    moderationNote.value = '';
  } catch (err) { error.value = err instanceof Error ? err.message : String(err); }
}

function openNotice(item: RecipeSummary) {
  notices.value = notices.value.filter((notice) => notice.id !== item.id);
  emit('openRecipe', item.id);
}

async function removeRecipe(item: RecipeSummary) {
  if (!confirm('Удалить рецепт? Это действие нельзя отменить.')) return;
  try {
    await api.delete(`recipes/${item.id}`);
    data.value = data.value.filter((recipe) => recipe.id !== item.id);
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else>
    <section v-if="notices.length" class="moderation-notices">
      <div v-for="item in notices" :key="`${item.id}-${item.moderation_status}`" :class="`notice-${item.moderation_status}`">
        <b v-if="item.moderation_status === 'accepted'">Ура! Твой рецепт добавлен в общую коллекцию!</b>
        <b v-else-if="item.moderation_status === 'rejected'">Увы! Рецепт не прошел модерацию</b>
        <b v-else>Ваш рецепт нуждается в доработке</b>
        <button type="button" @click="openNotice(item)">Перейти в рецепт</button>
      </div>
    </section>

    <section v-if="reviewRecipes.length" class="recipes-review">
      <h2>Рецепты на рассмотрении</h2>
      <div class="review-grid">
        <article v-for="item in reviewRecipes" :key="item.id" class="review-card" @click="emit('openRecipe', item.id)">
          <span class="recipe-id">{{ item.code }}</span><h3>{{ item.name }}</h3>
          <p v-if="item.moderation_note">{{ item.moderation_note }}</p>
          <div v-if="isAdmin" class="review-actions" @click.stop>
            <button class="primary" @click="moderate(item, 'accept')">Принять</button>
            <button @click="moderate(item, 'reject')">Отклонить</button>
            <button @click="moderationRecipe = item">Отправить на доработку</button>
          </div>
          <button v-else class="cancel-submission" @click.stop="cancelSubmission(item)">Отменить отправку</button>
        </article>
      </div>
    </section>

    <section v-if="!isAdmin" class="recipe-collections" aria-label="Коллекции рецептов">
      <button type="button" :class="{ active: collection === 'common' }" @click="collection = 'common'; category = 'all'">
        <span class="collection-icon">◉</span>
        <span><b>Общая коллекция</b><small>Рецепты, доступные всем пользователям</small></span>
        <strong>{{ commonCount }}</strong>
      </button>
      <button type="button" :class="{ active: collection === 'local' }" @click="collection = 'local'; category = 'all'">
        <span class="collection-icon">⌂</span>
        <span><b>Локальная коллекция</b><small>Ваши личные рецепты</small></span>
        <strong>{{ localCount }}</strong>
      </button>
    </section>

    <section class="recipe-categories visual" aria-label="Типы рецептов">
      <button type="button" class="category-card all" :class="{ active: category === 'all' }" @click="category = 'all'">
        <span class="category-photo all-photo"></span>
        <span class="category-copy"><b>Все рецепты</b><small>Полный каталог</small></span>
        <strong>{{ collectionItems.length }}</strong>
      </button>
      <button
        v-for="item in visibleCategories"
        :key="item.key"
        type="button"
        class="category-card"
        :class="[`category-${item.key.toLowerCase()}`, { active: category === item.key }]"
        :style="{ '--icon-x': `${item.x}%`, '--icon-y': `${item.y}%` }"
        @click="category = item.key"
      >
        <span class="category-photo recipe-sprite"></span>
        <span class="category-copy"><b>{{ item.label }}</b><small>{{ item.key }}</small></span>
        <strong>{{ counts[item.key] }}</strong>
      </button>
    </section>

    <details class="legend">
      <summary>Что означают ID рецептов?</summary>
      <div>
        <span v-for="(value, key) in idLegend" :key="key"><b>{{ key }}-</b> {{ value }}</span>
      </div>
      <p>Цифры после дефиса — последовательный номер рецепта в категории.</p>
    </details>

    <Toolbar v-model:query="query" :count-label="`Записей: ${shown.length}`" :reset-disabled="!sort.dir" @reset="resetSort">
      <select id="recipe-order" :value="orderValue" aria-label="Сортировка рецептов" @change="setOrder(($event.target as HTMLSelectElement).value)">
        <option value="">Исходный порядок</option>
        <option value="name:1">Название: А–Я</option>
        <option value="name:-1">Название: Я–А</option>
        <option value="category:1">Категория: А–Я</option>
        <option value="status:1">Статус: А–Я</option>
        <option value="version:1">Версия: по возрастанию</option>
        <option value="version:-1">Версия: по убыванию</option>
        <option value="kcal_per_serving:1">Калории: меньше</option>
        <option value="kcal_per_serving:-1">Калории: больше</option>
        <option value="protein_per_serving_g:-1">Белок: больше</option>
        <option value="protein_per_serving_g:1">Белок: меньше</option>
        <option value="cost_per_serving_rsd:1">Цена: меньше</option>
        <option value="cost_per_serving_rsd:-1">Цена: больше</option>
      </select>
    </Toolbar>

    <div id="recipe-grid" class="recipe-grid">
      <article v-for="item in shown" :key="item.id" class="recipe-tile" tabindex="0" title="Открыть рецепт" @click="emit('openRecipe', item.id)" @keydown.enter.prevent="emit('openRecipe', item.id)" @keydown.space.prevent="emit('openRecipe', item.id)">
        <div class="recipe-tile-head">
          <span class="recipe-id">{{ item.code }}</span>
          <span class="pill">{{ item.status }}</span>
        </div>
        <div class="recipe-category">{{ recipeCategoryMap[item.category]?.label || item.category }}</div>
        <h3>{{ item.name }}</h3>
        <p>{{ item.subcategory || item.tags || 'Рецепт из личной коллекции' }}</p>
        <div class="tile-macros">
          <span><b>{{ fmt(item.kcal_per_serving) }}</b><small>ккал</small></span>
          <span><b>{{ fmt(item.protein_per_serving_g) }}</b><small>белки</small></span>
          <span><b>{{ fmt(item.fat_per_serving_g) }}</b><small>жиры</small></span>
          <span><b>{{ fmt(item.carbs_per_serving_g) }}</b><small>углев.</small></span>
        </div>
        <div class="recipe-tile-foot">
          <span>v{{ item.version }}</span>
          <b>{{ fmt(item.cost_per_serving_rsd) }} RSD <small v-if="item.manual_price_per_serving_rsd != null">фикс.</small></b>
        </div>
        <button
          v-if="item.collection === 'local'"
          type="button"
          class="submit-to-common"
          @click.stop="item.submission_requested ? cancelSubmission(item) : submissionRecipe = item"
        >{{ item.submission_requested ? 'Отменить отправку' : 'Добавить в общую коллекцию' }}</button>
        <div v-if="isAdmin || item.collection === 'local'" class="recipe-tile-actions" @click.stop>
          <button type="button" class="edit-recipe" @click="emit('edit', item.id)">✎ Редактировать</button>
          <button type="button" class="delete-recipe" @click="removeRecipe(item)">Удалить</button>
        </div>
      </article>
      <div v-if="!shown.length" class="panel empty">Ничего не найдено</div>
    </div>
  </template>

  <ModalDialog :open="Boolean(submissionRecipe)" title="Добавить в общую коллекцию" eyebrow="ПОДТВЕРЖДЕНИЕ" @close="submissionRecipe = null">
    <p class="confirm-message">Ваш запрос на добавление рецепта будет отправлен на рассмотрение</p>
    <div class="actions">
      <button type="button" :disabled="submitting" @click="submissionRecipe = null">Отменить</button>
      <button type="button" class="primary" :disabled="submitting" @click="confirmSubmission">Ок</button>
    </div>
  </ModalDialog>
  <ModalDialog :open="Boolean(moderationRecipe)" title="Отправить на доработку" eyebrow="МОДЕРАЦИЯ" @close="moderationRecipe = null">
    <div class="field full"><label>Примечание для пользователя</label><textarea v-model="moderationNote" rows="5" required></textarea></div>
    <div class="actions"><button @click="moderationRecipe = null">Отменить</button><button class="primary" :disabled="!moderationNote.trim()" @click="moderationRecipe && moderate(moderationRecipe, 'revision', moderationNote)">Отправить</button></div>
  </ModalDialog>
</template>

<style lang="scss">
.recipe-grid {
  margin-top: 0;
}

.recipes-review { margin-bottom: 20px; padding: 18px; border: 1px solid #fca700; border-radius: 14px; background: #fff7d6; }
.recipes-review h2 { margin: 0 0 13px; font-size: 20px; }
.review-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 11px; }
.review-card { padding: 15px; border: 1px solid #f0b429; border-radius: 12px; background: #fff; cursor: pointer; box-shadow: 0 5px 16px #7f5f0118; }
.review-card h3 { margin: 8px 0; }
.review-card p { color: var(--muted); }
.review-actions { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 12px; }
.review-actions button, .cancel-submission { padding: 8px 10px; border: 1px solid var(--line); border-radius: 7px; cursor: pointer; font-weight: 750; }
.cancel-submission { margin-top: 8px; color: #ae2a19; background: #ffebe6; }
.moderation-notices { display: grid; gap: 9px; margin-bottom: 16px; }
.moderation-notices > div { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 14px 16px; border-radius: 11px; background: #e7f6ee; color: #216e4e; }
.moderation-notices .notice-rejected { background: #ffebe6; color: #ae2a19; }
.moderation-notices .notice-revision { background: #fff7d6; color: #7f5f01; }
.moderation-notices button { border: 0; border-radius: 7px; padding: 8px 11px; background: #fff; color: inherit; cursor: pointer; font-weight: 800; }

.recipe-collections {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-bottom: 18px;

  button {
    display: grid;
    grid-template-columns: 48px 1fr auto;
    gap: 12px;
    align-items: center;
    min-height: 92px;
    padding: 16px;
    border: 1px solid var(--line);
    border-radius: 14px;
    background: linear-gradient(145deg, #fff, #f4f7ff);
    color: var(--ink);
    text-align: left;
    cursor: pointer;

    &.active { border-color: var(--blue); box-shadow: 0 0 0 2px #0c66e426; }
    b, small { display: block; }
    small { margin-top: 4px; color: var(--muted); }
    strong { padding: 4px 9px; border-radius: 99px; background: #e9f2ff; color: var(--blue); }
  }
}

.collection-icon {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 13px;
  background: #e9f2ff;
  color: var(--blue);
  font-size: 22px;
}

.submit-to-common {
  width: 100%;
  margin-top: 12px;
  padding: 9px 12px;
  border: 1px solid var(--blue);
  border-radius: 8px;
  background: #e9f2ff;
  color: var(--blue);
  font-weight: 800;
  cursor: pointer;

  &:disabled { border-color: var(--line); color: var(--muted); cursor: default; }
}

@media (max-width: 700px) {
  .recipe-collections { grid-template-columns: 1fr; }
}
</style>
