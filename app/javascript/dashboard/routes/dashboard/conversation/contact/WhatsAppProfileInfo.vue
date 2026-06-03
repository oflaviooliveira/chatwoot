<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  profile: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const formattedType = computed(() => {
  if (props.profile.type === 'group') {
    return t('CONTACT_PANEL.WHATSAPP_PROFILE.GROUP');
  }

  if (props.profile.type === 'contact') {
    return t('CONTACT_PANEL.WHATSAPP_PROFILE.CONTACT');
  }

  return '';
});

const formattedSyncedAt = computed(() => {
  if (!props.profile.synced_at) return '';

  return new Date(props.profile.synced_at).toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  });
});

const normalizeValue = value => {
  if (Array.isArray(value)) return value.filter(Boolean).join(', ');
  return value;
};

const rows = computed(() =>
  [
    [t('CONTACT_PANEL.WHATSAPP_PROFILE.TYPE'), formattedType.value],
    [
      t('CONTACT_PANEL.WHATSAPP_PROFILE.NAME'),
      props.profile.profile_name || props.profile.display_name,
    ],
    [t('CONTACT_PANEL.WHATSAPP_PROFILE.COMPANY'), props.profile.business_name],
    [
      t('CONTACT_PANEL.WHATSAPP_PROFILE.DESCRIPTION'),
      props.profile.description,
    ],
    [
      t('CONTACT_PANEL.WHATSAPP_PROFILE.PARTICIPANTS'),
      props.profile.participants_count,
    ],
    [t('CONTACT_PANEL.WHATSAPP_PROFILE.PHONE'), props.profile.phone_number],
    [t('CONTACT_PANEL.WHATSAPP_PROFILE.EMAIL'), props.profile.email],
    [t('CONTACT_PANEL.WHATSAPP_PROFILE.SYNCED_AT'), formattedSyncedAt.value],
  ]
    .map(([label, value]) => [label, normalizeValue(value)])
    .filter(
      ([, value]) => value !== undefined && value !== null && value !== ''
    )
);
</script>

<template>
  <div class="px-4 py-3">
    <div v-if="rows.length" class="flex flex-col gap-3">
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
    <div v-else class="text-sm text-n-slate-11">
      {{ t('CONTACT_PANEL.WHATSAPP_PROFILE.EMPTY') }}
    </div>
  </div>
</template>
