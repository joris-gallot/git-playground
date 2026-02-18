<script setup lang="ts">
const props = defineProps<{
  msg: string
}>()

// Main branch v2: Enhanced with animations and transitions
import { ref, watch, onMounted } from 'vue'
const displayMessage = ref('')
const isAnimating = ref(true)

onMounted(() => {
  displayMessage.value = `✨ ${props.msg.toUpperCase()} ✨`
  setTimeout(() => isAnimating.value = false, 1000)
})
</script>

<template>
  <div class="greetings main-v2-layout" :class="{ 'animating': isAnimating }">
    <h1 class="main-v2-title text-indigo-700">{{ displayMessage }}</h1>
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
