<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { DashboardResponse, PageId } from '@/types';
import { fmt } from '@/utils/format';
import MetricCard from '@/components/shared/MetricCard.vue';

const props = defineProps<{ refreshKey: number }>();
const emit = defineEmits<{
  navigate: [page: PageId];
  openRecipe: [id: string];
}>();

const data = ref<DashboardResponse | null>(null);
const loading = ref(false);
const error = ref('');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    data.value = await api.dashboard();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(() => props.refreshKey, load);
</script>

<template>
  <div v-if="loading" class="panel">Загрузка…</div>
  <div v-else-if="error" class="panel empty">{{ error }}</div>
  <template v-else-if="data">
    <div class="kpis dashboard-kpis">
      <MetricCard label="Продукты" :value="data.products" icon="◫" note="Открыть каталог →" button @click="emit('navigate', 'products')" />
      <MetricCard label="Рецепты" :value="data.recipes" icon="◇" note="Открыть рецепты →" button @click="emit('navigate', 'recipes')" />
      <MetricCard
        label="Текущие показатели"
        :value="`${data.latest[0]?.weight_kg || '—'} кг`"
        icon="↗"
        :note="`${data.latest[0]?.waist_cm ? `Талия ${fmt(data.latest[0].waist_cm)} см · ` : ''}Открыть прогресс →`"
        button
        @click="emit('navigate', 'progress')"
      />
    </div>

    <div class="panel">
      <h3>Самые белковые порции</h3>
      <div class="bars protein-recipe-links">
        <button
          v-for="recipe in data.top"
          :key="recipe.recipe_id"
          type="button"
          class="bar protein-recipe-link"
          :title="`Открыть рецепт ${recipe.name}`"
          @click="emit('openRecipe', recipe.recipe_id)"
        >
          <span>{{ recipe.name }}</span>
          <span class="track"><i :style="{ width: `${Math.min((Number(recipe.protein_per_serving_g) || 0) / 55 * 100, 100)}%` }"></i></span>
          <b>{{ fmt(recipe.protein_per_serving_g) }} г</b>
          <em>→</em>
        </button>
      </div>
    </div>
  </template>
</template>

<style lang="scss">
.dashboard-kpis {
  button {
    border: 1px solid var(--line);
    cursor: pointer;
  }
}
</style>
