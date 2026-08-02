import type {
  DashboardResponse,
  DiaryEntry,
  Exercise,
  Product,
  ProductMeasure,
  ProgressEntry,
  RecipeDetail,
  RecipeSummary,
  WorkoutEntry
} from '@/types';

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`/api/${path}`, {
    headers: { 'Content-Type': 'application/json', ...(init.headers || {}) },
    ...init
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error || 'Ошибка');
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
  dashboard: () => request<DashboardResponse>('dashboard'),
  products: () => request<Product[]>('products'),
  productMeasures: () => request<ProductMeasure[]>('product-measures'),
  recipes: () => request<RecipeSummary[]>('recipes'),
  recipe: (id: string) => request<RecipeDetail>(`recipes/${id}`),
  diary: () => request<DiaryEntry[]>('diary'),
  progress: () => request<ProgressEntry[]>('progress'),
  workouts: () => request<WorkoutEntry[]>('workouts'),
  exercises: () => request<Exercise[]>('exercises'),
  post: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('POST', path, body),
  put: <T = { ok: boolean }>(path: string, body: unknown) => write<T>('PUT', path, body),
  delete: <T = { ok: boolean }>(path: string) => write<T>('DELETE', path)
};
