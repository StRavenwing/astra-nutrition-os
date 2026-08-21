<script setup lang="ts">
import { reactive, ref } from 'vue';
import { api, setAccessToken } from '@/api/client';
import type { AuthUser } from '@/types';

const props = withDefaults(defineProps<{ allowGuest?: boolean }>(), { allowGuest: false });
const emit = defineEmits<{ authenticated: [user: AuthUser]; guest: [] }>();

const mode = ref<'login' | 'register'>('login');
const resetMode = ref(false);
const resetSent = ref(false);
const loading = ref(false);
const error = ref('');
const notice = ref('');
const form = reactive({
  email: '',
  password: ''
});
const resetForm = reactive({
  email: '',
  code: '',
  password: ''
});

async function submit() {
  loading.value = true;
  error.value = '';
  notice.value = '';
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

function openReset() {
  resetMode.value = true;
  resetSent.value = false;
  error.value = '';
  notice.value = '';
  resetForm.email = form.email;
  resetForm.code = '';
  resetForm.password = '';
}

function closeReset() {
  resetMode.value = false;
  resetSent.value = false;
  error.value = '';
  notice.value = '';
}

async function requestResetCode() {
  loading.value = true;
  error.value = '';
  notice.value = '';
  try {
    await api.requestPasswordReset(resetForm.email);
    resetSent.value = true;
    notice.value = 'Если аккаунт существует, код отправлен на почту.';
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}

async function confirmReset() {
  loading.value = true;
  error.value = '';
  notice.value = '';
  try {
    await api.confirmPasswordReset(resetForm.email, resetForm.code, resetForm.password);
    form.email = resetForm.email;
    form.password = '';
    closeReset();
    notice.value = 'Пароль изменён. Теперь можно войти.';
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="auth-page" :class="{ 'reset-active': resetMode }">
    <section class="auth-panel">
      <div class="brand auth-brand">
        <img class="auth-brand-mark" src="/assets/astra-app-icon.png" alt="Astra">
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
      <section v-if="resetMode" class="auth-reset">
        <div class="auth-section-heading">
          <h2>Забыли пароль?</h2>
          <p>Отправим одноразовый код на email, указанный при регистрации.</p>
        </div>
        <form v-if="!resetSent" class="auth-form auth-reset-form" @submit.prevent="requestResetCode">
          <div class="field">
            <label>Email</label>
            <input v-model="resetForm.email" type="email" autocomplete="email" required>
          </div>
          <p id="form-error">{{ error }}</p>
          <button type="submit" class="primary auth-submit" :disabled="loading">
            {{ loading ? 'Отправка…' : 'Отправить код' }}
          </button>
        </form>
        <form v-else class="auth-form auth-reset-form" @submit.prevent="confirmReset">
          <div class="field">
            <label>Код из письма</label>
            <input v-model="resetForm.code" inputmode="numeric" autocomplete="one-time-code" minlength="6" maxlength="6" required>
          </div>
          <div class="field">
            <label>Новый пароль</label>
            <input v-model="resetForm.password" type="password" autocomplete="new-password" minlength="8" required>
          </div>
          <p id="form-error">{{ error }}</p>
          <p class="auth-notice">{{ notice }}</p>
          <button type="submit" class="primary auth-submit" :disabled="loading">
            {{ loading ? 'Сохранение…' : 'Сохранить новый пароль' }}
          </button>
        </form>
        <button type="button" class="auth-back" @click="closeReset">← Вернуться ко входу</button>
      </section>
      <button v-if="!resetMode && mode === 'login'" type="button" class="forgot-password" @click="openReset">Забыли пароль?</button>
      <p v-if="!resetMode && notice" class="auth-notice">{{ notice }}</p>
      <button v-if="props.allowGuest" type="button" class="guest-entry" @click="$emit('guest')">Продолжить без входа</button>
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

.auth-brand-mark {
  display: block;
  flex: 0 0 44px;
  width: 44px;
  height: 44px;
  border-radius: 12px;
  object-fit: cover;
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

.reset-active .auth-tabs,
.reset-active > .auth-panel > form.auth-form:not(.auth-reset-form),
.reset-active .guest-entry {
  display: none;
}

.auth-reset {
  display: block;
}

.auth-section-heading {
  margin-bottom: 18px;

  h2 {
    margin: 0 0 6px;
    font-size: 20px;
  }

  p {
    margin: 0;
    color: var(--muted);
    font-size: 13px;
    line-height: 1.45;
  }
}

.auth-notice {
  min-height: 18px;
  margin: 0;
  color: #216e4e;
  font-size: 12px;
}

.forgot-password,
.auth-back {
  display: block;
  width: 100%;
  margin-top: 12px;
  border: 0;
  background: transparent;
  color: var(--blue);
  font-size: 12px;
  font-weight: 750;
  cursor: pointer;
}

.auth-back {
  color: var(--muted);
}

.guest-entry {
  width: 100%;
  margin-top: 10px;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 10px 12px;
  background: #fff;
  color: var(--muted);
  font-weight: 700;
  cursor: pointer;
}
</style>
