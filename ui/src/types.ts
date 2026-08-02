export type PageId = 'dashboard' | 'products' | 'recipes' | 'diary' | 'progress' | 'workouts';

export interface PageInfo {
  id: PageId;
  icon: string;
  title: string;
}

export type SortState = {
  key: string | null;
  dir: 0 | 1 | -1;
};

export interface DashboardTopRecipe {
  recipe_id: string;
  name: string;
  kcal_per_serving: number | null;
  protein_per_serving_g: number | null;
  cost_per_serving_rsd: number | null;
}

export interface DashboardResponse {
  products: number;
  recipes: number;
  approved: number;
  latest: ProgressEntry[];
  top: DashboardTopRecipe[];
}

export interface Product {
  product_id: string;
  name: string;
  category: string | null;
  unit: string | null;
  package_price_rsd: number | null;
  package_size: number | null;
  price_per_100_or_unit_rsd: number | null;
  kcal: number | null;
  protein_g: number | null;
  fat_g: number | null;
  carbs_g: number | null;
  data_status: string | null;
  note: string | null;
  [key: string]: unknown;
}

export interface ProductMeasure {
  product_id: string;
  measure_name: string;
  base_quantity: number;
}

export interface RecipeSummary {
  recipe_id: string;
  name: string;
  category: string;
  subcategory: string | null;
  version: string | number | null;
  status: string | null;
  servings: number | null;
  tags: string | null;
  manual_price_per_serving_rsd: number | null;
  manual_kcal_per_serving: number | null;
  manual_protein_per_serving_g: number | null;
  manual_fat_per_serving_g: number | null;
  manual_carbs_per_serving_g: number | null;
  kcal: number | null;
  protein_g: number | null;
  fat_g: number | null;
  carbs_g: number | null;
  kcal_per_serving: number | null;
  protein_per_serving_g: number | null;
  fat_per_serving_g: number | null;
  carbs_per_serving_g: number | null;
  cost_per_serving_rsd: number | null;
  [key: string]: unknown;
}

export interface RecipeIngredient {
  product_id: string;
  name: string;
  quantity: number | null;
  unit: string | null;
  measurement_name: string | null;
  measurement_quantity: number | null;
  portion_description: string | null;
  kcal: number | null;
  protein_g: number | null;
  fat_g: number | null;
  carbs_g: number | null;
  cost_rsd: number | null;
}

export interface RecipeDetail {
  recipe: RecipeSummary[];
  ingredients: RecipeIngredient[];
}

export interface DiaryEntry {
  diary_id: number;
  entry_date: string;
  meal_type: string | null;
  recipe_id: string | null;
  product_id: string | null;
  servings: number | null;
  quantity: number | null;
  unit: string | null;
  measurement_name: string | null;
  measurement_quantity: number | null;
  comment: string | null;
  name: string | null;
  item_type: 'recipe' | 'product';
  kcal_per_serving: number | null;
  protein_per_serving_g: number | null;
  fat_per_serving_g: number | null;
  carbs_per_serving_g: number | null;
  cost_per_serving_rsd: number | null;
  [key: string]: unknown;
}

export interface DiaryTotals {
  kcal: number;
  protein: number;
  fat: number;
  carbs: number;
  cost: number;
}

export interface ProgressEntry {
  progress_id: number;
  measured_at: string;
  weight_kg: number | null;
  height_cm: number | null;
  bmi: number | null;
  body_fat_pct: number | null;
  fat_mass_kg: number | null;
  muscle_pct: number | null;
  muscle_mass_kg: number | null;
  protein_target_g: number | null;
  fat_target_g: number | null;
  waist_cm: number | null;
  chest_cm: number | null;
  hips_cm: number | null;
  sleep_score: number | null;
  wellbeing_score: number | null;
  comment: string | null;
  [key: string]: unknown;
}

export interface Exercise {
  exercise_id: string;
  muscle_group: string | null;
  name: string;
  default_unit: string | null;
  default_sets: number | null;
  default_reps: number | null;
  target_rir: string | null;
  note: string | null;
}

export interface WorkoutEntry {
  workout_log_id: number;
  performed_at: string;
  exercise_id: string;
  working_weight: number | null;
  sets: number | null;
  reps: number | null;
  rir: string | null;
  machine_location: string | null;
  comment: string | null;
  name: string;
  muscle_group: string | null;
  default_unit: string | null;
  [key: string]: unknown;
}

export type ModalKind = 'products' | 'recipes' | 'diary' | 'progress' | 'workouts' | 'exercises';

export interface ModalState {
  kind: ModalKind;
  id?: string | number;
}
