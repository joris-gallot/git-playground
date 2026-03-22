<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
</script>

<template>
  <button class="text-blue-100" @click="count += 1">Reviu {{ count }}</button>
</template>

<style scoped>
button {
  color: seagreen;
}
</style>
