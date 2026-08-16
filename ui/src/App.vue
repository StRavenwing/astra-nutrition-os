<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { api, clearAccessToken, getAccessToken, setUnauthorizedHandler } from '@/api/client';
import { pages } from '@/constants';
import type { Article, AuthUser, Exercise, ModalState, PageId, WorkoutComplex, WorkoutPlan } from '@/types';
import AuthView from '@/components/AuthView.vue';
import AppShell from '@/components/layout/AppShell.vue';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import DashboardView from '@/views/DashboardView.vue';
import ProductsView from '@/views/ProductsView.vue';
import RecipesView from '@/views/RecipesView.vue';
import DiaryView from '@/views/DiaryView.vue';
import ProgressView from '@/views/ProgressView.vue';
import WorkoutsView from '@/views/WorkoutsView.vue';
import TheoryView from '@/views/TheoryView.vue';
import ProductForm from '@/components/forms/ProductForm.vue';
import RecipeForm from '@/components/forms/RecipeForm.vue';
import DiaryEntryForm from '@/components/forms/DiaryEntryForm.vue';
import ProgressForm from '@/components/forms/ProgressForm.vue';
import WorkoutForm from '@/components/forms/WorkoutForm.vue';
import ExerciseForm from '@/components/forms/ExerciseForm.vue';
import EquipmentForm from '@/components/forms/EquipmentForm.vue';
import CategoryForm from '@/components/forms/CategoryForm.vue';
import ArticleForm from '@/components/forms/ArticleForm.vue';
import RecipeDetailModal from '@/components/modals/RecipeDetailModal.vue';
import ExerciseManagerModal from '@/components/modals/ExerciseManagerModal.vue';
import WorkoutBuilderModal from '@/components/modals/WorkoutBuilderModal.vue';
import WorkoutComplexModal from '@/components/modals/WorkoutComplexModal.vue';
import WorkoutDetailModal from '@/components/modals/WorkoutDetailModal.vue';
import ExerciseDetailModal from '@/components/modals/ExerciseDetailModal.vue';
import FeedbackModal from '@/components/modals/FeedbackModal.vue';
import PwaUpdateToast from '@/components/shared/PwaUpdateToast.vue';

const pageIds = new Set(pages.map((page) => page.id));
const hashPage = () => {
  const value = window.location.hash.slice(1) as PageId;
  return pageIds.has(value) ? value : 'dashboard';
};

const currentPage = ref<PageId>(hashPage());
const authLoading = ref(true);
const currentUser = ref<AuthUser | null>(null);
const reloadKey = ref(0);
const modal = ref<ModalState | null>(null);
const recipeDetailId = ref<number | null>(null);
const exerciseManagerOpen = ref(false);
const workoutBuilderOpen = ref(false);
const repeatPlan = ref<WorkoutPlan | null>(null);
const editPlan = ref<WorkoutPlan | null>(null);
const workoutDetailPlan = ref<WorkoutPlan | null>(null);
const exerciseDetail = ref<Exercise | null>(null);
const equipmentKind = ref<'machine' | 'equipment'>('machine');
const feedbackOpen = ref(false);
const feedbackUnread = ref(0);
let feedbackTimer: ReturnType<typeof setInterval> | null = null;
const complexEditorOpen = ref(false);
const complexEditor = ref<WorkoutComplex | null>(null);
const complexEditorMode = ref<'create' | 'edit'>('create');
const categoryOpen = ref(false);
const categoryKind = ref<'product' | 'recipe'>('product');
const articleOpen = ref(false);
const articleEditor = ref<Article | null>(null);
const articleFormKey = ref(0);

const title = computed(() => pages.find((page) => page.id === currentPage.value)?.title || 'Обзор');
const isAdmin = computed(() => Boolean(currentUser.value?.is_admin));
const activeUser = computed(() => currentUser.value as AuthUser);
const canAdd = computed(() => {
  if (currentPage.value === 'dashboard' || currentPage.value === 'theory') return false;
  if (currentPage.value === 'workouts') return false;
  if (currentPage.value === 'products') return isAdmin.value;
  return true;
});
const articleModalTitle = computed(() => articleEditor.value ? 'Редактировать статью' : 'Добавить статью');
const addLabel = computed(() => currentPage.value === 'workouts' ? 'Собрать тренировку' : 'Добавить');
const modalTitle = computed(() => {
  if (!modal.value) return '';
  const editing = modal.value.id != null;
  const labels: Record<string, string> = {
    products: editing ? 'Редактировать продукт' : 'Добавить продукт',
    recipes: editing ? 'Редактировать рецепт' : 'Добавить рецепт',
    diary: editing ? 'Редактировать запись дневника' : 'Добавить в дневник',
    progress: editing ? 'Редактировать показатели' : 'Добавить показатели',
    workouts: editing ? 'Редактировать тренировку' : 'Добавить тренировку',
    exercises: 'Добавить упражнение',
    equipment: editing ? 'Редактировать оборудование' : 'Добавить оборудование'
  };
  return labels[modal.value.kind];
});

function navigate(page: PageId) {
  currentPage.value = page;
  if (window.location.hash !== `#${page}`) {
    history.replaceState(null, '', `${window.location.pathname}${window.location.search}#${page}`);
  }
}

function onHashChange() {
  currentPage.value = hashPage();
}

function openAdd() {
  if (!canAdd.value || currentPage.value === 'dashboard') return;
  if (currentPage.value === 'workouts') {
    repeatPlan.value = null;
    editPlan.value = null;
    workoutBuilderOpen.value = true;
    return;
  }
  modal.value = { kind: currentPage.value as ModalState['kind'] };
}

function openFeedback() {
  feedbackOpen.value = true;
}

function openCategory(kind: 'product' | 'recipe') {
  categoryKind.value = kind;
  categoryOpen.value = true;
}

function openArticleEditor(article: Article | null = null) {
  if (!isAdmin.value) return;
  articleFormKey.value += 1;
  articleEditor.value = article;
  articleOpen.value = true;
}

function closeArticleEditor() {
  articleOpen.value = false;
  articleEditor.value = null;
}

function closeModal() {
  modal.value = null;
}

function refresh() {
  reloadKey.value += 1;
  void loadFeedbackUnread();
}

async function loadFeedbackUnread() {
  if (!isAdmin.value) {
    feedbackUnread.value = 0;
    return;
  }
  try {
    feedbackUnread.value = (await api.feedbackUnreadCount()).count;
  } catch {
    feedbackUnread.value = 0;
  }
}

