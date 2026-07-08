<script setup>
import { computed, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
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

const participantLabel = participant =>
  participant.label || participant.phone || participant.jid || 'Participante';

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

const updateParticipant = updatedParticipant => {
  participants.value = participants.value.map(participant =>
    participant.jid === updatedParticipant.jid
      ? { ...participant, ...updatedParticipant }
      : participant
  );
};

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

const saveParticipant = async participant => {
  if (!participant?.jid || participant.saved || isSaving(participant)) return;

  setSaving(participant.jid, true);
  try {
    const { data } = await WhatsappGroupParticipantsAPI.saveContact(
      props.conversationId,
      {
        jid: participant.jid,
        label: participantLabel(participant),
        lid: participant.lid,
      }
    );
    updateParticipant(data.participant);
    useAlert('Contato salvo');
  } catch {
    useAlert('Nao foi possivel salvar o contato');
  } finally {
    setSaving(participant.jid, false);
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
        <Avatar :name="participantLabel(participant)" rounded-full :size="32" />

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
          </div>
          <div
            v-if="participantDetails(participant)"
            class="text-xs truncate text-n-slate-10"
            :title="participantDetails(participant)"
          >
            {{ participantDetails(participant) }}
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
          @click="saveParticipant(participant)"
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
  </div>
</template>
