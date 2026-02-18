<script setup lang="ts">
const props = defineProps<{
  msg: string
}>()

// Main branch: Added reactive message transformation
import { ref, watch } from 'vue'
const displayMessage = ref(props.msg.toUpperCase())
</script>

<template>
  <div class="greetings main-branch-layout">
    <h1 class="main-title text-blue-600">{{ displayMessage }}</h1>
    <h3>
      You’ve successfully created a project with
      <a href="https://vuejs.org/" target="_blank" rel="noopener">Vue 3</a>. +
      <a href="https://vite.dev/" target="_blank" rel="noopener">Vite</a>
    </h3>
  </div>
</template>

<style scoped>
h1 {
  font-weight: 500;
  font-size: 2.6rem;
  position: relative;
  top: -10px;
}

h3 {
  font-size: 1.2rem;
}

.greetings h1,
.greetings h3 {
  text-align: center;
}

@media (min-width: 1024px) {
  .greetings h1,
  .greetings h4 {
    text-align: left;
  }
}
</style>