function startFeedbackPolling() {
  if (feedbackTimer) clearInterval(feedbackTimer);
  feedbackTimer = setInterval(() => { void loadFeedbackUnread(); }, 30_000);
}

function saved(recipeId?: number) {
  const wasRecipe = modal.value?.kind === 'recipes';
  closeModal();
  refresh();
  if (wasRecipe && recipeId) recipeDetailId.value = recipeId;
}

function openRecipe(id: number) {
  recipeDetailId.value = id;
}

function editRecipe(id: number) {
  recipeDetailId.value = null;
  modal.value = { kind: 'recipes', id };
}

function openExerciseAdd() {
  if (!isAdmin.value) return;
  exerciseManagerOpen.value = false;
  workoutBuilderOpen.value = false;
  repeatPlan.value = null;
  editPlan.value = null;
  modal.value = { kind: 'exercises' };
}

function editExercise(id: number) {
  if (!isAdmin.value) return;
  exerciseManagerOpen.value = false;
  modal.value = { kind: 'exercises', id };
}

function openEquipmentAdd(kind: 'machine' | 'equipment') {
  if (!isAdmin.value) return;
  equipmentKind.value = kind;
  modal.value = { kind: 'equipment' };
}

function editEquipment(id: number) {
  if (!isAdmin.value) return;
  modal.value = { kind: 'equipment', id };
}

function openWorkoutDetail(plan: WorkoutPlan) {
  workoutDetailPlan.value = plan;
}

function openExerciseDetail(exercise: Exercise) {
  exerciseDetail.value = exercise;
}

function editWorkoutFromDetail(plan: WorkoutPlan) {
  workoutDetailPlan.value = null;
  exerciseDetail.value = null;
  editPlan.value = plan;
  repeatPlan.value = null;
  workoutBuilderOpen.value = true;
}

function buildWorkoutFromComplex(payload: { complex: WorkoutComplex | null; mode: 'create' | 'edit' }) {
  if (!isAdmin.value) return;
  workoutDetailPlan.value = null;
  exerciseDetail.value = null;
  repeatPlan.value = null;
  editPlan.value = null;
  complexEditor.value = payload.complex;
  complexEditorMode.value = payload.mode;
  complexEditorOpen.value = true;
}

