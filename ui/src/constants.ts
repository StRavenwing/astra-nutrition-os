import type { PageInfo } from './types';

export const pages: PageInfo[] = [
  { id: 'dashboard', icon: '⌂', title: 'Обзор' },
  { id: 'products', icon: '◫', title: 'Продукты' },
  { id: 'recipes', icon: '◇', title: 'Рецепты' },
  { id: 'diary', icon: '☷', title: 'Дневник питания' },
  { id: 'progress', icon: '↗', title: 'Прогресс' },
  { id: 'workouts', icon: '⚡', title: 'Тренировки' },
  { id: 'theory', icon: '◈', title: 'Информация' }
];

export const productCategoryOptions = [
  'Белковые', 'Добавки', 'Зелень', 'Крупы', 'Масла', 'Молочные',
  'Морепродукты', 'Мясо', 'Напитки', 'Овощи', 'Основа', 'Перекусы',
  'Рыба', 'Соусы', 'Сыры', 'Фрукты', 'Хлеб', 'Ягоды'
];

export const productUnitOptions = ['г', 'мл', 'шт', 'бут.'];
export const mealOrder = ['Завтрак', 'Обед', 'Ужин', 'Перекус', 'Напиток'];
export const recipeCategories = [
  { key: 'Main', label: 'Основные блюда', prefix: 'M', x: 50, y: 0 },
  { key: 'Breakfast', label: 'Завтраки', prefix: 'B', x: 0, y: 0 },
  { key: 'Wrap', label: 'Врапы', prefix: 'W', x: 100, y: 0 },
  { key: 'Dessert', label: 'Десерты', prefix: 'D', x: 0, y: 50 },
  { key: 'Garnish', label: 'Гарниры', prefix: 'G', x: 50, y: 50 },
  { key: 'Salad', label: 'Салаты', prefix: 'S', x: 100, y: 50 },
  { key: 'Sauce', label: 'Соусы', prefix: 'SA', x: 100, y: 100 },
  { key: 'Snack', label: 'Перекусы', prefix: 'SN', x: 0, y: 100 },
  { key: 'Drink', label: 'Напитки', prefix: 'DR', x: 50, y: 100 },
  { key: 'Ready', label: 'Готовые блюда', prefix: 'R', x: 0, y: 0 }
];

export const recipeCategoryMap = Object.fromEntries(
  recipeCategories.map((item) => [item.key, item])
);

export const idLegend: Record<string, string> = {
  B: 'Breakfast · завтрак',
  M: 'Main · основное блюдо',
  W: 'Wrap · врап',
  D: 'Dessert · десерт',
  G: 'Garnish · гарнир',
  S: 'Salad · салат',
  SA: 'Sauce · соус',
  SN: 'Snack · перекус',
  DR: 'Drink · напиток',
  R: 'Ready · готовое блюдо'
};

export const productSpritePositions: Record<string, [number, number]> = {
  Белковые: [0, 0],
  Добавки: [25, 0],
  Зелень: [50, 0],
  Крупы: [75, 0],
  Масла: [100, 0],
  Молочные: [0, 33.333],
  Морепродукты: [25, 33.333],
  Мясо: [50, 33.333],
  Напитки: [75, 33.333],
  Овощи: [100, 33.333],
  Основа: [0, 66.667],
  Перекусы: [25, 66.667],
  Рыба: [50, 66.667],
  Соусы: [75, 66.667],
  Сыры: [100, 66.667],
  Хлеб: [0, 100],
  Ягоды: [25, 100],
  Фрукты: [50, 100]
};

export const workoutIcons: Record<string, string> = {
  Ноги: '◢',
  'Задняя цепь': '↙',
  Ягодицы: '●',
  Приводящие: '◇',
  Спина: '↟',
  Грудь: '◆',
  Плечи: '▲',
  Руки: '⌁',
  Кор: '◎'
};
