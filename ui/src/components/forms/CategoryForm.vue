<script setup lang="ts">
import { reactive, ref } from 'vue';
import { api } from '@/api/client';

const props = defineProps<{ kind: 'product' | 'recipe'; isAdmin: boolean }>();
const emit = defineEmits<{ saved: []; cancel: [] }>();
const form = reactive({ name: '', collection: props.isAdmin ? 'common' : 'local' });
const error = ref('');
const saving = ref(false);

async function save() {
  if (!form.name.trim() || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    await api.createCategory({ kind: props.kind, name: form.name.trim(), collection: form.collection });
    emit('saved');
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <form class="modal-form-body" @submit.prevent="save">
    <div class="field full"><label>Название категории</label><input v-model="form.name" required maxlength="120" autofocus></div>
    <div class="field full">
      <label>Коллекция</label>
      <select v-model="form.collection" :disabled="!props.isAdmin">
        <option value="common">Общая коллекция</option>
        <option value="local">Личная коллекция</option>
      </select>
      <small class="subtle">Общие категории видны всем пользователям, личные — только вам.</small>
    </div>
    <p v-if="error" class="form-error">{{ error }}</p>
    <div class="actions"><button type="button" @click="$emit('cancel')">Отмена</button><button class="primary" type="submit" :disabled="saving || !form.name.trim()">Сохранить</button></div>
  </form>
</template>