async function completeWorkoutFromDetail(plan: WorkoutPlan) {
  try {
    await api.completeWorkoutPlan(plan.id);
    workoutDetailPlan.value = null;
    refresh();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

async function cancelWorkoutFromDetail(plan: WorkoutPlan) {
  if (!confirm('Отменить запланированную тренировку? Она попадёт в архив.')) return;
  try {
    await api.cancelWorkoutPlan(plan.id);
    workoutDetailPlan.value = null;
    refresh();
  } catch (err) {
    alert(err instanceof Error ? err.message : String(err));
  }
}

function authenticated(user: AuthUser) {
  currentUser.value = user;
  refresh();
  startFeedbackPolling();
}

function clearSession() {
  clearAccessToken();
  currentUser.value = null;
  modal.value = null;
  recipeDetailId.value = null;
  exerciseManagerOpen.value = false;
  workoutBuilderOpen.value = false;
  workoutDetailPlan.value = null;
  exerciseDetail.value = null;
  feedbackOpen.value = false;
  feedbackUnread.value = 0;
  if (feedbackTimer) clearInterval(feedbackTimer);
  feedbackTimer = null;
  complexEditorOpen.value = false;
  complexEditor.value = null;
  repeatPlan.value = null;
  editPlan.value = null;
}

async function logout() {
  try {
    await api.logout();
  } catch {
    // JWT logout is client-side; expired sessions are cleared locally as well.
  } finally {
    clearSession();
  }
}

onMounted(async () => {
  setUnauthorizedHandler(clearSession);
  navigate(currentPage.value);
  window.addEventListener('hashchange', onHashChange);
  if (!getAccessToken()) {
    authLoading.value = false;
    return;
  }
  try {
    currentUser.value = await api.me();
    await loadFeedbackUnread();
    startFeedbackPolling();
  } catch {
    clearSession();
  } finally {
    authLoading.value = false;
  }
});

onBeforeUnmount(() => {
  setUnauthorizedHandler(null);
  window.removeEventListener('hashchange', onHashChange);
  if (feedbackTimer) clearInterval(feedbackTimer);
});
</script>

<template>
  <div v-if="authLoading" class="auth-page">
    <div class="panel auth-loading">Загрузка…</div>
  </div>
  <AuthView v-else-if="!currentUser" @authenticated="authenticated" />
  <AppShell
    v-else
    :current-page="currentPage"
    :title="title"
    :can-add="canAdd"
    :add-label="addLabel"
    :user="activeUser"
    :feedback-unread="feedbackUnread"
    @navigate="navigate"
    @add="openAdd"
    @logout="logout"
    @feedback="openFeedback"
  >
    <DashboardView v-if="currentPage === 'dashboard'" :refresh-key="reloadKey" :is-admin="isAdmin" @navigate="navigate" @open-recipe="openRecipe" />
    <ProductsView v-else-if="currentPage === 'products'" :refresh-key="reloadKey" :is-admin="isAdmin" @edit="modal = { kind: 'products', id: $event }" @add-category="openCategory('product')" />
    <RecipesView v-else-if="currentPage === 'recipes'" :refresh-key="reloadKey" :is-admin="isAdmin" @open-recipe="openRecipe" @edit="editRecipe" @add-category="openCategory('recipe')" />
    <DiaryView v-else-if="currentPage === 'diary'" :refresh-key="reloadKey" @edit="modal = { kind: 'diary', id: $event }" />
    <ProgressView v-else-if="currentPage === 'progress'" :refresh-key="reloadKey" @edit="modal = { kind: 'progress', id: $event }" />
    <WorkoutsView
      v-else-if="currentPage === 'workouts'"
      :refresh-key="reloadKey"
      :is-admin="isAdmin"
      @edit="modal = { kind: 'workouts', id: $event }"
      @add-exercise="openExerciseAdd"
      @edit-exercise="editExercise"
      @add-equipment="openEquipmentAdd"
      @edit-equipment="editEquipment"
      @open-plan="openWorkoutDetail"
      @open-exercise="openExerciseDetail"
      @build-complex="buildWorkoutFromComplex"
      @manage-exercises="exerciseManagerOpen = true"
      @build="repeatPlan = null; editPlan = null; workoutBuilderOpen = true"
      @edit-plan="editPlan = $event; repeatPlan = null; workoutBuilderOpen = true"
      @repeat="repeatPlan = $event; editPlan = null; workoutBuilderOpen = true"
    />
    <TheoryView v-else-if="currentPage === 'theory'" :is-admin="isAdmin" :refresh-key="reloadKey" @add-article="openArticleEditor()" @edit-article="openArticleEditor" />
  </AppShell>

  <RecipeDetailModal :recipe-id="recipeDetailId" :is-admin="isAdmin" @close="recipeDetailId = null" @edit="editRecipe" @deleted="recipeDetailId = null; refresh()" @changed="refresh" />
  <ExerciseManagerModal v-if="isAdmin" :open="exerciseManagerOpen" @close="exerciseManagerOpen = false" @add="openExerciseAdd" @edit="editExercise" @changed="refresh" />
  <WorkoutBuilderModal :open="workoutBuilderOpen" :repeat-plan="repeatPlan" :edit-plan="editPlan" @close="workoutBuilderOpen = false; repeatPlan = null; editPlan = null" @saved="workoutBuilderOpen = false; repeatPlan = null; editPlan = null; refresh()" />
  <WorkoutComplexModal :open="complexEditorOpen" :complex="complexEditor" :mode="complexEditorMode" @close="complexEditorOpen = false" @saved="complexEditorOpen = false; complexEditor = null; refresh()" @open-exercise="openExerciseDetail" />
  <WorkoutDetailModal :plan="workoutDetailPlan" @close="workoutDetailPlan = null" @edit="editWorkoutFromDetail" @repeat="repeatPlan = $event; editPlan = null; workoutDetailPlan = null; workoutBuilderOpen = true" @complete="completeWorkoutFromDetail" @cancel="cancelWorkoutFromDetail" />
  <ExerciseDetailModal :exercise="exerciseDetail" @close="exerciseDetail = null" />
  <FeedbackModal :open="feedbackOpen" :is-admin="isAdmin" @close="feedbackOpen = false" @sent="feedbackOpen = false" @read="loadFeedbackUnread" />

  <ModalDialog :open="categoryOpen" :title="categoryKind === 'product' ? 'Добавить категорию продуктов' : 'Добавить категорию рецептов'" eyebrow="КАТЕГОРИЯ" @close="categoryOpen = false">
    <CategoryForm :kind="categoryKind" :is-admin="isAdmin" @saved="categoryOpen = false; refresh()" @cancel="categoryOpen = false" />
  </ModalDialog>
  <ModalDialog :open="articleOpen" :title="articleModalTitle" eyebrow="ИНФОРМАЦИЯ" wide @close="closeArticleEditor">
    <ArticleForm :key="articleFormKey" :article="articleEditor" @saved="closeArticleEditor(); refresh()" @deleted="closeArticleEditor(); refresh()" @cancel="closeArticleEditor" />
  </ModalDialog>

  <ModalDialog :open="Boolean(modal)" :title="modalTitle" @close="closeModal">
    <ProductForm v-if="modal?.kind === 'products'" :product-id="modal.id" @saved="saved" @deleted="saved" @cancel="closeModal" />
    <RecipeForm v-else-if="modal?.kind === 'recipes'" :recipe-id="modal.id" @saved="saved" @cancel="closeModal" />
    <DiaryEntryForm v-else-if="modal?.kind === 'diary'" :diary-id="modal.id as number | undefined" @saved="saved" @deleted="saved" @cancel="closeModal" />
    <ProgressForm v-else-if="modal?.kind === 'progress'" :progress-id="modal.id as number | undefined" @saved="saved" @cancel="closeModal" />
    <WorkoutForm v-else-if="modal?.kind === 'workouts'" :workout-log-id="modal.id as number | undefined" @saved="saved" @deleted="saved" @cancel="closeModal" />
    <ExerciseForm v-else-if="modal?.kind === 'exercises'" :exercise-id="modal.id" @saved="saved" @cancel="closeModal" />
    <EquipmentForm v-else-if="modal?.kind === 'equipment'" :key="`${equipmentKind}-${modal.id || 'new'}`" :equipment-id="modal.id" :kind="equipmentKind" @saved="saved" @cancel="closeModal" />
  </ModalDialog>
  <PwaUpdateToast />
</template>

<style lang="scss">
:root {
  --ink: #172b4d;
  --blue: #0c66e4;
  --bg: #f7f8fa;
  --line: #dfe1e6;
  --muted: #626f86;
  --green: #22a06b;
  --purple: #6e5dc6;
  --orange: #fca700;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font: 14px/1.45 Inter, Segoe UI, Arial, sans-serif;
  background: var(--bg);
  color: var(--ink);
}

button,
input,
select,
textarea {
  font: inherit;
}

aside {
  position: fixed;
  inset: 0 auto 0 0;
  width: 238px;
  background: #fff;
  border-right: 1px solid var(--line);
  padding: 24px 16px;
  display: flex;
  flex-direction: column;
}

.brand {
  display: flex;
  gap: 11px;
  align-items: center;
  font-size: 18px;
  font-weight: 750;
  padding: 0 8px 25px;

  > span {
    display: grid;
    place-items: center;
    width: 36px;
    height: 36px;
    border-radius: 12px;
    color: #fff;
    background: linear-gradient(135deg, var(--blue), var(--purple));
  }

  small {
    display: block;
    color: var(--muted);
    font-size: 11px;
    font-weight: 500;
  }
}

nav {
  display: grid;
  gap: 4px;

  button {
    border: 0;
    background: none;
    text-align: left;
    padding: 11px 12px;
    border-radius: 8px;
    color: #44546f;
    font-weight: 600;
    cursor: pointer;

    &:hover,
    &.active {
      background: #e9f2ff;
      color: var(--blue);
    }
  }
}

.aside-note {
  margin-top: auto;
  background: #f1f2f4;
  padding: 13px;
  border-radius: 10px;
  color: var(--muted);
  font-size: 12px;
}

main {
  margin-left: 238px;
  padding: 31px 38px;
  max-width: 1600px;
}

header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  margin-bottom: 27px;
}

h1,
h2 {
  margin: 0;
}

h1 {
  font-size: 31px;
}

.eyebrow {
  margin: 0 0 5px;
  color: var(--muted);
  font-weight: 750;
  font-size: 10px;
  letter-spacing: .13em;
}

.primary {
  border: 0;
  background: var(--blue);
  color: #fff;
  border-radius: 8px;
  padding: 11px 16px;
  font-weight: 700;
  cursor: pointer;
}

.kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
}

