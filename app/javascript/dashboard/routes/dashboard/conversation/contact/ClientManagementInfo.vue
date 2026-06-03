<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  customAttributes: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const normalizeValue = value => {
  if (Array.isArray(value)) return value.filter(Boolean).join(', ');
  return value;
};

const resolveValue = key => {
  const value = normalizeValue(props.customAttributes[key]);
  return value || t('CONTACT_PANEL.CLIENT_MANAGEMENT.NOT_SET');
};

const rows = computed(() => [
  [
    t('CONTACT_PANEL.CLIENT_MANAGEMENT.PRIMARY_OWNER'),
    resolveValue('responsavel_principal'),
  ],
  [
    t('CONTACT_PANEL.CLIENT_MANAGEMENT.OPERATIONAL_SUPPORT'),
    resolveValue('apoio_operacional'),
  ],
]);
</script>

<template>
  <div class="px-4 py-3">
    <div class="flex flex-col gap-3">
      <div v-for="[label, value] in rows" :key="label" class="min-w-0">
        <div class="mb-1 text-xs font-medium uppercase text-n-slate-11">
          {{ label }}
        </div>
        <div
          class="text-sm leading-5 break-words whitespace-pre-line text-n-slate-12"
        >
          {{ value }}
        </div>
      </div>
    </div>
  </div>
</template>
