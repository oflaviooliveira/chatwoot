<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { renderWhatsappMentions } from 'dashboard/helper/whatsappGroupMentions';

const { content, attachments, contentAttributes, messageType } =
  useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  const contentToRender = (() => {
    if (renderOriginal.value) {
      return content.value;
    }

    if (hasTranslations.value) {
      return translationContent.value;
    }

    return content.value;
  })();

  return renderWhatsappMentions(contentToRender, contentAttributes.value);
});

const whatsappGroupSender = computed(() => {
  return (
    contentAttributes.value?.whatsappGroupSender ||
    contentAttributes.value?.whatsapp_group_sender ||
    null
  );
});

const whatsappGroupSenderLabel = computed(() => {
  const sender = whatsappGroupSender.value;
  if (!sender) return '';

  return sender.label || sender.name || sender.phone || sender.jid || '';
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span
        v-if="whatsappGroupSenderLabel"
        class="-mb-2 text-xs font-medium text-n-slate-11"
      >
        {{ whatsappGroupSenderLabel }}
      </span>
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