.card,
.panel {
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 12px;
  box-shadow: 0 1px 2px #091e4220;
}

.card {
  padding: 18px;

  .label {
    color: var(--muted);
    font-weight: 650;
  }

  strong {
    display: block;
    font-size: 30px;
    margin-top: 8px;
  }
}

.panel {
  margin-top: 18px;
  padding: 20px;

  h3 {
    margin: 0 0 15px;
    font-size: 16px;
  }
}

.toolbar {
  display: flex;
  gap: 10px;
  margin: 14px 0;
  flex-wrap: wrap;

  input {
    min-width: 260px;
  }
}

.toolbar input,
.toolbar select,
input,
select,
textarea {
  border: 1px solid #b7beca;
  border-radius: 7px;
  padding: 9px 10px;
  background: #fff;
  color: var(--ink);
}

input[readonly] {
  background: #f1f2f4;
  color: #44546f;
  border-style: dashed;
  font-weight: 700;
  cursor: not-allowed;
}

.reset-sort {
  margin-left: auto;
  border: 1px solid var(--line);
  background: #fff;
  border-radius: 7px;
  padding: 8px 11px;
  color: #44546f;
  cursor: pointer;

  &:disabled {
    opacity: .45;
    cursor: default;
  }
}

.subtle {
  color: var(--muted);
  font-size: 12px;
}

.empty {
  padding: 50px;
  text-align: center;
  color: var(--muted);
}

.pill {
  display: inline-block;
  padding: 3px 8px;
  border-radius: 999px;
  background: #e3fcef;
  color: #216e4e;
  font-size: 11px;
  font-weight: 700;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: #fff;
}

th {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--muted);
  text-align: left;
  padding: 10px;
  border-bottom: 2px solid var(--line);
}

td {
  padding: 11px 10px;
  border-bottom: 1px solid #ebecf0;
}

tbody tr:hover {
  background: #fafbfc;
}

.number {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

dialog {
  border: 0;
  border-radius: 14px;
  padding: 0;
  width: min(680px, 92vw);
  box-shadow: 0 20px 60px #091e4260;

  &::backdrop {
    background: #091e4270;
  }

  &.recipe-dialog {
    width: min(980px, 94vw);
  }
}

.modal-head {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 20px;
}

.icon {
  border: 0;
  background: #f1f2f4;
  border-radius: 8px;
  width: 34px;
  height: 34px;
  font-size: 22px;
  cursor: pointer;
}

.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 13px;
}

.field {
  display: grid;
  gap: 5px;

  &.full {
    grid-column: 1 / -1;
  }

  label {
    font-size: 12px;
    font-weight: 700;
    color: #44546f;
  }
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 9px;
  margin-top: 22px;

  button {
    border: 1px solid var(--line);
    border-radius: 8px;
    padding: 10px 15px;
    font-weight: 700;
    cursor: pointer;
  }

  .primary {
    border: 0;
  }
}

#form-error {
  min-height: 18px;
  color: #ae2a19;
}

.bars {
  display: grid;
  gap: 10px;
}

.bar {
  display: grid;
  grid-template-columns: 220px 1fr 70px;
  gap: 12px;
  align-items: center;
}

.track {
  height: 9px;
  background: #e9ebef;
  border-radius: 99px;
  overflow: hidden;

  i {
    display: block;
    height: 100%;
    background: linear-gradient(90deg, var(--blue), var(--purple));
    border-radius: 99px;
  }
}

.protein-recipe-link {
  grid-template-columns: 220px 1fr 70px 22px;
  width: 100%;
  padding: 8px 10px;
  border: 1px solid transparent;
  border-radius: 9px;
  background: transparent;
  color: var(--ink);
  text-align: left;
  cursor: pointer;
  transition: background .16s ease, border-color .16s ease, transform .16s ease;

  > span:first-child {
    font-size: 14px;
    font-weight: 750;
  }

  &:hover {
    border-color: #85b8ff;
    background: #f4f8ff;
    transform: translateX(2px);
  }

  em {
    color: var(--blue);
    font-size: 17px;
    font-style: normal;
    font-weight: 800;
  }
}

.legend {
  margin: 0 0 14px;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 12px 15px;

  summary {
    font-weight: 750;
    cursor: pointer;
    color: var(--blue);
  }

  div {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 12px;
  }

  span {
    background: #f1f2f4;
    border-radius: 7px;
    padding: 6px 9px;
    font-size: 12px;
  }

  p {
    margin: 10px 0 0;
    color: var(--muted);
    font-size: 12px;
  }
}

.recipe-categories,
.product-categories {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(175px, 1fr));
  gap: 13px;
  margin-bottom: 18px;
}

.category-card,
.product-category-card {
  position: relative;
  display: block;
  min-height: 174px;
  padding: 0;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: #fff;
  color: var(--ink);
  text-align: left;
  box-shadow: 0 2px 5px #091e4214;
  cursor: pointer;
  overflow: hidden;
  transition: transform .18s ease, border-color .18s ease, box-shadow .18s ease;

  &:hover {
    transform: translateY(-2px);
    border-color: #85b8ff;
    box-shadow: 0 9px 24px #091e421f;
  }

  &.active {
    border-color: var(--blue);
    box-shadow: 0 0 0 2px #0c66e426, 0 9px 24px #091e4218;
  }

  > strong {
    position: absolute;
    z-index: 2;
    right: 10px;
    top: 10px;
    padding: 3px 8px;
    border-radius: 99px;
    background: #fffffff0;
    color: var(--blue);
    font-size: 12px;
    box-shadow: 0 1px 3px #091e4220;
  }
}

.product-category-card {
  &:hover {
    border-color: #7bc8a4;
  }

  &.active {
    border-color: var(--green);
    box-shadow: 0 0 0 2px #22a06b26, 0 9px 24px #091e4218;
  }

  > strong {
    color: #216e4e;
  }
}

.category-photo,
.product-category-photo {
  display: block;
  height: 112px;
  background-size: cover;
  background-position: center;
}

.recipe-sprite {
  background-color: #f7f5ff;
  background-image: url('/assets/recipe-category-icons.png');
  background-repeat: no-repeat;
  background-size: 300% 300%;
  background-position: var(--icon-x) var(--icon-y);
}

