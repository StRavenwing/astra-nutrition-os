<script setup lang="ts">
import { computed, ref } from 'vue';
import type { SortState } from '@/types';
import { compareValues, formatDate, fmtValue, searchable } from '@/utils/format';

const props = defineProps<{
  rows: Record<string, unknown>[];
  columns: Array<{ key: string; label: string }>;
  query: string;
  sort: SortState;
}>();

const emit = defineEmits<{ 'update:sort': [sort: SortState] }>();
const localSort = ref<SortState>(props.sort);

const shown = computed(() => {
  let items = props.rows.filter((row) => searchable(row, props.query));
  if (props.sort.dir && props.sort.key) {
    items = [...items].sort((a, b) => compareValues(a[props.sort.key!], b[props.sort.key!]) * props.sort.dir);
  }
  return items;
});

function setSort(key: string) {
  if (props.sort.key !== key) localSort.value = { key, dir: 1 };
  else if (props.sort.dir === 1) localSort.value = { key, dir: -1 };
  else localSort.value = { key: null, dir: 0 };
  emit('update:sort', localSort.value);
}

function display(row: Record<string, unknown>, key: string) {
  const value = row[key];
  if (key.includes('date') || key.includes('_at')) return formatDate(value as string);
  return fmtValue(value);
}
</script>

<template>
  <div class="panel table-panel">
    <table>
      <thead>
        <tr>
          <th v-for="column in columns" :key="column.key">
            <button type="button" class="sort-button" @click="setSort(column.key)">
              {{ column.label }}
              <span>{{ sort.key === column.key ? (sort.dir === 1 ? '↑' : '↓') : '↕' }}</span>
            </button>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in shown" :key="JSON.stringify(row)">
          <td v-for="column in columns" :key="column.key" :class="{ number: typeof row[column.key] === 'number' }">
            <span v-if="column.key === 'status' || column.key === 'data_status'" class="pill">{{ display(row, column.key) }}</span>
            <template v-else>{{ display(row, column.key) }}</template>
          </td>
        </tr>
        <tr v-if="!shown.length">
          <td :colspan="columns.length" class="empty">Ничего не найдено</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style lang="scss">
.table-panel {
  width: 100%;
}
</style>
