import type { DiaryEntry, DiaryTotals } from '@/types';

export function fmt(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  const numeric = Number(value);
  if (Number.isNaN(numeric)) return String(value);
  return numeric.toLocaleString('ru-RU', { maximumFractionDigits: 1 });
}

export function fmtValue(value: unknown): string {
  return typeof value === 'number' ? fmt(value) : String(value ?? '—');
}

export function formatDate(value: string | null | undefined): string {
  return value ? new Date(value).toLocaleDateString('ru-RU') : '—';
}

export function formatDateTime(value: string | null | undefined): string {
  return value ? new Date(value).toLocaleString('ru-RU', { dateStyle: 'short', timeStyle: 'short' }) : '—';
}

export function dayIso(year: number, month: number, day: number): string {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

export function localToday(): string {
  const now = new Date();
  return dayIso(now.getFullYear(), now.getMonth(), now.getDate());
}

export function compareValues(a: unknown, b: unknown): number {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  const da = Date.parse(String(a));
  const db = Date.parse(String(b));
  if (!Number.isNaN(da) && !Number.isNaN(db) && String(a).match(/^\d{4}-/)) {
    return da - db;
  }
  return String(a).localeCompare(String(b), 'ru', { numeric: true, sensitivity: 'base' });
}

export function diaryTotals(items: DiaryEntry[]): DiaryTotals {
  return items.reduce(
    (total, item) => {
      const servings = Number(item.servings) || 0;
      total.kcal += (Number(item.kcal_per_serving) || 0) * servings;
      total.protein += (Number(item.protein_per_serving_g) || 0) * servings;
      total.fat += (Number(item.fat_per_serving_g) || 0) * servings;
      total.carbs += (Number(item.carbs_per_serving_g) || 0) * servings;
      total.cost += (Number(item.cost_per_serving_rsd) || 0) * servings;
      return total;
    },
    { kcal: 0, protein: 0, fat: 0, carbs: 0, cost: 0 }
  );
}

export function asNumberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const numeric = Number(value);
  return Number.isNaN(numeric) ? null : numeric;
}

export function searchable(item: unknown, query: string): boolean {
  return JSON.stringify(item).toLowerCase().includes(query.toLowerCase());
}