.product-sprite {
  background-color: #f3faf7;
  background-image: url('/assets/product-category-icons.png');
  background-repeat: no-repeat;
  background-size: 500% 400%;
  background-position: var(--icon-x) var(--icon-y);
}

.all-photo,
.all-products-photo {
  position: relative;
  height: 112px;
}

.all-photo {
  background-image: linear-gradient(135deg, #0c66e4, #6e5dc6 58%, #22a06b);
}

.all-products-photo {
  background-image: linear-gradient(135deg, #22a06b, #0c66e4 58%, #6e5dc6);
}

.all-photo::after,
.all-products-photo::after {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 24px;
  letter-spacing: 9px;
  text-shadow: 0 2px 10px #091e4266;
}

.all-photo::after {
  content: '✦  ◇  ◉';
}

.all-products-photo::after {
  content: '●  ◇  ✦';
}

.category-copy,
.product-category-copy {
  display: block;
  padding: 11px 13px;

  b,
  small {
    display: block;
  }

  b {
    font-size: 14px;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: .08em;
  }
}

.recipe-grid,
.product-grid,
.workout-grid,
.progress-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(255px, 1fr));
  gap: 15px;
  scroll-margin-top: 18px;
}

.recipe-tile,
.product-tile,
.workout-tile,
.progress-tile,
.current-progress-card {
  position: relative;
  display: flex;
  flex-direction: column;
  min-height: 255px;
  padding: 18px;
  border: 1px solid var(--line);
  border-radius: 15px;
  background: #fff;
  box-shadow: 0 2px 5px #091e4214;
  overflow: hidden;
  transition: transform .18s ease, border-color .18s ease, box-shadow .18s ease;

  &::before {
    content: '';
    position: absolute;
    inset: 0 0 auto;
    height: 4px;
    background: linear-gradient(90deg, var(--blue), var(--purple), var(--green));
  }

  &:hover {
    transform: translateY(-3px);
    border-color: #85b8ff;
    box-shadow: 0 12px 30px #091e421f;
  }

  h3 {
    margin: 6px 0 5px;
    font-size: 19px;
    line-height: 1.2;
  }

  > p {
    min-height: 35px;
    margin: 0;
    color: var(--muted);
    font-size: 12px;
  }
}

.recipe-tile {
  cursor: pointer;
}

.product-tile::before {
  background: linear-gradient(90deg, #22a06b, #0c66e4);
}

.workout-tile::before {
  background: linear-gradient(90deg, #6e5dc6, #0c66e4, #22a06b);
}

.recipe-tile-head,
.recipe-tile-foot,
.product-tile-head,
.product-tile-foot,
.workout-tile-head,
.progress-tile-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.recipe-id {
  color: var(--muted);
  font: 750 11px/1.2 ui-monospace, SFMono-Regular, Consolas, monospace;
}

.recipe-category,
.product-tile-category {
  margin-top: 20px;
  color: var(--blue);
  font-size: 10px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .1em;
}

.product-tile-category {
  color: #216e4e;
}

.tile-macros,
.product-macros,
.workout-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 5px;
  margin: 15px 0;

  &::before {
    grid-column: 1 / -1;
    color: var(--muted);
    font-size: 9px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: .09em;
  }

  span {
    padding: 8px 4px;
    border-radius: 8px;
    background: #f7f8fa;
    text-align: center;
  }

  b,
  small {
    display: block;
  }

  b {
    font-size: 14px;
  }

  small {
    margin-top: 2px;
    color: var(--muted);
    font-size: 8px;
    text-transform: uppercase;
  }
}

.tile-macros::before {
  content: 'КБЖУ на порцию';
}

.product-macros::before {
  content: 'КБЖУ · расчётная единица';
}

.recipe-tile-foot,
.product-tile-foot {
  margin-top: auto;
  padding-top: 12px;
  border-top: 1px solid #ebecf0;
  color: var(--muted);
  font-size: 11px;

  b {
    color: var(--ink);
    font-size: 13px;
    white-space: nowrap;
  }
}

.product-tile-actions,
.workout-tile-actions,
.recipe-tile-actions,
.progress-tile-actions,
.exercise-card-actions,
.diary-entry-actions {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 82px;
  gap: 7px;
  min-height: 36px;
  margin-top: auto;

  button {
    box-sizing: border-box;
    width: 100%;
    min-height: 36px;
    height: 36px;
    border-radius: 8px;
    padding: 0 10px;
    font-size: 11px;
    font-weight: 750;
    line-height: 1;
    white-space: nowrap;
    cursor: pointer;
  }
}

.edit-product,
.edit-workout,
.edit-progress-tile,
.edit-recipe,
.edit-exercise,
.edit-diary-entry {
  border: 1px solid #85b8ff;
  background: #e9f2ff;
  color: var(--blue);
}

.delete-product,
.delete-workout,
.delete-progress-tile,
.delete-recipe,
.delete-exercise,
.delete-diary-entry,
.danger-button,
.row-delete {
  border: 1px solid #f5a79b;
  background: #ffebe6;
  color: #ae2a19;
}

.danger-button {
  border-radius: 8px;
  padding: 8px 12px;
  font-weight: 750;
  cursor: pointer;
}

.recipe-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin: -6px 0 13px;

  button {
    border-radius: 8px;
    padding: 9px 13px;
    font-weight: 750;
    cursor: pointer;
  }
}

.recipe-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(145px, 1fr));
  gap: 10px;
  margin-bottom: 23px;

  > div {
    background: #f7f8fa;
    border: 1px solid var(--line);
    border-radius: 10px;
    padding: 13px;
  }

  span {
    display: block;
    color: var(--muted);
    font-size: 11px;
  }

  b {
    display: block;
    margin-top: 4px;
    font-size: 18px;
  }
}

.recipe-total > div {
  background: #eef3fb;
  border-color: #c7d7f2;
}

.macro-heading {
  margin: 17px 0 9px;
  font-size: 14px;
  color: #44546f;
}

.portion-price {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: -13px 0 21px;
  padding: 11px 13px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: #fff;

  span {
    color: var(--muted);
    font-size: 11px;
  }

  b {
    font-size: 16px;
  }
}

.ingredients-heading {
  margin: 24px 0 10px;
  font-size: 16px;
}

.recipe-table {
  overflow: auto;
  border: 1px solid var(--line);
  border-radius: 10px;

  small {
    display: block;
    color: var(--muted);
    font-size: 11px;
  }
}

