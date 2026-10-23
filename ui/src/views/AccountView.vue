<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { api } from '@/api/client';
import type { AuthUser } from '@/types';

const props = defineProps<{ user: AuthUser }>();
const emit = defineEmits<{ updated: [user: AuthUser] }>();

const profile = reactive({
  name: '',
  email: '',
  phone: '',
  avatar: null as string | null
});
const password = reactive({
  current_password: '',
  new_password: '',
  confirm_password: ''
});

const profileError = ref('');
const profileNotice = ref('');
const profileLoading = ref(false);
const passwordError = ref('');
const passwordNotice = ref('');
const passwordLoading = ref(false);
const verificationCode = ref('');
const verificationError = ref('');
const verificationNotice = ref('');
const verificationLoading = ref(false);
const resetError = ref('');
const resetNotice = ref('');
const resetLoading = ref(false);
const showPasswords = ref(false);
const avatarInput = ref<HTMLInputElement | null>(null);
const emailNeedsSave = computed(() => profile.email.trim().toLowerCase() !== props.user.email.toLowerCase());

function syncProfile(user: AuthUser) {
  profile.name = user.name || '';
  profile.email = user.email || '';
  profile.phone = user.phone || '';
  profile.avatar = user.avatar || null;
}

watch(() => props.user, syncProfile, { immediate: true });

function displayInitial() {
  return (profile.name || profile.email || '?').trim().slice(0, 1).toUpperCase();
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : 'Не удалось выполнить операцию';
}

function selectAvatar() {
  avatarInput.value?.click();
}

function readAvatar(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  if (!file.type.startsWith('image/')) {
    profileError.value = 'Выберите файл изображения';
    return;
  }
  if (file.size > 700 * 1024) {
    profileError.value = 'Размер аватара не должен превышать 700 КБ';
    return;
  }

  const reader = new FileReader();
  reader.onload = () => {
    profile.avatar = typeof reader.result === 'string' ? reader.result : null;
    profileError.value = '';
    profileNotice.value = 'Аватар выбран. Сохраните профиль, чтобы применить изменения.';
  };
  reader.onerror = () => { profileError.value = 'Не удалось прочитать файл аватара'; };
  reader.readAsDataURL(file);
}

async function saveProfile() {
  profileError.value = '';
  profileNotice.value = '';
  profileLoading.value = true;
  try {
    const updated = await api.updateProfile({ ...profile });
    emit('updated', updated);
    profileNotice.value = updated.email_verified
      ? 'Профиль сохранён'
      : 'Профиль сохранён. Новый email нужно подтвердить';
    verificationCode.value = '';
    verificationError.value = '';
    verificationNotice.value = '';
  } catch (error) {
    profileError.value = errorMessage(error);
  } finally {
    profileLoading.value = false;
  }
}

async function changePassword() {
  passwordError.value = '';
  passwordNotice.value = '';
  passwordLoading.value = true;
  try {
    const result = await api.changePassword({ ...password });
    password.current_password = '';
    password.new_password = '';
    password.confirm_password = '';
    passwordNotice.value = result.message || 'Пароль изменён';
  } catch (error) {
    passwordError.value = errorMessage(error);
  } finally {
    passwordLoading.value = false;
  }
}

async function requestVerification() {
  verificationError.value = '';
  verificationNotice.value = '';
  verificationLoading.value = true;
  try {
    const result = await api.requestEmailVerification();
    verificationNotice.value = result.message;
  } catch (error) {
    verificationError.value = errorMessage(error);
  } finally {
    verificationLoading.value = false;
  }
}

async function confirmVerification() {
  verificationError.value = '';
  verificationNotice.value = '';
  verificationLoading.value = true;
  try {
    const updated = await api.confirmEmailVerification(verificationCode.value);
    emit('updated', updated);
    verificationCode.value = '';
    verificationNotice.value = 'Email подтверждён';
  } catch (error) {
    verificationError.value = errorMessage(error);
  } finally {
    verificationLoading.value = false;
  }
}

async function requestReset() {
  resetError.value = '';
  resetNotice.value = '';
  resetLoading.value = true;
  try {
    const result = await api.requestPasswordReset(profile.email);
    resetNotice.value = result.message;
  } catch (error) {
    resetError.value = errorMessage(error);
  } finally {
    resetLoading.value = false;
  }
}
</script>

