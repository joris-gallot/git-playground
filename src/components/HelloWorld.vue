<script setup lang="ts">
const props = defineProps<{
  msg: string
}>()

// Main branch v3: CONFLICTING - Added dark mode and theme support
import { ref, watch, onMounted, computed } from 'vue'
const displayMessage = ref('')
const isAnimating = ref(true)
const isDarkMode = ref(false)
const themeClass = computed(() => isDarkMode.value ? 'dark-theme' : 'light-theme')

onMounted(() => {
  displayMessage.value = `🌟 ${props.msg.toUpperCase()} 🌟`
  setTimeout(() => isAnimating.value = false, 500)
  isDarkMode.value = window.matchMedia('(prefers-color-scheme: dark)').matches
})
</script>

<template>
  <div class="greetings main-v3-dark-mode" :class="[themeClass, { 'animating': isAnimating }]">
    <h1 class="main-v3-title text-emerald-600">{{ displayMessage }}</h1>
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