.ready-recipe-note {
  display: flex;
  flex-direction: column;
  gap: 5px;
  padding: 17px;
  border-radius: 11px;
  background: #f5f2ff;
  color: #5e4db2;

  span {
    color: var(--muted);
    font-size: 12px;
  }
}

.ready-recipe-fields,
.product-measure-fields {
  margin-top: 17px;
  padding: 16px;
  border: 1px solid #9f8fef;
  border-radius: 13px;
  background: linear-gradient(145deg, #fff, #f5f2ff);
}

.ready-recipe-fields::before {
  content: 'КБЖУ ГОТОВОГО БЛЮДА · НА ОДНУ ПОРЦИЮ';
  grid-column: 1 / -1;
  color: #5e4db2;
  font-size: 10px;
  font-weight: 850;
  letter-spacing: .08em;
}

.product-measure-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 13px;

  h3 {
    margin: 0;
    font-size: 15px;
  }

  > small {
    color: var(--muted);
    font-size: 10px;
  }
}

.ingredient-row {
  display: grid;
  grid-template-columns: minmax(150px, 1fr) 105px 120px 36px;
  gap: 7px;
  margin: 7px 0;

  button {
    border: 0;
    border-radius: 7px;
    cursor: pointer;
  }
}

.destructive-zone {
  display: flex;
  justify-content: flex-start;
  margin-top: 20px;
  padding-top: 15px;
  border-top: 1px solid #ffd7d2;
}

.current-day-card,
.current-progress-card {
  position: relative;
  width: 100%;
  margin: 0 0 25px;
  padding: 25px;
  border: 1px solid #9f8fef;
  border-radius: 18px;
  background: linear-gradient(135deg, #fff 8%, #f4f1ff 58%, #edf7ff);
  color: var(--ink);
  text-align: left;
  box-shadow: 0 13px 35px #091e4220;
  overflow: hidden;
}

.current-progress-card {
  display: flex;
  flex-direction: column;
  padding: 18px;
}

.current-day-card {
  cursor: pointer;
}

.current-day-head,
.current-progress-head {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 15px;
  margin-bottom: 20px;
}

.current-day-head h2,
.current-progress-head h2 {
  margin: 3px 0 0;
  font-size: 28px;
  text-transform: capitalize;
}

.current-day-head > span {
  padding: 8px 11px;
  border-radius: 8px;
  background: #ffffffb8;
  color: var(--blue);
  font-size: 11px;
  font-weight: 800;
}

.current-day-body {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(300px, .75fr);
  gap: 18px;
}

.today-meals {
  display: grid;
  gap: 7px;
}

.today-meal-row {
  display: grid;
  grid-template-columns: 88px minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
  padding: 11px 13px;
  border: 1px solid #ffffffb8;
  border-radius: 11px;
  background: #ffffff9c;

  > span {
    color: #5e4db2;
    font-size: 10px;
    font-weight: 850;
    text-transform: uppercase;
  }

  > b {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 12px;
  }
}

.today-empty {
  display: flex;
  min-height: 106px;
  flex-direction: column;
  justify-content: center;
  padding: 16px;
  border: 1px dashed #9f8fef;
  border-radius: 12px;
  background: #ffffff75;
}

.today-kbju {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;

  span {
    display: grid;
    place-items: center;
    align-content: center;
    min-height: 72px;
    padding: 10px;
    border: 1px solid #ffffffc4;
    border-radius: 11px;
    background: #ffffffb8;
    text-align: center;
  }

  b,
  small {
    display: block;
  }

  b {
    font-size: 22px;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 12px;
    font-weight: 800;
    text-transform: none;
  }

  .today-cost {
    grid-column: 1 / -1;
    min-height: 56px;
    background: linear-gradient(135deg, #ffffffd9, #e9ddffcc);
    color: #5e4db2;
  }

  .goal-met {
    border-color: #4cbb7b;
    background: #e7f8ed;
    color: #126a3a;
  }

  .goal-exceeded {
    border-color: #e06a70;
    background: #fff0f1;
    color: #b4232c;
  }
}

.diary-month-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 15px;
  margin-bottom: 15px;

  h2 {
    text-transform: capitalize;
    font-size: 25px;
  }
}

.change-month {
  border: 1px solid #85b8ff;
  border-radius: 9px;
  background: #e9f2ff;
  color: var(--blue);
  padding: 10px 14px;
  font-weight: 800;
  cursor: pointer;
}

.diary-summary {
  display: flex;
  gap: 12px;
  margin: 15px 0;

  > div {
    min-width: 145px;
    padding: 11px 14px;
    border: 1px solid var(--line);
    border-radius: 10px;
    background: #fff;
  }

  span {
    display: block;
    color: var(--muted);
    font-size: 10px;
    text-transform: uppercase;
  }

  b {
    font-size: 19px;
  }
}

.month-summary {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
}

.diary-days-panel {
  padding: 17px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 2px 5px #091e4214;
}

.diary-weekdays,
.diary-day-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 8px;
}

.diary-weekdays {
  margin-bottom: 8px;

  span {
    color: var(--muted);
    font-size: 10px;
    font-weight: 800;
    text-align: center;
    text-transform: uppercase;
  }
}

.diary-day-card,
.diary-day-blank {
  min-height: 116px;
}

.diary-day-card {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: space-between;
  padding: 11px;
  border: 1px solid var(--line);
  border-radius: 11px;
  background: #fafbfc;
  color: var(--ink);
  text-align: left;
  cursor: pointer;
  overflow: hidden;

  &.filled {
    border-color: #9f8fef;
    background: linear-gradient(145deg, #fff, #f5f2ff);
    box-shadow: inset 0 4px #6e5dc6;
  }
}

.diary-day-number {
  display: grid;
  place-items: center;
  width: 29px;
  height: 29px;
  border-radius: 9px;
  background: #f1f2f4;
  font-size: 15px;
  font-weight: 850;
}

.diary-day-copy b,
.diary-day-copy small {
  display: block;
}

.diary-day-copy small {
  margin-top: 3px;
  color: var(--muted);
  font-size: 9px;
}

.diary-day-arrow {
  position: absolute;
  right: 9px;
  top: 12px;
  color: var(--blue);
  font-weight: 850;
}

.month-picker-row {
  display: flex;
  gap: 8px;
  margin-bottom: 17px;

  input {
    flex: 1;
  }
}

.month-choice-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(185px, 1fr));
  gap: 11px;
}

