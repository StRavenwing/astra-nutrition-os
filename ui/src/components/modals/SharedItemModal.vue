<script setup lang="ts">
import { computed } from 'vue';
import ModalDialog from '@/components/shared/ModalDialog.vue';
import type { SharedItemDetail } from '@/types';
import { fmt, formatDate } from '@/utils/format';

const props = defineProps<{ item: SharedItemDetail | null }>();
const emit = defineEmits<{ close: [] }>();

const data = computed(() => (props.item?.data || {}) as Record<string, any>);
const recipe = computed(() => data.value.recipe as Record<string, any> | null);
const ingredients = computed(() => Array.isArray(data.value.ingredients) ? data.value.ingredients as Record<string, any>[] : []);
const complexItems = computed(() => Array.isArray(data.value.items) ? data.value.items as Record<string, any>[] : []);
</script>

<template>
  <ModalDialog :open="Boolean(props.item)" :title="props.item?.name || 'Отправленный материал'" eyebrow="ОТ ТРЕНЕРА" wide @close="emit('close')">
    <div v-if="props.item" class="shared-item-modal">
      <template v-if="props.item.type === 'recipe' && recipe">
        <p class="subtle">{{ recipe.code }} · {{ recipe.is_ready ? 'Готовое блюдо' : 'Рецепт' }}</p>
        <div class="shared-item-macros">
          <div><span>Ккал</span><b>{{ fmt(recipe.kcal_per_serving) }}</b></div>
          <div><span>Белки</span><b>{{ fmt(recipe.protein_per_serving_g) }} г</b></div>
          <div><span>Жиры</span><b>{{ fmt(recipe.fat_per_serving_g) }} г</b></div>
          <div><span>Углеводы</span><b>{{ fmt(recipe.carbs_per_serving_g) }} г</b></div>
        </div>
        <h3>Состав</h3>
        <div v-if="recipe.is_ready" class="shared-item-note">КБЖУ готового блюда указано вручную.</div>
        <div v-else-if="ingredients.length" class="shared-item-list"><div v-for="ingredient in ingredients" :key="ingredient.id"><b>{{ ingredient.name }}</b><span>{{ fmt(ingredient.quantity) }} {{ ingredient.unit }}</span></div></div>
        <p v-else class="subtle">Состав не указан.</p>
      </template>

      <template v-else-if="props.item.type === 'product'">
        <p class="subtle">{{ data.category || 'Продукт' }}<template v-if="data.unit"> · на {{ data.unit }}</template></p>
        <div class="shared-item-macros">
          <div><span>Ккал</span><b>{{ fmt(data.kcal) }}</b></div>
          <div><span>Белки</span><b>{{ fmt(data.protein_g) }} г</b></div>
          <div><span>Жиры</span><b>{{ fmt(data.fat_g) }} г</b></div>
          <div><span>Углеводы</span><b>{{ fmt(data.carbs_g) }} г</b></div>
        </div>
        <p v-if="data.note" class="shared-item-text">{{ data.note }}</p>
      </template>

      <template v-else-if="props.item.type === 'article'">
        <p class="subtle">{{ data.section_name }}</p>
        <div class="shared-item-text">{{ data.body }}</div>
        <div v-if="data.links?.length" class="shared-item-list"><a v-for="link in data.links" :key="link.url" :href="link.url" target="_blank" rel="noreferrer">{{ link.title }}</a></div>
      </template>

      <template v-else-if="props.item.type === 'exercise'">
        <p class="subtle">{{ data.muscle_group || 'Другое' }} · {{ data.code }}</p>
        <p class="shared-item-text">{{ data.description || data.note || 'Описание упражнения пока не добавлено.' }}</p>
        <div v-if="data.variants?.length" class="shared-item-list"><div v-for="(variant, index) in data.variants" :key="variant.id || index"><b>Вариант {{ index + 1 }}</b><span>{{ [variant.machine, variant.equipment, variant.description].filter(Boolean).join(' · ') }}</span></div></div>
      </template>

      <template v-else-if="props.item.type === 'progress'">
        <p class="subtle">Замер от {{ formatDate(data.measured_at) }}</p>
        <div class="shared-item-metrics"><div><span>Вес</span><b>{{ fmt(data.weight_kg) }} кг</b></div><div><span>Желаемый вес</span><b>{{ fmt(data.desired_weight_kg) }} кг</b></div><div><span>Талия</span><b>{{ fmt(data.waist_cm) }} см</b></div><div><span>ИМТ</span><b>{{ fmt(data.bmi) }}</b></div><div><span>Процент жира</span><b>{{ fmt(data.body_fat_pct) }}%</b></div><div><span>Самочувствие</span><b>{{ fmt(data.wellbeing_score) }} / 5</b></div></div>
        <p v-if="data.comment" class="shared-item-text">{{ data.comment }}</p>
      </template>

      <template v-else-if="props.item.type === 'workout_complex'">
        <p v-if="data.comment" class="shared-item-text">{{ data.comment }}</p>
        <div v-if="complexItems.length" class="shared-item-list"><div v-for="item in complexItems" :key="item.id || item.exercise_id"><b>{{ item.name }}</b><span>{{ item.sets ? `${item.sets} подходов` : '' }}{{ item.duration_minutes ? ` · ${item.duration_minutes} мин` : '' }}</span></div></div>
      </template>

      <template v-else>
        <p class="subtle">{{ data.kind === 'machine' ? 'Тренажёр' : 'Инвентарь' }}</p>
        <p class="shared-item-text">{{ data.description || 'Описание не добавлено.' }}</p>
      </template>
    </div>
  </ModalDialog>
</template>

<style scoped lang="scss">
.shared-item-modal { min-width: min(560px, 100%); }
.shared-item-modal h3 { margin: 22px 0 9px; font-size: 15px; }
.shared-item-macros, .shared-item-metrics { display: grid; grid-template-columns: repeat(4, 1fr); gap: 9px; margin-top: 16px; }
.shared-item-metrics { grid-template-columns: repeat(3, 1fr); }
.shared-item-macros div, .shared-item-metrics div { display: grid; gap: 4px; padding: 11px; border-radius: 10px; background: #f5f7fb; }
.shared-item-macros span, .shared-item-metrics span { color: var(--muted); font-size: 10px; }
.shared-item-macros b, .shared-item-metrics b { font-size: 13px; }
.shared-item-text { margin: 16px 0 0; color: var(--ink); line-height: 1.6; white-space: pre-wrap; }
.shared-item-note { padding: 12px; border-radius: 10px; background: #f5f7fb; color: var(--muted); }
.shared-item-list { display: grid; gap: 7px; margin-top: 12px; }
.shared-item-list > div, .shared-item-list > a { display: flex; justify-content: space-between; gap: 12px; padding: 10px 12px; border: 1px solid var(--line); border-radius: 9px; color: inherit; text-decoration: none; }
.shared-item-list span { color: var(--muted); font-size: 12px; text-align: right; }
@media (max-width: 600px) { .shared-item-macros { grid-template-columns: repeat(2, 1fr); }.shared-item-metrics { grid-template-columns: repeat(2, 1fr); } }
</style>
