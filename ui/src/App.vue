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
const guestMode = ref(false);
const authOpen = ref(false);
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
const isGuest = computed(() => guestMode.value && !currentUser.value);
const activeUser = computed<AuthUser>(() => currentUser.value || { id: 0, email: 'Гостевой режим', is_admin: false });
const canAdd = computed(() => {
  if (isGuest.value || currentPage.value === 'dashboard' || currentPage.value === 'theory') return false;
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
  if (isGuest.value) {
    openLogin();
    return;
  }
  feedbackOpen.value = true;
}

function openLogin() {
  authOpen.value = true;
  guestMode.value = false;
}

function continueAsGuest() {
  authOpen.value = false;
  guestMode.value = true;
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
  guestMode.value = false;
  authOpen.value = false;
  refresh();
  startFeedbackPolling();
}

function clearSession() {
  const hadSession = Boolean(currentUser.value || getAccessToken());
  clearAccessToken();
  currentUser.value = null;
  if (hadSession) {
    guestMode.value = true;
    authOpen.value = false;
  }
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
    guestMode.value = true;
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
  <AuthView v-else-if="authOpen || (!currentUser && !guestMode)" allow-guest @authenticated="authenticated" @guest="continueAsGuest" />
  <AppShell
    v-else-if="currentUser || guestMode"
    :current-page="currentPage"
    :title="title"
    :can-add="canAdd"
    :add-label="addLabel"
    :user="activeUser"
    :guest-mode="isGuest"
    :feedback-unread="feedbackUnread"
    @navigate="navigate"
    @add="openAdd"
    @logout="logout"
    @feedback="openFeedback"
    @login="openLogin"
  >
    <DashboardView v-if="currentPage === 'dashboard'" :refresh-key="reloadKey" :is-admin="isAdmin" @navigate="navigate" @open-recipe="openRecipe" />
    <ProductsView v-else-if="currentPage === 'products'" :refresh-key="reloadKey" :is-admin="isAdmin" :read-only="isGuest" @edit="modal = { kind: 'products', id: $event }" @add-category="openCategory('product')" />
    <RecipesView v-else-if="currentPage === 'recipes'" :refresh-key="reloadKey" :is-admin="isAdmin" :read-only="isGuest" @open-recipe="openRecipe" @edit="editRecipe" @add-category="openCategory('recipe')" />
    <DiaryView v-else-if="currentPage === 'diary'" :refresh-key="reloadKey" @edit="modal = { kind: 'diary', id: $event }" />
    <ProgressView v-else-if="currentPage === 'progress'" :refresh-key="reloadKey" @edit="modal = { kind: 'progress', id: $event }" />
    <WorkoutsView
      v-else-if="currentPage === 'workouts'"
      :refresh-key="reloadKey"
      :is-admin="isAdmin"
      :read-only="isGuest"
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

<style lang="scss">
:root {
  --ink: #172033;
  --blue: #6f82ff;
  --bg: #f6f8fc;
  --line: #e5eaf2;
  --muted: #7d879b;
  --green: #329a63;
  --purple: #aa9cff;
  --orange: #f4b96b;
  --nav: #0e1728;
  --nav-surface: #26364a;
  --mint: #bdf2d3;
}

body { background: var(--bg); color: var(--ink); font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
aside { width: 248px; padding: 28px 16px 22px; border: 0; background: var(--nav); color: #f4f7fc; }
.brand { padding: 0 8px 42px; color: #fff; }
.brand .brand-mark { width: 34px; height: 34px; border-radius: 50%; background: var(--mint); color: var(--ink); }
.brand small { color: #8190a6; }
.nav-caption { margin: 0 8px 12px; color: #647189; font-size: 10px; font-weight: 800; letter-spacing: .12em; }
nav { gap: 4px; }
nav button, .feedback-link { color: #aab4c4; border-radius: 12px; }
nav button { min-height: 48px; padding: 11px 14px; }
nav button:hover, nav button.active { background: var(--nav-surface); color: #f9fbff; }
.nav-icon { display: inline-grid; flex: 0 0 28px; place-items: center; color: inherit; font-size: 18px; }
.feedback-link { margin-top: 18px; border-top-color: #26344a; padding: 18px 12px 11px; }
.feedback-link:hover { color: var(--mint); }
.aside-note { display: none; }
.aside-user { display: flex; align-items: center; gap: 10px; margin-top: auto; padding: 14px 10px; border-radius: 16px; background: #17243a; }
.aside-user .avatar { display: grid; flex: 0 0 40px; place-items: center; width: 40px; height: 40px; border-radius: 50%; background: #f3c6a9; color: var(--ink); font-weight: 800; }
.aside-user b, .aside-user small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.aside-user b { max-width: 140px; color: #f4f7fc; font-size: 12px; }
.aside-user small { max-width: 140px; margin-top: 3px; color: #8190a6; font-size: 10px; }
main { margin-left: 248px; max-width: 1520px; padding: 52px 40px 64px; }
header { margin-bottom: 34px; }
h1 { font-size: 30px; letter-spacing: -.04em; }
.eyebrow { color: var(--muted); letter-spacing: .12em; }
.primary { border-radius: 10px; background: var(--ink); padding: 12px 16px; }
.primary:hover { background: #26364a; }
.login-button { border: 1px solid var(--line); border-radius: 10px; padding: 11px 15px; background: #fff; color: var(--ink); font-weight: 800; cursor: pointer; }
.login-button:hover { border-color: var(--blue); color: var(--blue); }
.guest-badge { color: var(--muted); font-size: 11px; font-weight: 800; }
.user-chip { border-color: var(--line); border-radius: 12px; }
.card, .panel { border-color: var(--line); border-radius: 18px; box-shadow: none; }
.card { padding: 20px; }
.card .label { color: var(--muted); }
.card strong { color: var(--ink); }
.card small { color: var(--blue); font-size: 11px; font-weight: 800; }
.panel { padding: 24px; }
.toolbar { margin: 18px 0; }
input, select, textarea, .toolbar input, .toolbar select { border-color: var(--line); border-radius: 10px; padding: 11px 12px; background: #fff; }
.reset-sort { border-color: var(--line); border-radius: 10px; }
.recipe-grid, .product-grid, .workout-grid, .progress-grid { gap: 16px; }
.recipe-tile, .product-tile, .workout-tile, .progress-tile, .current-progress-card { border-color: var(--line); border-radius: 18px; box-shadow: none; }
.recipe-tile:hover, .product-tile:hover, .workout-tile:hover, .progress-tile:hover { border-color: #aab6ff; box-shadow: 0 12px 30px #17203312; }
.recipe-tile::before, .product-tile::before, .workout-tile::before, .progress-tile::before { height: 0; }
.recipe-tile h3, .product-tile h3, .workout-tile h3 { font-size: 18px; }
.tile-macros span, .product-macros span, .workout-stats span { background: #f7f8fc; }
.category-card, .product-category-card, .workout-category-card { border-color: var(--line); border-radius: 16px; box-shadow: none; }
.category-card:hover, .product-category-card:hover, .workout-category-card:hover { border-color: #aab6ff; box-shadow: 0 10px 25px #17203312; }
.category-card.active, .product-category-card.active { border-color: var(--blue); box-shadow: 0 0 0 2px #6f82ff22; }
.legend, .diary-days-panel { border-color: var(--line); border-radius: 18px; box-shadow: none; }
.current-day-card, .current-progress-card { border: 0; border-radius: 22px; background: var(--nav); color: #fff; box-shadow: none; }
.current-day-card .eyebrow, .current-progress-card .eyebrow { color: var(--mint); }
.current-day-head h2, .current-progress-head h2 { color: #fff; }
.current-day-head > span, .current-badge { background: var(--mint); color: var(--ink); }
.today-meal-row, .today-kbju span { border-color: #34445b; background: #17243a; }
.today-meal-row > span { color: var(--mint); }
.today-meal-row > b, .today-kbju b { color: #fff; }
.today-kbju small { color: #aab6c8; }
.diary-summary > div { border-color: var(--line); border-radius: 14px; }
.diary-day-card { border-color: var(--line); border-radius: 12px; }
.diary-day-card.filled { border-color: #aab6ff; background: #f4f3ff; box-shadow: inset 0 4px var(--blue); }
.progress-history-head { margin-top: 28px; }
dialog { border-radius: 22px; box-shadow: 0 24px 80px #17203340; }
dialog::backdrop { background: #0e172880; }
.dialog-panel { padding: 30px; }
.modal-head { margin-bottom: 24px; }
.icon { border-radius: 10px; background: #f1f3f8; }
.actions button { border-color: var(--line); border-radius: 10px; }
.actions .primary { color: #fff; }
.ready-recipe-fields, .product-measure-fields { border-color: #d8d1ff; border-radius: 16px; background: #f8f7ff; }
.exercise-toolbar { border-color: #d8d1ff; border-radius: 16px; background: #f8f7ff; box-shadow: none; }
.day-total { border-radius: 16px; background: var(--nav); }
.product-sprite, .recipe-sprite { position: relative; display: grid; place-items: center; background: #f6f8fc; }
.product-sprite::before, .recipe-sprite::before { content: ''; display: block; width: 58px; height: 58px; border-radius: 50%; background-repeat: no-repeat; }
.product-sprite::before { background-image: url('/assets/astra-category-icons-products.svg'); background-size: 1260px 760px; background-position: var(--sprite-left) var(--sprite-top); }
.recipe-sprite::before { background-image: url('/assets/astra-category-icons-recipes.svg'); background-size: 1260px 600px; background-position: var(--sprite-left) var(--sprite-top); }
.product-category-card .product-category-photo.product-sprite, .category-card .category-photo.recipe-sprite { background-image: none; }
.product-category-card .product-category-photo.product-sprite::before, .category-card .category-photo.recipe-sprite::before { margin-top: 0; }
.workout-section-icon { width: 48px; height: 48px; border-radius: 50%; background-image: url('/assets/astra-category-icons-workouts.svg'); background-size: 1260px 600px; background-position: -140px -157px; background-color: #e6e7ff; font-size: 0; }
.workout-section-tile:nth-child(2) .workout-section-icon { background-position: -330px -333px; background-color: #e2f7eb; }
.workout-section-tile:nth-child(3) .workout-section-icon { background-position: -710px -333px; background-color: #e6e7ff; }
.workout-section-tile:nth-child(4) .workout-section-icon { background-position: -900px -333px; background-color: #fff1de; }
.add-section-card::before { display: none; }
.article-section-card { display: grid; grid-template-columns: 48px minmax(0, 1fr) auto; gap: 11px; align-items: center; min-height: 96px; padding: 15px; border-radius: 14px; }
.article-section-card > span { grid-column: 2; min-width: 0; }
.article-section-card > strong { grid-column: 3; grid-row: 1; align-self: start; }
.article-section-card::before { content: ''; position: static; grid-column: 1; grid-row: 1; width: 48px; height: 48px; border-radius: 50%; background: #e2f7eb url('/assets/astra-category-icons-articles.svg') -119px -162px no-repeat; }
.article-section-card:nth-child(2)::before { background-color: #f0f1ff; background-position: -309px -162px; }
.article-section-card:nth-child(3)::before { background-color: #dff2f7; background-position: -499px -162px; }
.article-section-card:nth-child(4)::before { background-color: #e6e7ff; background-position: -689px -162px; }
.article-section-card:nth-child(5)::before { background-color: #fff1de; background-position: -879px -162px; }
.article-section-card:nth-child(6)::before { background-color: #fde7e2; background-position: -1069px -162px; }
.article-section-card.add-section-card { display: flex; min-height: 96px; padding: 15px; }
.article-section-card.add-section-card > span { min-width: 0; }
.recipes-page-subtitle { margin: -22px 0 24px; color: var(--muted); font-size: 14px; }
.recipe-collections { display: none; }
.recipe-categories { grid-template-columns: repeat(auto-fit, minmax(144px, 1fr)); gap: 16px; margin-bottom: 24px; }
.recipe-categories .category-card { display: grid; grid-template-columns: 48px minmax(0, 1fr) auto; align-items: center; gap: 11px; min-height: 92px; padding: 15px; border-radius: 16px; }
.recipe-categories .category-card > strong { position: static; grid-column: 3; grid-row: 1; align-self: start; padding: 5px 8px; background: #edf2ff; color: var(--blue); box-shadow: none; }
.recipe-categories .category-photo { width: 48px; height: 48px; border-radius: 50%; }
.recipe-categories .category-photo::before { width: 48px; height: 48px; }
.recipe-categories .category-copy { grid-column: 2; padding: 0; min-width: 0; }
.recipe-categories .category-copy b { display: block; font-size: 12px; line-height: 1.2; }
.recipe-categories .category-copy small { margin-top: 4px; color: var(--muted); font-size: 10px; text-transform: none; letter-spacing: 0; }
.recipe-categories .all-photo { background: #e2f7eb; }
.recipe-categories .all-photo::after { content: '✦'; color: #329a63; font-size: 24px; text-shadow: none; }
.recipe-categories .add-category-card { border-style: dashed; background: #fff; }
.recipe-categories .add-category-card .category-photo { display: grid; place-items: center; background: #f0f1ff; color: var(--blue); font-size: 24px; }
.recipe-grid { grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 24px; }
.recipe-tile { min-height: 268px; padding: 16px; border-radius: 18px; box-shadow: 0 8px 28px #15233d12; }
.recipe-tile::before { display: none; }
.recipe-cover { position: relative; display: flex; align-items: center; height: 94px; padding: 0 26px; border-radius: 13px; overflow: hidden; background: #e2f7eb; color: #329a63; }
.recipe-cover-icon { font-size: 42px; line-height: 1; }
.recipe-serving { position: absolute; top: 12px; right: 12px; padding: 5px 9px; border-radius: 8px; background: #ffffffd1; color: inherit; font-size: 10px; font-weight: 800; }
.recipe-cover-breakfast { background: #f0f1ff; color: #6f82ff; }
.recipe-cover-dessert { background: #fff1de; color: #c88731; }
.recipe-cover-salad, .recipe-cover-drink { background: #dff2f7; color: #4b9db0; }
.recipe-cover-wrap, .recipe-cover-garnish { background: #e2f7eb; color: #329a63; }
.recipe-cover-sauce, .recipe-cover-snack { background: #f0f1ff; color: #6f82ff; }
.recipe-cover-ready { background: #fde7e2; color: #d56666; }
.recipe-tile-head { display: none; }
.recipe-tile .recipe-category { margin-top: 14px; color: var(--muted); font-size: 10px; text-transform: none; letter-spacing: .02em; }
.recipe-tile h3 { margin: 5px 0 4px; font-size: 18px; line-height: 1.2; }
.recipe-tile > p { min-height: 18px; margin: 0; font-size: 11px; }
.recipe-tile .tile-macros { grid-template-columns: repeat(4, 1fr); gap: 0; margin: 12px 0 10px; padding-top: 12px; border-top: 1px solid #edf0f5; }
.recipe-tile .tile-macros::before { display: none; }
.recipe-tile .tile-macros span { padding: 0; background: transparent; text-align: left; }
.recipe-tile .tile-macros b { color: var(--muted); font-size: 11px; }
.recipe-tile .tile-macros span:first-child b { color: var(--blue); }
.recipe-tile .tile-macros small { margin-top: 2px; font-size: 8px; }
.recipe-tile-foot { padding-top: 0; border-top: 0; }
.recipe-tile-foot > span:first-child { display: none; }
.recipe-tile-foot::before { content: 'Открыть рецепт'; display: inline-flex; align-items: center; min-height: 28px; padding: 0 13px; border-radius: 8px; background: var(--ink); color: #fff; font-size: 10px; font-weight: 800; }
.recipe-tile-foot b { color: var(--muted); font-size: 10px; }
.recipe-tile-foot b small { font-size: 9px; }
.products-page-subtitle { margin: -22px 0 24px; color: var(--muted); font-size: 14px; }
.product-catalog-layout { display: grid; grid-template-columns: 184px minmax(0, 1fr); gap: 28px; align-items: start; }
.product-catalog-layout .product-categories { display: flex; flex-direction: column; gap: 3px; margin: 0; padding-right: 16px; border-right: 1px solid var(--line); }
.product-catalog-layout .product-categories { grid-column: 1; grid-row: 1 / span 2; }
.product-catalog-layout .product-category-card { display: grid; grid-template-columns: 36px minmax(0, 1fr) auto; align-items: center; gap: 9px; min-height: 48px; padding: 6px 9px; border: 0; border-radius: 10px; box-shadow: none; background: transparent; }
.product-catalog-layout .product-category-card:hover { transform: none; background: #f1f4fb; box-shadow: none; }
.product-catalog-layout .product-category-card.active { border: 0; background: #e2f7eb; box-shadow: none; }
.product-catalog-layout .product-category-card > strong { position: static; grid-column: 3; grid-row: 1; padding: 4px 7px; background: #fff; color: var(--blue); box-shadow: none; }
.product-catalog-layout .product-category-photo { width: 36px; height: 36px; border-radius: 50%; }
.product-catalog-layout .product-category-photo::before { width: 36px; height: 36px; background-size: 1260px 760px; }
.product-catalog-layout .product-category-copy { grid-column: 2; padding: 0; min-width: 0; }
.product-catalog-layout .product-category-copy b { display: block; overflow: hidden; font-size: 11px; line-height: 1.2; text-overflow: ellipsis; white-space: nowrap; }
.product-catalog-layout .product-category-copy small { margin-top: 3px; color: var(--muted); font-size: 9px; text-transform: none; letter-spacing: 0; }
.product-catalog-layout .product-category-card.all { margin-bottom: 5px; background: #e2f7eb; }
.product-catalog-layout .product-category-card.all .product-category-photo { background: #fff; }
.product-catalog-layout .product-category-card.all-products-photo::after { content: '✦'; color: #329a63; font-size: 20px; letter-spacing: 0; text-shadow: none; }
.product-catalog-layout .product-category-card.add-category-card { margin-top: 8px; border: 1px dashed #b8c0d1; background: #fff; }
.product-catalog-layout .product-category-card.add-category-card .product-category-photo { display: grid; place-items: center; background: #f0f1ff; color: var(--blue); font-size: 20px; }
.product-catalog-layout .toolbar { grid-column: 2; grid-row: 1; margin: 0 0 18px; }
.product-catalog-layout .product-grid { grid-column: 2; grid-row: 2; margin-top: 0; display: block; overflow: hidden; border: 1px solid var(--line); border-radius: 16px; background: #fff; }
.product-table-head, .product-tile { display: grid; grid-template-columns: minmax(190px, 2fr) minmax(100px, 1.15fr) repeat(4, minmax(64px, .7fr)); gap: 12px; align-items: center; }
.product-table-head { min-height: 45px; padding: 0 24px; border-bottom: 1px solid var(--line); background: #fbfcfe; color: var(--muted); font-size: 9px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
.product-tile { min-height: 72px; padding: 12px 24px; border: 0; border-bottom: 1px solid #edf0f5; border-radius: 0; box-shadow: none; }
.product-tile:last-of-type { border-bottom: 0; }
.product-tile:hover { transform: none; border-color: #edf0f5; background: #fbfcff; box-shadow: none; }
.product-tile::before { display: none; }
.product-tile-head { display: none; }
.product-tile h3 { grid-column: 1; grid-row: 1; margin: 0; font-size: 14px; line-height: 1.25; }
.product-tile-category { grid-column: 2; grid-row: 1; margin: 0; color: var(--muted); font-size: 11px; font-weight: 600; text-transform: none; letter-spacing: 0; }
.product-tile > p { grid-column: 1; grid-row: 2; min-height: 0; margin: 4px 0 0; overflow: hidden; color: var(--muted); font-size: 9px; text-overflow: ellipsis; white-space: nowrap; }
.product-tile .product-macros { display: grid; grid-column: 3 / -1; grid-row: 1 / 3; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; align-items: center; margin: 0; }
.product-tile .product-macros::before { display: none; }
.product-tile .product-macros span { padding: 0; background: transparent; text-align: left; }
.product-tile .product-macros b { color: var(--ink); font-size: 12px; }
.product-tile .product-macros small { margin-top: 2px; font-size: 8px; }
.product-tile .product-tile-foot { grid-column: 2; grid-row: 2; margin: 4px 0 0; padding: 0; border: 0; font-size: 9px; }
.product-tile .product-tile-foot span { display: none; }
.product-tile .product-tile-foot b { color: var(--muted); font-size: 9px; }
.product-tile .product-tile-actions { grid-column: 1 / -1; grid-row: 3; display: flex; justify-content: flex-end; min-height: 30px; margin: 4px 0 0; }
.product-tile .product-tile-actions button { width: auto; min-height: 28px; height: 28px; }
.product-catalog-layout > .product-grid > .empty { margin: 16px; }
@media (max-width: 900px) { aside { width: auto; } main { margin-left: 0; padding: 32px 24px 48px; } }
@media (max-width: 760px) { .product-catalog-layout { grid-template-columns: 1fr; } .product-catalog-layout .product-categories { grid-column: 1; grid-row: auto; flex-direction: row; overflow-x: auto; padding: 0 0 8px; border-right: 0; border-bottom: 1px solid var(--line); } .product-catalog-layout .product-category-card { min-width: 150px; } .product-catalog-layout .toolbar, .product-catalog-layout .product-grid { grid-column: 1; grid-row: auto; } .product-catalog-layout .product-grid { margin-top: 0; overflow-x: auto; } .product-table-head, .product-tile { min-width: 720px; } }
.product-catalog-layout { display: block; }
.product-catalog-layout .product-categories { display: grid; grid-template-columns: repeat(auto-fit, minmax(144px, 1fr)); grid-column: auto; grid-row: auto; gap: 16px; margin-bottom: 24px; padding: 0; border: 0; }
.product-catalog-layout .product-category-card { display: grid; grid-template-columns: 48px minmax(0, 1fr) auto; min-height: 92px; padding: 15px; border: 1px solid var(--line); border-radius: 16px; background: #fff; }
.product-catalog-layout .product-category-card:hover { transform: translateY(-2px); background: #fff; }
.product-catalog-layout .product-category-card.active { border-color: var(--blue); background: #fff; box-shadow: 0 0 0 2px #6f82ff22; }
.product-catalog-layout .product-category-card > strong { position: static; grid-column: 3; grid-row: 1; align-self: start; }
.product-catalog-layout .product-category-photo { width: 48px; height: 48px; }
.product-catalog-layout .product-category-photo::before { width: 48px; height: 48px; }
.product-catalog-layout .product-category-copy b { font-size: 12px; }
.product-catalog-layout .product-category-copy small { font-size: 10px; }
.product-catalog-layout .toolbar { margin: 18px 0; }
.product-catalog-layout .product-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 24px; overflow: visible; border: 0; border-radius: 0; background: transparent; }
.product-table-head { display: none; }
.product-tile { display: flex; flex-direction: column; min-height: 300px; padding: 16px; border: 1px solid var(--line); border-radius: 18px; background: #fff; box-shadow: 0 8px 28px #15233d12; }
.product-tile:hover { transform: translateY(-3px); border-color: #aab6ff; background: #fff; box-shadow: 0 12px 30px #17203312; }
.product-cover { position: relative; display: flex; align-items: center; justify-content: center; height: 108px; border-radius: 13px; background: #fff1de; color: #c88731; overflow: hidden; }
.product-cover-label { position: absolute; top: 12px; left: 12px; padding: 5px 9px; border-radius: 8px; background: #ffffffd1; color: inherit; font-size: 10px; font-weight: 800; }
.product-cover-icon { width: 64px; height: 64px; border-radius: 50%; background: #fff; }
.product-cover-icon.product-sprite { display: grid; place-items: center; background: #ffffffd1; }
.product-cover-icon.product-sprite::before { width: 58px; height: 58px; }
.product-cover-tone-0, .product-cover-tone-3 { background: #e2f7eb; color: #329a63; }
.product-cover-tone-1, .product-cover-tone-4 { background: #f0f1ff; color: #6f82ff; }
.product-cover-tone-2 { background: #dff2f7; color: #4b9db0; }
.product-cover-tone-5 { background: #fde7e2; color: #d56666; }
.product-tile .product-tile-category { display: none; }
.product-tile h3 { margin: 14px 0 4px; font-size: 18px; line-height: 1.2; }
.product-tile > p { min-height: 18px; margin: 0; font-size: 11px; white-space: normal; }
.product-tile .product-macros { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0; margin: 12px 0 10px; padding-top: 12px; border-top: 1px solid #edf0f5; }
.product-tile .product-macros::before { display: none; }
.product-tile .product-macros span { padding: 0; background: transparent; text-align: left; }
.product-tile .product-macros b { color: var(--ink); font-size: 11px; }
.product-tile .product-macros span:first-child b { color: var(--blue); }
.product-tile .product-macros small { margin-top: 2px; font-size: 8px; }
.product-tile .product-tile-foot { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: auto; padding-top: 12px; border-top: 1px solid #edf0f5; }
.product-tile .product-tile-foot span { display: block; overflow: hidden; color: var(--muted); font-size: 9px; text-overflow: ellipsis; white-space: nowrap; }
.product-tile .product-tile-foot b { color: var(--ink); font-size: 11px; }
.product-tile .product-tile-actions { display: flex; gap: 7px; min-height: 32px; margin-top: 10px; }
.product-tile .product-tile-actions button { width: auto; min-height: 32px; height: 32px; }
.product-catalog-layout > .product-grid > .empty { grid-column: 1 / -1; margin: 0; }
@media (max-width: 760px) { .product-catalog-layout .product-categories { display: flex; flex-direction: row; overflow-x: auto; padding-bottom: 8px; } .product-catalog-layout .product-category-card { min-width: 150px; } .product-catalog-layout .product-grid { grid-template-columns: 1fr; } .product-table-head, .product-tile { min-width: 0; } }
@media (max-width: 560px) { main { padding: 24px 16px 40px; } }
.workout-tile, .article-card { min-height: 300px; padding: 16px; border-radius: 18px; box-shadow: 0 8px 28px #15233d12; }
.workout-tile::before { content: '↗'; position: static; display: grid; flex: 0 0 108px; place-items: center; width: calc(100% + 32px); height: 108px; margin: -16px -16px 0; background: #f0f1ff; color: #6f82ff; font-size: 44px; }
.planned-plan-tile::before, .archive-plan-tile::before { content: '↗'; background: #f0f1ff; color: #6f82ff; }
.exercise-card::before { content: '✦'; background: #e2f7eb; color: #329a63; }
.workout-tile:hover, .article-card:hover { border-color: #aab6ff; box-shadow: 0 12px 30px #17203312; }
.article-card { min-height: 300px; }
.article-card::before { height: 108px; margin: -16px -16px 0; background: #dff2f7; }
.article-card img { position: relative; z-index: 1; width: calc(100% + 32px); height: 108px; margin: -16px -16px 15px; }
.article-card:not(:has(img))::after { content: '◈'; position: absolute; top: 36px; left: 34px; z-index: 1; color: #4b9db0; font-size: 44px; }
.article-card:not(:has(img)) .article-card-head { margin-top: 15px; }
.card-compact, .article-section-card, .workout-section-tile { min-height: 96px; border-radius: 14px; }
.article-section-card, .workout-section-tile, .recipe-categories .category-card, .product-catalog-layout .product-category-card { box-shadow: none; }
.article-section-card:hover, .workout-section-tile:hover, .recipe-categories .category-card:hover, .product-catalog-layout .product-category-card:hover { transform: translateY(-2px); }
@media (max-width: 760px) { .workout-tile, .article-card { min-height: 255px; } .workout-tile::before, .article-card::before { flex-basis: 76px; height: 76px; } .article-card img { height: 76px; } }
</style>

<style lang="scss">
/* Design v2: shared foundation, entity cards and popup system. */
:root {
  --v2-bg: #f7f8fc;
  --v2-surface: #ffffff;
  --v2-ink: #172033;
  --v2-muted: #7d879b;
  --v2-line: #e3e8f1;
  --v2-soft: #f0f2f7;
  --v2-purple: #6f82ff;
  --v2-mint: #bdf2d3;
  --v2-danger: #d56666;
}

body { background: var(--v2-bg); color: var(--v2-ink); }
main { padding-top: 44px; }
main > header { margin-bottom: 30px; }
main > header h1 { margin-bottom: 7px; font-size: clamp(27px, 3vw, 34px); }
main > header p { color: var(--v2-muted); }
.eyebrow { font-size: 10px; font-weight: 800; letter-spacing: .13em; text-transform: uppercase; }

button, input, select, textarea { font: inherit; }
button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible, a:focus-visible {
  outline: 3px solid #6f82ff55;
  outline-offset: 2px;
}
.primary, .mint-button, .complete-plan {
  min-height: 48px;
  padding: 0 18px;
  border: 0;
  border-radius: 12px;
  background: var(--v2-ink);
  color: #fff;
  font-size: 12px;
  font-weight: 800;
  cursor: pointer;
}
.primary:hover, .complete-plan:hover { background: #26364a; }
.mint-button { background: var(--v2-mint); color: var(--v2-ink); }
.mint-button:hover { background: #d1f8df; }
.secondary-button, .reset-sort, .login-button, .actions button:not(.primary), .toolbar button:not(.primary) {
  min-height: 44px;
  padding: 0 15px;
  border: 1px solid var(--v2-line);
  border-radius: 11px;
  background: var(--v2-surface);
  color: var(--v2-ink);
  font-size: 12px;
  font-weight: 800;
  cursor: pointer;
}
.secondary-button:hover, .reset-sort:hover, .login-button:hover, .actions button:not(.primary):hover { border-color: var(--v2-purple); color: var(--v2-purple); }
.danger-button, .delete-product, .delete-recipe, .delete-workout, .delete-progress-tile, .delete-diary-entry {
  border-color: #f0caca !important;
  background: #fff7f7 !important;
  color: var(--v2-danger) !important;
}
.icon { display: grid; place-items: center; width: 40px; height: 40px; min-height: 40px; padding: 0; border: 0; border-radius: 11px; background: var(--v2-soft); color: var(--v2-ink); cursor: pointer; }
.icon:hover { background: #e5e9f2; }
button:disabled { cursor: not-allowed; opacity: .52; }
input, select, textarea { min-height: 44px; border: 1px solid var(--v2-line); border-radius: 11px; background: #fff; color: var(--v2-ink); }
textarea { min-height: 110px; }
.toolbar { gap: 10px; padding: 14px; border: 1px solid var(--v2-line); border-radius: 16px; background: #fff; }
.toolbar input, .toolbar select { min-height: 40px; }

/* Overview */
body .dashboard-layout { grid-template-columns: minmax(0, 1.7fr) minmax(260px, .8fr); gap: 18px; }
body .dashboard-hero { min-height: 250px; padding: 32px; border-radius: 24px; background: var(--v2-ink); box-shadow: 0 18px 40px #17203318; }
body .dashboard-hero h2 { max-width: 560px; font-size: clamp(25px, 3.2vw, 36px); }
body .dashboard-ring { flex-basis: 156px; width: 156px; height: 156px; }
body .dashboard-database { padding: 28px; border-radius: 24px; background: #e2f7eb; }
body .dashboard-quick { margin-top: 2px; }
body .dashboard-quick-grid { gap: 12px; }
body .dashboard-quick-grid .card { min-height: 116px; padding: 18px; border-radius: 17px; }
body .dashboard-diary, body .dashboard-protein { padding: 24px; border-radius: 20px; }
body .dashboard-meal-row { padding: 13px 0; }

/* Food Calendar / diary */
.diary-page-subtitle, .progress-page-subtitle, .workouts-page-subtitle, .information-page-subtitle, .products-page-subtitle, .recipes-page-subtitle { margin: -21px 0 24px; color: var(--v2-muted); font-size: 14px; }
body .current-day-card { min-height: 286px; padding: 28px; border-radius: 24px; text-align: left; box-shadow: 0 18px 40px #17203318; }
body .current-day-head { margin-bottom: 24px; }
body .today-meal-row { min-height: 54px; border-radius: 12px; }
body .today-kbju { gap: 10px; }
body .today-kbju span { min-width: 92px; padding: 12px; border-radius: 12px; }
body .diary-month-head { margin-top: 28px; }
body .diary-summary { gap: 12px; }
body .diary-summary > div { min-height: 88px; padding: 16px; background: #fff; }
body .diary-days-panel { padding: 22px; background: #fff; }
body .diary-day-card { min-height: 88px; background: #fff; }
body .diary-day-card.filled { background: #f0f1ff; }
body .month-choice { border-radius: 11px; }
body .day-total { padding: 20px; border-radius: 20px; }

/* Progress */
body .current-progress-card { padding: 28px; border-radius: 24px; box-shadow: 0 18px 40px #17203318; }
body .current-progress-main { gap: 18px; }
body .current-progress-main > strong { font-size: clamp(42px, 6vw, 64px); letter-spacing: -.06em; }
body .progress-grid { grid-template-columns: repeat(auto-fit, minmax(235px, 1fr)); gap: 14px; }
body .progress-tile { min-height: 214px; padding: 20px; border-radius: 18px; background: #fff; }
body .progress-tile-actions { gap: 7px; }
body .progress-history-head { margin-top: 30px; }

/* Workouts */
body .scheduled-workouts { margin-bottom: 26px; }
body .scheduled-workouts-head, body .subsection-heading, body .equipment-group-head, body .archive-group-head { margin-bottom: 14px; }
body .scheduled-grid, body .exercise-grid, body .archive-workout-grid { grid-template-columns: repeat(auto-fit, minmax(265px, 1fr)); gap: 16px; }
body .workout-tile { min-height: 300px; border-radius: 18px; background: #fff; }
body .planned-plan-tile, body .archive-plan-tile { padding-top: 16px; }
body .planned-plan-tile::before, body .archive-plan-tile::before { display: none; }
body .workout-section-menu { grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 0 0 28px; }
body .workout-section-tile { min-height: 104px; padding: 16px; border-radius: 16px; background: #fff; }
body .workout-section-tile.active { border-color: var(--v2-purple); background: #f0f1ff; box-shadow: 0 0 0 2px #6f82ff22; }
body .workout-section-icon { width: 52px; height: 52px; }
body .workout-complex-card, body .exercise-category-card, body .equipment-card { border-radius: 16px; }
body .exercise-category-card { min-height: 76px; }
body .exercise-card { min-height: 280px; }
body .equipment-card-photo { height: 108px; border-radius: 13px; object-fit: cover; }

/* Information */
body .theory-head { margin-bottom: 8px; }
body .popular-articles { padding: 20px; border: 1px solid #c9c0ff; border-radius: 22px; background: linear-gradient(135deg, #fff, #f5f2ff); }
body .article-grid { grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
body .theory-page .article-card { min-height: 300px; padding: 16px; border-radius: 18px; background: #fff; }
body .theory-page .article-card::before { content: ''; position: static; inset: auto; display: block; width: calc(100% + 32px); height: 108px; margin: -16px -16px 0; border-radius: 14px 14px 0 0; background: #dff2f7; }
body .theory-page .article-card img { width: calc(100% + 32px); height: 108px; margin: -16px -16px 15px; }
body .theory-page .article-card h3 { font-size: 19px; line-height: 1.24; }
body .theory-page .article-section-card { min-height: 104px; padding: 16px; border-radius: 16px; background: #fff; }
body .article-sections { grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
body .article-section-info { border-radius: 18px; }
body .article-detail-body { line-height: 1.7; }

/* Recipes: full cards with the compact v2 controls. */
body .recipe-categories { grid-template-columns: repeat(auto-fit, minmax(155px, 1fr)); gap: 12px; }
body .recipe-categories .category-card { min-height: 96px; border-radius: 16px; }
body .recipe-grid { grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
body .recipe-tile { min-height: 314px; border-radius: 18px; background: #fff; }
body .recipe-cover { height: 108px; border-radius: 14px; }
body .recipe-tile-foot::before { min-height: 34px; padding: 0 15px; border-radius: 10px; }

/* Products: v2 uses a dense catalogue row rather than a large content card. */
body .product-catalog-layout { display: grid; grid-template-columns: 184px minmax(0, 1fr); gap: 24px; }
body .product-catalog-layout .product-categories { display: flex; flex-direction: column; gap: 3px; margin: 0; padding-right: 14px; border-right: 1px solid var(--v2-line); }
body .product-catalog-layout .product-category-card { min-height: 48px; padding: 6px 9px; border: 0; border-radius: 10px; background: transparent; }
body .product-catalog-layout .product-category-card:hover { transform: none; background: #f0f2f7; }
body .product-catalog-layout .product-category-card.active { border: 0; background: #e2f7eb; box-shadow: none; }
body .product-catalog-layout .product-category-photo { width: 36px; height: 36px; }
body .product-catalog-layout .product-category-photo::before { width: 36px; height: 36px; }
body .product-catalog-layout .product-category-copy b { font-size: 11px; }
body .product-catalog-layout .product-category-copy small { font-size: 9px; }
body .product-catalog-layout .product-grid { display: block; overflow: hidden; border: 1px solid var(--v2-line); border-radius: 16px; background: #fff; }
body .product-table-head, body .product-tile { display: grid; grid-template-columns: minmax(190px, 2fr) minmax(100px, 1.15fr) repeat(4, minmax(64px, .7fr)); gap: 12px; align-items: center; }
body .product-table-head { min-height: 46px; padding: 0 20px; border-bottom: 1px solid var(--v2-line); background: #fbfcfe; }
body .product-tile { min-height: 78px; padding: 12px 20px; border: 0; border-bottom: 1px solid #edf0f5; border-radius: 0; box-shadow: none; }
body .product-tile:hover { transform: none; background: #fbfcff; box-shadow: none; }
body .product-tile .product-cover { display: none; }
body .product-tile h3 { grid-column: 1; grid-row: 1; margin: 0; font-size: 14px; }
body .product-tile-category { grid-column: 2; grid-row: 1; display: block !important; margin: 0; color: var(--v2-muted); font-size: 11px; }
body .product-tile > p { grid-column: 1; grid-row: 2; margin: 3px 0 0; }
body .product-tile .product-macros { grid-column: 3 / -1; grid-row: 1 / 3; margin: 0; padding: 0; border: 0; }
body .product-tile .product-tile-foot { grid-column: 2; grid-row: 2; margin: 3px 0 0; padding: 0; border: 0; }
body .product-tile .product-tile-actions { grid-column: 1 / -1; grid-row: 3; min-height: 28px; margin: 3px 0 0; justify-content: flex-end; }

/* Popups: one shell for view, add, edit, delete and action variants. */
dialog { width: min(640px, calc(100vw - 32px)); max-height: min(820px, calc(100vh - 32px)); padding: 0; border: 1px solid var(--v2-line); border-radius: 22px; background: #fff; color: var(--v2-ink); }
dialog.recipe-dialog { width: min(900px, calc(100vw - 32px)); }
dialog > form, dialog > .dialog-panel { padding: 28px; }
dialog > form { margin: 0; }
dialog .modal-head { align-items: flex-start; margin-bottom: 24px; }
dialog .modal-head h2 { margin-top: 5px; font-size: 24px; letter-spacing: -.035em; }
dialog .modal-head .eyebrow { margin: 0; color: var(--v2-purple); }
dialog .actions { display: flex; justify-content: flex-end; gap: 9px; margin-top: 24px; padding-top: 18px; border-top: 1px solid var(--v2-line); }
dialog .actions button { min-height: 44px; }
dialog .confirm-message { padding: 16px; border-radius: 12px; background: #f7f8fc; color: var(--v2-muted); line-height: 1.55; }
dialog .danger-button, dialog .delete-button { background: #fff7f7; color: var(--v2-danger); }
dialog .field { gap: 7px; }
dialog .field label { color: var(--v2-ink); font-size: 11px; font-weight: 800; }
dialog .field small, dialog .hint { color: var(--v2-muted); font-size: 11px; line-height: 1.45; }
dialog .field.full { grid-column: 1 / -1; }
.form-grid, .field-grid { gap: 14px; }

@media (max-width: 900px) {
  body .dashboard-layout { grid-template-columns: 1fr; }
  body .dashboard-database, body .dashboard-diary, body .dashboard-protein { grid-column: 1; }
  body .workout-section-menu { grid-template-columns: repeat(2, 1fr); }
  body .product-catalog-layout { grid-template-columns: 1fr; }
  body .product-catalog-layout .product-categories { flex-direction: row; overflow-x: auto; padding: 0 0 8px; border-right: 0; border-bottom: 1px solid var(--v2-line); }
  body .product-catalog-layout .product-category-card { min-width: 148px; }
}
@media (max-width: 760px) {
  main { padding: 30px 20px 44px; }
  body .dashboard-hero, body .current-day-card, body .current-progress-card { padding: 22px; border-radius: 19px; }
  body .product-catalog-layout .product-grid { overflow-x: auto; }
  body .product-table-head, body .product-tile { min-width: 720px; }
  dialog > form, dialog > .dialog-panel { padding: 22px; }
}
</style>
