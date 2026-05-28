<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, minLength, email } from '@vuelidate/validators';
import FormInput from '../../../../components/Form/Input.vue';
import { resetPassword } from '../../../../api/auth';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: { FormInput, NextButton },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      credentials: { email: '' },
      resetPassword: {
        message: '',
        showLoading: false,
      },
      error: '',
    };
  },
  validations() {
    return {
      credentials: {
        email: {
          required,
          email,
          minLength: minLength(4),
        },
      },
    };
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.resetPassword.showLoading = false;
      useAlert(message);
    },
    submit() {
      this.resetPassword.showLoading = true;
      resetPassword(this.credentials)
        .then(res => {
          let successMessage = this.$t('RESET_PASSWORD.API.SUCCESS_MESSAGE');
          if (res.data && res.data.message) {
            successMessage = res.data.message;
          }
          this.showAlertMessage(successMessage);
        })
        .catch(error => {
          let errorMessage = this.$t('RESET_PASSWORD.API.ERROR_MESSAGE');
          if (error?.response?.data?.message) {
            errorMessage = error.response.data.message;
          }
          this.showAlertMessage(errorMessage);
        });
    },
  },
};
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
          {{ $t('LOGIN.HERO_TITLE') }}
        </h1>
        <p class="mt-6 max-w-lg text-lg leading-8 text-white/70">
          {{ $t('LOGIN.HERO_SUBTITLE') }}
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
          <h1
            class="mt-8 text-3xl font-semibold leading-tight tracking-normal text-[#0B0E30]"
          >
            {{ $t('RESET_PASSWORD.TITLE') }}
          </h1>
          <p class="mt-3 text-base leading-7 text-n-slate-11">
            {{ $t('RESET_PASSWORD.DESCRIPTION') }}
          </p>
        </div>

        <form
          class="rounded-lg border border-n-weak bg-white p-6 shadow-[0_24px_70px_rgba(11,14,48,0.12)] sm:p-8"
          @submit.prevent="submit"
        >
          <div class="space-y-5">
            <FormInput
              v-model="credentials.email"
              name="email_address"
              :label="$t('RESET_PASSWORD.EMAIL.LABEL')"
              :has-error="v$.credentials.email.$error"
              :error-message="$t('RESET_PASSWORD.EMAIL.ERROR')"
              :placeholder="$t('RESET_PASSWORD.EMAIL.PLACEHOLDER')"
              @input="v$.credentials.email.$touch"
            />
            <NextButton
              lg
              type="submit"
              data-testid="submit_button"
              class="w-full rounded-lg !bg-[#F40064] !text-white hover:!bg-[#d90058]"
              :label="$t('RESET_PASSWORD.SUBMIT')"
              :disabled="
                v$.credentials.email.$invalid || resetPassword.showLoading
              "
              :is-loading="resetPassword.showLoading"
            />
          </div>
          <p class="mt-4 -mb-1 text-sm text-n-slate-11">
            {{ $t('RESET_PASSWORD.GO_BACK_TO_LOGIN') }}
            <router-link to="/app/login" class="font-medium text-[#F40064]">
              {{ $t('COMMON.CLICK_HERE') }}.
            </router-link>
          </p>
        </form>
      </div>
    </section>
  </main>
</template>
