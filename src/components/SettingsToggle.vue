<script setup lang="ts">
defineProps<{
  label: string;
  value: boolean;
}>();

const emit = defineEmits<{
  update: [value: boolean];
}>();
</script>

<template>
  <div class="toggle-row">
    <label>{{ label }}</label>
    <button
      class="toggle"
      :class="{ active: value }"
      role="switch"
      :aria-checked="value"
      @click="emit('update', !value)"
    >
      <span class="toggle-knob" />
    </button>
  </div>
</template>

<style scoped>
.toggle-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
}

.toggle-row label {
  font-weight: 500;
}

.toggle {
  position: relative;
  width: 44px;
  height: 24px;
  border: none;
  border-radius: 12px;
  background: var(--color-border);
  cursor: pointer;
  transition: background 0.2s;
  padding: 0;
}

.toggle.active {
  background: hsla(160, 100%, 37%, 1);
}

.toggle-knob {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: white;
  transition: transform 0.2s;
}

.toggle.active .toggle-knob {
  transform: translateX(20px);
}
</style>
