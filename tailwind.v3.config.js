const baseConfig = require('./tailwind.config');

module.exports = {
  ...baseConfig,
  content: [
    './app/javascript/v3/**/*.{js,vue}',
    './app/javascript/dashboard/components/auth/MfaVerification.vue',
    './app/javascript/dashboard/components-next/TeleportWithDirection.vue',
    './app/javascript/dashboard/components-next/button/**/*.{js,vue}',
    './app/javascript/dashboard/components-next/dialog/**/*.vue',
    './app/javascript/dashboard/components-next/icon/Icon.vue',
    './app/javascript/dashboard/components-next/spinner/Spinner.vue',
    './app/javascript/shared/components/FluentIcon/{Icon,Index}.vue',
    './app/javascript/shared/components/Spinner.vue',
  ],
};
