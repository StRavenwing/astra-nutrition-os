<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { DashboardResponse, PageId, RegisteredUser } from '@/types';
import { fmt, formatDate } from '@/utils/format';
import MetricCard from '@/components/shared/MetricCard.vue';
import ModalDialog from '@/components/shared/ModalDialog.vue';

const props = defineProps<{ refreshKey: number; isAdmin: boolean }>();
const emit = defineEmits<{
  navigate: [page: PageId];
  openRecipe: [id: number];
}>();

const data = ref<DashboardResponse | null>(null);
const users = ref<RegisteredUser[]>([]);
const usersOpen = ref(false);
const loading = ref(false);
const error = ref('');

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const [dashboardData, registeredUsers] = await Promise.all([
      api.dashboard(),
      props.isAdmin ? api.users() : Promise.resolve([] as RegisteredUser[])
    ]);
    data.value = dashboardData;
    users.value = registeredUsers;
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
        :value="`${data.latest?.weight_kg || '—'} кг`"
        icon="↗"
        :note="`${data.latest?.waist_cm ? `Талия ${fmt(data.latest.waist_cm)} см · ` : ''}Открыть прогресс →`"
        button
        @click="emit('navigate', 'progress')"
      />
      <MetricCard v-if="props.isAdmin" label="Пользователи" :value="users.length" icon="👥" note="Открыть список →" button @click="usersOpen = true" />
    </div>

    <div class="panel">
      <h3>Самые белковые порции</h3>
      <div class="bars protein-recipe-links">
        <button
          v-for="recipe in data.top"
          :key="recipe.id"
          type="button"
          class="bar protein-recipe-link"
          :title="`Открыть рецепт ${recipe.name}`"
          @click="emit('openRecipe', recipe.id)"
        >
          <span>{{ recipe.name }}</span>
          <span class="track"><i :style="{ width: `${Math.min((Number(recipe.protein_per_serving_g) || 0) / 55 * 100, 100)}%` }"></i></span>
          <b>{{ fmt(recipe.protein_per_serving_g) }} г</b>
          <em>→</em>
        </button>
      </div>
    </div>
  </template>
  <ModalDialog :open="usersOpen" title="Зарегистрированные пользователи" eyebrow="USERS" wide @close="usersOpen = false">
    <div class="registered-users-list">
      <div v-for="user in users" :key="user.id" class="registered-user-row">
        <div><b>{{ user.email }}</b><small>ID {{ user.id }} · {{ user.is_admin ? 'Администратор' : 'Пользователь' }}</small></div>
        <time>{{ formatDate(user.created_at) }}</time>
      </div>
      <div v-if="!users.length" class="empty">Зарегистрированных пользователей пока нет</div>
    </div>
  </ModalDialog>
</template>

<style lang="scss">
.dashboard-kpis {
  button {
    border: 1px solid var(--line);
    cursor: pointer;
  }
}

.registered-users-list { display: grid; gap: 8px; }
.registered-user-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 13px; border: 1px solid var(--line); border-radius: 10px; background: #fafbfc; }
.registered-user-row b, .registered-user-row small { display: block; }
.registered-user-row small, .registered-user-row time { color: var(--muted); font-size: 11px; }
.registered-user-row time { white-space: nowrap; }
@media (max-width: 600px) { .registered-user-row { align-items: flex-start; flex-direction: column; gap: 4px; } }
</style>