.month-choice {
  min-height: 105px;
  padding: 14px;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: #fafbfc;
  color: var(--ink);
  text-align: left;
  cursor: pointer;

  &:hover,
  &.active {
    border-color: #9f8fef;
    background: #f5f2ff;
    box-shadow: 0 7px 18px #091e4218;
  }

  span,
  b,
  small {
    display: block;
  }

  span {
    text-transform: capitalize;
    font-weight: 800;
  }

  b {
    margin-top: 9px;
    font-size: 24px;
  }
}

.calendar-back {
  margin-bottom: 15px;
  border: 0;
  background: #e9f2ff;
  color: var(--blue);
  border-radius: 8px;
  padding: 8px 11px;
  font-weight: 750;
  cursor: pointer;
}

.meal-group {
  margin: 0 0 17px;

  h3 {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin: 0 0 8px;
    font-size: 14px;
  }
}

.meal-cost {
  padding: 4px 9px;
  border-radius: 99px;
  background: #e9ddff;
  color: #5e4db2;
  font-size: 11px;
  font-weight: 850;
  white-space: nowrap;
}

.meal-entry {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  margin: 6px 0;
  padding: 12px 14px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: #fff;
  color: var(--ink);
  text-align: left;
  cursor: pointer;

  span b,
  span small {
    display: block;
  }

  span small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 10px;
  }
}

.diary-entry-actions {
  margin: 0 0 9px;

  button {
    border-radius: 8px;
    font-size: 11px;
    font-weight: 800;
  }

  .goal-label {
    color: inherit;
  }

  span:has(.goal-label) {
    min-height: 104px;
    box-shadow: 0 0 0 3px #0c66e433, 0 8px 18px #091e4220;
  }
}

.day-total {
  margin-top: 21px;
  padding: 17px;
  border-radius: 13px;
  background: linear-gradient(135deg, #172b4d, #2d4774);
  color: #fff;

  h3 {
    margin: 0 0 12px;
  }

  > div {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 9px;
  }

  span {
    padding: 10px;
    border-radius: 9px;
    background: #ffffff12;
    text-align: center;
  }

  b,
  small {
    display: block;
  }

  small {
    color: #c7d7f2;
    font-size: 9px;
    text-transform: uppercase;
  }

  .day-cost {
    grid-column: 1 / -1;
    background: #ffffff20;
    border: 1px solid #ffffff24;
  }
}

.diary-date {
  max-width: 220px;
  margin-bottom: 16px;
}

.diary-form-labels,
.diary-form-row {
  display: grid;
  grid-template-columns: minmax(130px, 1.05fr) minmax(180px, 1.5fr) minmax(115px, .8fr) minmax(90px, .8fr) 36px;
  gap: 7px;
  align-items: center;
}

.diary-form-labels {
  padding: 0 2px 5px;
  color: var(--muted);
  font-size: 10px;
  font-weight: 750;
  text-transform: uppercase;
}

.diary-form-row {
  margin-bottom: 8px;
  padding: 8px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: #fff;

  select,
  input {
    min-width: 0;
    width: 100%;
  }
}

.diary-product-row {
  background: #fff;
}

.diary-quantity,
.diary-unit {
  min-width: 0;
}

.diary-quantity {
  display: flex;
  align-items: center;
  border: 1px solid #b7c0d1;
  border-radius: 7px;
  background: #fff;
  overflow: hidden;
}

.diary-quantity input {
  min-width: 0;
  border: 0;
}

.diary-quantity span,
.diary-unit > span {
  padding: 0 8px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 800;
  white-space: nowrap;
}

.diary-unit select {
  width: 100%;
}

.diary-quantity,
.diary-edit-quantity {
  display: flex;
  align-items: center;
  min-width: 0;
  border: 1px solid #b7c0d1;
  border-radius: 7px;
  background: #fff;
  overflow: hidden;

  input {
    min-width: 0;
    border: 0;
  }

  span {
    padding: 0 9px;
    color: var(--muted);
    font-size: 11px;
    font-weight: 800;
    white-space: nowrap;
  }
}

.remove-diary-row {
  height: 36px;
  border: 0;
  border-radius: 7px;
  background: #ffebe6;
  color: #ae2a19;
  font-size: 20px;
  cursor: pointer;
}

.diary-add-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;

  button {
    border: 1px dashed #85b8ff;
    background: #e9f2ff;
    color: var(--blue);
    border-radius: 8px;
    padding: 9px 12px;
    font-weight: 750;
    cursor: pointer;
  }

}

.diary-form-labels span:nth-child(5),
.diary-form-row .dc {
  display: none;
}

.diary-quantity > span {
  display: none;
}

.diary-quantity input {
  flex: 1 1 auto;
  width: 100%;
}

.current-progress-head > div:last-child {
  display: flex;
  align-items: center;
  gap: 8px;
}

.current-progress-actions {
  justify-content: flex-end;
  margin-top: auto;
}

.current-badge {
  display: inline-block;
  padding: 3px 8px;
  border-radius: 99px;
  background: #e9ddff;
  color: #5e4db2;
  font-size: 9px;
  font-weight: 850;
  text-transform: uppercase;
}

.current-progress-main,
.progress-primary {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
}

.progress-primary {
  grid-template-columns: repeat(3, 1fr);
  margin-bottom: 17px;
}

.current-progress-main span,
.progress-primary span,
.progress-metrics span {
  padding: 13px 8px;
  border-radius: 10px;
  background: linear-gradient(145deg, #f4f8ff, #f7f5ff);
  text-align: center;
}

.current-progress-main b,
.current-progress-main small,
.progress-primary b,
.progress-primary small,
.progress-metrics b,
.progress-metrics small {
  display: block;
}

.current-progress-main b {
  font-size: 28px;
}

.progress-primary b {
  font-size: 22px;
}

.progress-primary small,
.progress-metrics small,
.current-progress-main small {
  margin-top: 3px;
  color: var(--muted);
  font-size: 8px;
  text-transform: uppercase;
}

.progress-primary i,
.progress-metrics i,
.current-progress-main i {
  color: var(--muted);
  font-size: 9px;
  font-style: normal;
}

.current-progress-details {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 20px;

  > div {
    padding: 14px;
    border-radius: 12px;
    background: #ffffff82;
  }

  h4 {
    margin: 0 0 9px;
    color: #44546f;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: .08em;
  }
}

.progress-metrics {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 6px;

  &.body-composition {
    grid-template-columns: repeat(4, 1fr);
  }
}

.progress-comment {
  margin: 14px 0 0;
  padding: 10px 11px;
  border-left: 3px solid #9f8fef;
  border-radius: 0 8px 8px 0;
  background: #f7f5ff;
  color: var(--muted);
  font-size: 11px;
}

.progress-history-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  margin: 0 0 12px;

  h3 {
    margin: 0;
    font-size: 18px;
  }
}

