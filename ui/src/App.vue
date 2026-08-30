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
import ClientsView from '@/views/ClientsView.vue';
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
import WorkoutComplexDetailModal from '@/components/modals/WorkoutComplexDetailModal.vue';
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
const diaryMenuAction = ref<{ kind: 'day' | 'week'; token: number } | null>(null);
const recipeDetailId = ref<number | null>(null);
const exerciseManagerOpen = ref(false);
const workoutBuilderOpen = ref(false);
const repeatPlan = ref<WorkoutPlan | null>(null);
const editPlan = ref<WorkoutPlan | null>(null);
const workoutComplexForBuilder = ref<WorkoutComplex | null>(null);
const workoutDetailPlan = ref<WorkoutPlan | null>(null);
const exerciseDetail = ref<Exercise | null>(null);
const equipmentKind = ref<'machine' | 'equipment'>('machine');
const feedbackOpen = ref(false);
const feedbackUnread = ref(0);
let feedbackTimer: ReturnType<typeof setInterval> | null = null;
const complexEditorOpen = ref(false);
const complexEditor = ref<WorkoutComplex | null>(null);
const complexEditorMode = ref<'create' | 'edit'>('create');
const workoutComplexDetail = ref<WorkoutComplex | null>(null);
const categoryOpen = ref(false);
const categoryKind = ref<'product' | 'recipe'>('product');
const articleOpen = ref(false);
const articleEditor = ref<Article | null>(null);
const articleFormKey = ref(0);

const title = computed(() => pages.find((page) => page.id === currentPage.value)?.title || 'Обзор');
const isAdmin = computed(() => Boolean(currentUser.value?.is_admin));
const isTrainer = computed(() => Boolean(currentUser.value?.is_trainer));
const canManageTraining = computed(() => isAdmin.value || isTrainer.value);
const canAccessClients = computed(() => canManageTraining.value);
const isGuest = computed(() => guestMode.value && !currentUser.value);
const activeUser = computed<AuthUser>(() => currentUser.value || { id: 0, email: 'Гостевой режим', name: 'Гостевой режим', is_admin: false, is_trainer: false });
const canAdd = computed(() => {
  if (isGuest.value || currentPage.value === 'dashboard' || currentPage.value === 'theory' || currentPage.value === 'clients') return false;
  if (currentPage.value === 'workouts') return false;
  if (currentPage.value === 'products') return isAdmin.value;
  return true;
});
const articleModalTitle = computed(() => articleEditor.value ? 'Редактировать статью' : 'Добавить статью');
const addLabel = computed(() => currentPage.value === 'workouts' ? 'Собрать тренировку' : currentPage.value === 'progress' ? 'Добавить показатели' : 'Добавить');
const canAddCategory = computed(() => ['recipes', 'products'].includes(currentPage.value) && !isGuest.value);
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

function openAdd(mealType?: string) {
  if (!canAdd.value || currentPage.value === 'dashboard') return;
  if (currentPage.value === 'workouts') {
    repeatPlan.value = null;
    editPlan.value = null;
    workoutComplexForBuilder.value = null;
    workoutBuilderOpen.value = true;
    return;
  }
  modal.value = { kind: currentPage.value as ModalState['kind'], ...(mealType ? { mealType } : {}) };
}

function openDiaryMenu(kind: 'day' | 'week') {
  diaryMenuAction.value = { kind, token: (diaryMenuAction.value?.token || 0) + 1 };
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
  if (!canManageTraining.value) return;
  exerciseManagerOpen.value = false;
  workoutBuilderOpen.value = false;
  repeatPlan.value = null;
  editPlan.value = null;
  modal.value = { kind: 'exercises' };
}

function editExercise(id: number) {
  if (!canManageTraining.value) return;
  exerciseManagerOpen.value = false;
  modal.value = { kind: 'exercises', id };
}

function openEquipmentAdd(kind: 'machine' | 'equipment') {
  if (!canManageTraining.value) return;
  equipmentKind.value = kind;
  modal.value = { kind: 'equipment' };
}

function editEquipment(id: number) {
  if (!canManageTraining.value) return;
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
  if (!canManageTraining.value) return;
  workoutDetailPlan.value = null;
  exerciseDetail.value = null;
  repeatPlan.value = null;
  editPlan.value = null;
  workoutComplexForBuilder.value = null;
  complexEditor.value = payload.complex;
  complexEditorMode.value = payload.mode;
  complexEditorOpen.value = true;
}

function scheduleWorkoutFromComplex(complex: WorkoutComplex) {
  workoutDetailPlan.value = null;
  exerciseDetail.value = null;
  repeatPlan.value = null;
  editPlan.value = null;
  workoutComplexForBuilder.value = complex;
  workoutBuilderOpen.value = true;
}

function openWorkoutComplexDetail(complex: WorkoutComplex) {
  workoutComplexDetail.value = complex;
}

