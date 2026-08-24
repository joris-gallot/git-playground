<script setup lang="ts">
defineProps<{ label: string; tone: 'ok' | 'warn' | 'error' }>()
</script>

<template>
  <span class="status-pill" :class="`status-pill--${tone}`">{{ label }}</span>
</template>