<template>
  <section class="account-page">
    <div class="account-hero">
      <div class="account-avatar account-avatar-large">
        <img v-if="profile.avatar" :src="profile.avatar" alt="Аватар пользователя">
        <span v-else>{{ displayInitial() }}</span>
      </div>
      <div>
        <p class="eyebrow">ПРОФИЛЬ</p>
        <h2>Личный кабинет</h2>
        <p>Управляйте личными данными, безопасностью и подтверждением почты.</p>
      </div>
    </div>

    <div class="account-grid">
      <section class="account-card">
        <div class="account-card-heading">
          <div>
            <p class="eyebrow">ЛИЧНЫЕ ДАННЫЕ</p>
            <h3>Профиль</h3>
          </div>
          <button type="button" class="secondary-button" @click="selectAvatar">Изменить аватар</button>
          <input ref="avatarInput" class="visually-hidden" type="file" accept="image/*" @change="readAvatar">
        </div>

        <form class="account-form" @submit.prevent="saveProfile">
          <div class="account-avatar-row">
            <div class="account-avatar">
              <img v-if="profile.avatar" :src="profile.avatar" alt="Аватар пользователя">
              <span v-else>{{ displayInitial() }}</span>
            </div>
            <div>
              <strong>{{ profile.name || 'Ваше имя' }}</strong>
              <p>Изображение будет отображаться в навигации и профиле.</p>
            </div>
          </div>

          <div class="account-fields">
            <label class="account-field">
              <span>Имя</span>
              <input v-model.trim="profile.name" type="text" maxlength="120" autocomplete="name" placeholder="Ваше имя">
            </label>
            <label class="account-field">
              <span>Email</span>
              <input v-model.trim="profile.email" :type="props.user.is_admin ? 'text' : 'email'" required autocomplete="email" inputmode="email" placeholder="name@example.com">
            </label>
            <label class="account-field">
              <span>Номер телефона</span>
              <input v-model.trim="profile.phone" type="tel" maxlength="40" autocomplete="tel" placeholder="+1234567890">
            </label>
          </div>

          <div class="account-status" :class="props.user.email_verified ? 'is-ok' : 'is-warning'">
            <span>{{ props.user.email_verified ? '✓' : '!' }}</span>
            <div>
              <strong>{{ props.user.email_verified ? 'Email подтверждён' : 'Email не подтверждён' }}</strong>
              <p v-if="!props.user.email_verified">{{ emailNeedsSave ? 'Сначала сохраните новый email, затем запросите код.' : 'Подтвердите почту, чтобы восстановление доступа было безопасным.' }}</p>
            </div>
            <button v-if="!props.user.email_verified" type="button" class="secondary-button" :disabled="verificationLoading || emailNeedsSave" @click="requestVerification">
              {{ verificationLoading ? 'Отправка…' : 'Отправить код' }}
            </button>
          </div>

          <div v-if="!props.user.email_verified" class="verification-row">
            <input v-model.trim="verificationCode" inputmode="numeric" maxlength="6" placeholder="Код из письма" aria-label="Код подтверждения email">
            <button type="button" class="secondary-button" :disabled="verificationLoading || verificationCode.length !== 6" @click="confirmVerification">Подтвердить email</button>
          </div>
          <p v-if="verificationError" class="form-message is-error">{{ verificationError }}</p>
          <p v-if="verificationNotice" class="form-message is-ok">{{ verificationNotice }}</p>
          <p v-if="profileError" class="form-message is-error">{{ profileError }}</p>
          <p v-if="profileNotice" class="form-message is-ok">{{ profileNotice }}</p>

          <div class="account-actions">
            <button type="submit" class="primary" :disabled="profileLoading">{{ profileLoading ? 'Сохранение…' : 'Сохранить профиль' }}</button>
          </div>
        </form>
      </section>

      <section class="account-card">
        <div class="account-card-heading">
          <div>
            <p class="eyebrow">БЕЗОПАСНОСТЬ</p>
            <h3>Пароль</h3>
          </div>
          <button type="button" class="text-button" @click="showPasswords = !showPasswords">{{ showPasswords ? 'Скрыть' : 'Показать' }}</button>
        </div>

        <form class="account-form" @submit.prevent="changePassword">
          <label class="account-field">
            <span>Старый пароль</span>
            <input v-model="password.current_password" :type="showPasswords ? 'text' : 'password'" required autocomplete="current-password">
          </label>
          <label class="account-field">
            <span>Новый пароль</span>
            <input v-model="password.new_password" :type="showPasswords ? 'text' : 'password'" required minlength="8" autocomplete="new-password">
          </label>
          <label class="account-field">
            <span>Подтвердите новый пароль</span>
            <input v-model="password.confirm_password" :type="showPasswords ? 'text' : 'password'" required minlength="8" autocomplete="new-password">
          </label>
          <p class="account-hint">Минимальная длина пароля — 8 символов.</p>
          <p v-if="passwordError" class="form-message is-error">{{ passwordError }}</p>
          <p v-if="passwordNotice" class="form-message is-ok">{{ passwordNotice }}</p>
          <div class="account-actions">
            <button type="submit" class="primary" :disabled="passwordLoading">{{ passwordLoading ? 'Сохранение…' : 'Сменить пароль' }}</button>
          </div>
        </form>

        <div class="reset-password-block">
          <div>
            <strong>Не помните текущий пароль?</strong>
            <p>Отправим письмо для создания нового пароля на {{ profile.email }}.</p>
          </div>
          <button type="button" class="secondary-button" :disabled="resetLoading" @click="requestReset">{{ resetLoading ? 'Отправка…' : 'Сбросить пароль' }}</button>
          <p v-if="resetError" class="form-message is-error">{{ resetError }}</p>
          <p v-if="resetNotice" class="form-message is-ok">{{ resetNotice }}</p>
        </div>
      </section>
    </div>
  </section>