function editWorkoutComplexFromDetail(complex: WorkoutComplex) {
  workoutComplexDetail.value = null;
  buildWorkoutFromComplex({ complex, mode: 'edit' });
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
  workoutComplexForBuilder.value = null;
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
    :can-add-category="canAddCategory"
    :add-label="addLabel"
    :show-diary-menu-actions="currentPage === 'diary' && canAdd"
    :user="activeUser"
    :guest-mode="isGuest"
    :feedback-unread="feedbackUnread"
    :can-access-clients="canAccessClients"
    @navigate="navigate"
    @add="openAdd"
    @collect-day-menu="openDiaryMenu('day')"
    @collect-week-menu="openDiaryMenu('week')"
    @add-category="openCategory(currentPage === 'products' ? 'product' : 'recipe')"
    @logout="logout"
    @feedback="openFeedback"
    @login="openLogin"
  >
    <DashboardView v-if="currentPage === 'dashboard'" :refresh-key="reloadKey" :is-admin="isAdmin" @navigate="navigate" @open-recipe="openRecipe" />
    <ProductsView v-else-if="currentPage === 'products'" :refresh-key="reloadKey" :is-admin="isAdmin" :can-manage="canManageTraining" :read-only="isGuest" @edit="modal = { kind: 'products', id: $event }" @add="openAdd" @add-category="openCategory('product')" />
    <RecipesView v-else-if="currentPage === 'recipes'" :refresh-key="reloadKey" :is-admin="isAdmin" :can-manage="canManageTraining" :read-only="isGuest" @open-recipe="openRecipe" @edit="editRecipe" @add="openAdd" @add-category="openCategory('recipe')" />
    <DiaryView v-else-if="currentPage === 'diary'" :refresh-key="reloadKey" :read-only="isGuest" :menu-action="diaryMenuAction" @edit="modal = { kind: 'diary', id: $event }" @add="openAdd" />
    <ProgressView v-else-if="currentPage === 'progress'" :refresh-key="reloadKey" :read-only="isGuest" @edit="modal = { kind: 'progress', id: $event }" @add="openAdd" />
    <WorkoutsView
      v-else-if="currentPage === 'workouts'"
      :refresh-key="reloadKey"
      :is-admin="isAdmin"
      :can-manage="canManageTraining"
      :read-only="isGuest"
      @edit="modal = { kind: 'workouts', id: $event }"
      @add-exercise="openExerciseAdd"
      @edit-exercise="editExercise"
      @add-equipment="openEquipmentAdd"
      @edit-equipment="editEquipment"
      @open-plan="openWorkoutDetail"
      @open-exercise="openExerciseDetail"
      @open-complex="openWorkoutComplexDetail"
      @build-complex="buildWorkoutFromComplex"
      @schedule-from-complex="scheduleWorkoutFromComplex"
      @manage-exercises="exerciseManagerOpen = true"
      @build="repeatPlan = null; editPlan = null; workoutBuilderOpen = true"
      @edit-plan="editPlan = $event; repeatPlan = null; workoutBuilderOpen = true"
      @repeat="repeatPlan = $event; editPlan = null; workoutBuilderOpen = true"
    />
    <ClientsView v-else-if="currentPage === 'clients'" :refresh-key="reloadKey" :can-access="canAccessClients" :is-admin="isAdmin" @changed="refresh" @feedback="openFeedback" />
    <TheoryView v-else-if="currentPage === 'theory'" :is-admin="isAdmin" :can-manage="canManageTraining" :refresh-key="reloadKey" @add-article="openArticleEditor()" @edit-article="openArticleEditor" />
  </AppShell>

  <RecipeDetailModal :recipe-id="recipeDetailId" :is-admin="isAdmin" :can-manage="canManageTraining" @close="recipeDetailId = null" @edit="editRecipe" @deleted="recipeDetailId = null; refresh()" @changed="refresh" />
  <ExerciseManagerModal v-if="canManageTraining" :open="exerciseManagerOpen" @close="exerciseManagerOpen = false" @add="openExerciseAdd" @edit="editExercise" @changed="refresh" />
  <WorkoutBuilderModal :open="workoutBuilderOpen" :repeat-plan="repeatPlan" :edit-plan="editPlan" :complex="workoutComplexForBuilder" @close="workoutBuilderOpen = false; repeatPlan = null; editPlan = null; workoutComplexForBuilder = null" @saved="workoutBuilderOpen = false; repeatPlan = null; editPlan = null; workoutComplexForBuilder = null; refresh()" />
  <WorkoutComplexModal :open="complexEditorOpen" :complex="complexEditor" :mode="complexEditorMode" @close="complexEditorOpen = false" @saved="complexEditorOpen = false; complexEditor = null; refresh()" @open-exercise="openExerciseDetail" />
  <WorkoutComplexDetailModal :open="Boolean(workoutComplexDetail)" :complex="workoutComplexDetail" :can-manage="canManageTraining" :read-only="isGuest" @close="workoutComplexDetail = null" @edit="editWorkoutComplexFromDetail" />
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
    <DiaryEntryForm v-else-if="modal?.kind === 'diary'" :diary-id="modal.id as number | undefined" :initial-meal-type="modal.mealType" @saved="saved" @deleted="saved" @cancel="closeModal" />
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

.side-nav {
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
  .side-nav {
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
/* Astra button system: shared across pages, cards and popups. */
body button {
  box-sizing: border-box;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  transition: background-color .16s ease, border-color .16s ease, color .16s ease, box-shadow .16s ease, transform .16s ease;
}
body button:disabled { transform: none !important; }

body .primary,
body .mint-button,
body .complete-plan,
body .create-complex-button {
  min-height: 48px;
  height: 48px;
  border: 0;
  border-radius: 12px;
  padding: 0 18px;
  background: #172033;
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
}
body .mint-button,
body .complete-plan,
body .create-complex-button { background: #bdf2d3; color: #172033; }
body .primary:hover,
body .complete-plan:hover,
body .create-complex-button:hover { background: #26364a; color: #fff; transform: translateY(-1px); }
body .mint-button:hover { background: #d1f8df; color: #172033; transform: translateY(-1px); }

body .secondary-button,
body .login-button,
body .reset-sort,
body .change-month,
body .clear-filter,
body .section-info-edit,
body .edit-workout,
body .edit-product,
body .edit-recipe,
body .edit-exercise,
body .edit-equipment,
body .edit-progress-tile,
body .edit-diary-entry,
body .edit-article-button,
body .edit-complex-button,
body .article-open-button,
body .cancel-submission,
body .month-choice {
  min-height: 44px;
  height: 44px;
  border: 1px solid #dde3ec;
  border-radius: 11px;
  padding: 0 15px;
  background: #f6f8fc;
  color: #7d879b;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}
body .secondary-button:hover,
body .login-button:hover,
body .reset-sort:hover,
body .change-month:hover,
body .clear-filter:hover,
body .section-info-edit:hover,
body .edit-workout:hover,
body .edit-product:hover,
body .edit-recipe:hover,
body .edit-exercise:hover,
body .edit-equipment:hover,
body .edit-progress-tile:hover,
body .edit-diary-entry:hover,
body .edit-article-button:hover,
body .edit-complex-button:hover,
body .article-open-button:hover,
body .cancel-submission:hover,
body .month-choice:hover { border-color: #6f82ff; background: #eaf2ff; color: #6f82ff; transform: translateY(-1px); }

body .danger-button,
body .delete-product,
body .delete-recipe,
body .delete-workout,
body .delete-exercise,
body .delete-progress-tile,
body .delete-diary-entry,
body .row-delete,
body .article-visibility-button {
  min-height: 44px;
  height: 44px;
  border: 1px solid #f3a59a !important;
  border-radius: 11px;
  padding: 0 15px;
  background: #fff0ed !important;
  color: #d56666 !important;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}
body .danger-button:hover,
body .delete-product:hover,
body .delete-recipe:hover,
body .delete-workout:hover,
body .delete-exercise:hover,
body .delete-progress-tile:hover,
body .delete-diary-entry:hover,
body .row-delete:hover,
body .article-visibility-button:hover { border-color: #d56666 !important; background: #ffe4df !important; transform: translateY(-1px); }
body dialog .actions .danger-button,
body dialog .actions .delete-button { border-color: #d56666 !important; background: #d56666 !important; color: #fff !important; }

body .icon {
  width: 38px;
  min-width: 38px;
  height: 38px;
  min-height: 38px;
  padding: 0;
  border: 0;
  border-radius: 10px;
  background: #f6f8fc;
  color: #7d879b;
}
body .icon:hover { background: #eaf2ff; color: #6f82ff; transform: translateY(-1px); }
body .article-pin-action,
body .article-pin-button,
body .article-card-actions button,
body .article-detail-actions button,
body .workout-card-actions button,
body .recipe-tile-actions button,
body .product-tile-actions button,
body .progress-tile-actions button {
  min-height: 38px;
  height: 38px;
  border-radius: 10px;
  padding: 0 12px;
  font-size: 11px;
  font-weight: 700;
}
body .article-pin-action,
body .article-pin-button { border: 1px solid #dde3ec; background: #eaf2ff; color: #6f82ff; }
body .article-pin-action:hover,
body .article-pin-button:hover { border-color: #6f82ff; background: #dce8ff; }
body .article-card-actions button,
body .article-detail-actions button { background: #f6f8fc; color: #7d879b; }
body .article-card-actions .article-open-button,
body .article-detail-actions .article-open-button { background: #172033; color: #fff; }
body .article-card-actions .article-open-button:hover,
body .article-detail-actions .article-open-button:hover { background: #26364a; color: #fff; }
body .actions button:not(.primary),
body .toolbar button:not(.primary) { min-height: 44px; height: 44px; border-radius: 11px; }
body .actions button:hover { transform: translateY(-1px); }
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
.side-nav { width: 248px; padding: 28px 16px 22px; border: 0; background: var(--nav); color: #f4f7fc; }
.brand { padding: 0 8px 42px; color: #fff; }
.brand .brand-mark { display: block; width: 34px; height: 34px; border-radius: 10px; object-fit: cover; background: none; }
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
@media (max-width: 900px) { .side-nav { width: auto; } main { margin-left: 0; padding: 32px 24px 48px; } }
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

/* Workouts v2: featured plan, compact plan rows and action hierarchy. */
body .scheduled-grid { grid-template-columns: 1fr; gap: 12px; }
body .scheduled-grid .planned-plan-tile {
  display: grid;
  grid-template-columns: minmax(240px, 1.25fr) minmax(220px, 1fr) auto;
  grid-template-rows: auto auto;
  min-height: 92px;
  padding: 16px 24px;
  padding-right: 250px;
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 4px 16px #1720330d;
}
body .scheduled-grid .planned-plan-tile > .workout-tile-head { grid-column: 1; grid-row: 1; min-height: 0; }
body .scheduled-grid .planned-plan-tile > h3 { grid-column: 1; grid-row: 2; min-height: 0; margin: 3px 0 0; font-size: 16px; }
body .scheduled-grid .planned-plan-tile > p { grid-column: 2; grid-row: 1 / 3; align-self: center; min-height: 0; margin: 0; }
body .scheduled-grid .planned-plan-items { display: none; }
body .scheduled-grid .planned-plan-tile > .planned-tile-actions { grid-column: 3; grid-row: 1 / 3; align-self: end; display: flex; gap: 7px; min-height: 0; margin: 0; }
body .scheduled-grid .planned-plan-tile:first-child {
  min-height: 118px;
  padding: 22px 32px;
  padding-right: 250px;
  border: 0;
  border-radius: 20px;
  background: var(--v2-ink);
  color: #fff;
  box-shadow: 0 18px 40px #17203320;
}
body .scheduled-grid .planned-plan-tile:first-child > h3 { font-size: 19px; }
body .scheduled-grid .planned-plan-tile:first-child > p { color: #aab6c8; }
body .scheduled-grid .planned-plan-tile:first-child .workout-date { color: #aab6c8; }
body .scheduled-grid .planned-plan-tile:first-child .planned-badge { background: transparent; color: var(--v2-mint); }
body .scheduled-grid .planned-plan-tile:first-child .edit-workout { border-color: #42516a; background: #26364a; color: #fff; }
body .scheduled-grid .planned-plan-tile:first-child .delete-workout { border-color: #5a4650 !important; background: transparent !important; color: #ffb4a9 !important; }
body .workout-complete-action {
  top: 16px;
  right: 24px;
  min-width: 128px;
  min-height: 40px;
  border-radius: 10px;
  background: var(--v2-mint);
  color: var(--v2-ink);
}
body .scheduled-grid .planned-plan-tile:first-child .workout-complete-action { top: 22px; right: 32px; }

body .archive-workout-grid { grid-template-columns: 1fr; gap: 10px; }
body .archive-workout-grid .archive-plan-tile {
  display: grid;
  grid-template-columns: minmax(240px, 1.25fr) minmax(220px, 1fr) auto;
  align-items: center;
  min-height: 78px;
  padding: 14px 24px;
  border-radius: 14px;
  box-shadow: none;
}
body .archive-workout-grid .archive-plan-tile > .workout-tile-head { grid-column: 1; }
body .archive-workout-grid .archive-plan-tile > .planned-plan-items { grid-column: 2; min-height: 0; max-height: 48px; margin: 0; overflow: hidden; }
body .archive-workout-grid .archive-plan-tile > .planned-plan-items div { display: none; }
body .archive-workout-grid .archive-plan-tile > .planned-plan-items div:first-child { display: block; padding: 0; background: transparent; }
body .archive-workout-grid .archive-plan-tile > .workout-card-actions { grid-column: 3; min-height: 0; margin: 0; }

body .workout-card-actions button,
body .create-complex-button,
body .edit-complex-button,
body .exercise-actions .secondary-button {
  min-height: 40px;
  height: 40px;
  border-radius: 10px;
  padding: 0 13px;
  font-size: 11px;
  font-weight: 800;
}
body .edit-workout,
body .edit-complex-button,
body .exercise-actions .secondary-button {
  border: 1px solid var(--v2-line);
  background: #fff;
  color: var(--v2-ink);
}
body .edit-workout:hover,
body .edit-complex-button:hover,
body .exercise-actions .secondary-button:hover { border-color: var(--v2-purple); color: var(--v2-purple); }
body .delete-workout { border: 1px solid #f0caca; background: #fff7f7; color: var(--v2-danger); }
body .delete-workout:hover { border-color: var(--v2-danger); background: #fff0f0; }
body .complete-plan,
body .create-complex-button { border: 0; background: var(--v2-mint); color: var(--v2-ink); }
body .complete-plan:hover,
body .create-complex-button:hover { background: #d1f8df; }
body .workout-card-actions { gap: 7px; }

body .workout-section-tile { transition: transform .16s ease, border-color .16s ease, box-shadow .16s ease, background .16s ease; }
body .workout-section-tile:hover { background: #fbfcff; }
body .workout-section-tile.active { background: #f0f1ff; }
body .exercise-category-card { min-height: 76px; border-radius: 14px; }
body .exercise-category-card.active { border-color: var(--v2-purple); background: #f0f1ff; }
body .exercise-card, body .equipment-card { min-height: 280px; border-radius: 18px; }
body .exercise-card .workout-tile-actions, body .equipment-card .workout-tile-actions { margin-top: auto; }
body .equipment-card-mark { border-radius: 12px; background: #e2f7eb; }

@media (max-width: 820px) {
  body .scheduled-grid .planned-plan-tile,
  body .archive-workout-grid .archive-plan-tile { grid-template-columns: minmax(0, 1fr) auto; padding-right: 24px; }
  body .scheduled-grid .planned-plan-tile > p,
  body .archive-workout-grid .archive-plan-tile > .planned-plan-items { grid-column: 1; grid-row: 3; margin-top: 8px; }
  body .scheduled-grid .planned-plan-tile > .planned-tile-actions,
  body .archive-workout-grid .archive-plan-tile > .workout-card-actions { grid-column: 2; grid-row: 1 / 4; }
  body .scheduled-grid .planned-plan-tile { padding-top: 58px; }
  body .scheduled-grid .planned-plan-tile:first-child { padding-top: 68px; }
}

/* Workout component sheet: create tiles, reference cards and history cards. */
body .workout-complex-grid { grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; }
body .workout-create-card { position: relative; overflow: hidden; cursor: pointer; }
body .workout-create-card::before { display: none; }
body .workout-create-card.workout-complex-card {
  display: grid;
  grid-template-columns: 86px minmax(0, 1fr);
  grid-template-rows: 1fr auto;
  align-items: center;
  min-height: 154px;
  padding: 24px 28px;
  border: 0;
  border-radius: 20px;
  background: #172033;
  color: #fff;
}
body .workout-create-icon {
  display: grid;
  grid-row: 1 / -1;
  place-items: center;
  width: 86px;
  height: 86px;
  border-radius: 50%;
  background: #bdf2d3;
  color: #172033;
  font-size: 42px;
  font-weight: 400;
  line-height: 1;
}
body .workout-create-copy { min-width: 0; padding-left: 28px; }
body .workout-create-copy .eyebrow { margin: 0 0 7px; color: #bdf2d3; }
body .workout-create-copy h3 { margin: 0; color: inherit; font-size: 18px; line-height: 1.2; }
body .workout-create-copy p:not(.eyebrow) { margin: 7px 0 0; color: #aab6c8; font-size: 12px; line-height: 1.4; }
body .workout-create-card.workout-complex-card > .primary { grid-column: 2; justify-self: start; min-height: 38px; height: 38px; margin-top: 12px; border-radius: 10px; background: #bdf2d3; color: #172033; }
body .workout-create-card.workout-complex-card > .primary:hover { background: #d1f8df; color: #172033; }

body .workout-create-card.add-exercise-card,
body .workout-create-card.add-equipment-card {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 298px;
  padding: 28px;
  border: 1px dashed #d9e2ff;
  border-radius: 18px;
  background: #f8faff;
  color: #172033;
  text-align: center;
}
body .workout-create-card.add-exercise-card .workout-create-icon,
body .workout-create-card.add-equipment-card .workout-create-icon { flex: 0 0 60px; width: 60px; height: 60px; font-size: 32px; background: #eef0ff; color: #6f82ff; }
body .workout-create-card.add-exercise-card .workout-create-copy,
body .workout-create-card.add-equipment-card .workout-create-copy { padding: 0; }
body .workout-create-card.add-exercise-card .workout-create-copy h3,
body .workout-create-card.add-equipment-card .workout-create-copy h3 { margin-top: 18px; font-size: 16px; }
body .workout-create-card.add-exercise-card > .primary,
body .workout-create-card.add-equipment-card > .primary { min-height: 38px; height: 38px; margin-top: 18px; border-radius: 10px; background: #172033; color: #fff; }
body .workout-create-card.add-exercise-card > .primary:hover,
body .workout-create-card.add-equipment-card > .primary:hover { background: #26364a; color: #fff; }

body .exercise-grid { grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
body .exercise-card:not(.workout-create-card)::before,
body .equipment-card:not(.workout-create-card)::before { height: 112px; background: #e2f7eb; color: #329a63; }
body .exercise-card .workout-group,
body .equipment-card .workout-group { display: inline-flex; width: fit-content; padding: 5px 9px; border-radius: 999px; background: #f0ecff; color: #6652c7; font-size: 10px; font-weight: 800; letter-spacing: .06em; }
body .exercise-card .exercise-code,
body .equipment-card .exercise-code { color: #7d879b; font-size: 10px; }
body .exercise-card h3,
body .equipment-card h3 { margin-top: 10px; font-size: 16px; line-height: 1.25; }
body .exercise-card > p,
body .equipment-card > p { min-height: 44px; line-height: 1.45; }
body .exercise-card-actions,
body .equipment-card-actions { display: flex; gap: 8px; grid-template-columns: none; }
body .exercise-card-actions .edit-workout,
body .equipment-card-actions .edit-workout { flex: 1; min-height: 32px; height: 32px; border-radius: 9px; padding: 0 10px; background: #eaf2ff; color: #6f82ff; }
body .exercise-card-actions .delete-workout { min-height: 32px; height: 32px; padding: 0 11px; border-radius: 9px; }
body .equipment-card-photo { height: 108px; margin: -16px -16px 10px; width: calc(100% + 32px); border-radius: 14px 14px 0 0; }

body .archive-workout-grid { grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 16px; }
body .archive-workout-grid .archive-plan-tile {
  display: flex;
  min-height: 264px;
  padding: 24px;
  border-radius: 18px;
  box-shadow: 0 6px 20px #1720330d;
}
body .archive-workout-grid .archive-plan-tile > .planned-plan-items { display: grid; min-height: 72px; max-height: 90px; margin: 20px 0 12px; overflow: hidden; }
body .archive-workout-grid .archive-plan-tile > .planned-plan-items div { display: block; padding: 8px 0; border-top: 1px solid #e5eaf2; background: transparent; }
body .archive-workout-grid .archive-plan-tile > .workout-card-actions { display: flex; gap: 8px; min-height: 36px; margin-top: auto; }
body .archive-workout-grid .archive-plan-tile > .workout-card-actions .edit-workout { flex: 1; }
body .completed-badge { background: #f0ecff; color: #6652c7; }
body .canceled-badge { background: #f7eaea; color: #d55555; }

/* Workouts v2 final layout: keep workout collections independent from recipe/category grids. */
body main .workout-subsection { display: block !important; width: 100% !important; min-width: 0; }
body main .workout-subsection > .subsection-heading { display: flex !important; width: 100%; align-items: flex-end; justify-content: flex-start; }
body main .workout-subsection > .subsection-heading > h2 { margin-right: auto; }
body main .workout-subsection > .subsection-heading:has(> .eyebrow) { flex-wrap: wrap; }
body main .workout-subsection > .subsection-heading:has(> .eyebrow) > h2 { flex: 0 0 100%; margin-right: 0; }
body main .workout-complex-grid,
body main .exercise-grid,
body main .archive-workout-grid {
  display: grid !important;
  width: 100% !important;
  min-width: 0;
  gap: 16px !important;
}
body main .workout-complex-grid { grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)) !important; }
body main .exercise-grid { grid-template-columns: repeat(auto-fill, minmax(265px, 1fr)) !important; }
body main .archive-workout-grid { grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)) !important; }
body main .workout-complex-grid > .workout-complex-card,
body main .exercise-grid > .exercise-card,
body main .archive-workout-grid > .archive-plan-tile {
  min-width: 0;
  width: auto;
}
body main .workout-complex-grid > .workout-complex-card { min-height: 260px; }
body main .workout-complex-grid > .workout-create-card.workout-complex-card { min-height: 154px; }

@media (max-width: 900px) {
  body main .workout-complex-grid,
  body main .exercise-grid,
  body main .archive-workout-grid { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
}
@media (max-width: 600px) {
  body main .workout-complex-grid,
  body main .exercise-grid,
  body main .archive-workout-grid { grid-template-columns: 1fr !important; }
}

@media (max-width: 700px) {
  body .workout-create-card.workout-complex-card { grid-template-columns: 62px minmax(0, 1fr); padding: 20px; }
  body .workout-create-icon { width: 62px; height: 62px; font-size: 32px; }
  body .workout-create-copy { padding-left: 16px; }
  body .workout-create-card.add-exercise-card,
  body .workout-create-card.add-equipment-card { min-height: 230px; }
  body .archive-workout-grid { grid-template-columns: 1fr; }
}

/* Recipes page v2: compact toolbar, category rail and recipe card states. */
body .legend { display: none; }
body .recipe-toolbar { display: grid; grid-template-columns: minmax(260px, 1fr) 168px 170px auto; gap: 10px; min-height: 68px; margin: 0 0 24px; padding: 14px 24px; border: 1px solid #e5eaf2; border-radius: 16px; background: #fff; }
body .recipe-toolbar input,
body .recipe-toolbar select { min-width: 0; height: 40px; min-height: 40px; border: 0; border-radius: 10px; background: #f6f8fc; color: #7d879b; }
body .recipe-toolbar select:not(#recipe-order) { grid-column: 2; }
body .recipe-toolbar #recipe-order { grid-column: 3; }
body .recipe-toolbar .subtle { justify-self: end; white-space: nowrap; }
body .recipe-toolbar .reset-sort { display: none; }
body .recipe-categories { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px; margin: 0 0 26px; }
body .recipe-categories .category-card { min-height: 86px; padding: 12px 14px; border: 1px solid #e5eaf2; border-radius: 16px; background: #fff; box-shadow: none; }
body .recipe-categories .category-card.active,
body .recipe-categories .category-card.all.active { border-color: #9eddb9; background: #e2f7eb; box-shadow: none; }
body .recipe-categories .category-card:hover { border-color: #aab6ff; box-shadow: 0 8px 20px #1720330d; transform: translateY(-1px); }
body .recipe-categories .category-photo { width: 42px; height: 42px; }
body .recipe-categories .category-photo::before { width: 42px; height: 42px; }
body .recipe-categories .category-copy b { font-size: 12px; }
body .recipe-categories .category-copy small { margin-top: 4px; font-size: 10px; }
body .recipe-categories .category-card > strong { padding: 4px 7px; border-radius: 99px; background: #f0ecff; color: #6f82ff; font-size: 11px; }
body .recipe-categories .category-card.all > strong { background: #fff; color: #329a63; }
body .recipe-categories .add-category-card { border-style: dashed; background: #f8fafd; }
body .recipes-results-head { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin: 0 0 14px; }
body .recipes-results-head h2 { margin: 0; font-size: 18px; }
body .recipes-results-head span { color: #7d879b; font-size: 12px; }
body .recipe-grid { grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; }
body .recipe-tile,
body .recipe-add-card { min-height: 272px; padding: 14px; border-radius: 18px; background: #fff; box-shadow: 0 8px 28px #15233d12; }
body .recipe-tile:hover { border-color: #9aa7ff; box-shadow: 0 12px 30px #15233d18; transform: translateY(-2px); }
body .recipe-cover { height: 82px; min-height: 82px; padding: 0 20px; border-radius: 12px; }
body .recipe-cover-icon { font-size: 38px; }
body .recipe-serving { top: 10px; right: 10px; padding: 4px 7px; border-radius: 8px; }
body .recipe-tile .recipe-category { margin-top: 15px; font-size: 10px; }
body .recipe-tile h3 { margin: 6px 0 4px; font-size: 16px; line-height: 1.22; }
body .recipe-tile > p { min-height: 18px; margin: 0; color: #7d879b; font-size: 11px; }
body .recipe-tile .tile-macros { grid-template-columns: 1fr; gap: 3px; margin: 12px 0 0; padding-top: 12px; border-top: 1px solid #edf0f5; }
body .recipe-tile .tile-macros span { display: inline; padding: 0; background: transparent; text-align: left; }
body .recipe-tile .tile-macros span:first-child { grid-column: 1; }
body .recipe-tile .tile-macros span:not(:first-child) { display: inline-block; margin-right: 9px; }
body .recipe-tile .tile-macros b { color: #7d879b; font-size: 11px; }
body .recipe-tile .tile-macros span:first-child b { color: #6f82ff; }
body .recipe-tile .tile-macros small { display: inline; margin-left: 3px; font-size: 9px; }
body .recipe-tile-foot { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: auto; padding-top: 10px; border-top: 0; }
body .recipe-tile-foot::before { content: 'Просмотр'; min-height: 26px; padding: 0 12px; border-radius: 8px; background: #172033; font-size: 10px; }
body .recipe-tile-foot > span:first-child { display: none; }
body .recipe-tile-foot b { color: #7d879b; font-size: 10px; }
body .recipe-tile-actions { display: flex; gap: 6px; margin-top: 7px; }
body .recipe-tile-actions button { min-height: 30px; height: 30px; border-radius: 8px; font-size: 10px; }
body .submit-to-common { min-height: 30px; height: 30px; margin-top: 7px; border-radius: 8px; font-size: 10px; }
body .recipe-add-card { display: flex; align-items: center; flex-direction: column; justify-content: center; border: 1px dashed #d6dde8; background: #f8fafd; text-align: center; }
body .recipe-add-card:hover { border-color: #9aa7ff; background: #f0f1ff; transform: translateY(-2px); }
body .recipe-add-icon { display: grid; place-items: center; width: 60px; height: 60px; border-radius: 50%; background: #fff; color: #8a95a7; font-size: 34px; }
body .recipe-add-card h3 { margin: 18px 0 5px; font-size: 16px; }
body .recipe-add-card p { margin: 0; color: #7d879b; font-size: 11px; }
body .recipe-add-card .primary { min-height: 32px; height: 32px; margin-top: 18px; border-radius: 9px; padding: 0 14px; font-size: 11px; }

@media (max-width: 800px) {
  body .recipe-toolbar { grid-template-columns: 1fr 1fr; }
  body .recipe-toolbar input { grid-column: 1 / -1; }
  body .recipe-toolbar .subtle { justify-self: start; }
}
@media (max-width: 560px) {
  body .recipe-toolbar { grid-template-columns: 1fr; padding: 12px; }
  body .recipe-categories { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
  body .recipe-grid { grid-template-columns: 1fr; }
}

/* Popup sheet: entity accents and the shared 630×332 view shell. */
body dialog {
  position: relative;
  width: min(630px, calc(100vw - 32px));
  min-height: 0;
  max-height: min(820px, calc(100vh - 32px));
  overflow: hidden auto;
  border: 1px solid #e5eaf2;
  border-radius: 22px;
  background: #fff;
  box-shadow: 0 18px 50px #15233d1c;
}
body dialog.recipe-dialog { width: min(900px, calc(100vw - 32px)); }
body dialog::before { content: ''; position: sticky; z-index: 2; display: block; width: 100%; height: 6px; margin-bottom: -6px; background: #6f82ff; }
body dialog > form,
body dialog > .dialog-panel { padding: 30px 32px; }
body dialog > form { margin: 0; }
body dialog .modal-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; margin-bottom: 22px; padding-top: 4px; }
body dialog .modal-head > div { min-width: 0; }
body dialog .modal-head .eyebrow { display: inline-flex; align-items: center; min-height: 26px; margin: 0 0 14px; padding: 0 12px; border-radius: 8px; background: #f0f1ff; color: #6f82ff; font-size: 10px; font-weight: 800; letter-spacing: .08em; }
body dialog .modal-head h2 { margin: 0; color: #172033; font-size: 20px; line-height: 1.2; letter-spacing: -.03em; }
body dialog .modal-head .icon { flex: 0 0 36px; width: 36px; min-width: 36px; height: 36px; min-height: 36px; border-radius: 10px; background: #f6f8fc; color: #172033; font-size: 20px; }
body dialog .modal-head .icon:hover { background: #eaf2ff; color: #6f82ff; }
body dialog .actions { display: flex; align-items: center; justify-content: flex-end; gap: 10px; margin-top: 24px; padding-top: 18px; border-top: 1px solid #edf0f5; }
body dialog .actions button { min-width: 96px; }
body dialog .field { gap: 7px; }
body dialog .field label,
body dialog .field > span { color: #172033; font-size: 11px; font-weight: 800; }
body dialog .field input,
body dialog .field select,
body dialog .field textarea { width: 100%; }
body dialog .recipe-meta { margin: -8px 0 18px; }
body dialog .recipe-actions,
body dialog .article-detail-actions { display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 20px; }
body dialog .recipe-actions button,
body dialog .article-detail-actions button { min-height: 34px; height: 34px; border-radius: 9px; padding: 0 12px; font-size: 11px; }
body dialog .recipe-kpis { gap: 8px; }
body dialog .recipe-kpis > div { padding: 11px; border: 1px solid #edf0f5; border-radius: 10px; background: #f8fafd; }
body dialog .exercise-detail-section,
body dialog .workout-detail-section,
body dialog .diary-entry-detail { padding-top: 16px; border-top: 1px solid #edf0f5; }
body dialog .exercise-variant-detail { border-radius: 10px; background: #f8fafd; }
body dialog .confirm-message { margin: 0; padding: 16px; border-radius: 12px; background: #f6f8fc; color: #7d879b; line-height: 1.55; }

body dialog.popup-article::before { background: #4b9db0; }
body dialog.popup-article .modal-head .eyebrow { background: #dff2f7; color: #4b9db0; }
body dialog.popup-recipe::before,
body dialog.popup-complex::before,
body dialog.popup-progress::before { background: #7ddba8; }
body dialog.popup-recipe .modal-head .eyebrow,
body dialog.popup-complex .modal-head .eyebrow,
body dialog.popup-progress .modal-head .eyebrow { background: #e2f7eb; color: #329a63; }
body dialog.popup-product::before,
body dialog.popup-exercise::before { background: #f4b96b; }
body dialog.popup-product .modal-head .eyebrow,
body dialog.popup-exercise .modal-head .eyebrow { background: #fff1de; color: #c88731; }
body dialog.popup-equipment::before { background: #6f82ff; }
body dialog.popup-equipment .modal-head .eyebrow { background: #f0f1ff; color: #6f82ff; }
body dialog.popup-workout::before,
body dialog.popup-diary::before { background: #6f82ff; }
body dialog.popup-workout .modal-head .eyebrow,
body dialog.popup-diary .modal-head .eyebrow { background: #f0f1ff; color: #6f82ff; }
body dialog.popup-food-day::before { background: #172033; }
body dialog.popup-food-day .modal-head .eyebrow { background: #f6f8fc; color: #7d879b; }
body dialog.popup-default::before { background: #6f82ff; }

@media (max-width: 640px) {
  body dialog > form,
  body dialog > .dialog-panel { padding: 24px 20px; }
  body dialog .modal-head h2 { font-size: 18px; }
  body dialog .actions { align-items: stretch; flex-direction: column-reverse; }
  body dialog .actions button { width: 100%; }
}

/* Products page v3: category cards and full product cards. */
body .product-catalog-layout { display: flex; flex-direction: column; gap: 0; }
body .product-toolbar { order: 1; display: grid; grid-template-columns: minmax(260px, 1fr) 174px auto; gap: 10px; min-height: 70px; margin: 0 0 24px; padding: 15px 24px; border: 1px solid #e5eaf2; border-radius: 16px; background: #fff; }
body .product-toolbar input,
body .product-toolbar select { min-width: 0; height: 40px; min-height: 40px; border: 0; border-radius: 10px; background: #f6f8fc; color: #7d879b; }
body .product-toolbar .subtle { justify-self: end; white-space: nowrap; }
body .product-toolbar .reset-sort { display: none; }
body .product-catalog-layout > .product-categories { order: 2; display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px; margin: 0 0 26px; padding: 0; border: 0; }
body .product-catalog-layout .product-category-card { display: grid; grid-template-columns: 42px minmax(0, 1fr); grid-template-rows: 1fr auto; min-height: 78px; padding: 12px 14px; border: 1px solid #e5eaf2; border-radius: 16px; background: #fff; box-shadow: none; }
body .product-catalog-layout .product-category-card:hover { border-color: #aab6ff; background: #fbfcff; box-shadow: 0 8px 20px #1720330d; transform: translateY(-1px); }
body .product-catalog-layout .product-category-card.active { border-color: #6f82ff; background: #eef0ff; box-shadow: 0 0 0 2px #6f82ff20; }
body .product-catalog-layout .product-category-photo { width: 40px; height: 40px; }
body .product-catalog-layout .product-category-photo::before { width: 40px; height: 40px; }
body .product-catalog-layout .product-category-copy { grid-column: 2; padding: 0; }
body .product-catalog-layout .product-category-copy b { font-size: 12px; line-height: 1.2; }
body .product-catalog-layout .product-category-copy small { margin-top: 4px; font-size: 10px; }
body .product-catalog-layout .product-category-card > strong { grid-column: 2; grid-row: 2; justify-self: start; align-self: end; padding: 0; background: transparent; color: #6f82ff; box-shadow: none; font-size: 11px; }
body .product-catalog-layout .product-category-card.all.active { background: #eef0ff; }
body .product-catalog-layout .product-category-card.all-products-photo { background: #fff; }
body .product-catalog-layout .product-category-card.all-products-photo::after { content: '✦'; color: #6f82ff; font-size: 21px; }
body .product-catalog-layout .product-category-card.add-category-card { border-style: dashed; background: #f8fafd; }
body .product-catalog-layout .product-category-card.add-category-card .product-category-photo { display: grid; place-items: center; background: #eef0ff; color: #6f82ff; font-size: 22px; }
body .product-results-head { order: 2; display: flex; align-items: center; justify-content: space-between; gap: 16px; margin: 0 0 14px; }
body .product-results-head h2 { margin: 0; font-size: 18px; }
body .product-results-head span { color: #7d879b; font-size: 12px; }
body .product-catalog-layout > .product-grid { order: 3; display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; overflow: visible; border: 0; border-radius: 0; background: transparent; }
body .product-catalog-layout .product-table-head { display: none; }
body .product-catalog-layout .product-tile {
  display: flex;
  flex-direction: column;
  min-height: 312px;
  padding: 14px;
  border: 1px solid #e5eaf2;
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 8px 28px #15233d12;
}
body .product-catalog-layout .product-tile:hover { border-color: #9aa7ff; box-shadow: 0 12px 30px #15233d18; transform: translateY(-2px); }
body .product-catalog-layout .product-tile .product-cover { display: flex; align-items: center; justify-content: center; height: 96px; min-height: 96px; margin: -14px -14px 0; border-radius: 18px 18px 12px 12px; }
body .product-catalog-layout .product-cover-label { top: 12px; left: 14px; padding: 4px 7px; border-radius: 8px; font-size: 10px; }
body .product-catalog-layout .product-cover-icon { width: 54px; height: 54px; }
body .product-catalog-layout .product-cover-icon.product-sprite::before { width: 50px; height: 50px; }
body .product-catalog-layout .product-tile-head { display: none; }
body .product-catalog-layout .product-tile-category { display: block !important; margin: 15px 0 0; color: #d88927; font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
body .product-catalog-layout .product-tile h3 { margin: 7px 0 4px; font-size: 16px; line-height: 1.25; }
body .product-catalog-layout .product-tile > p { min-height: 18px; margin: 0; overflow: hidden; color: #7d879b; font-size: 11px; text-overflow: ellipsis; white-space: nowrap; }
body .product-catalog-layout .product-tile .product-macros { grid-template-columns: repeat(3, 1fr); gap: 0; margin: 13px 0 0; padding-top: 12px; border-top: 1px solid #e5eaf2; }
body .product-catalog-layout .product-tile .product-macros::before { display: none; }
body .product-catalog-layout .product-tile .product-macros span { padding: 0; background: transparent; text-align: left; }
body .product-catalog-layout .product-tile .product-macros span:nth-child(4) { display: none; }
body .product-catalog-layout .product-tile .product-macros b { color: #172033; font-size: 14px; }
body .product-catalog-layout .product-tile .product-macros span:first-child b { color: #6f82ff; }
body .product-catalog-layout .product-tile .product-macros small { margin-top: 3px; font-size: 8px; }
body .product-catalog-layout .product-tile .product-tile-foot { display: flex; align-items: center; justify-content: flex-start; gap: 8px; margin-top: auto; padding-top: 9px; border-top: 0; }
body .product-catalog-layout .product-tile .product-tile-foot span { overflow: hidden; color: #7d879b; font-size: 10px; text-overflow: ellipsis; white-space: nowrap; }
body .product-catalog-layout .product-tile .product-tile-foot b { color: #7d879b; font-size: 10px; white-space: nowrap; }
body .product-catalog-layout .product-tile .product-tile-actions { display: flex; gap: 8px; min-height: 28px; margin-top: 8px; }
body .product-catalog-layout .product-tile .product-tile-actions button { min-height: 28px; height: 28px; border-radius: 8px; padding: 0 11px; font-size: 10px; }
body .product-add-card { grid-column: 1 / -1; display: grid; grid-template-columns: 44px minmax(0, 1fr) auto; align-items: center; gap: 16px; min-height: 76px; padding: 14px 24px; border: 1px dashed #d9e2ff; border-radius: 18px; background: #f8faff; }
body .product-add-card:hover { border-color: #9aa7ff; background: #f0f1ff; }
body .product-add-icon { display: grid; place-items: center; width: 44px; height: 44px; border-radius: 50%; background: #eef0ff; color: #6f82ff; font-size: 24px; }
body .product-add-card b, body .product-add-card small { display: block; }
body .product-add-card b { font-size: 16px; }
body .product-add-card small { margin-top: 4px; color: #7d879b; font-size: 11px; }
body .product-add-card .primary { min-height: 38px; height: 38px; border-radius: 10px; font-size: 11px; }

@media (max-width: 800px) {
  body .product-toolbar { grid-template-columns: minmax(0, 1fr) 174px; }
  body .product-toolbar input { grid-column: 1 / -1; }
  body .product-toolbar .subtle { justify-self: start; }
}
@media (max-width: 560px) {
  body .product-toolbar { grid-template-columns: 1fr; padding: 12px; }
  body .product-catalog-layout > .product-categories { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
  body .product-catalog-layout > .product-grid { grid-template-columns: 1fr; }
  body .product-add-card { grid-template-columns: 40px minmax(0, 1fr); padding: 14px; }
  body .product-add-card .primary { grid-column: 1 / -1; justify-self: start; }
}

/* Popup v2: view, form, delete-confirmation and action-menu states. */
body dialog.popup-view { width: min(630px, calc(100vw - 32px)); }
body dialog.popup-form { width: min(668px, calc(100vw - 32px)); }
body dialog.popup-form > form,
body dialog.popup-form > .dialog-panel { padding: 34px 40px; }
body dialog.popup-form .modal-head { padding-bottom: 18px; border-bottom: 1px solid #edf0f5; }
body dialog.popup-form .modal-head h2 { font-size: 20px; }
body dialog.popup-form .modal-head .eyebrow { display: none; }
body dialog.popup-form .field input,
body dialog.popup-form .field select,
body dialog.popup-form .field textarea { min-height: 46px; border-color: #dde3ec; border-radius: 10px; }
body dialog.popup-form .field textarea { min-height: 110px; }
body dialog.popup-form .actions { margin-top: 22px; padding-top: 0; border-top: 0; }
body dialog.popup-form .danger-button { align-self: flex-start; margin-right: auto; }

body dialog.popup-delete,
body dialog.popup-confirm { width: min(470px, calc(100vw - 32px)); }
body dialog.popup-delete::before,
body dialog.popup-confirm::before { background: #d56666; }
body dialog.popup-delete > .dialog-panel,
body dialog.popup-confirm > .dialog-panel { padding: 34px 32px 30px; }
body dialog.popup-delete .modal-head .eyebrow,
body dialog.popup-confirm .modal-head .eyebrow { background: #fff0ed; color: #d56666; }
body dialog.popup-delete .modal-head h2,
body dialog.popup-confirm .modal-head h2 { font-size: 20px; }
body dialog.popup-delete .confirm-message,
body dialog.popup-confirm .confirm-message { margin: 0; padding: 0; background: transparent; }
body dialog.popup-delete .actions,
body dialog.popup-confirm .actions { margin-top: 26px; padding-top: 0; border-top: 0; }
body dialog.popup-delete .actions .danger-button,
body dialog.popup-confirm .actions .danger-button { min-width: 144px; background: #d56666 !important; color: #fff !important; }

body dialog.popup-actions { width: min(286px, calc(100vw - 32px)); border-radius: 16px; }
body dialog.popup-actions::before { background: #6f82ff; }
body dialog.popup-actions > .dialog-panel { padding: 28px; }
body dialog.popup-actions .modal-head { display: block; margin-bottom: 10px; padding-bottom: 12px; border-bottom: 1px solid #edf0f5; }
body dialog.popup-actions .modal-head .eyebrow { display: block; overflow: hidden; margin-bottom: 0; padding: 0; background: transparent; color: #7d879b; text-overflow: ellipsis; white-space: nowrap; }
body dialog.popup-actions .modal-head h2,
body dialog.popup-actions .modal-head .icon { display: none; }
body dialog.popup-actions .popup-action-list { display: grid; gap: 4px; }
body dialog.popup-actions .popup-action-list button { justify-content: flex-start; width: 100%; min-height: 40px; border: 0; border-radius: 9px; background: transparent; color: #172033; text-align: left; }
body dialog.popup-actions .popup-action-list button:hover { background: #f6f8fc; color: #6f82ff; }
body dialog.popup-actions .popup-action-list .danger-button { color: #d56666 !important; }

body dialog.popup-food-day.recipe-dialog { width: min(1328px, calc(100vw - 32px)); }
body dialog.popup-food-day > .dialog-panel { padding: 38px 40px; }
body dialog.popup-food-day .modal-head { margin-bottom: 20px; }
body dialog.popup-food-day .day-total { border-radius: 18px; }
body dialog.popup-food-day .meal-entry { min-height: 78px; border-color: #dde3ec; border-radius: 12px; }
body dialog.popup-food-day .diary-entry-actions { min-height: 38px; }

/* Food Calendar day popup from astra-diary-calendar-popup.svg. */
body dialog.popup-food-day.recipe-dialog { width: min(900px, calc(100vw - 32px)); max-height: calc(100vh - 48px); }
body dialog.popup-food-day.recipe-dialog > .dialog-panel { padding: 0 36px 18px; }
body dialog.popup-food-day.recipe-dialog .modal-head { margin: 0; padding: 30px 0 20px; }
body dialog.popup-food-day.recipe-dialog .modal-head h2 { font-size: 26px; letter-spacing: -.04em; }
body dialog.popup-food-day.recipe-dialog .calendar-shell { padding: 0; }
body .diary-day-summary { display: grid; grid-template-columns: minmax(0, 1fr) auto; align-items: center; gap: 20px; min-height: 62px; margin-bottom: 28px; padding: 13px 28px; border-radius: 14px; background: #f6f8fc; }
body .diary-day-summary span { display: block; margin-bottom: 5px; color: #7d879b; font-size: 10px; font-weight: 800; letter-spacing: 1px; }
body .diary-day-summary b { display: block; color: #172033; font-size: 13px; }
body .diary-day-edit { border: 0; background: transparent; color: #6f82ff; font-size: 11px; font-weight: 800; cursor: pointer; }
body .diary-popup-meal-group { margin-bottom: 26px; }
body .diary-popup-meal-group h3 { justify-content: flex-start; gap: 6px; margin-bottom: 10px; font-size: 18px; }
body .diary-popup-meal-group .meal-cost { padding: 0; background: transparent; color: #7d879b; font-size: 11px; font-weight: 550; }
body dialog.popup-food-day .meal-entry { min-height: 72px; margin: 0 0 8px; padding: 14px 28px; border-color: #e5eaf2; border-radius: 12px; }
body dialog.popup-food-day .meal-entry::before { content: ''; width: 30px; height: 30px; flex: 0 0 30px; border-radius: 50%; background: #e2f7eb; }
body dialog.popup-food-day .meal-entry > span { flex: 1; }
body dialog.popup-food-day .meal-entry > span b { font-size: 13px; }
body dialog.popup-food-day .meal-entry > span small { font-size: 11px; }
body dialog.popup-food-day .meal-entry > strong { min-width: 80px; font-size: 13px; text-align: right; }
body dialog.popup-food-day .diary-entry-actions { margin: -4px 0 8px 66px; }
body .diary-calendar-add { display: block; width: 100%; min-height: 36px; border: 1px solid #79a8ff; border-radius: 10px; background: #eaf2ff; color: #6f82ff; font-size: 11px; font-weight: 800; cursor: pointer; }
body .diary-calendar-add:hover { background: #dceaff; }
body .diary-popup-nutrients { margin-top: 20px; padding: 28px; border-radius: 16px; background: #172033; }
body .diary-popup-nutrients h3 { margin: 0 0 14px; color: #bdf2d3; font-size: 10px; letter-spacing: 1px; text-transform: uppercase; }
body .diary-popup-nutrients > div { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
body .diary-popup-nutrients > div span { display: grid; gap: 6px; min-height: 54px; padding: 11px 16px; border-radius: 10px; background: #222d42; text-align: left; }
body .diary-popup-nutrients > div b { font-size: 13px; }
body .diary-popup-nutrients > div small { color: #aab6c8; font-size: 10px; }
body .diary-popup-nutrients .nutrient-protein { background: #e2f7eb; color: #172033; }
body .diary-popup-nutrients .nutrient-protein small { color: #329a63; }
body .diary-popup-nutrients .nutrient-fat { border: 1px solid #ffb4aa; background: #fff1f0; color: #d55555; }
body .diary-popup-nutrients .nutrient-fat small { color: #d55555; }
body .diary-popup-footer { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 24px; }
body .diary-popup-footer .secondary-button { min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }
body .diary-popup-footer .primary { min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }

/* Diary page v4: Food Calendar dashboard, nutrition widget and monthly calendar. */
body .diary-page-subtitle { margin: -20px 0 26px; }
body .diary-current-day { margin-bottom: 42px; }
body .diary-current-banner { display: grid; grid-template-columns: minmax(260px, 1fr) auto auto; align-items: center; gap: 34px; min-height: 104px; padding: 24px 32px; border-radius: 18px; background: #172033; color: #fff; box-shadow: 0 18px 40px #17203318; }
body .diary-current-banner .eyebrow { margin: 0 0 8px; color: #bdf2d3; }
body .diary-current-banner h2 { margin: 0; color: #fff; font-size: 20px; }
body .diary-current-stats { display: flex; gap: 48px; }
body .diary-current-stats span { display: grid; gap: 4px; min-width: 130px; }
body .diary-current-stats small { color: #aab6c8; font-size: 11px; }
body .diary-current-stats b { font-size: 23px; line-height: 1.1; }
body .today-badge { min-height: 36px; padding: 0 16px; border: 0; border-radius: 9px; background: #bdf2d3; color: #172033; font-size: 11px; font-weight: 800; cursor: pointer; }
body .diary-widget-heading { margin: 0 0 20px; }
body .diary-widget-heading h2, body .diary-average-heading h2 { margin: 0 0 5px; font-size: 19px; }
body .diary-widget-heading p, body .diary-average-heading p { margin: 0; color: #7d879b; font-size: 12px; }
body .diary-current-grid { display: grid; grid-template-columns: minmax(0, 2.38fr) minmax(260px, 1fr); gap: 28px; }
body .diary-meals-card, body .diary-norm-card { min-height: 506px; padding: 32px; border: 1px solid #e5eaf2; border-radius: 20px; background: #fff; }
body .diary-meals-card > .eyebrow { margin: 0 0 7px; }
body .diary-meals-card > h2, body .diary-norm-card h2 { margin: 0 0 18px; font-size: 19px; }
body .diary-meal-list { display: grid; gap: 14px; }
body .diary-meal-card { display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; align-items: center; gap: 16px; min-height: 76px; padding: 15px 16px; border: 1px solid #dde3ec; border-radius: 14px; background: #fff; }
body .diary-meal-card:nth-child(even) { background: #f6f8fc; }
body .diary-meal-icon { display: grid; place-items: center; width: 32px; height: 32px; border-radius: 50%; background: #e2f7eb; color: #329a63; font-size: 13px; font-weight: 800; }
body .diary-meal-card:nth-child(2) .diary-meal-icon { background: #f0f1ff; color: #6f82ff; }
body .diary-meal-card:nth-child(3) .diary-meal-icon { background: #fff1de; color: #d88927; }
body .diary-meal-card > div { min-width: 0; }
body .diary-meal-card b, body .diary-meal-card small, body .diary-meal-card p { display: block; }
body .diary-meal-card b { font-size: 14px; }
body .diary-meal-card small { margin-top: 3px; color: #7d879b; font-size: 11px; }
body .diary-meal-card p { overflow: hidden; margin: 7px 0 0; color: #172033; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
body .diary-meal-card > strong { display: grid; gap: 4px; min-width: 92px; color: #172033; font-size: 13px; text-align: right; }
body .diary-meal-card > strong small { font-weight: 500; }
body .diary-meal-empty { background: #f6f8fc !important; }
body .diary-add-meal { min-height: 36px; padding: 0 13px; border: 0; border-radius: 10px; background: #e2f7eb; color: #329a63; font-size: 11px; font-weight: 800; cursor: pointer; }
body .diary-norm-card > p { margin: -10px 0 20px; color: #7d879b; font-size: 11px; }
body .diary-norm-item { display: grid; gap: 8px; margin-top: 14px; padding: 24px; border-radius: 14px; }
body .diary-norm-item span { font-size: 10px; font-weight: 800; letter-spacing: 1px; }
body .diary-norm-item b { font-size: 17px; }
body .diary-norm-item small { font-size: 11px; }
body .diary-norm-item i { display: block; height: 7px; overflow: hidden; border-radius: 4px; background: #e5e9f4; }
body .diary-norm-item i em { display: block; height: 100%; border-radius: inherit; background: #6f82ff; }
body .diary-norm-item.norm-kcal { background: #f5f6ff; color: #172033; }
body .diary-norm-item.norm-kcal span, body .diary-norm-item.norm-kcal small { color: #6f82ff; }
body .diary-norm-item.norm-protein { background: #f4fbf7; }
body .diary-norm-item.norm-protein span { color: #329a63; }
body .diary-norm-item.norm-protein i { background: #ddeee3; }
body .diary-norm-item.norm-protein i em { background: #329a63; }
body .diary-norm-item.norm-fat { background: #fff1f0; border: 1px solid #ffb4aa; }
body .diary-norm-item.norm-fat span, body .diary-norm-item.norm-fat small { color: #d55555; }
body .diary-norm-item.norm-fat i { background: #f2d7d4; }
body .diary-norm-item.norm-fat i em { background: #d55555; }

body .diary-month-head { margin-top: 56px; }
body .diary-calendar-heading { align-items: center; margin-bottom: 20px; }
body .diary-calendar-heading > div:first-child p { margin: 0; color: #7d879b; font-size: 12px; }
body .diary-calendar-heading h2 { margin-bottom: 5px; }
body .diary-calendar-actions { display: flex; gap: 8px; }
body .diary-calendar-actions .change-month { min-width: 44px; min-height: 36px; padding: 0 12px; }
body .diary-calendar-actions .primary { min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }
body .diary-average-heading { display: flex; align-items: end; justify-content: space-between; gap: 20px; margin: 30px 0 20px; }
body .diary-average-heading > span { color: #7d879b; font-size: 11px; }
body .diary-average-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 28px; }
body .diary-average-card { position: relative; min-height: 178px; padding: 32px; overflow: hidden; border-radius: 20px; }
body .diary-average-card > span { display: block; font-size: 10px; font-weight: 800; letter-spacing: 1px; }
body .diary-average-card > b { display: block; margin-top: 18px; font-size: 27px; line-height: 1; }
body .diary-average-card > small { display: block; margin-top: 8px; font-size: 11px; }
body .diary-average-card > strong { position: absolute; top: 68px; right: 32px; font-size: 14px; }
body .diary-average-card svg { display: block; width: 100%; height: 54px; margin-top: 10px; }
body .diary-average-card svg path { fill: none; stroke: currentColor; stroke-dasharray: 3 5; opacity: .35; }
body .diary-average-card svg polyline { fill: none; stroke: currentColor; stroke-width: 3; stroke-linecap: round; stroke-linejoin: round; }
body .average-kcal { background: #172033; color: #fff; }
body .average-kcal > span, body .average-kcal > strong { color: #bdf2d3; }
body .average-kcal > small { color: #aab6c8; }
body .average-kcal svg { color: #6f82ff; }
body .average-protein { border: 1px solid #c5ebd4; background: #e2f7eb; color: #172033; }
body .average-protein > span, body .average-protein > strong { color: #329a63; }
body .average-protein > small { color: #7d879b; }
body .average-protein svg { color: #329a63; }

body .diary-days-panel { margin-top: 20px; padding: 18px 16px 16px; border-radius: 20px; }
body .diary-weekdays, body .diary-day-grid { grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 16px; }
body .diary-weekdays { padding: 0 16px 10px; }
body .diary-day-card { display: grid; align-content: center; grid-template-columns: 1fr; gap: 4px; min-height: 64px; padding: 10px 16px; border-radius: 12px; text-align: left; }
body .diary-day-card .diary-day-copy b, body .diary-day-card .diary-day-copy small { display: block; }
body .diary-day-card .diary-day-copy b { color: #7d879b; font-size: 11px; font-weight: 600; }
body .diary-day-card .diary-day-copy small { margin-top: 2px; color: #7d879b; font-size: 10px; }
body .diary-day-card .diary-day-number { color: #172033; font-size: 16px; font-weight: 800; }
body .diary-day-card .diary-day-arrow { display: none; }
body .diary-day-card.complete { background: #e2f7eb; border-color: transparent; }
body .diary-day-card.complete .diary-day-number { color: #329a63; }
body .diary-day-card.partial { background: #fff1de; border-color: transparent; }
body .diary-day-card.partial .diary-day-number { color: #d88927; }
body .diary-day-card.empty { background: #f6f8fc; border-color: transparent; }
body .diary-day-card.today { background: #eef0ff; border: 2px solid #6f82ff; }
body .diary-day-card.today .diary-day-number { color: #6f82ff; }

@media (max-width: 1000px) {
  body .diary-current-banner { grid-template-columns: 1fr auto; gap: 18px; }
  body .diary-current-stats { grid-column: 1 / -1; grid-row: 2; justify-content: space-between; }
  body .diary-current-grid { grid-template-columns: 1fr; }
  body .diary-norm-card { min-height: auto; }
}
@media (max-width: 700px) {
  body .diary-current-banner { padding: 22px; }
  body .diary-current-stats { gap: 18px; }
  body .diary-current-stats b { font-size: 18px; }
  body .diary-meals-card, body .diary-norm-card { padding: 20px; }
  body .diary-meal-card { grid-template-columns: 32px minmax(0, 1fr); }
  body .diary-meal-card > strong { grid-column: 2; text-align: left; }
  body .diary-meal-card > .diary-add-meal { grid-column: 2; justify-self: start; }
  body .diary-average-grid { grid-template-columns: 1fr; gap: 14px; }
  body .diary-calendar-heading { align-items: flex-start; flex-direction: column; }
  body .diary-calendar-actions { width: 100%; }
  body .diary-calendar-actions .change-month:nth-child(2) { flex: 1; }
  body .diary-average-card { padding: 24px; }
  body .diary-weekdays, body .diary-day-grid { gap: 5px; }
  body .diary-days-panel { padding-inline: 8px; overflow-x: auto; }
body .diary-weekdays, body .diary-day-grid { min-width: 620px; }
}

/* Progress page v3: key indicators, weight chart and compact measurement history. */
body .progress-stat-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 22px; }
body .progress-stat-card { min-height: 132px; padding: 28px; border: 1px solid #e5eaf2; border-radius: 18px; background: #fff; }
body .progress-stat-card > span { display: block; color: #7d879b; font-size: 10px; font-weight: 800; letter-spacing: 1px; }
body .progress-stat-card > b { display: block; margin-top: 24px; color: #172033; font-size: 30px; line-height: 1; letter-spacing: -.05em; }
body .progress-stat-card > b i { font-size: 15px; font-style: normal; letter-spacing: 0; }
body .progress-stat-card > small { display: block; margin-top: 10px; color: #7d879b; font-size: 11px; }
body .progress-stat-card > small.positive { color: #329a63; font-weight: 800; }
body .progress-stat-card > small.negative { color: #d55555; font-weight: 800; }
body .progress-stat-card > small.blue-note { color: #6f82ff; font-weight: 800; }
body .progress-stat-card.wellbeing-stat { border-color: #c5ebd4; background: #e2f7eb; }
body .progress-stat-card.wellbeing-stat > span { color: #329a63; }
body .progress-overview-grid { display: grid; grid-template-columns: minmax(0, 2.65fr) minmax(260px, 1fr); gap: 28px; margin-top: 40px; }
body .progress-chart-card { min-height: 420px; padding: 32px; border: 1px solid #e5eaf2; border-radius: 20px; background: #fff; }
body .progress-section-head { display: flex; align-items: start; justify-content: space-between; gap: 18px; }
body .progress-section-head h2 { margin: 0 0 4px; font-size: 19px; }
body .progress-section-head p, body .progress-section-head > span { margin: 0; color: #7d879b; font-size: 11px; }
body .progress-chart-wrap { display: grid; grid-template-columns: 28px minmax(0, 1fr); grid-template-rows: 190px 22px; gap: 6px 12px; margin-top: 30px; }
body .progress-chart-y { display: flex; flex-direction: column; justify-content: space-between; align-items: center; color: #7d879b; font-size: 10px; }
body .progress-chart { width: 100%; height: 190px; overflow: visible; }
body .chart-grid-line { fill: none; stroke: #eef1f6; stroke-width: 1; }
body .chart-area { fill: #6f82ff; opacity: .08; }
body .chart-line { fill: none; stroke: #6f82ff; stroke-width: 4; stroke-linecap: round; stroke-linejoin: round; }
body .chart-dot { fill: #6f82ff; }
body .progress-chart-x { grid-column: 2; display: flex; justify-content: space-between; color: #7d879b; font-size: 10px; }
body .progress-chart-empty { display: grid; min-height: 250px; place-items: center; color: #7d879b; text-align: center; }
body .progress-latest-card { min-height: 420px; padding: 32px 30px; border-radius: 20px; background: #172033; color: #fff; }
body .progress-latest-card .eyebrow { margin: 0 0 22px; color: #bdf2d3; }
body .progress-latest-card h2 { margin: 0 0 26px; color: #fff; font-size: 19px; }
body .progress-latest-card dl { margin: 0; }
body .progress-latest-card dl > div { display: flex; justify-content: space-between; gap: 12px; padding: 14px 0; border-bottom: 1px solid #344057; }
body .progress-latest-card dt { color: #aab6c8; font-size: 11px; }
body .progress-latest-card dd { margin: 0; color: #fff; font-size: 13px; font-weight: 800; }
body .progress-latest-edit { width: 100%; min-height: 38px; margin-top: 24px; border: 0; border-radius: 10px; background: #bdf2d3; color: #172033; font-size: 11px; font-weight: 800; cursor: pointer; }
body .progress-details-link { margin-top: 18px; padding: 0; border: 0; background: transparent; color: #bdf2d3; font-size: 11px; cursor: pointer; }
body .progress-history-head { align-items: end; margin-top: 56px; }
body .progress-history-head h3 { margin: 0 0 5px; font-size: 19px; }
body .progress-history-head .eyebrow { margin: 0; }
body .progress-history-head + .toolbar { margin-top: 18px; }
body .progress-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; margin-top: 16px; }
body .progress-tile { min-height: 274px; padding: 28px; border-radius: 18px; background: #fff; }
body .progress-tile-head { align-items: center; padding-bottom: 14px; border-bottom: 1px solid #e5eaf2; }
body .progress-tile-head strong { color: #172033; font-size: 14px; }
body .progress-tile-head > span { padding: 4px 9px; border-radius: 99px; background: #f0ecff; color: #6e5dc6; font-size: 9px; font-weight: 800; letter-spacing: 1px; }
body .progress-history-rows { display: grid; gap: 0; margin: 10px 0 22px; }
body .progress-history-rows > div { display: flex; justify-content: space-between; gap: 14px; padding: 7px 0; }
body .progress-history-rows span { color: #7d879b; font-size: 11px; }
body .progress-history-rows b { color: #172033; font-size: 12px; }
body .progress-tile-actions { grid-template-columns: minmax(0, 1fr) 78px 62px; gap: 8px; min-height: 30px; }
body .progress-tile-actions button { min-height: 30px; height: 30px; padding: 0 8px; border-radius: 8px; font-size: 10px; }
body .progress-tile-actions .progress-open-button { border: 1px solid #79a8ff; background: #eaf2ff; color: #6f82ff; }
body .progress-tile-actions .progress-open-button:only-child { grid-column: 1 / -1; }
body .progress-tile-actions .progress-open-button { border-color: #172033; background: #172033; color: #fff; }
body .progress-latest-edit { background: #bdf2d3; color: #172033; }
body .progress-add-card { display: grid; min-height: 274px; place-items: center; align-content: center; padding: 24px; border: 1px dashed #d9e2ff; border-radius: 18px; background: #f8faff; text-align: center; }
body .progress-add-card:hover { border-color: #9aa7ff; background: #f0f1ff; }
body .progress-add-icon { display: grid; place-items: center; width: 56px; height: 56px; border-radius: 50%; background: #eef0ff; color: #6f82ff; font-size: 30px; }
body .progress-add-card h3 { margin: 16px 0 5px; font-size: 16px; }
body .progress-add-card p { margin: 0; color: #7d879b; font-size: 11px; }
body .progress-add-card .primary { min-height: 36px; height: 36px; margin-top: 20px; border-radius: 10px; font-size: 11px; }
body .progress-tip { display: grid; gap: 5px; margin-top: 48px; padding: 28px 32px; border-radius: 18px; background: #e2f7eb; }
body .progress-tip span { color: #329a63; font-size: 10px; font-weight: 800; letter-spacing: 1px; }
body .progress-tip b { color: #172033; font-size: 16px; }
body .progress-tip small { color: #7d879b; font-size: 11px; }

/* Card action rule: one primary action, all secondary actions are icon actions. */
body .icon-action { display: inline-grid; place-items: center; width: 36px; min-width: 36px; height: 36px; min-height: 36px; padding: 0; border: 1px solid #d9e2ec; border-radius: 10px; background: #f6f8fc; color: #172033; font-size: 16px; line-height: 1; cursor: pointer; }
body .icon-action:hover, body .icon-action:focus-visible { border-color: #6f82ff; background: #eef0ff; color: #6f82ff; outline: none; }
body .icon-action.danger-icon { border-color: #f0caca; background: #fff7f7; color: #d55555; }
body .icon-action.danger-icon:hover, body .icon-action.danger-icon:focus-visible { border-color: #d55555; background: #fff0ed; color: #d55555; }
body .card-primary { min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }
body .product-tile .product-tile-actions { display: grid; grid-template-columns: minmax(0, 1fr) 36px; align-items: center; gap: 8px; min-height: 36px; margin-top: 10px; }
body .product-tile .product-tile-actions .card-primary { width: 100%; }
body .recipe-tile .recipe-open-primary { width: 100%; margin-top: 10px; }
body .recipe-tile .submit-to-common { align-self: flex-end; margin-top: 8px; }
body .recipe-tile .recipe-tile-actions { display: flex; justify-content: flex-end; gap: 8px; min-height: 36px; margin-top: 8px; }
body .workout-card-actions { display: flex; justify-content: flex-end; align-items: center; gap: 8px; min-height: 36px; }
body .workout-card-actions .primary { min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }
body .planned-tile-actions .icon-action { margin-left: 0; }
body .workout-complex-actions { display: flex; align-items: center; gap: 8px; }
body .workout-complex-actions .create-complex-button { flex: 1; min-height: 36px; height: 36px; border-radius: 10px; font-size: 11px; }
body .workout-complex-actions .icon-action { flex: 0 0 36px; }
body .exercise-card-actions .primary { flex: 1; }
body .equipment-card-actions .primary { width: 100%; }
body .progress-latest-card .progress-details-link { width: 36px; min-width: 36px; height: 36px; min-height: 36px; margin-top: 18px; padding: 0; border: 1px solid #344057; border-radius: 10px; background: #222d42; color: #bdf2d3; font-size: 16px; }
body .progress-latest-card .progress-details-link:hover { border-color: #bdf2d3; background: #2d3a52; }
body .article-card-primary { width: 100%; margin-top: 12px; }
body .article-card .article-card-actions { display: flex; justify-content: flex-end; gap: 8px; min-height: 36px; margin-top: 8px; }
body .article-card .article-card-actions .icon-action { flex: 0 0 36px; width: 36px; min-height: 36px; height: 36px; padding: 0; }
body .article-card .article-pin-action { top: 15px; right: 15px; width: 36px; min-width: 36px; height: 36px; min-height: 36px; padding: 0; border: 1px solid #d9e2ec; border-radius: 10px; background: #f6f8fc; color: #6f82ff; font-size: 15px; }
body .article-card .article-pin-action.pinned { border-color: #7bc8a4; background: #e3fcef; color: #216e4e; }
body .review-card .review-actions { display: flex; align-items: center; gap: 8px; }
body .review-card .review-actions .icon-action { flex: 0 0 36px; width: 36px; min-width: 36px; padding: 0; }
body .review-card .cancel-submission { display: inline-grid; place-items: center; width: 36px; min-width: 36px; height: 36px; min-height: 36px; padding: 0; border: 1px solid #f0caca; border-radius: 10px; background: #fff7f7; color: #d55555; font-size: 16px; }

@media (max-width: 1050px) {
  body .progress-stat-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  body .progress-overview-grid { grid-template-columns: 1fr; }
  body .progress-latest-card { min-height: auto; }
  body .progress-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 650px) {
  body .progress-stat-grid, body .progress-grid { grid-template-columns: 1fr; }
  body .progress-stat-card, body .progress-chart-card, body .progress-latest-card, body .progress-tile { padding: 22px; }
  body .progress-chart-card { min-height: 350px; }
  body .progress-chart-wrap { margin-top: 22px; }
  body .progress-history-head { align-items: flex-start; flex-direction: column; gap: 8px; }
  body .progress-tip { margin-top: 30px; padding: 22px; }
}

@media (max-width: 700px) {
  body dialog.popup-form > form,
  body dialog.popup-form > .dialog-panel { padding: 26px 20px; }
  body dialog.popup-food-day.recipe-dialog { width: min(630px, calc(100vw - 32px)); }
  body dialog.popup-food-day > .dialog-panel { padding: 26px 20px; }
}

/* Only the navigation aside is fixed. Content cards that use <aside> stay in the page flow. */
body main aside { position: static; inset: auto; width: auto; }

/* Product v3 final layout: never collapse the catalogue into the legacy sidebar/table column. */
body main .product-catalog-layout { display: flex !important; flex-direction: column !important; width: 100% !important; min-width: 0; }
body main .product-catalog-layout > .product-toolbar { order: 1; width: 100%; }
body main .product-catalog-layout > .product-categories { order: 2; display: grid !important; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)) !important; width: 100%; min-width: 0; }
body main .product-catalog-layout > .product-results-head { order: 3; width: 100%; }
body main .product-catalog-layout > .product-grid { order: 4; display: grid !important; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)) !important; width: 100%; min-width: 0; }
body main .product-catalog-layout > .product-grid > .product-tile { display: flex !important; min-width: 0; width: auto; }
body main .product-catalog-layout > .product-grid > .product-add-card { grid-column: 1 / -1; width: auto; }

/* Workout history component sheet: two compact cards beside the history statistics widget. */
body main .archive-history-layout { display: grid !important; grid-template-columns: minmax(0, 1fr) 408px; align-items: start; gap: 24px; width: 100%; min-width: 0; }
body main .archive-history-groups { min-width: 0; }
body main .archive-history-groups .archive-workout-grid { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; gap: 16px !important; }
body main .archive-history-groups .archive-workout-grid .panel.empty { grid-column: 1 / -1; }
body main .history-workout-card { display: flex !important; min-width: 0; width: auto; min-height: 264px !important; height: 264px; padding: 24px !important; border-radius: 18px !important; box-shadow: 0 6px 20px #1720330d; }
body main .history-workout-card .workout-tile-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; min-height: 24px; }
body main .history-workout-card .workout-date { color: var(--v2-ink); font-size: 14px; font-weight: 700; }
body main .history-workout-card .workout-group { flex: 0 0 auto; padding: 5px 9px; border-radius: 999px; font-size: 10px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; }
body main .history-workout-card h3 { display: -webkit-box; min-height: 46px; margin: 18px 0 6px; overflow: hidden; font-size: 19px; line-height: 1.22; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
body main .history-workout-card > p { min-height: 18px; margin: 0; color: var(--v2-muted); font-size: 12px; }
body main .history-workout-card .planned-plan-items { min-height: 52px; max-height: 52px; margin: 16px 0 10px; overflow: hidden; }
body main .history-workout-card .planned-plan-items div { padding: 0; border-top: 1px solid var(--v2-line); background: transparent; }
body main .history-workout-card .planned-plan-items div:first-child { padding-top: 10px; }
body main .history-workout-card .planned-plan-items div:nth-child(n + 2) { display: none; }
body main .history-card-actions { display: flex !important; align-items: center; justify-content: flex-start !important; gap: 10px; min-height: 36px; margin-top: auto; }
body main .history-card-actions .history-details-action { flex: 0 0 36px; }
body main .history-card-actions .edit-workout { flex: 0 0 auto; min-width: 126px; }
body main .history-statistics-card { display: flex; flex-direction: column; min-height: 264px; padding: 24px; border: 0; border-radius: 18px; background: #172033; color: #fff; }
body main .history-statistics-card .eyebrow { margin: 0 0 18px; color: #bdf2d3; }
body main .history-statistics-card h3 { margin: 0; color: #fff; font-size: 20px; line-height: 1.25; }
body main .history-statistics-period { margin: 7px 0 22px; color: #aab6c8; font-size: 12px; }
body main .history-statistics-metrics { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-top: auto; }
body main .history-statistics-metrics > div { min-width: 0; padding: 12px; border-radius: 10px; background: #222d42; }
body main .history-statistics-metrics b { display: block; color: #fff; font-size: 19px; line-height: 1; }
body main .history-statistics-metrics span { display: block; margin-top: 8px; color: #aab6c8; font-size: 9px; font-weight: 800; letter-spacing: .06em; }

@media (max-width: 1100px) {
  body main .archive-history-layout { grid-template-columns: 1fr; }
  body main .history-statistics-card { min-height: 220px; }
}
@media (max-width: 700px) {
  body main .archive-history-groups .archive-workout-grid { grid-template-columns: 1fr !important; }
  body main .history-workout-card { height: auto; min-height: 264px !important; }
  body main .history-statistics-metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}

/* Workout component sheet: equipment and machine cards. */
body main .equipment-grid { grid-template-columns: repeat(auto-fill, minmax(296px, 1fr)) !important; gap: 16px !important; }
body main .equipment-grid > .equipment-card:not(.workout-create-card) { display: flex !important; flex-direction: column; min-width: 0; min-height: 290px !important; height: 290px; padding: 18px !important; border-radius: 18px !important; }
body main .equipment-grid > .equipment-card:not(.workout-create-card)::before { display: none; }
body main .equipment-card-visual { display: grid; flex: 0 0 108px; place-items: center; width: calc(100% + 36px); height: 108px; margin: -18px -18px 0; overflow: hidden; background: #e2f7eb; }
body main .equipment-card-photo { width: 100%; height: 108px; margin: 0; border-radius: 0; object-fit: cover; }
body main .equipment-card-mark { display: grid; place-items: center; width: 100%; height: 108px; margin: 0; border-radius: 0; background: transparent; color: #329a63; font-size: 40px; }
body main .equipment-card .workout-tile-head { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: 18px; }
body main .equipment-card .workout-group { padding: 5px 9px; border-radius: 999px; background: #f0ecff; color: #6652c7; font-size: 10px; font-weight: 800; letter-spacing: .06em; }
body main .equipment-card .equipment-badge { background: #fff1da; color: #d88927; }
body main .equipment-card h3 { display: -webkit-box; min-height: 39px; margin: 12px 0 6px; overflow: hidden; font-size: 16px; line-height: 1.25; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
body main .equipment-card > p { display: -webkit-box; min-height: 36px; margin: 0; overflow: hidden; color: var(--v2-muted); font-size: 12px; line-height: 1.45; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
body main .equipment-card-actions { display: flex !important; align-items: center; justify-content: flex-start; min-height: 32px; margin-top: auto; }
body main .equipment-card-actions .edit-workout { flex: 0 0 auto; width: 130px; min-height: 32px; height: 32px; padding: 0 12px; border-radius: 9px; background: #eaf2ff; color: #6f82ff; font-size: 11px; }
body main .equipment-card-actions .edit-workout:hover { border-color: #6f82ff; background: #eaf2ff; color: #6f82ff; }

@media (max-width: 700px) {
  body main .equipment-grid { grid-template-columns: 1fr !important; }
}

/* Recipes page v2 final layout: 250×272 cards, compact category rail and one clear card CTA. */
body main .recipe-toolbar { grid-template-columns: minmax(260px, 1fr) 168px 170px auto !important; min-height: 68px; }
body main .recipe-categories.visual { grid-template-columns: repeat(auto-fit, minmax(154px, 1fr)) !important; gap: 16px !important; margin-bottom: 26px; }
body main .recipe-categories.visual .category-card { min-width: 0; min-height: 86px; padding: 12px 14px; border-radius: 16px; }
body main .recipes-results-head { margin-bottom: 14px; }
body main .recipe-grid { grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)) !important; gap: 20px !important; }
body main .recipe-tile,
body main .recipe-add-card { min-width: 0; min-height: 272px !important; height: auto; padding: 14px !important; border-radius: 18px !important; }
body main .recipe-tile { min-width: 0; min-height: 272px !important; height: auto; padding: 14px !important; border-radius: 18px !important; }
body main .recipe-tile { display: flex !important; flex-direction: column; }
body main .recipe-tile::before { display: none !important; }
body main .recipe-cover { flex: 0 0 82px; height: 82px; min-height: 82px; padding: 0 20px; border-radius: 12px; }
body main .recipe-tile .recipe-tile-head { display: none; }
body main .recipe-tile .recipe-category { margin-top: 15px; font-size: 10px; }
body main .recipe-tile h3 { display: -webkit-box; min-height: 39px; margin: 6px 0 4px; overflow: hidden; font-size: 18px; line-height: 1.22; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
body main .recipe-tile > p { display: -webkit-box; min-height: 18px; margin: 0; overflow: hidden; color: var(--v2-muted); font-size: 11px; line-height: 1.35; -webkit-box-orient: vertical; -webkit-line-clamp: 1; }
body main .recipe-tile .tile-macros { display: block !important; margin: 12px 0 0; padding-top: 12px; border-top: 1px solid #edf0f5; }
body main .recipe-tile .tile-macros span { display: inline-flex !important; align-items: baseline; gap: 3px; padding: 0; background: transparent; text-align: left; }
body main .recipe-tile .tile-macros span:first-child { display: flex !important; margin-bottom: 8px; }
body main .recipe-tile .tile-macros span:not(:first-child) { margin-right: 12px; }
body main .recipe-tile .tile-macros b { color: var(--v2-muted); font-size: 11px; }
body main .recipe-tile .tile-macros span:first-child b { color: var(--v2-blue); }
body main .recipe-tile .tile-macros span:not(:first-child) small { display: none; }
body main .recipe-tile .tile-macros span:nth-child(2) b::before { content: 'Б '; }
body main .recipe-tile .tile-macros span:nth-child(3) b::before { content: 'Ж '; }
body main .recipe-tile .tile-macros span:nth-child(4) b::before { content: 'У '; }
body main .recipe-tile .tile-macros span:first-child small { display: inline; margin-left: 0; font-size: 9px; }
body main .recipe-tile .recipe-tile-foot { display: none !important; }
body main .recipe-card-footer { display: flex; align-items: center; justify-content: space-between; gap: 8px; min-height: 32px; margin-top: auto; }
body main .recipe-card-footer .recipe-open-primary { flex: 0 0 auto; width: 90px; min-height: 26px; height: 26px; margin: 0; padding: 0 12px; border-radius: 8px; font-size: 10px; }
body main .recipe-card-footer .recipe-tile-actions { display: flex; align-items: center; gap: 6px; min-height: 26px; margin: 0; }
body main .recipe-card-footer .icon-action { flex: 0 0 26px; width: 26px; min-width: 26px; height: 26px; min-height: 26px; border-radius: 8px; font-size: 13px; }
body main .recipe-add-card { display: flex; align-items: center; flex-direction: column; justify-content: center; border: 1px dashed #d6dde8; background: #f8fafd; text-align: center; }
body main .recipe-add-card .recipe-add-icon { width: 60px; height: 60px; }
body main .recipe-add-card h3 { margin: 18px 0 5px; font-size: 16px; }
body main .recipe-add-card p { margin: 0; color: var(--v2-muted); font-size: 11px; }
body main .recipe-add-card .primary { min-height: 32px; height: 32px; margin-top: 18px; border-radius: 9px; padding: 0 14px; font-size: 11px; }

@media (max-width: 800px) {
  body main .recipe-toolbar { grid-template-columns: 1fr 1fr !important; }
  body main .recipe-toolbar input { grid-column: 1 / -1; }
}
@media (max-width: 560px) {
  body main .recipe-toolbar { grid-template-columns: 1fr !important; padding: 12px; }
  body main .recipe-categories.visual { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; gap: 10px !important; }
  body main .recipe-grid { grid-template-columns: 1fr !important; }
}

/* Products page v3 final layout: compact category tiles and 242×312 product cards. */
body main .product-catalog-layout > .product-categories { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)) !important; gap: 16px !important; margin: 0 0 26px; }
body main .product-catalog-layout > .product-categories .product-category-card { display: grid !important; grid-template-columns: 40px minmax(0, 1fr); grid-template-rows: 1fr auto; min-width: 0; min-height: 78px !important; padding: 12px 14px !important; border: 1px solid #e5eaf2; border-radius: 16px; background: #fff; }
body main .product-catalog-layout > .product-categories .product-category-card:hover { border-color: #aab6ff; background: #fbfcff; box-shadow: 0 8px 20px #1720330d; transform: translateY(-1px); }
body main .product-catalog-layout > .product-categories .product-category-card.active { border-color: #6f82ff; box-shadow: 0 0 0 2px #6f82ff20; }
body main .product-catalog-layout > .product-categories .product-category-card.all.active { background: #eef0ff; }
body main .product-catalog-layout > .product-categories .product-category-card > strong { grid-column: 2; grid-row: 2; justify-self: start; align-self: end; padding: 0; background: transparent; color: #6f82ff; font-size: 11px; box-shadow: none; }
body main .product-catalog-layout > .product-categories .product-category-photo { width: 40px; height: 40px; }
body main .product-catalog-layout > .product-categories .product-category-photo::before { width: 40px; height: 40px; }
body main .product-catalog-layout > .product-categories .product-category-copy { grid-column: 2; min-width: 0; padding: 0; }
body main .product-catalog-layout > .product-categories .product-category-copy b { display: block; overflow: hidden; font-size: 12px; line-height: 1.2; text-overflow: ellipsis; white-space: nowrap; }
body main .product-catalog-layout > .product-categories .product-category-copy small { display: block; margin-top: 4px; font-size: 10px; }
body main .product-catalog-layout > .product-categories .product-category-tone-0 { background: #e2f7eb; }
body main .product-catalog-layout > .product-categories .product-category-tone-1 { background: #fff1de; }
body main .product-catalog-layout > .product-categories .product-category-tone-2 { background: #e0f4f7; }
body main .product-catalog-layout > .product-categories .product-category-tone-3 { background: #fff1de; }
body main .product-catalog-layout > .product-categories .product-category-tone-4 { background: #f0f1ff; }
body main .product-catalog-layout > .product-categories .product-category-card.add-category-card { border-style: dashed; background: #f8fafd; }
body main .product-catalog-layout > .product-categories .product-category-card.add-category-card .product-category-photo { display: grid; place-items: center; background: #eef0ff; color: #6f82ff; font-size: 22px; }
body main .product-catalog-layout > .product-categories .all-products-photo { background: #fff; }
body main .product-catalog-layout > .product-categories .all-products-photo::after { content: '✦'; color: #6f82ff; font-size: 21px; }
body main .product-catalog-layout > .product-grid { grid-template-columns: repeat(auto-fill, minmax(242px, 1fr)) !important; gap: 20px !important; overflow: visible; border: 0; border-radius: 0; background: transparent; }
body main .product-catalog-layout > .product-grid .product-table-head { display: none !important; }
body main .product-catalog-layout > .product-grid > .product-tile { display: flex !important; flex-direction: column; min-width: 0; min-height: 312px !important; height: auto; padding: 14px !important; border: 1px solid #e5eaf2; border-radius: 18px !important; background: #fff; box-shadow: 0 8px 28px #15233d12; }
body main .product-catalog-layout > .product-grid > .product-tile:hover { border-color: #9aa7ff; box-shadow: 0 12px 30px #15233d18; transform: translateY(-2px); }
body main .product-catalog-layout > .product-grid > .product-tile::before { display: none !important; }
body main .product-catalog-layout .product-tile .product-cover { display: flex !important; flex: 0 0 96px; align-items: center; justify-content: center; height: 96px; min-height: 96px; margin: -14px -14px 0; border-radius: 18px 18px 12px 12px; }
body main .product-catalog-layout .product-tile .product-cover-label { display: none; }
body main .product-catalog-layout .product-tile .product-cover-icon { width: 54px; height: 54px; border-radius: 50%; background: #ffffffd9; }
body main .product-catalog-layout .product-tile .product-cover-icon.product-sprite::before { width: 50px; height: 50px; }
body main .product-catalog-layout .product-tile .product-tile-head { display: none; }
body main .product-catalog-layout .product-tile .product-tile-category { display: block !important; margin: 15px 0 0; font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; }
body main .product-catalog-layout .product-tile.product-cover-tone-0 .product-tile-category,
body main .product-catalog-layout .product-tile.product-cover-tone-3 .product-tile-category { color: #329a63; }
body main .product-catalog-layout .product-tile.product-cover-tone-1 .product-tile-category,
body main .product-catalog-layout .product-tile.product-cover-tone-4 .product-tile-category { color: #6652c7; }
body main .product-catalog-layout .product-tile.product-cover-tone-2 .product-tile-category { color: #4aa8b3; }
body main .product-catalog-layout .product-tile.product-cover-tone-5 .product-tile-category { color: #d56666; }
body main .product-catalog-layout .product-tile h3 { display: -webkit-box; min-height: 40px; margin: 7px 0 4px; overflow: hidden; font-size: 16px; line-height: 1.25; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
body main .product-catalog-layout .product-tile > p { display: -webkit-box; min-height: 18px; margin: 0; overflow: hidden; color: #7d879b; font-size: 11px; line-height: 1.35; -webkit-box-orient: vertical; -webkit-line-clamp: 1; }
body main .product-catalog-layout .product-tile .product-macros { display: grid !important; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0; margin: 13px 0 0; padding-top: 12px; border-top: 1px solid #e5eaf2; }
body main .product-catalog-layout .product-tile .product-macros span { padding: 0; background: transparent; text-align: left; }
body main .product-catalog-layout .product-tile .product-macros span:nth-child(4) { display: none; }
body main .product-catalog-layout .product-tile .product-macros b { color: #172033; font-size: 14px; }
body main .product-catalog-layout .product-tile .product-macros span:first-child b { color: #6f82ff; }
body main .product-catalog-layout .product-tile .product-macros small { display: block; margin-top: 3px; font-size: 8px; }
body main .product-catalog-layout .product-tile .product-tile-foot { display: flex; align-items: center; justify-content: flex-start; gap: 8px; margin-top: auto; padding-top: 9px; border-top: 0; }
body main .product-catalog-layout .product-tile .product-tile-foot span { overflow: hidden; color: #7d879b; font-size: 10px; text-overflow: ellipsis; white-space: nowrap; }
body main .product-catalog-layout .product-tile .product-tile-foot b { color: #7d879b; font-size: 10px; white-space: nowrap; }
body main .product-catalog-layout .product-tile .product-tile-actions { display: grid !important; grid-template-columns: minmax(0, 1fr) 36px; gap: 8px; min-height: 32px; margin-top: 8px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product { width: 100%; min-height: 28px; height: 28px; border-radius: 8px; padding: 0 11px; font-size: 10px; }
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { width: 36px; min-width: 36px; min-height: 28px; height: 28px; border-radius: 8px; }
body main .product-catalog-layout > .product-grid > .product-add-card { min-height: 312px; }

/* Product cards: match the v3 reference with a large cover and full-width actions. */
body main .product-catalog-layout > .product-grid { grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)) !important; gap: 24px !important; }
body main .product-catalog-layout > .product-grid > .product-tile { min-height: 400px !important; padding: 22px !important; border-radius: 18px !important; }
body main .product-catalog-layout .product-tile .product-cover { flex-basis: 122px; height: 122px; min-height: 122px; margin: -22px -22px 0; border-radius: 18px 18px 14px 14px; }
body main .product-catalog-layout .product-tile .product-cover-icon { width: 70px; height: 70px; }
body main .product-catalog-layout .product-tile .product-cover-icon.product-sprite::before { width: 64px; height: 64px; }
body main .product-catalog-layout .product-tile .product-tile-category { margin-top: 20px; font-size: 12px; letter-spacing: .04em; }
body main .product-catalog-layout .product-tile h3 { min-height: 0; margin: 10px 0 5px; font-size: 20px; line-height: 1.18; }
body main .product-catalog-layout .product-tile > p { min-height: 20px; font-size: 14px; line-height: 1.35; }
body main .product-catalog-layout .product-tile .product-macros { margin-top: 18px; padding-top: 15px; }
body main .product-catalog-layout .product-tile .product-macros b { font-size: 20px; }
body main .product-catalog-layout .product-tile .product-macros small { margin-top: 5px; font-size: 11px; font-weight: 700; text-transform: uppercase; }
body main .product-catalog-layout .product-tile .product-tile-foot { margin-top: auto; padding-top: 18px; }
body main .product-catalog-layout .product-tile .product-tile-foot span { font-size: 14px; }
body main .product-catalog-layout .product-tile .product-tile-foot b { font-size: 14px; }
body main .product-catalog-layout .product-tile .product-tile-actions { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 9px; min-height: 38px; margin-top: 10px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product,
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { width: 100%; min-width: 0; min-height: 38px; height: 38px; border-radius: 10px; padding: 0 10px; font-size: 0; font-weight: 800; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product { border: 1px solid #6f9cff; background: #eef3ff; color: #6f82ff; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product::before { content: '✎'; margin-right: 6px; font-size: 13px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product::after { content: 'Изменить'; font-size: 14px; }
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { border: 1px solid #ff9e97; background: #fff7f6; color: #e05b5b; }
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product::after { content: 'Удалить'; font-size: 14px; }
body main .product-catalog-layout .product-tile.product-cover-tone-0 .product-cover { background: #e2f7eb; color: #329a63; }
body main .product-catalog-layout .product-tile.product-cover-tone-1 .product-cover { background: #fff0dc; color: #d88927; }
body main .product-catalog-layout .product-tile.product-cover-tone-2 .product-cover { background: #e8f1ff; color: #6f82ff; }
body main .product-catalog-layout .product-tile.product-cover-tone-3 .product-cover { background: #fde7e2; color: #d56666; }
body main .product-catalog-layout .product-tile.product-cover-tone-4 .product-cover { background: #f0f1ff; color: #6652c7; }
body main .product-catalog-layout .product-tile.product-cover-tone-5 .product-cover { background: #dff2f7; color: #4aa8b3; }
body main .product-catalog-layout .product-tile.product-cover-tone-0 .product-tile-category { color: #329a63; }
body main .product-catalog-layout .product-tile.product-cover-tone-1 .product-tile-category { color: #d88927; }
body main .product-catalog-layout .product-tile.product-cover-tone-2 .product-tile-category { color: #6f82ff; }
body main .product-catalog-layout .product-tile.product-cover-tone-3 .product-tile-category { color: #d56666; }
body main .product-catalog-layout .product-tile.product-cover-tone-4 .product-tile-category { color: #6652c7; }
body main .product-catalog-layout .product-tile.product-cover-tone-5 .product-tile-category { color: #4aa8b3; }

/* Compact product card size from the design system: 242 x 312 px. */
body main .product-catalog-layout > .product-grid { grid-template-columns: repeat(auto-fill, 242px) !important; gap: 20px !important; justify-content: start; }
body main .product-catalog-layout > .product-grid > .product-tile { box-sizing: border-box; width: 242px; min-width: 242px; max-width: 242px; height: 312px; min-height: 312px !important; max-height: 312px; padding: 14px !important; }
body main .product-catalog-layout .product-tile .product-cover { flex-basis: 82px; height: 82px; min-height: 82px; margin: -14px -14px 0; border-radius: 18px 18px 12px 12px; }
body main .product-catalog-layout .product-tile .product-cover-icon { width: 54px; height: 54px; }
body main .product-catalog-layout .product-tile .product-cover-icon.product-sprite::before { width: 50px; height: 50px; }
body main .product-catalog-layout .product-tile .product-tile-category { margin-top: 12px; font-size: 10px; }
body main .product-catalog-layout .product-tile h3 { margin: 6px 0 3px; font-size: 16px; line-height: 1.2; }
body main .product-catalog-layout .product-tile > p { min-height: 16px; font-size: 11px; }
body main .product-catalog-layout .product-tile .product-macros { margin-top: 10px; padding-top: 10px; }
body main .product-catalog-layout .product-tile .product-macros b { font-size: 14px; }
body main .product-catalog-layout .product-tile .product-macros small { margin-top: 3px; font-size: 8px; }
body main .product-catalog-layout .product-tile .product-tile-foot { padding-top: 8px; }
body main .product-catalog-layout .product-tile .product-tile-foot span { font-size: 10px; }
body main .product-catalog-layout .product-tile .product-tile-actions { gap: 7px; min-height: 28px; margin-top: 7px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product,
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { min-height: 28px; height: 28px; border-radius: 8px; padding: 0 6px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product::before { margin-right: 3px; font-size: 11px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product::after,
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product::after { font-size: 11px; }

/* Exact card geometry from astra-products-page-v3.svg. */
body main .product-catalog-layout > .product-grid > .product-tile { padding: 18px !important; }
body main .product-catalog-layout .product-tile .product-cover { flex-basis: 96px; height: 96px; min-height: 96px; margin: -18px -18px 0; border-radius: 18px; }
body main .product-catalog-layout .product-tile .product-cover-icon { width: 54px; height: 54px; }
body main .product-catalog-layout .product-tile .product-cover-icon.product-sprite::before { width: 50px; height: 50px; }
body main .product-catalog-layout .product-tile .product-tile-category { margin-top: 16px; font-size: 10px; letter-spacing: 1px; line-height: 12px; }
body main .product-catalog-layout .product-tile h3 { min-height: 0; margin: 8px 0 4px; font-size: 16px; line-height: 19px; }
body main .product-catalog-layout .product-tile > p { min-height: 17px; font-size: 12px; line-height: 17px; }
body main .product-catalog-layout .product-tile .product-macros { margin-top: 15px; padding-top: 10px; }
body main .product-catalog-layout .product-tile .product-macros b { font-size: 16px; line-height: 19px; }
body main .product-catalog-layout .product-tile .product-macros small { margin-top: 3px; font-size: 10px; letter-spacing: 1px; line-height: 12px; }
body main .product-catalog-layout .product-tile .product-tile-foot { padding-top: 16px; }
body main .product-catalog-layout .product-tile .product-tile-foot span { font-size: 12px; line-height: 17px; }
body main .product-catalog-layout .product-tile .product-tile-actions { grid-template-columns: 100px 80px; justify-content: start; gap: 8px; min-height: 28px; margin-top: 5px; }
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product,
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { width: 100px; min-width: 0; min-height: 28px; height: 28px; border-radius: 8px; padding: 0; }
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product { width: 80px; }

/* Popup and action-button system from astra-popups-all-items.svg. */
body dialog { box-sizing: border-box; border: 1px solid #e5eaf2; border-radius: 22px; background: #fff; box-shadow: 0 12px 40px #15233d26; }
body dialog::before { height: 6px; background: #6f82ff; }
body dialog > form,
body dialog > .dialog-panel { padding: 30px 32px; }
body dialog .modal-head { margin-bottom: 22px; }
body dialog .modal-head .eyebrow { min-height: 26px; margin: 0 0 14px; padding: 0 12px; border-radius: 8px; font-size: 10px; letter-spacing: .08em; }
body dialog .modal-head h2 { font-size: 20px; line-height: 1.2; }
body dialog .modal-head .icon { flex: 0 0 36px; width: 36px; min-width: 36px; height: 36px; min-height: 36px; border-radius: 50%; background: #f6f8fc; color: #172033; font-size: 18px; }
body dialog .modal-head .icon:hover { background: #eaf2ff; color: #6f82ff; }
body dialog .actions { display: flex; align-items: center; justify-content: flex-end; gap: 12px; margin-top: 24px; padding-top: 18px; border-top: 1px solid #edf0f5; }
body dialog .actions button { min-height: 34px; height: 34px; border-radius: 9px; padding: 0 14px; font-size: 11px; font-weight: 700; }
body dialog .actions button.primary { border: 0; background: #172033; color: #fff; }
body dialog .actions button:not(.primary) { border: 1px solid #e5eaf2; background: #fff; color: #172033; }
body dialog .actions button:not(.primary):hover { border-color: #6f82ff; color: #6f82ff; }
body dialog .article-detail-actions { display: flex; align-items: center; gap: 12px; margin: 20px 0 0; padding-top: 0; border-top: 0; }
body dialog .article-detail-actions button { box-sizing: border-box; min-height: 34px; height: 34px; border-radius: 9px; padding: 0 12px; font-size: 11px; font-weight: 700; }
body dialog .article-detail-actions .edit-article-button { min-width: 106px; border: 1px solid #79a8ff; background: #eaf2ff; color: #6f82ff; }
body dialog .article-detail-actions .article-pin-button { min-width: 86px; border: 1px solid #e5eaf2; background: #f6f8fc; color: #7d879b; }
body dialog .article-detail-actions .article-visibility-button { min-width: 106px; border: 1px solid #ffb4aa; background: #fff0ed; color: #d56666; }
body dialog .article-detail-actions .article-return-button { border-color: #7bc8a4; background: #e7f6ee; color: #216e4e; }
body dialog.popup-article::before { background: #4b9db0; }
body dialog.popup-article .modal-head .eyebrow { background: #dff2f7; color: #4b9db0; }
body dialog.popup-recipe::before,
body dialog.popup-complex::before,
body dialog.popup-progress::before { background: #7ddba8; }
body dialog.popup-recipe .modal-head .eyebrow,
body dialog.popup-complex .modal-head .eyebrow,
body dialog.popup-progress .modal-head .eyebrow { background: #e2f7eb; color: #329a63; }
body dialog.popup-product::before,
body dialog.popup-exercise::before { background: #f4b96b; }
body dialog.popup-product .modal-head .eyebrow,
body dialog.popup-exercise .modal-head .eyebrow { background: #fff1de; color: #c88731; }
body dialog.popup-equipment::before { background: #6f82ff; }
body dialog.popup-equipment .modal-head .eyebrow { background: #f0f1ff; color: #6f82ff; }
body dialog.popup-workout::before,
body dialog.popup-diary::before { background: #6f82ff; }
body dialog.popup-workout .modal-head .eyebrow,
body dialog.popup-diary .modal-head .eyebrow { background: #f0f1ff; color: #6f82ff; }
body dialog.popup-delete::before,
body dialog.popup-confirm::before { background: #d56666; }
body dialog.popup-delete .modal-head .eyebrow,
body dialog.popup-confirm .modal-head .eyebrow { background: #fff0ed; color: #d56666; }
body dialog.popup-delete .actions .danger-button,
body dialog.popup-confirm .actions .danger-button { border: 1px solid #ffb4aa; background: #fff0ed !important; color: #d56666 !important; }

@media (max-width: 760px) {
  body main .product-catalog-layout > .product-categories { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; gap: 10px !important; }
  body main .product-catalog-layout > .product-grid { grid-template-columns: 1fr !important; }
}

/* Workout components v2: compact complex cards and exact reference-card geometry. */
body main .workout-complex-grid { grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)) !important; gap: 16px !important; }
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card) {
  display: flex !important;
  flex-direction: column;
  min-width: 0;
  min-height: 154px !important;
  height: 154px;
  padding: 0 !important;
  overflow: hidden;
  border: 1px solid #e5eaf2;
  border-radius: 20px !important;
  background: #fff;
  cursor: pointer;
}
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card):hover,
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card):focus-visible {
  border-color: #6f82ff;
  box-shadow: 0 0 0 2px #6f82ff26, 0 10px 24px #17203312;
  outline: none;
}
body main .workout-complex-card:not(.workout-create-card) .workout-complex-photo {
  display: grid;
  flex: 0 0 84px;
  place-items: center;
  width: 100%;
  height: 84px;
  background: #eef0ff;
  color: #6f82ff;
  font-size: 28px;
}
body main .workout-complex-card:not(.workout-create-card) .category-copy { min-width: 0; padding: 12px 16px 0; }
body main .workout-complex-card:not(.workout-create-card) .category-copy b { display: block; overflow: hidden; color: #172033; font-size: 15px; line-height: 1.2; text-overflow: ellipsis; white-space: nowrap; }
body main .workout-complex-card:not(.workout-create-card) .category-copy small { display: block; margin-top: 4px; overflow: hidden; color: #7d879b; font-size: 11px; line-height: 1.3; text-overflow: ellipsis; white-space: nowrap; }
body main .workout-complex-card:not(.workout-create-card) .workout-complex-actions { display: flex; align-items: center; gap: 8px; margin-top: auto; padding: 10px 16px 14px; }
body main .workout-complex-card:not(.workout-create-card) .create-complex-button { flex: 1; min-width: 0; min-height: 34px; height: 34px; border: 0; border-radius: 9px; background: #172033; color: #fff; font-size: 11px; }
body main .workout-complex-card:not(.workout-create-card) .create-complex-button:hover { background: #2a3549; }
body main .workout-complex-card:not(.workout-create-card) .edit-complex-button { flex: 0 0 34px; width: 34px; min-width: 34px; height: 34px; min-height: 34px; padding: 0; border: 1px solid #d9e2ec; border-radius: 9px; background: #f6f8fc; color: #6f82ff; }

body main .equipment-card:not(.workout-create-card) .card-action,
body main .equipment-card:not(.workout-create-card) .edit-workout {
  width: 130px;
  min-height: 32px;
  height: 32px;
  border: 1px solid #79a8ff;
  border-radius: 9px;
  background: #eaf2ff;
  color: #6f82ff;
  font-size: 11px;
  font-weight: 800;
}
body main .equipment-card:not(.workout-create-card) .card-action:hover,
body main .equipment-card:not(.workout-create-card) .edit-workout:hover { border-color: #6f82ff; background: #eaf2ff; color: #566ddf; }

/* The form mockup is 980 px wide with a two-column intro and table-like exercise rows. */
body dialog.popup-complex.popup-form { width: min(980px, calc(100vw - 32px)); }
body dialog.popup-complex.popup-form > .dialog-panel { padding: 34px 44px 26px; }
body dialog.popup-complex.popup-form .complex-form > .grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 20px; margin: 20px 0 30px; }
body dialog.popup-complex.popup-form .complex-form > .grid .field { min-width: 0; }
body dialog.popup-complex.popup-form .complex-form > .grid .field input { height: 48px; min-height: 48px; }
body dialog.popup-complex.popup-form .complex-form > .grid .field textarea { min-height: 48px; height: 48px; resize: vertical; }
body dialog.popup-complex.popup-form .complex-exercises-section,
body dialog.popup-complex.popup-form .complex-media-section { margin-top: 0; padding: 0; border: 0; border-radius: 0; background: transparent; }
body dialog.popup-complex.popup-form .complex-media-section { margin-top: 28px; padding-top: 20px; border-top: 1px solid #edf0f5; }
body dialog.popup-complex.popup-form .complex-items { gap: 0; margin-top: 12px; border: 1px solid #dde3ec; border-radius: 10px; overflow: hidden; background: #fff; }
body dialog.popup-complex.popup-form .complex-item { padding: 13px 16px; border: 0; border-radius: 0; background: #fff; }
body dialog.popup-complex.popup-form .complex-item + .complex-item { border-top: 1px solid #edf0f5; }
body dialog.popup-complex.popup-form .complex-item-head { min-height: 30px; }
body dialog.popup-complex.popup-form .builder-number { display: grid; place-items: center; width: 26px; height: 26px; flex: 0 0 26px; border-radius: 50%; background: #eef0ff; color: #6f82ff; font-size: 11px; font-weight: 800; }
body dialog.popup-complex.popup-form .complex-item-head select { min-height: 34px; height: 34px; border: 0; background: transparent; font-weight: 700; }
body dialog.popup-complex.popup-form .complex-exercise-link { display: none; }
body dialog.popup-complex.popup-form .complex-item-fields { grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin: 10px 0 0 42px; }
body dialog.popup-complex.popup-form .complex-item-fields .field label { margin-bottom: 4px; font-size: 10px; }
body dialog.popup-complex.popup-form .complex-item-fields input { height: 34px; min-height: 34px; padding: 0 9px; }
body dialog.popup-complex.popup-form .remove-builder-item { width: 28px; height: 28px; min-width: 28px; border: 0; border-radius: 8px; background: transparent; color: #7d879b; font-size: 18px; }
body dialog.popup-complex.popup-form .remove-builder-item:hover { background: #fff0ed; color: #d56666; }
body dialog.popup-complex.popup-form .complex-section-head h3 { font-size: 16px; }
body dialog.popup-complex.popup-form .complex-section-head .secondary-button { min-height: 38px; height: 38px; border: 0; border-radius: 10px; background: #e2f7eb; color: #329a63; }
body dialog.popup-complex.popup-form .complex-form > .actions { margin-top: 20px; padding-top: 20px; border-top: 1px solid #edf0f5; }
body dialog.popup-complex.popup-form .complex-form > .actions button { min-height: 38px; height: 38px; border-radius: 10px; }
body dialog.popup-complex.popup-form .complex-form > .actions .primary { min-width: 94px; border: 0; background: #172033; color: #fff; }

@media (max-width: 700px) {
  body dialog.popup-complex.popup-form > .dialog-panel { padding: 26px 20px; }
  body dialog.popup-complex.popup-form .complex-form > .grid { grid-template-columns: 1fr; gap: 12px; }
  body dialog.popup-complex.popup-form .complex-item-fields { grid-template-columns: 1fr 1fr; margin-left: 0; }
}

/* Workout history cards: match the completed/cancelled states from the component sheet. */
body main .archive-history-groups .archive-workout-grid { grid-template-columns: repeat(2, minmax(0, 410px)) !important; justify-content: start; gap: 16px !important; }
body main .history-workout-card {
  box-sizing: border-box;
  width: 410px;
  min-width: 0;
  min-height: 264px !important;
  height: 264px;
  padding: 24px !important;
  border: 1px solid #e5eaf2;
  border-radius: 18px !important;
  background: #fff;
  box-shadow: 0 6px 20px #1720330d;
}
body main .history-workout-card:hover,
body main .history-workout-card:focus-visible { border-color: #79a8ff; box-shadow: 0 0 0 2px #79a8ff26, 0 8px 24px #17203312; outline: none; }
body main .history-workout-card .workout-tile-head { min-height: 24px; }
body main .history-workout-card .workout-date { color: #172033; font-size: 14px; font-weight: 700; }
body main .history-workout-card .workout-group { padding: 5px 9px; border-radius: 999px; font-size: 10px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; }
body main .history-workout-card h3 { min-height: 46px; margin: 18px 0 6px; font-size: 19px; line-height: 1.22; }
body main .history-workout-card > p { min-height: 18px; margin: 0; color: #7d879b; font-size: 12px; }
body main .history-card-summary { min-height: 52px; max-height: 52px; margin: 16px 0 10px; padding-top: 10px; overflow: hidden; border-top: 1px solid #e5eaf2; }
body main .history-card-summary b,
body main .history-card-summary small { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
body main .history-card-summary b { color: #172033; font-size: 12px; line-height: 18px; }
body main .history-card-summary small { margin-top: 4px; color: #7d879b; font-size: 12px; line-height: 18px; }
body main .history-card-actions { display: flex !important; align-items: center; justify-content: flex-start !important; gap: 10px; min-height: 36px; margin-top: auto; }
body main .history-card-actions .history-details-action,
body main .history-card-actions .history-repeat-action,
body main .history-card-actions .history-delete-action { box-sizing: border-box; min-height: 36px; height: 36px; border-radius: 9px; padding: 0 12px; font-size: 11px; font-weight: 800; }
body main .history-card-actions .history-details-action { flex: 0 0 160px; width: 160px; border: 1px solid #79a8ff; background: #eaf2ff; color: #6f82ff; }
body main .history-card-actions .history-repeat-action { flex: 0 0 126px; width: 126px; border: 0; background: #172033; color: #fff; }
body main .history-card-actions .history-repeat-action:hover { background: #2a3549; }
body main .history-card-actions .history-delete-action { flex: 0 0 126px; width: 126px; border: 1px solid #ccd3df; background: #f7f8fa; color: #7d879b; }
body main .history-card-actions .history-delete-action:hover { border-color: #ffb4aa; background: #fff2f0; color: #d55555; }

@media (max-width: 900px) {
  body main .archive-history-groups .archive-workout-grid { grid-template-columns: minmax(0, 410px) !important; }
  body main .history-workout-card { width: min(410px, 100%); }
}

/* Final history reset: legacy archive-grid alignment must not affect the component-sheet cards. */
body main .archive-history-layout { grid-template-columns: minmax(0, 836px) 408px !important; }
body main .archive-history-groups { width: 836px; max-width: 100%; }
body main .archive-history-groups .archive-workout-grid { display: grid !important; grid-template-columns: repeat(2, 410px) !important; width: 836px; max-width: 100%; }
body main .history-workout-card { display: flex !important; flex-direction: column !important; align-items: stretch !important; justify-content: flex-start !important; width: 410px; max-width: 100%; }
body main .history-workout-card .workout-tile-head,
body main .history-workout-card h3,
body main .history-workout-card > p,
body main .history-workout-card .history-card-summary,
body main .history-workout-card .history-card-actions { width: 100%; max-width: 100%; text-align: left; }
body main .history-workout-card .workout-tile-head { flex: 0 0 auto; }
body main .history-workout-card h3 { display: -webkit-box; flex: 0 0 auto; text-align: left; }
body main .history-card-actions .history-details-action { flex: 0 0 160px !important; width: 160px !important; }
body main .history-card-actions .history-repeat-action,
body main .history-card-actions .history-delete-action { flex: 0 0 126px !important; width: 126px !important; }

@media (max-width: 1100px) {
  body main .archive-history-layout { grid-template-columns: minmax(0, 1fr) !important; }
  body main .archive-history-groups { width: 100%; }
  body main .archive-history-groups .archive-workout-grid { width: 100%; }
}
@media (max-width: 900px) {
  body main .archive-history-groups .archive-workout-grid { grid-template-columns: minmax(0, 410px) !important; }
}
@media (max-width: 500px) {
  body main .archive-history-groups .archive-workout-grid { grid-template-columns: minmax(0, 1fr) !important; }
  body main .history-workout-card { width: 100%; }
  body main .history-card-actions .history-details-action { flex-basis:  min(160px, calc(100% - 136px)) !important; width: min(160px, calc(100% - 136px)) !important; }
}

/* Card action rule: details is an icon action, not a text button. */
body main .history-card-actions .history-details-action {
  display: inline-grid;
  place-items: center;
  flex: 0 0 36px !important;
  width: 36px !important;
  min-width: 36px;
  height: 36px;
  min-height: 36px;
  padding: 0;
  border: 1px solid #79a8ff;
  border-radius: 9px;
  background: #eaf2ff;
  color: #6f82ff;
  font-size: 16px;
  line-height: 1;
}
body main .history-card-actions .history-details-action:hover { border-color: #6f82ff; background: #dfeaff; color: #566ddf; }

/* Complex cards: keep the visual, content and actions inside the card bounds. */
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card) {
  display: flex !important;
  flex-direction: column !important;
  align-items: stretch !important;
  justify-content: flex-start !important;
  min-height: 184px !important;
  height: 184px;
  overflow: hidden;
  padding: 0 !important;
}
body main .workout-complex-card:not(.workout-create-card) .workout-complex-photo {
  flex: 0 0 72px;
  height: 72px;
  min-height: 72px;
}
body main .workout-complex-card:not(.workout-create-card) .category-copy {
  flex: 1 1 auto;
  min-height: 0;
  padding: 10px 16px 0;
}
body main .workout-complex-card:not(.workout-create-card) .category-copy b { line-height: 18px; }
body main .workout-complex-card:not(.workout-create-card) .category-copy small { margin-top: 2px; line-height: 14px; }
body main .workout-complex-card:not(.workout-create-card) .workout-complex-actions {
  flex: 0 0 46px;
  min-height: 46px;
  margin-top: 0;
  padding: 7px 16px 9px;
}
body main .workout-complex-card:not(.workout-create-card) .create-complex-button,
body main .workout-complex-card:not(.workout-create-card) .edit-complex-button { min-height: 30px; height: 30px; }
body main .workout-complex-grid > .workout-create-card.workout-complex-card {
  grid-column: span 2;
  min-height: 154px !important;
  height: 154px;
}
@media (max-width: 900px) {
  body main .workout-complex-grid > .workout-create-card.workout-complex-card { grid-column: 1 / -1; }
}

/* Content card pattern: WORKOUT CARD · 354 x 300 from astra-component-cards.svg. */
body main .workout-complex-grid { grid-template-columns: repeat(auto-fill, minmax(354px, 1fr)) !important; gap: 20px !important; }
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card) {
  display: flex !important;
  flex-direction: column !important;
  align-items: stretch !important;
  justify-content: flex-start !important;
  width: 354px;
  max-width: 100%;
  min-width: 0;
  min-height: 300px !important;
  height: 300px;
  padding: 0 !important;
  overflow: hidden;
  border: 0;
  border-radius: 18px !important;
  background: #fff;
  box-shadow: 0 8px 24px #15233d14;
}
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card):hover,
body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card):focus-visible {
  border-color: transparent;
  box-shadow: 0 0 0 2px #6f82ff26, 0 12px 30px #15233d20;
  outline: none;
  transform: translateY(-2px);
}
body main .workout-complex-cover {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex: 0 0 108px;
  width: calc(100% - 32px);
  height: 108px;
  margin: 16px 16px 0;
  padding: 0 14px 0 20px;
  box-sizing: border-box;
  border-radius: 13px;
  background: #f0f1ff;
}
body main .workout-complex-mark { color: #6f82ff; font-size: 46px; line-height: 1; }
body main .workout-complex-duration { padding: 5px 10px; border-radius: 8px; background: #fff; color: #6f82ff; font-size: 12px; font-weight: 700; }
body main .workout-complex-body { display: flex; flex: 1 1 auto; min-height: 0; flex-direction: column; padding: 0 20px 14px; }
body main .workout-complex-body h3 { display: -webkit-box; min-height: 22px; margin: 16px 0 4px; overflow: hidden; color: #172033; font-size: 18px; line-height: 22px; text-align: left; text-overflow: ellipsis; -webkit-box-orient: vertical; -webkit-line-clamp: 1; }
body main .workout-complex-body > p { min-height: 17px; margin: 0; overflow: hidden; color: #7d879b; font-size: 12px; line-height: 17px; text-align: left; text-overflow: ellipsis; white-space: nowrap; }
body main .workout-complex-divider { flex: 0 0 1px; height: 1px; margin: 10px 0 9px; background: #edf0f5; }
body main .workout-complex-meta { display: flex; align-items: center; justify-content: space-between; gap: 10px; min-height: 18px; color: #7d879b; font-size: 12px; line-height: 18px; }
body main .workout-complex-meta span { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
body main .workout-complex-meta strong { flex: 0 0 auto; color: #329a63; font-size: 12px; font-weight: 700; }
body main .workout-complex-body .workout-complex-actions { display: flex; align-items: center; gap: 8px; flex: 0 0 28px; min-height: 28px; margin-top: auto; padding: 0; }
body main .workout-complex-body .create-complex-button { flex: 0 0 164px; width: 164px; min-height: 28px; height: 28px; border: 0; border-radius: 8px; padding: 0 10px; background: #172033; color: #fff; font-size: 12px; font-weight: 700; }
body main .workout-complex-body .create-complex-button:hover { background: #2a3549; }
body main .workout-complex-body .edit-complex-button { flex: 0 0 36px; width: 36px; min-width: 36px; height: 28px; min-height: 28px; padding: 0; border: 1px solid #d9e2ec; border-radius: 8px; background: #f6f8fc; color: #6f82ff; font-size: 15px; }
body main .workout-complex-body .edit-complex-button:hover { border-color: #79a8ff; background: #eaf2ff; }
body main .workout-complex-grid > .workout-create-card.workout-complex-card { grid-column: span 2; }
@media (max-width: 900px) {
  body main .workout-complex-grid { grid-template-columns: minmax(0, 354px) !important; }
  body main .workout-complex-grid > .workout-create-card.workout-complex-card { grid-column: 1; }
}
@media (max-width: 500px) {
  body main .workout-complex-grid { grid-template-columns: 1fr !important; }
  body main .workout-complex-grid > .workout-complex-card:not(.workout-create-card) { width: 100%; }
}

/* Article content cards: reset the legacy flow so long titles cannot push actions over the excerpt. */
body main .theory-page .article-grid { display: grid !important; grid-template-columns: repeat(3, minmax(0, 1fr)) !important; gap: 24px !important; }
body main .theory-page .article-card {
  position: relative !important;
  display: block !important;
  box-sizing: border-box;
  width: 100%;
  height: 300px !important;
  min-height: 300px !important;
  padding: 20px !important;
  overflow: hidden !important;
  border: 0;
  border-radius: 18px !important;
  background: #fff;
  box-shadow: 0 8px 24px #15233d14;
}
body main .theory-page .article-card::before {
  content: '' !important;
  position: absolute !important;
  inset: 16px 16px auto !important;
  width: auto !important;
  height: 108px !important;
  margin: 0 !important;
  border-radius: 13px !important;
  background: #dff2f7 !important;
  z-index: 0;
}
body main .theory-page .article-card::after {
  content: '◈' !important;
  position: absolute !important;
  top: 48px !important;
  left: 38px !important;
  z-index: 1;
  color: #4b9db0;
  font-size: 44px;
  line-height: 1;
}
body main .theory-page .article-card > img { display: none !important; }
body main .theory-page .article-card .article-card-head { position: absolute; top: 30px; left: 24px; z-index: 2; }
body main .theory-page .article-card .article-card-head .eyebrow { margin: 0; padding: 5px 9px; border-radius: 8px; background: #ffffffd1; color: #4b9db0; font-size: 10px; }
body main .theory-page .article-card .article-title {
  position: absolute;
  top: 138px;
  left: 20px;
  right: 20px;
  display: -webkit-box;
  height: 48px;
  min-height: 48px !important;
  margin: 0 !important;
  overflow: hidden;
  color: #172033;
  font-size: 20px !important;
  line-height: 24px !important;
  text-overflow: ellipsis;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
body main .theory-page .article-card .article-lead {
  position: absolute;
  top: 194px;
  left: 20px;
  right: 20px;
  display: flex;
  align-items: flex-start;
  gap: 8px;
  height: 34px;
  min-height: 34px;
  overflow: hidden;
  color: #7d879b;
  line-height: 17px;
}
body main .theory-page .article-card .article-open-icon { flex: 0 0 24px; width: 24px; height: 24px; }
body main .theory-page .article-card .article-excerpt {
  display: -webkit-box;
  max-height: 34px;
  margin: 0;
  overflow: hidden;
  color: #7d879b;
  font-size: 12px;
  line-height: 17px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
body main .theory-page .article-card .article-tags { display: none !important; }
body main .theory-page .article-card .article-card-primary {
  position: absolute;
  left: 20px;
  bottom: 14px;
  z-index: 3;
  width: 132px;
  min-width: 132px;
  height: 28px;
  min-height: 28px !important;
  margin: 0 !important;
  padding: 0 10px;
  border-radius: 8px;
  font-size: 11px;
}
body main .theory-page .article-card .article-card-actions {
  position: absolute;
  right: 20px;
  bottom: 14px;
  z-index: 3;
  display: flex !important;
  align-items: center;
  gap: 6px;
  width: auto;
  min-height: 28px;
  margin: 0 !important;
}
body main .theory-page .article-card .article-card-actions button {
  flex: 0 0 28px;
  width: 28px;
  min-width: 28px;
  height: 28px;
  min-height: 28px;
  padding: 0;
  border-radius: 8px;
  font-size: 14px;
  line-height: 1;
}
body main .theory-page .article-card .article-pin-action { top: 30px; right: 16px; z-index: 4; width: 36px; min-width: 36px; height: 36px; min-height: 36px; padding: 0; border: 1px solid #7bc8a4; border-radius: 10px; background: #e7f6ee; color: #216e4e; }
body main .theory-page .article-card:hover,
body main .theory-page .article-card:focus-visible { border-color: transparent; box-shadow: 0 0 0 2px #4b9db026, 0 12px 30px #15233d20; outline: none; transform: translateY(-2px); }
@media (max-width: 900px) { body main .theory-page .article-grid { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; } }
@media (max-width: 600px) { body main .theory-page .article-grid { grid-template-columns: 1fr !important; } }

/* Product v3 final card reset: 242 x 312, with visible name and actions. */
body main .product-catalog-layout > .product-grid { grid-template-columns: repeat(auto-fill, 242px) !important; gap: 20px !important; justify-content: start; }
body main .product-catalog-layout > .product-grid > .product-tile {
  display: flex !important;
  flex-direction: column !important;
  align-items: stretch !important;
  justify-content: flex-start !important;
  box-sizing: border-box;
  width: 242px;
  min-width: 242px;
  max-width: 242px;
  height: 312px !important;
  min-height: 312px !important;
  max-height: 312px;
  padding: 0 !important;
  overflow: hidden;
  border: 1px solid #e5eaf2;
  border-radius: 18px !important;
  background: #fff;
  color: #172033;
  box-shadow: 0 8px 28px #15233d12;
  cursor: pointer;
}
body main .product-catalog-layout > .product-grid > .product-tile:hover,
body main .product-catalog-layout > .product-grid > .product-tile:focus-visible { border-color: #79a8ff; box-shadow: 0 0 0 2px #79a8ff26, 0 12px 30px #15233d18; outline: none; transform: translateY(-2px); }
body main .product-catalog-layout .product-tile::before { display: none !important; }
body main .product-catalog-layout .product-tile .product-cover {
  display: flex !important;
  align-items: center;
  justify-content: center;
  flex: 0 0 96px;
  width: 100%;
  height: 96px;
  min-height: 96px;
  margin: 0 !important;
  border-radius: 18px 18px 13px 13px;
}
body main .product-catalog-layout .product-tile .product-cover-label { display: none !important; }
body main .product-catalog-layout .product-tile .product-cover-icon { width: 54px; height: 54px; border-radius: 50%; background: #ffffffd9; }
body main .product-catalog-layout .product-tile .product-cover-icon.product-sprite::before { width: 50px; height: 50px; }
body main .product-catalog-layout .product-tile .product-tile-head { display: none !important; }
body main .product-catalog-layout .product-tile .product-tile-category {
  display: block !important;
  min-height: 12px;
  margin: 22px 18px 0 !important;
  color: #d88927;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  line-height: 12px;
  text-transform: uppercase;
}
body main .product-catalog-layout .product-tile.product-cover-tone-0 .product-tile-category { color: #329a63; }
body main .product-catalog-layout .product-tile.product-cover-tone-1 .product-tile-category { color: #d88927; }
body main .product-catalog-layout .product-tile.product-cover-tone-2 .product-tile-category { color: #6f82ff; }
body main .product-catalog-layout .product-tile.product-cover-tone-3 .product-tile-category { color: #d56666; }
body main .product-catalog-layout .product-tile.product-cover-tone-4 .product-tile-category { color: #6652c7; }
body main .product-catalog-layout .product-tile.product-cover-tone-5 .product-tile-category { color: #4aa8b3; }
body main .product-catalog-layout .product-tile h3 {
  display: -webkit-box;
  min-height: 19px;
  height: 19px;
  margin: 6px 18px 3px !important;
  overflow: hidden;
  color: #172033;
  font-size: 16px !important;
  font-weight: 750;
  line-height: 19px !important;
  text-overflow: ellipsis;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 1;
}
body main .product-catalog-layout .product-tile > p {
  display: -webkit-box;
  min-height: 17px;
  height: 17px;
  margin: 0 18px !important;
  overflow: hidden;
  color: #7d879b;
  font-size: 12px;
  line-height: 17px;
  text-overflow: ellipsis;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 1;
}
body main .product-catalog-layout .product-tile .product-macros {
  display: grid !important;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0;
  margin: 12px 18px 0;
  padding-top: 8px;
  border-top: 1px solid #e5eaf2;
}
body main .product-catalog-layout .product-tile .product-macros span { padding: 0; background: transparent; text-align: left; }
body main .product-catalog-layout .product-tile .product-macros span:nth-child(4) { display: none; }
body main .product-catalog-layout .product-tile .product-macros b { color: #172033; font-size: 16px; line-height: 19px; }
body main .product-catalog-layout .product-tile .product-macros span:first-child b { color: #6f82ff; }
body main .product-catalog-layout .product-tile .product-macros small { display: block; margin-top: 3px; color: #7d879b; font-size: 10px; font-weight: 700; letter-spacing: 1px; line-height: 12px; text-transform: uppercase; }
body main .product-catalog-layout .product-tile .product-tile-foot {
  display: flex;
  align-items: center;
  flex: 0 0 17px;
  min-height: 17px;
  margin: auto 18px 0;
  padding: 0;
  border: 0;
}
body main .product-catalog-layout .product-tile .product-tile-foot span { display: block; overflow: hidden; color: #7d879b; font-size: 12px; line-height: 17px; text-overflow: ellipsis; white-space: nowrap; }
body main .product-catalog-layout .product-tile .product-tile-actions {
  display: grid !important;
  grid-template-columns: 100px 80px;
  gap: 8px;
  flex: 0 0 28px;
  min-height: 28px;
  margin: 5px 18px 8px;
}
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product {
  width: 100px;
  min-width: 100px;
  height: 28px;
  min-height: 28px;
  padding: 0;
  border: 1px solid #79a8ff;
  border-radius: 8px;
  background: #eaf2ff;
  color: #6f82ff;
  font-size: 11px;
  font-weight: 800;
}
body main .product-catalog-layout .product-tile .product-tile-actions .edit-product:hover { border-color: #6f82ff; background: #e0ebff; }
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product {
  width: 80px;
  min-width: 80px;
  height: 28px;
  min-height: 28px;
  padding: 0;
  border: 1px solid #ffb4aa;
  border-radius: 8px;
  background: #fff2f0;
  color: #d55555;
  font-size: 14px;
}
body main .product-catalog-layout .product-tile .product-tile-actions .delete-product:hover { border-color: #d55555; background: #ffe9e5; }
@media (max-width: 600px) {
  body main .product-catalog-layout > .product-grid { grid-template-columns: repeat(auto-fill, 242px) !important; justify-content: center; }
}

/* Information page: use the full workspace width instead of the legacy 1028px cap. */
body main .theory-page {
  width: 100% !important;
  max-width: none !important;
  min-width: 0;
}
body main .theory-page .popular-articles,
body main .theory-page .article-sections-block,
body main .theory-page .selected-section,
body main .theory-page .information-search,
body main .theory-page .article-grid,
body main .theory-page .article-sections {
  width: 100%;
  max-width: none;
}
body main .theory-page .article-grid {
  grid-template-columns: repeat(auto-fill, minmax(354px, 1fr)) !important;
}
body main .theory-page .article-sections {
  display: grid !important;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)) !important;
  gap: 16px;
}
body main .theory-page .article-section-card {
  width: auto;
  min-width: 0;
}
@media (max-width: 1100px) {
  body main .theory-page .article-grid { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
}
@media (max-width: 700px) {
  body main .theory-page .article-grid { grid-template-columns: 1fr !important; }
  body main .theory-page .article-sections { grid-template-columns: repeat(2, minmax(0, 1fr)) !important; }
}
</style>
