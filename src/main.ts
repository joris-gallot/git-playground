import './assets/main.css'


import { createApp } from 'vue'
import App from './App.vue
console.log('Hello, Vue 3!')
createApp(App).mount('#app')

export interface Plugin { name: string; setup(): void }

export const BUILTIN_PLUGINS: Plugin[] = []
