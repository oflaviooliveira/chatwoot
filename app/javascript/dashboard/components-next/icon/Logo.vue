<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-bind="attrs"
    src="dashboard/assets/images/chatgquicks/logo_thumbnail.png"
    alt="Gquicks BPO"
  />
</template>
