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
  WorkoutPlan
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
  workoutComplexes: () => request<WorkoutComplex[]>('workout-complexes'),
  createWorkoutComplex: (body: unknown) => write<WorkoutComplex>('POST', 'workout-complexes', body),
  updateWorkoutComplex: (id: number, body: unknown) => write<WorkoutComplex>('PUT', `workout-complexes/${id}`, body),
  updateWorkoutPlan: (id: number, body: unknown) => write<WorkoutPlan>('PUT', `workout-plans/${id}`, body),
  completeWorkoutPlan: (id: number) => write<WorkoutPlan>('POST', `workout-plans/${id}/complete`),
  cancelWorkoutPlan: (id: number) => write<WorkoutPlan>('POST', `workout-plans/${id}/cancel`),
  exercises: () => request<Exercise[]>('exercises'),
  feedback: () => request<FeedbackMessage[]>('feedback'),
  feedbackUnreadCount: () => request<{ count: number }>('feedback/unread-count'),
  markFeedbackRead: () => write<{ ok: boolean }>('POST', 'feedback/read'),
  sendFeedback: (message: string) => write<FeedbackMessage>('POST', 'feedback', { message }),
  post: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('POST', path, body),
  put: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('PUT', path, body),
  delete: <T = { ok: boolean }>(path: string) => write<T>('DELETE', path)
};
