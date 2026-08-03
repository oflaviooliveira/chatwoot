import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';

import App from '../v3/App.vue';
import { loadLocaleMessages } from '../v3/i18n';
import router, { initalizeRouter } from '../v3/views/index';
import store from '../v3/store';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
// import { emitter } from '../shared/helpers/mitt';

// [VITE] This was added in https://github.com/chatwoot/chatwoot/commit/b57063a8b83c86819bd285f481298d7cd38ad50e
// Commenting it out for Vite migration
// Vue.config.env = process.env;

const runWhenIdle = callback => {
  if (window.requestIdleCallback) {
    window.requestIdleCallback(callback);
  } else {
    setTimeout(callback, 0);
  }
};

const initializeErrorLogging = async app => {
  if (!window.errorLoggingConfig) return;

  const Sentry = await import('@sentry/vue');
  Sentry.init({
    app,
    dsn: window.errorLoggingConfig,
    denyUrls: [
      // Chrome extensions
      /^chrome:\/\//i,
      /chrome-extension:/i,
      /extensions\//i,

      // Locally saved copies
      /file:\/\//i,

      // Safari extensions.
      /safari-web-extension:/i,
      /safari-extension:/i,
    ],
    integrations: [Sentry.browserTracingIntegration({ router })],
    ignoreErrors: [
      'ResizeObserver loop completed with undelivered notifications',
    ],
  });
};

const initializeIntegrations = async () => {
  const { initializeAnalyticsEvents, initializeChatwootEvents } = await import(
    'dashboard/helper/scriptHelpers'
  );
  initializeChatwootEvents();
  initializeAnalyticsEvents();
};

const bootstrap = async () => {
  const locale = window.chatwootConfig.selectedLocale || 'en';
  const messages = await loadLocaleMessages(locale);
  const i18n = createI18n({
    legacy: false, // https://github.com/intlify/vue-i18n/issues/1902
    locale,
    messages,
  });

  const app = createApp(App);
  app.use(i18n);
  app.use(store);
  app.use(router);

  // Vue.use(VueRouter);
  // Vue.use(VueI18n);
  // Vue.prototype.$emitter = emitter;
  app.component('fluent-icon', FluentIcon);

  initalizeRouter();
  app.mount('#app');
  initializeErrorLogging(app);
  runWhenIdle(initializeIntegrations);
};

bootstrap();
