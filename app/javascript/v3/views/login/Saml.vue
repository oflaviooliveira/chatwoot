<script setup>
import { ref, nextTick, onMounted } from 'vue';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

// components
import FormInput from '../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  authError: {
    type: String,
    default: '',
  },
  target: {
    type: String,
    default: 'web',
  },
});

const { t } = useI18n();

const credentials = ref({
  email: '',
});

const loginApi = ref({
  showLoading: false,
  hasErrored: false,
});

const handleAuthError = () => {
  if (!props.authError) {
    return;
  }

  const translatedMessage = t('LOGIN.SAML.API.ERROR_MESSAGE');
  useAlert(translatedMessage);
  loginApi.value.hasErrored = true;
};

const validations = {
  credentials: {
    email: {
      required,
      email,
    },
  },
};

const v$ = useVuelidate(validations, { credentials });

const csrfToken = ref('');

onMounted(async () => {
  csrfToken.value =
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute('content') || '';

  await nextTick(handleAuthError);
});
</script>

<template>
  <main
    class="grid w-full min-h-screen bg-[#F6F7FB] lg:grid-cols-[minmax(0,1.05fr)_minmax(420px,0.95fr)]"
    style="font-family: Poppins, Inter, sans-serif"
  >
    <section
      class="relative hidden overflow-hidden bg-[#0B0E30] px-12 py-10 text-white lg:flex lg:flex-col lg:justify-between xl:px-16"
    >
      <img
        src="v3/assets/images/chatgquicks/login-symbol.png"
        alt="Gquicks HUB - Atendimento Web"
        class="pointer-events-none absolute -left-28 -top-20 h-[460px] w-[460px] max-w-none opacity-20"
      />
      <div
        class="pointer-events-none absolute -right-24 bottom-0 h-[360px] w-[360px] rounded-tl-[120px] bg-[#F40064]"
      />

      <div class="relative z-10">
        <img
          src="v3/assets/images/chatgquicks/login-logo-white.png"
          alt="Gquicks"
          class="h-9 w-auto"
        />
      </div>

      <div class="relative z-10 max-w-xl pb-20">
        <p
          class="mb-5 text-sm font-semibold uppercase tracking-normal text-[#F40064]"
        >
          Gquicks BPO
        </p>
        <h1
          class="text-5xl font-semibold leading-[1.08] tracking-normal xl:text-6xl"
        >
          {{ t('LOGIN.HERO_TITLE') }}
        </h1>
        <p class="mt-6 max-w-lg text-lg leading-8 text-white/70">
          {{ t('LOGIN.HERO_SUBTITLE') }}
        </p>
      </div>
    </section>

    <section
      class="flex min-h-screen items-center justify-center px-5 py-10 sm:px-8 lg:min-h-0 lg:px-12"
    >
      <div class="w-full max-w-[440px]">
        <div class="mb-8">
          <img
            src="v3/assets/images/chatgquicks/login-logo.png"
            alt="Gquicks"
            class="h-10 w-auto"
          />
          <h2
            class="mt-8 text-3xl font-semibold leading-tight tracking-normal text-[#0B0E30]"
          >
            {{ t('LOGIN.SAML.TITLE') }}
          </h2>
          <p class="mt-3 text-base leading-7 text-n-slate-11">
            {{ t('LOGIN.SAML.SUBTITLE') }}
          </p>
        </div>

        <form
          class="space-y-5 rounded-lg border border-n-weak bg-white p-6 shadow-[0_24px_70px_rgba(11,14,48,0.12)] sm:p-8"
          method="POST"
          action="/api/v1/auth/saml_login"
          :class="{
            'animate-wiggle': loginApi.hasErrored,
          }"
        >
          <FormInput
            v-model="credentials.email"
            name="email"
            type="text"
            :tabindex="1"
            required
            :label="t('LOGIN.SAML.WORK_EMAIL.LABEL')"
            :placeholder="t('LOGIN.SAML.WORK_EMAIL.PLACEHOLDER')"
            :has-error="v$.credentials.email.$error"
            @input="v$.credentials.email.$touch"
          />
          <input
            type="hidden"
            class="h-0"
            name="authenticity_token"
            :value="csrfToken"
          />
          <input type="hidden" class="h-0" name="target" :value="target" />
          <NextButton
            lg
            type="submit"
            class="w-full rounded-lg !bg-[#F40064] !text-white hover:!bg-[#d90058]"
            :tabindex="2"
            :label="t('LOGIN.SAML.SUBMIT')"
            :disabled="loginApi.showLoading"
            :is-loading="loginApi.showLoading"
          />
        </form>

        <p class="mt-6 text-sm text-n-slate-11">
          <router-link to="/app/login" class="font-medium text-[#F40064]">
            {{ t('LOGIN.SAML.BACK_TO_LOGIN') }}
          </router-link>
        </p>
      </div>
    </section>
  </main>
</template>
