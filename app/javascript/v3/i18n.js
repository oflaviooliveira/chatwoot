const localeLoaders = {
  ar: () => import('dashboard/i18n/locale/ar'),
  bg: () => import('dashboard/i18n/locale/bg'),
  ca: () => import('dashboard/i18n/locale/ca'),
  cs: () => import('dashboard/i18n/locale/cs'),
  da: () => import('dashboard/i18n/locale/da'),
  de: () => import('dashboard/i18n/locale/de'),
  el: () => import('dashboard/i18n/locale/el'),
  en: () => import('dashboard/i18n/locale/en'),
  es: () => import('dashboard/i18n/locale/es'),
  fa: () => import('dashboard/i18n/locale/fa'),
  fi: () => import('dashboard/i18n/locale/fi'),
  fr: () => import('dashboard/i18n/locale/fr'),
  he: () => import('dashboard/i18n/locale/he'),
  hi: () => import('dashboard/i18n/locale/hi'),
  hu: () => import('dashboard/i18n/locale/hu'),
  id: () => import('dashboard/i18n/locale/id'),
  is: () => import('dashboard/i18n/locale/is'),
  it: () => import('dashboard/i18n/locale/it'),
  ja: () => import('dashboard/i18n/locale/ja'),
  ko: () => import('dashboard/i18n/locale/ko'),
  lt: () => import('dashboard/i18n/locale/lt'),
  lv: () => import('dashboard/i18n/locale/lv'),
  ml: () => import('dashboard/i18n/locale/ml'),
  nl: () => import('dashboard/i18n/locale/nl'),
  no: () => import('dashboard/i18n/locale/no'),
  pl: () => import('dashboard/i18n/locale/pl'),
  pt: () => import('dashboard/i18n/locale/pt'),
  pt_BR: () => import('dashboard/i18n/locale/pt_BR'),
  ro: () => import('dashboard/i18n/locale/ro'),
  ru: () => import('dashboard/i18n/locale/ru'),
  sk: () => import('dashboard/i18n/locale/sk'),
  sr: () => import('dashboard/i18n/locale/sr'),
  sv: () => import('dashboard/i18n/locale/sv'),
  ta: () => import('dashboard/i18n/locale/ta'),
  th: () => import('dashboard/i18n/locale/th'),
  tr: () => import('dashboard/i18n/locale/tr'),
  uk: () => import('dashboard/i18n/locale/uk'),
  vi: () => import('dashboard/i18n/locale/vi'),
  zh_CN: () => import('dashboard/i18n/locale/zh_CN'),
  zh_TW: () => import('dashboard/i18n/locale/zh_TW'),
};

export const loadLocaleMessages = async locale => {
  const localeLoader = localeLoaders[locale] || localeLoaders.en;
  const localeModule = await localeLoader();

  return { [locale]: localeModule.default };
};
