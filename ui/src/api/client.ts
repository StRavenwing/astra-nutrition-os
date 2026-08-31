import type {
  AuthResponse,
  AuthUser,
  RegisteredUser,
  DashboardResponse,
  DiaryEntry,
  Exercise,
  FeedbackMessage,
  Product,
  ProductMeasure,
  ProductNutritionScanResult,
  ProgressEntry,
  RecipeDetail,
  RecipeSummary,
  WorkoutEntry,
  WorkoutComplex,
  WorkoutEquipment,
  WorkoutPlan,
  ContentCategory,
  Article,
  ArticleSection,
  ClientDetail,
  ClientSummary,
  TrainerChatParticipant,
  TrainerChatMessage,
  TrainerChatResponse,
  SharedItemDetail,
  SharedItemResult,
  ShareItemType
} from '@/types';

const TOKEN_KEY = 'astra_access_token';
let unauthorizedHandler: (() => void) | null = null;

export function getAccessToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAccessToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearAccessToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export function setUnauthorizedHandler(handler: (() => void) | null) {
  unauthorizedHandler = handler;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (!(init.body instanceof FormData)) {
    headers.set('Content-Type', headers.get('Content-Type') || 'application/json');
  }
  const token = getAccessToken();
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(`/api/v1/${path}`, {
    ...init,
    headers
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    if (response.status === 401) {
      clearAccessToken();
      unauthorizedHandler?.();
    }
    const detail = Array.isArray(payload?.details) ? payload.details[0]?.msg : payload?.details;
    throw new Error(payload?.error || detail || 'Ошибка');
  }
  if (path === 'products' && Array.isArray(payload)) {
    payload.sort((a: Product, b: Product) => a.name.localeCompare(b.name, 'ru', { sensitivity: 'base' }));
  }
  return payload as T;
}

function write<T>(method: 'POST' | 'PUT' | 'DELETE', path: string, body?: unknown): Promise<T> {
  return request<T>(path, {
    method,
    body: body === undefined ? undefined : JSON.stringify(body)
  });
}

export const api = {
  me: () => request<AuthUser>('auth/me'),
  users: () => request<RegisteredUser[]>('auth/users'),
  login: (email: string, password: string) => request<AuthResponse>('auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password })
  }),
  register: (email: string, password: string) => request<AuthResponse>('auth/register', {
    method: 'POST',
    body: JSON.stringify({ email, password })
  }),
  requestPasswordReset: (email: string) => request<{ ok: boolean; message: string }>('auth/password-reset/request', {
    method: 'POST',
    body: JSON.stringify({ email })
  }),
  confirmPasswordReset: (email: string, code: string, password: string) => request<{ ok: boolean; message: string }>('auth/password-reset/confirm', {
    method: 'POST',
    body: JSON.stringify({ email, code, password })
  }),
  logout: () => write<{ ok: boolean }>('POST', 'auth/logout'),
  dashboard: () => request<DashboardResponse>('dashboard'),
  products: () => request<Product[]>('products'),
  scanProductNutrition: (file: File) => {
    const body = new FormData();
    body.append('image', file);
    return request<ProductNutritionScanResult>('products/scan-nutrition-label', {
      method: 'POST',
      body
    });
  },
  productMeasures: () => request<ProductMeasure[]>('product-measures'),
  recipes: () => request<RecipeSummary[]>('recipes'),
  recipe: (id: number) => request<RecipeDetail>(`recipes/${id}`),
  requestRecipeSubmission: (id: number) => write<RecipeSummary>('POST', `recipes/${id}/submission-request`),
  cancelRecipeSubmission: (id: number) => write<RecipeSummary>('DELETE', `recipes/${id}/submission-request`),
  moderateRecipe: (id: number, action: 'accept' | 'reject' | 'revision', note?: string) => write<RecipeSummary>('POST', `recipes/${id}/moderation`, { action, note }),
  diary: () => request<DiaryEntry[]>('diary'),
  progress: () => request<ProgressEntry[]>('progress'),
  workouts: () => request<WorkoutEntry[]>('workouts'),
  workoutPlans: () => request<WorkoutPlan[]>('workout-plans'),
  clients: () => request<ClientSummary[]>('clients'),
  addClient: (email: string) => write<ClientSummary>('POST', 'clients', { email }),
  client: (id: number) => request<ClientDetail>(`clients/${id}`),
  clientDiary: (id: number) => request<DiaryEntry[]>(`clients/${id}/diary`),
  addClientDiary: (id: number, body: unknown) => write<DiaryEntry[]>('POST', `clients/${id}/diary`, body),
  deleteClientDiary: (clientId: number, entryId: number) => write<{ deleted: boolean; id: number }>('DELETE', `clients/${clientId}/diary/${entryId}`),
  scheduleClientWorkout: (id: number, body: unknown) => write<WorkoutPlan>('POST', `clients/${id}/workout-plans`, body),
  updateClientTargets: (id: number, body: unknown) => write<ProgressEntry>('PUT', `clients/${id}/nutrition-targets`, body),
  clientChat: (id: number) => request<TrainerChatMessage[]>(`clients/${id}/chat`),
  clientSharedItem: (clientId: number, itemType: ShareItemType, itemId: number) => request<SharedItemDetail>(`clients/${clientId}/shared-items/${itemType}/${itemId}`),
  sendClientChat: (id: number, message: string) => write<TrainerChatMessage>('POST', `clients/${id}/chat`, { message }),
  myTrainer: () => request<{ trainer: TrainerChatParticipant | null }>('clients/me/trainer'),
  myTrainerChat: () => request<TrainerChatResponse>('clients/me/chat'),
  sendMyTrainerChat: (message: string) => write<TrainerChatMessage>('POST', 'clients/me/chat', { message }),
  mySharedItem: (itemType: ShareItemType, itemId: number) => request<SharedItemDetail>(`clients/me/shared-items/${itemType}/${itemId}`),
  shareItem: (clientId: number, itemType: ShareItemType, itemId: number) => write<SharedItemResult>('POST', 'clients/shares', { client_id: clientId, item_type: itemType, item_id: itemId }),
  shareItemToTrainer: (itemType: ShareItemType, itemId: number) => write<SharedItemResult>('POST', 'clients/me/shares', { item_type: itemType, item_id: itemId }),
  workoutComplexes: () => request<WorkoutComplex[]>('workout-complexes'),
  workoutEquipment: () => request<WorkoutEquipment[]>('workout-equipment'),
  createWorkoutEquipment: (body: unknown) => write<WorkoutEquipment>('POST', 'workout-equipment', body),
  updateWorkoutEquipment: (id: number, body: unknown) => write<WorkoutEquipment>('PUT', `workout-equipment/${id}`, body),
  deleteWorkoutEquipment: (id: number) => write<{ deleted: boolean; id: number }>('DELETE', `workout-equipment/${id}`),
  createWorkoutComplex: (body: unknown) => write<WorkoutComplex>('POST', 'workout-complexes', body),
  updateWorkoutComplex: (id: number, body: unknown) => write<WorkoutComplex>('PUT', `workout-complexes/${id}`, body),
  updateWorkoutPlan: (id: number, body: unknown) => write<WorkoutPlan>('PUT', `workout-plans/${id}`, body),
  completeWorkoutPlan: (id: number) => write<WorkoutPlan>('POST', `workout-plans/${id}/complete`),
  cancelWorkoutPlan: (id: number) => write<WorkoutPlan>('POST', `workout-plans/${id}/cancel`),
  exercises: () => request<Exercise[]>('exercises'),
  feedback: () => request<FeedbackMessage[]>('feedback'),
  feedbackMine: () => request<FeedbackMessage[]>('feedback/mine'),
  feedbackUnreadCount: () => request<{ count: number }>('feedback/unread-count'),
  markFeedbackRead: (id: number) => write<{ ok: boolean }>('POST', `feedback/${id}/read`),
  replyFeedback: (id: number, reply: string) => write<FeedbackMessage>('POST', `feedback/${id}/reply`, { reply }),
  sendFeedback: (message: string) => write<FeedbackMessage>('POST', 'feedback', { message }),
  categories: (kind: 'product' | 'recipe') => request<ContentCategory[]>(`categories?kind=${kind}`),
  createCategory: (body: unknown) => write<ContentCategory>('POST', 'categories', body),
  articleSections: () => request<ArticleSection[]>('article-sections'),
  createArticleSection: (name: string) => write<ArticleSection>('POST', 'article-sections', { name }),
  updateArticleSection: (id: number, body: { description: string | null }) => write<ArticleSection>('PUT', `article-sections/${id}`, body),
  articles: () => request<Article[]>('articles'),
  createArticle: (body: unknown) => write<Article>('POST', 'articles', body),
  updateArticle: (id: number, body: unknown) => write<Article>('PUT', `articles/${id}`, body),
  updateArticleFlags: (id: number, body: unknown) => request<Article>(`articles/${id}/flags`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteArticle: (id: number) => write<{ deleted: boolean; id: number }>('DELETE', `articles/${id}`),
  post: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('POST', path, body),
  put: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('PUT', path, body),
  delete: <T = { ok: boolean }>(path: string) => write<T>('DELETE', path)
};
