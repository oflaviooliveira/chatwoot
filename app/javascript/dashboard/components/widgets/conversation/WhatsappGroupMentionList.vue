<script setup>
import Avatar from 'next/avatar/Avatar.vue';
import { ref, computed, watch, nextTick } from 'vue';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';

const props = defineProps({
  searchKey: {
    type: String,
    default: '',
  },
  participants: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectParticipant']);

const listRef = ref(null);
const selectedIndex = ref(0);

const items = computed(() => {
  const search = props.searchKey?.trim().toLowerCase() || '';
  return props.participants.filter(participant => {
    const label = participant.label?.toLowerCase() || '';
    const phone = participant.phone?.toLowerCase() || '';
    return search ? label.includes(search) || phone.includes(search) : true;
  });
});

const adjustScroll = () => {
  nextTick(() => {
    const selectedElement = listRef.value?.querySelector(
      `#whatsapp-mention-item-${selectedIndex.value}`
    );
    selectedElement?.scrollIntoView({ block: 'nearest', behavior: 'auto' });
  });
};

const onSelect = () => {
  const participant = items.value[selectedIndex.value];
  if (participant) emit('selectParticipant', participant);
};

useKeyboardNavigableList({
  items,
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(items, newItems => {
  if (newItems.length < selectedIndex.value + 1) {
    selectedIndex.value = 0;
  }
});

const onHover = index => {
  selectedIndex.value = index;
};

const onParticipantSelect = index => {
  selectedIndex.value = index;
  onSelect();
};

const participantDetails = participant => {
  const details = participant.phone || participant.jid || '';
  return details === participant.label ? '' : details;
};
</script>

<template>
  <div>
    <ul
      v-if="isLoading || items.length"
      ref="listRef"
      class="vertical dropdown menu mention--box bg-n-solid-1 p-1 rounded-xl text-sm overflow-auto absolute w-full z-20 shadow-md left-0 leading-[1.2] bottom-full max-h-[12.5rem] border border-solid border-n-strong"
      role="listbox"
    >
      <li v-if="isLoading" class="px-3 py-2 text-sm text-n-slate-11">
        Carregando participantes...
      </li>
      <template v-else>
        <li
          v-for="(item, index) in items"
          :id="`whatsapp-mention-item-${index}`"
          :key="item.jid"
        >
          <div
            :class="{ 'bg-n-alpha-black2': index === selectedIndex }"
            class="flex items-center px-2 py-1 rounded-md cursor-pointer"
            role="option"
            @click="onParticipantSelect(index)"
            @mouseover="onHover(index)"
          >
            <div class="ltr:mr-2 rtl:ml-2">
              <Avatar :name="item.label" rounded-full />
            </div>
            <div
              class="overflow-hidden flex-1 max-w-full whitespace-nowrap text-ellipsis"
            >
              <h5
                class="overflow-hidden mb-0 text-sm whitespace-nowrap text-n-slate-11 text-ellipsis"
                :class="{ 'text-n-slate-12': index === selectedIndex }"
              >
                {{ item.label }}
              </h5>
              <div
                v-if="participantDetails(item)"
                class="overflow-hidden text-xs whitespace-nowrap text-ellipsis text-n-slate-10"
                :class="{ 'text-n-slate-11': index === selectedIndex }"
              >
                {{ participantDetails(item) }}
              </div>
            </div>
          </div>
        </li>
      </template>
    </ul>
  </div>
</template>
