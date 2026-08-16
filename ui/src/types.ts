export type PageId = 'dashboard' | 'products' | 'recipes' | 'diary' | 'progress' | 'workouts' | 'theory';

export interface AuthUser {
  id: number;
  email: string;
  is_admin: boolean;
}

export interface AuthResponse {
  access_token: string;
  token_type: 'bearer';
  user: AuthUser;
}

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
  id: number;
  code: string;
  name: string;
  kcal_per_serving: number | null;
  protein_per_serving_g: number | null;
  cost_per_serving_rsd: number | null;
}

export interface DashboardResponse {
  products: number;
  recipes: number;
  approved: number;
  latest: ProgressEntry | null;
  top: DashboardTopRecipe[];
}

export interface Product {
  id: number;
  code: string;
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
  note: string | null;
  measures: ProductMeasure[];
  [key: string]: unknown;
}

export interface ProductMeasure {
  id: number;
  product_id: number;
  measure_name: string;
  base_quantity: number;
}

export interface ProductNutritionScanResult {
  kcal: number | null;
  protein_g: number | null;
  fat_g: number | null;
  carbs_g: number | null;
  basis: 'per_100' | 'unknown' | string;
  confidence: number;
  field_confidence: Record<string, number>;
  raw_text: string;
  warnings: string[];
}

export interface RecipeSummary {
  id: number;
  code: string;
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
  collection: 'common' | 'local';
  owner_id: number | null;
  submission_requested: boolean;
  moderation_status: 'none' | 'pending' | 'accepted' | 'rejected' | 'revision';
  moderation_note: string | null;
  submitted_by_id: number | null;
  is_submitter: boolean;
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
  id: number;
  product_id: number;
  product_code: string;
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
  recipe: RecipeSummary;
  ingredients: RecipeIngredient[];
}

export interface DiaryEntry {
  id: number;
  entry_date: string;
  meal_type: string | null;
  recipe_id: number | null;
  recipe_code: string | null;
  product_id: number | null;
  product_code: string | null;
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
  id: number;
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

export interface ExerciseVariant {
  id?: number;
  position?: number;
  machine: string | null;
  equipment: string | null;
  description: string | null;
  technique: string | null;
  tips: string | null;
}

export interface Exercise {
  id: number;
  code: string;
  muscle_group: string | null;
  name: string;
  default_unit: string | null;
  default_sets: number | null;
  default_reps: number | null;
  target_rir: string | null;
  note: string | null;
  description: string | null;
  photos: string[];
  video: string | null;
  variants: ExerciseVariant[];
}

export interface FeedbackMessage {
  id: number;
  email: string;
  submitted_at: string;
  message: string;
  is_read: boolean;
  reply: string | null;
  replied_at: string | null;
}

export interface RegisteredUser extends AuthUser {
  created_at: string;
}

export interface WorkoutEntry {
  id: number;
  performed_at: string;
  exercise_id: number;
  exercise_code: string;
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

export interface WorkoutPlanItem {
  id?: number;
  exercise_id: number;
  exercise_code?: string;
  name?: string;
  muscle_group?: string | null;
  default_unit?: string | null;
  working_weight: number | null;
  sets: number | null;
  duration_minutes: number | null;
  speed_kmh: number | null;
}

export interface WorkoutPlan {
  id: number;
  scheduled_at: string;
  status: 'planned' | 'archived' | string;
  completed_at: string | null;
  items: WorkoutPlanItem[];
}

export interface WorkoutComplex {
  id: number;
  name: string;
  comment: string | null;
  photos: string[];
  video: string | null;
  items: WorkoutPlanItem[];
}

export interface ContentCategory {
  id: number;
  kind: 'product' | 'recipe';
  name: string;
  collection: 'common' | 'local';
  owner_id: number | null;
}

export interface ArticleSection {
  id: number;
  name: string;
  description: string | null;
  article_count: number;
}

export interface ArticleLink {
  title: string;
  url: string;
}

export interface Article {
  id: number;
  section_id: number;
  section_name: string;
  title: string;
  body: string;
  tags: string | null;
  links: ArticleLink[];
  photos: string[];
  video: string | null;
  is_pinned: boolean;
  is_hidden: boolean;
  created_at: string;
  updated_at: string | null;
}

export type ModalKind = 'products' | 'recipes' | 'diary' | 'progress' | 'workouts' | 'exercises';

export interface ModalState {
  kind: ModalKind;
  id?: number;
}