.progress-card-actions {
  display: flex;
  gap: 6px;
}

.edit-progress-tile,
.delete-progress-tile {
  border-radius: 8px;
  padding: 8px 10px;
  font-size: 11px;
  font-weight: 750;
  cursor: pointer;
}

.exercise-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 18px;
  padding: 16px 18px;
  border: 1px solid #9f8fef;
  border-radius: 14px;
  background: linear-gradient(135deg, #fff, #f4f1ff);
  box-shadow: 0 4px 14px #091e4214;

  > div:last-child {
    display: flex;
    gap: 8px;
  }

  button {
    border: 1px solid #9f8fef;
    border-radius: 8px;
    background: #f3f0ff;
    color: #5e4db2;
    padding: 9px 12px;
    font-size: 11px;
    font-weight: 800;
    cursor: pointer;
  }

  #quick-add-exercise {
    border-color: var(--blue);
    background: var(--blue);
    color: #fff;
  }
}

.workout-categories {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 13px;
  margin-bottom: 18px;
}

.workout-category-card {
  position: relative;
  display: grid;
  grid-template-columns: 48px 1fr auto;
  gap: 11px;
  align-items: center;
  min-height: 96px;
  padding: 15px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: linear-gradient(145deg, #fff, #f4f1ff);
  color: var(--ink);
  text-align: left;
  box-shadow: 0 2px 5px #091e4214;
  cursor: pointer;

  &.active,
  &:hover {
    border-color: #6e5dc6;
    box-shadow: 0 0 0 2px #6e5dc626, 0 9px 24px #091e4218;
  }

  b,
  small {
    display: block;
  }

  small {
    color: var(--muted);
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: .08em;
  }

  > strong {
    align-self: start;
    padding: 3px 8px;
    border-radius: 99px;
    background: #fff;
    color: #5e4db2;
    font-size: 12px;
    box-shadow: 0 1px 3px #091e4220;
  }
}

.workout-category-icon {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: 13px;
  background: linear-gradient(135deg, #e9ddff, #d9e7fd);
  color: #5e4db2;
  font-size: 22px;
  font-weight: 850;
}

.workout-date {
  font-size: 14px;
  font-weight: 850;
}

.workout-group {
  padding: 4px 8px;
  border-radius: 99px;
  background: #f3f0ff;
  color: #5e4db2;
  font-size: 10px;
  font-weight: 800;
}

.exercise-manager-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
  color: var(--muted);
}

.exercise-manager-list {
  display: grid;
  gap: 7px;
  max-height: 58vh;
  overflow: auto;
}

.exercise-manager-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 13px;
  border: 1px solid var(--line);
  border-radius: 10px;
  background: #fff;

  b,
  small {
    display: block;
  }

  small {
    margin-top: 3px;
    color: var(--muted);
    font-size: 10px;
  }
}

.delete-exercise {
  border: 1px solid #f5a79b;
  border-radius: 7px;
  background: #ffebe6;
  color: #ae2a19;
  padding: 7px 10px;
  font-size: 10px;
  font-weight: 800;
  cursor: pointer;
}

@media (max-width: 900px) {
  aside {
    position: static;
    width: auto;
  }

  main {
    margin: 0;
    padding: 22px;
  }

  nav {
    display: flex;
    overflow: auto;
  }

  .aside-note {
    display: none;
  }

  .kpis,
  .dashboard-kpis {
    grid-template-columns: 1fr 1fr;
  }

  .grid {
    grid-template-columns: 1fr;
  }

  .field.full {
    grid-column: auto;
  }

  .panel {
    overflow: auto;
  }

  .month-summary,
  .current-progress-details {
    grid-template-columns: 1fr 1fr;
  }

  .current-day-body {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 700px) {
  .recipe-grid,
  .product-grid,
  .workout-grid,
  .progress-grid {
    grid-template-columns: 1fr;
  }

  .recipe-categories,
  .product-categories {
    grid-template-columns: 1fr 1fr;
    gap: 9px;
  }

  .category-card,
  .product-category-card {
    min-height: 148px;
  }

  .category-photo,
  .product-category-photo,
  .all-photo,
  .all-products-photo {
    height: 90px;
  }

  .diary-form-labels {
    display: none;
  }

  .diary-form-row {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(105px, .8fr) 36px;

    .diary-unit {
      grid-column: 1 / 3;
    }

    .remove-diary-row {
      grid-column: 4;
      grid-row: 2;
    }
  }

  .diary-product-row {
    grid-template-columns: 1fr 1fr 90px 36px;
  }

  .day-total > div {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 560px) {
  body {
    padding-top: env(safe-area-inset-top);
    padding-bottom: env(safe-area-inset-bottom);
  }

  header {
    align-items: flex-start;
    flex-direction: column;
  }

  .header-actions {
    align-items: stretch;
    flex-direction: column-reverse;
    width: 100%;
  }

  .kpis,
  .dashboard-kpis {
    grid-template-columns: 1fr;
  }

  .bar,
  .protein-recipe-link {
    grid-template-columns: 125px 1fr 50px 16px;
    padding: 8px 5px;
  }

  .toolbar input,
  .toolbar select,
  .reset-sort {
    width: 100%;
    min-width: 0;
    margin-left: 0;
  }

  .current-day-card,
  .current-progress-card {
    padding: 18px;
  }

  .current-day-head,
  .current-progress-head,
  .diary-month-head,
  .exercise-toolbar,
  .exercise-manager-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .today-kbju,
  .current-progress-main,
  .current-progress-details,
  .progress-primary,
  .progress-metrics,
  .progress-metrics.body-composition {
    grid-template-columns: 1fr 1fr;
  }

  .month-summary {
    grid-template-columns: 1fr 1fr;
  }

  .diary-weekdays,
  .diary-day-grid {
    gap: 4px;
  }

  .diary-days-panel {
    padding: 9px;
  }

  .diary-day-card,
  .diary-day-blank {
    min-height: 62px;
  }

  .diary-day-card {
    padding: 6px;
  }

  .diary-day-copy,
  .diary-day-arrow {
    display: none;
  }

  .ingredient-row {
    grid-template-columns: 1fr 90px 110px 36px;
  }
}
</style>
