<script setup lang="ts">
import { reactive, ref } from 'vue';
import { api, setAccessToken } from '@/api/client';
import type { AuthUser } from '@/types';
import PwaInstallButton from '@/components/shared/PwaInstallButton.vue';

const emit = defineEmits<{ authenticated: [user: AuthUser] }>();

const mode = ref<'login' | 'register'>('login');
const loading = ref(false);
const error = ref('');
const form = reactive({
  email: '',
  password: ''
});

async function submit() {
  loading.value = true;
  error.value = '';
  try {
    const result = mode.value === 'login'
      ? await api.login(form.email, form.password)
      : await api.register(form.email, form.password);
    setAccessToken(result.access_token);
    emit('authenticated', result.user);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="auth-page">
    <section class="auth-panel">
      <div class="brand auth-brand">
        <span>A</span>
        <div>
          Astra Nutrition OS
          <small>PERSONAL WORKSPACE</small>
        </div>
      </div>

      <div class="auth-tabs" role="tablist" aria-label="Авторизация">
        <button type="button" :class="{ active: mode === 'login' }" @click="mode = 'login'">Вход</button>
        <button type="button" :class="{ active: mode === 'register' }" @click="mode = 'register'">Регистрация</button>
      </div>

      <form class="auth-form" @submit.prevent="submit">
        <div class="field">
          <label>Email</label>
          <input v-model="form.email" type="email" autocomplete="email" required>
        </div>
        <div class="field">
          <label>Пароль</label>
          <input
            v-model="form.password"
            type="password"
            autocomplete="current-password"
            minlength="8"
            required
          >
        </div>
        <p id="form-error">{{ error }}</p>
        <button type="submit" class="primary auth-submit" :disabled="loading">
          {{ loading ? 'Проверка…' : mode === 'login' ? 'Войти' : 'Создать аккаунт' }}
        </button>
      </form>
      <PwaInstallButton wide />
    </section>
  </div>
</template>

<style lang="scss">
.auth-page {
  min-height: 100vh;
  margin: 0;
  padding: 28px;
  display: grid;
  place-items: center;
  background:
    linear-gradient(135deg, #f7f8fa 0%, #edf3ff 52%, #f2fbf6 100%);
}

.auth-panel {
  width: min(420px, 100%);
  padding: 24px;
  background: #fff;
  border: 1px solid var(--line);
  border-radius: 12px;
  box-shadow: 0 16px 42px #091e4224;
}

.auth-brand {
  padding: 0 0 20px;
}

.auth-tabs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
  padding: 4px;
  margin-bottom: 18px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #f7f8fa;

  button {
    border: 0;
    border-radius: 6px;
    padding: 9px;
    background: transparent;
    color: #44546f;
    font-weight: 700;
    cursor: pointer;

    &.active {
      background: #fff;
      color: var(--blue);
      box-shadow: 0 1px 2px #091e4218;
    }
  }
}

.auth-form {
  display: grid;
  gap: 12px;
  margin-bottom: 12px;
}

.auth-submit {
  width: 100%;

  &:disabled {
    opacity: .7;
    cursor: wait;
  }
}
</style>
