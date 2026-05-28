<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import FormInput from '../../../components/Form/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { setNewPassword } from '../../../api/auth';

export default {
  components: {
    FormInput,
    NextButton,
  },
  props: {
    resetPasswordToken: { type: String, default: '' },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        confirmPassword: '',
        password: '',
      },
      newPasswordAPI: {
        message: '',
        showLoading: false,
      },
      error: '',
    };
  },
  mounted() {
    // If url opened without token
    // redirect to login
    if (!this.resetPasswordToken) {
      window.location = DEFAULT_REDIRECT_URL;
    }
  },
  validations: {
    credentials: {
      password: {
        required,
        minLength: minLength(6),
      },
      confirmPassword: {
        required,
        minLength: minLength(6),
        isEqPassword(value) {
          if (value !== this.credentials.password) {
            return false;
          }
          return true;
        },
      },
    },
  },
  methods: {
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.newPasswordAPI.showLoading = false;
      useAlert(message);
    },
    submitForm() {
      this.newPasswordAPI.showLoading = true;
      const credentials = {
        confirmPassword: this.credentials.confirmPassword,
        password: this.credentials.password,
        resetPasswordToken: this.resetPasswordToken,
      };
      setNewPassword(credentials)
        .then(() => {
          window.location = DEFAULT_REDIRECT_URL;
        })
        .catch(error => {
          this.showAlertMessage(
            error?.message || this.$t('SET_NEW_PASSWORD.API.ERROR_MESSAGE')
          );
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
            {{ $t('SET_NEW_PASSWORD.TITLE') }}
          </h1>
        </div>

        <form
          class="rounded-lg border border-n-weak bg-white p-6 shadow-[0_24px_70px_rgba(11,14,48,0.12)] sm:p-8"
          @submit.prevent="submitForm"
        >
          <div class="space-y-5">
            <FormInput
              v-model="credentials.password"
              name="password"
              type="password"
              :label="$t('SET_NEW_PASSWORD.PASSWORD.LABEL')"
              :has-error="v$.credentials.password.$error"
              :error-message="$t('SET_NEW_PASSWORD.PASSWORD.ERROR')"
              :placeholder="$t('SET_NEW_PASSWORD.PASSWORD.PLACEHOLDER')"
              @blur="v$.credentials.password.$touch"
            />
            <FormInput
              v-model="credentials.confirmPassword"
              name="confirm_password"
              type="password"
              :label="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.LABEL')"
              :has-error="v$.credentials.confirmPassword.$error"
              :error-message="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.ERROR')"
              :placeholder="$t('SET_NEW_PASSWORD.CONFIRM_PASSWORD.PLACEHOLDER')"
              @blur="v$.credentials.confirmPassword.$touch"
            />
            <NextButton
              lg
              type="submit"
              data-testid="submit_button"
              class="w-full rounded-lg !bg-[#F40064] !text-white hover:!bg-[#d90058]"
              :label="$t('SET_NEW_PASSWORD.SUBMIT')"
              :disabled="
                v$.credentials.password.$invalid ||
                v$.credentials.confirmPassword.$invalid ||
                newPasswordAPI.showLoading
              "
              :is-loading="newPasswordAPI.showLoading"
            />
          </div>
        </form>
      </div>
    </section>
  </main>
</template>
