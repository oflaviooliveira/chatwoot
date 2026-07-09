<script setup>
import { computed, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import WhatsappGroupParticipantsAPI from 'dashboard/api/inbox/whatsappGroupParticipants';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const participants = ref([]);
const search = ref('');
const isLoading = ref(false);
const hasError = ref(false);
const savingJids = ref(new Set());
const saveDialogRef = ref(null);
const selectedParticipant = ref(null);
const contactForm = ref({
  name: '',
  phone: '',
  company: '',
  email: '',
  description: '',
  category: '',
  website: '',
});

const filteredParticipants = computed(() => {
  const query = search.value.trim().toLowerCase();
  if (!query) return participants.value;

  return participants.value.filter(participant => {
    const label = participant.label?.toLowerCase() || '';
    const phone = participant.phone?.toLowerCase() || '';
    const jid = participant.jid?.toLowerCase() || '';
    return (
      label.includes(query) || phone.includes(query) || jid.includes(query)
    );
  });
});

const savedCount = computed(
  () => participants.value.filter(participant => participant.saved).length
);

const participantDetails = participant => {
  const details = participant.phone || participant.jid || '';
  return details === participant.label ? '' : details;
};

const participantMetaDetails = participant =>
  [participant.business_name, participant.category]
    .filter(Boolean)
    .filter(detail => detail !== participant.label)
    .join(' · ');

const participantLabel = participant =>
  participant.label || participant.phone || participant.jid || 'Participante';

const sourceLabel = participant => {
  if (participant.saved) return 'Contato salvo';

  const labels = {
    whatsapp: 'WhatsApp',
    whatsapp_business: 'WhatsApp Business',
    description: 'Descricao',
    site: 'Site',
    email: 'E-mail',
    phone: 'Telefone',
  };

  return labels[participant.name_source] || '';
};

const sourceBadgeClass = participant => {
  if (participant.saved) return 'bg-n-teal-3 text-n-teal-11';
  if (['description', 'site', 'email'].includes(participant.name_source)) {
    return 'bg-n-blue-3 text-n-blue-11';
  }
  if (participant.name_source === 'phone') {
    return 'bg-n-slate-3 text-n-slate-11';
  }
  return 'bg-n-purple-3 text-n-purple-11';
};

const isSaving = participant => savingJids.value.has(participant.jid);

const setSaving = (jid, value) => {
  const nextSavingJids = new Set(savingJids.value);
  if (value) {
    nextSavingJids.add(jid);
  } else {
    nextSavingJids.delete(jid);
  }
  savingJids.value = nextSavingJids;
};

const updateParticipant = (
  updatedParticipant,
  originalJid = updatedParticipant.jid
) => {
  participants.value = participants.value.map(participant =>
    participant.jid === originalJid
      ? { ...participant, ...updatedParticipant }
      : participant
  );
};

const normalizeWebsite = value => {
  if (Array.isArray(value)) return value.join(', ');
  return value || '';
};

const openSaveDialog = participant => {
  if (!participant?.jid || participant.saved || isSaving(participant)) return;

  selectedParticipant.value = participant;
  contactForm.value = {
    name: participantLabel(participant),
    phone: participant.phone || participant.jid?.split('@')[0] || '',
    company: participant.business_name || '',
    email: participant.email || '',
    description: participant.description || '',
    category: participant.category || '',
    website: normalizeWebsite(participant.website),
  };
  saveDialogRef.value?.open();
};

const closeSaveDialog = () => {
  selectedParticipant.value = null;
};

const normalizedFormPhone = computed(() =>
  contactForm.value.phone.toString().replace(/\D/g, '')
);

const canSaveDialog = computed(
  () => contactForm.value.name.trim() && normalizedFormPhone.value
);

const fetchParticipants = async () => {
  if (!props.conversationId) return;

  isLoading.value = true;
  hasError.value = false;
  try {
    const { data } = await WhatsappGroupParticipantsAPI.get(
      props.conversationId
    );
    participants.value = data.participants || [];
  } catch {
    participants.value = [];
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const saveParticipant = async () => {
  const participant = selectedParticipant.value;
  if (!participant?.jid || participant.saved || isSaving(participant)) return;

  const originalJid = participant.jid;
  const jid = normalizedFormPhone.value
    ? `${normalizedFormPhone.value}@s.whatsapp.net`
    : participant.jid;

  setSaving(originalJid, true);
  try {
    const { data } = await WhatsappGroupParticipantsAPI.saveContact(
      props.conversationId,
      {
        jid,
        label: contactForm.value.name.trim(),
        lid: participant.lid,
        profile_name: contactForm.value.name.trim(),
        business_name: contactForm.value.company.trim(),
        description: contactForm.value.description.trim(),
        category: contactForm.value.category.trim(),
        website: contactForm.value.website.trim(),
        email: contactForm.value.email.trim(),
        profile_picture_url: participant.profile_picture_url,
      }
    );
    updateParticipant(data.participant, originalJid);
    saveDialogRef.value?.close();
    useAlert('Contato salvo');
  } catch {
    useAlert('Nao foi possivel salvar o contato');
  } finally {
    setSaving(originalJid, false);
  }
};

watch(
  () => props.conversationId,
  () => {
    search.value = '';
    fetchParticipants();
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-3 py-3">
    <div class="relative mb-3">
      <span
        class="absolute -translate-y-1/2 i-lucide-search size-4 left-3 top-1/2 text-n-slate-10"
      />
      <input
        v-model="search"
        type="search"
        class="w-full h-9 rounded-md border border-n-weak bg-n-solid-1 pl-9 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus:border-n-brand"
        placeholder="Buscar participante"
      />
    </div>

    <div class="flex items-center justify-between gap-2 mb-2">
      <div class="flex flex-col min-w-0 text-xs text-n-slate-10">
        <span>{{ participants.length }} participantes</span>
        <span>{{ savedCount }} salvos</span>
      </div>
      <NextButton
        xs
        faded
        slate
        icon="i-lucide-refresh-cw"
        label="Recarregar"
        :is-loading="isLoading"
        :disabled="isLoading"
        @click="fetchParticipants"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>

    <div v-else-if="filteredParticipants.length" class="flex flex-col gap-1">
      <div
        v-for="participant in filteredParticipants"
        :key="participant.jid"
        class="flex items-center gap-2 px-2 py-2 rounded-md hover:bg-n-alpha-2"
      >
        <Avatar
          :name="participantLabel(participant)"
          :src="participant.profile_picture_url"
          rounded-full
          :size="32"
        />

        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-1 min-w-0">
            <span
              class="text-sm font-medium truncate text-n-slate-12"
              :title="participantLabel(participant)"
            >
              {{ participantLabel(participant) }}
            </span>
            <span
              v-if="participant.admin"
              class="shrink-0 rounded bg-n-amber-3 px-1.5 py-0.5 text-[0.625rem] font-medium text-n-amber-11"
            >
              Admin
            </span>
            <span
              v-if="sourceLabel(participant)"
              class="shrink-0 rounded px-1.5 py-0.5 text-[0.625rem] font-medium"
              :class="sourceBadgeClass(participant)"
            >
              {{ sourceLabel(participant) }}
            </span>
          </div>
          <div
            v-if="participantDetails(participant)"
            class="text-xs truncate text-n-slate-10"
            :title="participantDetails(participant)"
          >
            {{ participantDetails(participant) }}
          </div>
          <div
            v-if="participantMetaDetails(participant)"
            class="text-xs truncate text-n-slate-9"
            :title="participantMetaDetails(participant)"
          >
            {{ participantMetaDetails(participant) }}
          </div>
        </div>

        <span
          v-if="participant.saved"
          class="shrink-0 rounded bg-n-teal-3 px-2 py-1 text-xs font-medium text-n-teal-11"
        >
          Salvo
        </span>
        <NextButton
          v-else
          xs
          outline
          slate
          icon="i-lucide-user-plus"
          label="Salvar"
          :is-loading="isSaving(participant)"
          :disabled="isSaving(participant)"
          @click="openSaveDialog(participant)"
        />
      </div>
    </div>

    <p
      v-else-if="hasError"
      class="px-3 py-6 text-sm leading-6 text-center text-n-slate-11"
    >
      Nao foi possivel carregar os participantes
    </p>

    <p v-else class="px-3 py-6 text-sm leading-6 text-center text-n-slate-11">
      Nenhum participante encontrado
    </p>

    <Dialog
      ref="saveDialogRef"
      width="lg"
      title="Salvar participante"
      description="Revise os dados antes de criar o contato no Chatwoot."
      confirm-button-label="Salvar contato"
      cancel-button-label="Cancelar"
      :is-loading="selectedParticipant ? isSaving(selectedParticipant) : false"
      :disable-confirm-button="!canSaveDialog"
      @confirm="saveParticipant"
      @close="closeSaveDialog"
    >
      <div class="flex flex-col gap-4">
        <div class="flex items-center gap-3 rounded-md bg-n-alpha-2 p-3">
          <Avatar
            :name="contactForm.name || 'Participante'"
            :src="selectedParticipant?.profile_picture_url"
            rounded-full
            :size="40"
          />
          <div class="min-w-0">
            <div class="truncate text-sm font-medium text-n-slate-12">
              {{ contactForm.name || 'Participante' }}
            </div>
            <div class="truncate text-xs text-n-slate-10">
              {{ selectedParticipant?.jid }}
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            Nome
            <input
              v-model="contactForm.name"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="Nome do contato"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            Telefone
            <input
              v-model="contactForm.phone"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="+55..."
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            Empresa
            <input
              v-model="contactForm.company"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="Empresa"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            E-mail
            <input
              v-model="contactForm.email"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="email@empresa.com"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            Categoria
            <input
              v-model="contactForm.category"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="Categoria"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-12">
            Site
            <input
              v-model="contactForm.website"
              class="h-10 rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm outline-none focus:border-n-brand"
              placeholder="https://..."
            />
          </label>
        </div>

        <label class="flex flex-col gap-1 text-sm text-n-slate-12">
          Descricao
          <textarea
            v-model="contactForm.description"
            class="min-h-20 rounded-md border border-n-weak bg-n-solid-1 px-3 py-2 text-sm outline-none focus:border-n-brand"
            placeholder="Descricao do contato"
          />
        </label>
      </div>
    </Dialog>
  </div>
</template>
