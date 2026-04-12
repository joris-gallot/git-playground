<script setup lang="ts">
import { ref } from 'vue'
import HelloWorld from './components/HelloWorld.vue'
import TheWelcome from './components/TheWelcome.vue'
import Settings from './components/Settings.vue'

const currentView = ref<'home' | 'settings'>('home')
</script>

<template>
  <header>
    <img alt="Vue logo" class="logo" src="./assets/logo.svg" width="125" height="125" />

    <div class="wrapper text-lg">
      <HelloWorld msg="You did it!" />
      <nav class="nav">
        <button :class="{ active: currentView === 'home' }" @click="currentView = 'home'">Accueil</button>
        <button :class="{ active: currentView === 'settings' }" @click="currentView = 'settings'">Paramètres</button>
      </nav>
    </div>
  </header>

  <main>
    <TheWelcome v-if="currentView === 'home'" />
    <Settings v-else />
  </main>
</template>

<style scoped>
header {
  line-height: 1.5;
}

.logo {
  display: block;
  margin: 0 auto 2rem;
}

.nav {
  display: flex;
  gap: 0.5rem;
  margin-top: 1rem;
  width: 100%;
}

.nav button {
  padding: 0.4rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: transparent;
  color: var(--color-text);
  cursor: pointer;
  transition: all 0.2s;
}

.nav button.active {
  background: var(--color-background-soft);
  border-color: hsla(160, 100%, 37%, 1);
  color: hsla(160, 100%, 37%, 1);
}

@media (min-width: 1024px) {
  header {
    display: flex;
    place-items: center;
    padding-right: calc(var(--section-gap) / 2);
  }

  .logo {
    margin: 0 2rem 0 0;
  }

  header .wrapper {
    display: flex;
    place-items: flex-start;
    flex-wrap: wrap;
  }
}
</style>
