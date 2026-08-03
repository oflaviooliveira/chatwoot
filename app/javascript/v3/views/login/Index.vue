<script>
// utils and composables
import { defineAsyncComponent } from 'vue';
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables/useAlert';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const MfaVerification = defineAsyncComponent(
  () => import('dashboard/components/auth/MfaVerification.vue')
);

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    return {
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
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
      <div
        class="pointer-events-none absolute bottom-10 left-12 grid grid-cols-8 gap-5 opacity-20"
      >
        <img
          v-for="index in 32"
          :key="index"
          src="v3/assets/images/chatgquicks/login-symbol.png"
          alt=""
          class="h-7 w-7"
          :class="{
            'rotate-45': index % 2 === 0,
            '-rotate-12': index % 3 === 0,
          }"
        />
      </div>

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
        <div class="mb-10 lg:hidden">
          <img
            src="v3/assets/images/chatgquicks/login-logo.png"
            alt="Gquicks"
            class="h-10 w-auto"
          />
        </div>

        <div class="mb-8">
          <img
            src="v3/assets/images/chatgquicks/login-logo.png"
            alt="Gquicks"
            class="hidden h-10 w-auto lg:block"
          />
          <h2
            class="mt-8 text-3xl font-semibold leading-tight tracking-normal text-[#0B0E30]"
          >
            {{ $t('LOGIN.TITLE') }}
          </h2>
          <p class="mt-3 text-base leading-7 text-n-slate-11">
            {{ $t('LOGIN.PANEL_SUBTITLE') }}
          </p>
          <p v-if="showSignupLink" class="mt-3 text-sm text-n-slate-11">
            {{ $t('COMMON.OR') }}
            <router-link
              to="auth/signup"
              class="lowercase text-link text-[#F40064]"
            >
              {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
            </router-link>
          </p>
        </div>

        <div
          class="rounded-lg border border-n-weak bg-white p-6 shadow-[0_24px_70px_rgba(11,14,48,0.12)] sm:p-8"
          :class="{ 'animate-wiggle': loginApi.hasErrored }"
        >
          <MfaVerification
            v-if="mfaRequired"
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />

          <div v-else-if="!email">
            <div class="flex flex-col gap-4">
              <GoogleOAuthButton v-if="showGoogleOAuth" />
              <div v-if="showSamlLogin" class="text-center">
                <router-link
                  to="/app/login/sso"
                  class="inline-flex w-full items-center justify-center rounded-lg bg-n-background px-4 py-3 shadow-sm ring-1 ring-inset ring-n-container hover:bg-n-alpha-2 focus:outline-offset-0"
                >
                  <Icon
                    icon="i-lucide-lock-keyhole"
                    class="size-5 text-n-slate-11"
                  />
                  <span class="ml-2 text-base font-medium text-n-slate-12">
                    {{ $t('LOGIN.SAML.LABEL') }}
                  </span>
                </router-link>
              </div>
              <SimpleDivider
                v-if="showGoogleOAuth || showSamlLogin"
                :label="$t('COMMON.OR')"
                class="uppercase"
              />
            </div>
            <form class="space-y-5" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate">
                  <router-link
                    to="auth/reset/password"
                    class="text-sm font-medium text-[#F40064] hover:text-[#0B0E30]"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>
              <NextButton
                lg
                type="submit"
                data-testid="submit_button"
                class="w-full rounded-lg !bg-[#F40064] !text-white hover:!bg-[#d90058]"
                :tabindex="3"
                :label="$t('LOGIN.SUBMIT')"
                :disabled="loginApi.showLoading"
                :is-loading="loginApi.showLoading"
              />
            </form>
          </div>
          <div v-else class="flex items-center justify-center py-8">
            <Spinner color-scheme="primary" size="" />
          </div>
        </div>
      </div>
    </section>
  </main>
</template>