</template>

<style scoped lang="scss">
.account-page {
  display: grid;
  gap: 20px;
}

.account-hero {
  display: flex;
  align-items: center;
  gap: 18px;
  min-height: 150px;
  padding: 28px 32px;
  border-radius: 24px;
  background: #172033;
  color: #fff;

  h2 {
    margin: 0;
    font-size: clamp(26px, 3vw, 36px);
  }

  p:not(.eyebrow) {
    margin: 8px 0 0;
    color: #aab6c8;
  }

  .eyebrow { color: #bdf2d3; }
}

.account-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(320px, .9fr);
  gap: 18px;
  align-items: start;
}

.account-card {
  display: grid;
  gap: 22px;
  padding: 25px;
  border: 1px solid #e1e5ed;
  border-radius: 20px;
  background: #fff;
}

.account-card-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;

  h3 { margin: 0; font-size: 22px; }
}

.account-avatar {
  display: grid;
  flex: 0 0 68px;
  place-items: center;
  width: 68px;
  height: 68px;
  overflow: hidden;
  border-radius: 50%;
  background: #f3c6a9;
  color: #172033;
  font-size: 25px;
  font-weight: 850;

  img { width: 100%; height: 100%; object-fit: cover; }
}

.account-avatar-large {
  flex-basis: 82px;
  width: 82px;
  height: 82px;
  border: 4px solid #bdf2d3;
}

.account-avatar-row {
  display: flex;
  align-items: center;
  gap: 14px;

  strong { display: block; font-size: 14px; }
  p { margin: 4px 0 0; color: #7d879b; font-size: 12px; }
}

.account-form, .account-fields { display: grid; gap: 14px; }
.account-fields { grid-template-columns: 1fr 1fr; }

.account-field {
  display: grid;
  gap: 7px;

  span { color: #172033; font-size: 12px; font-weight: 800; }
  input { width: 100%; }
}

.account-status {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 13px 14px;
  border-radius: 13px;

  > span {
    display: grid;
    flex: 0 0 25px;
    place-items: center;
    width: 25px;
    height: 25px;
    border-radius: 50%;
    font-weight: 900;
  }

  div { flex: 1; min-width: 0; }
  strong { font-size: 12px; }
  p { margin: 3px 0 0; font-size: 11px; }
  .secondary-button { flex: 0 0 auto; min-height: 38px; }
}

.account-status.is-ok { background: #e2f7eb; color: #21764b; }
.account-status.is-ok > span { background: #bdf2d3; }
.account-status.is-warning { background: #fff5df; color: #8b641f; }
.account-status.is-warning > span { background: #ffdf9f; }

.verification-row {
  display: flex;
  gap: 10px;

  input { flex: 1; min-width: 0; }
}

.account-actions { display: flex; justify-content: flex-end; }
.account-hint { margin: -4px 0 0; color: #7d879b; font-size: 11px; }
.text-button { border: 0; background: none; color: #5f6fc2; font-size: 12px; font-weight: 800; cursor: pointer; }
.form-message { margin: 0; font-size: 12px; }
.form-message.is-error { color: #ae2a19; }
.form-message.is-ok { color: #21764b; }

.reset-password-block {
  display: grid;
  gap: 10px;
  padding-top: 20px;
  border-top: 1px solid #e8ebf1;

  strong { font-size: 13px; }
  p { margin: 4px 0 0; color: #7d879b; font-size: 11px; }
  .secondary-button { justify-self: start; }
}

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

@media (max-width: 850px) {
  .account-grid { grid-template-columns: 1fr; }
}

@media (max-width: 560px) {
  .account-hero { align-items: flex-start; padding: 22px; }
  .account-card { padding: 19px; }
  .account-fields { grid-template-columns: 1fr; }
  .account-status { align-items: flex-start; flex-wrap: wrap; }
  .account-status .secondary-button { margin-left: 35px; }
  .verification-row { flex-direction: column; }
}
</style>
