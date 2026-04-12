<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { settingsService, type AppSettings } from '../services/settings';
import SettingsToggle from './SettingsToggle.vue';

const settings = ref<AppSettings>(settingsService.get());

const themes = [
  { value: 'light', label: 'Clair' },
  { value: 'dark', label: 'Sombre' },
  { value: 'system', label: 'Système' },
] as const;

const languages = [
  { value: 'fr', label: 'Français' },
  { value: 'en', label: 'English' },
  { value: 'es', label: 'Español' },
];

const frequencies = [
  { value: 'realtime', label: 'Temps réel' },
  { value: 'daily', label: 'Quotidien' },
  { value: 'weekly', label: 'Hebdomadaire' },
] as const;

function updateTheme(theme: AppSettings['theme']) {
  settings.value = settingsService.update({ theme });
}

function updateLanguage(language: string) {
  settings.value = settingsService.update({ language });
}

function updateNotification(key: keyof AppSettings['notifications'], value: boolean | string) {
  settingsService.updateNotifications({ [key]: value });
  settings.value = settingsService.get();
}

function updatePrivacy(key: keyof AppSettings['privacy'], value: boolean) {
  settingsService.updatePrivacy({ [key]: value });
  settings.value = settingsService.get();
}

function resetSettings() {
  settings.value = settingsService.reset();
}

let unsubscribe: (() => void) | null = null;

onMounted(() => {
  unsubscribe = settingsService.onChange((updated) => {
    settings.value = updated;
  });
});

onUnmounted(() => {
  unsubscribe?.();
});
</script>

<template>
  <div class="settings">
    <h2>Paramètres</h2>

    <section class="settings-section">
      <h3>Apparence</h3>
      <div class="setting-row">
        <label>Thème</label>
        <div class="button-group">
          <button
            v-for="theme in themes"
            :key="theme.value"
            :class="{ active: settings.theme === theme.value }"
            @click="updateTheme(theme.value)"
          >
            {{ theme.label }}
          </button>
        </div>
      </div>
      <div class="setting-row">
        <label>Langue</label>
        <select :value="settings.language" @change="updateLanguage(($event.target as HTMLSelectElement).value)">
          <option v-for="lang in languages" :key="lang.value" :value="lang.value">
            {{ lang.label }}
          </option>
        </select>
      </div>
    </section>

    <section class="settings-section">
      <h3>Notifications</h3>
      <SettingsToggle
        label="Notifications email"
        :value="settings.notifications.email"
        @update="updateNotification('email', $event)"
      />
      <SettingsToggle
        label="Notifications push"
        :value="settings.notifications.push"
        @update="updateNotification('push', $event)"
      />
      <div class="setting-row">
        <label>Fréquence</label>
        <select
          :value="settings.notifications.frequency"
          @change="updateNotification('frequency', ($event.target as HTMLSelectElement).value)"
        >
          <option v-for="freq in frequencies" :key="freq.value" :value="freq.value">
            {{ freq.label }}
          </option>
        </select>
      </div>
    </section>

    <section class="settings-section">
      <h3>Confidentialité</h3>
      <SettingsToggle
        label="Analytics"
        :value="settings.privacy.analyticsEnabled"
        @update="updatePrivacy('analyticsEnabled', $event)"
      />
      <SettingsToggle
        label="Rapports de crash"
        :value="settings.privacy.crashReportsEnabled"
        @update="updatePrivacy('crashReportsEnabled', $event)"
      />
      <SettingsToggle
        label="Partage de données d'utilisation"
        :value="settings.privacy.shareUsageData"
        @update="updatePrivacy('shareUsageData', $event)"
      />
    </section>

    <div class="settings-footer">
      <button class="reset-btn" @click="resetSettings">Réinitialiser les paramètres</button>
    </div>
  </div>
</template>

<style scoped>
.settings {
  max-width: 600px;
  margin: 0 auto;
  padding: 1.5rem;
}

.settings h2 {
  margin-bottom: 1.5rem;
  color: var(--color-heading);
}

.settings-section {
  margin-bottom: 2rem;
  padding: 1rem;
  border: 1px solid var(--color-border);
  border-radius: 8px;
}

.settings-section h3 {
  margin-bottom: 1rem;
  font-size: 0.9rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text);
  opacity: 0.7;
}

.setting-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
}

.setting-row label {
  font-weight: 500;
}

.button-group {
  display: flex;
  gap: 0.25rem;
}

.button-group button {
  padding: 0.35rem 0.75rem;
  border: 1px solid var(--color-border);
  background: transparent;
  color: var(--color-text);
  cursor: pointer;
  transition: all 0.2s;
}

.button-group button:first-child {
  border-radius: 6px 0 0 6px;
}

.button-group button:last-child {
  border-radius: 0 6px 6px 0;
}

.button-group button.active {
  background: var(--color-background-soft);
  border-color: hsla(160, 100%, 37%, 1);
  color: hsla(160, 100%, 37%, 1);
}

select {
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: transparent;
  color: var(--color-text);
}

.settings-footer {
  text-align: center;
  padding-top: 1rem;
}

.reset-btn {
  padding: 0.5rem 1.5rem;
  border: 1px solid var(--color-border);
  border-radius: 6px;
  background: transparent;
  color: var(--color-text);
  cursor: pointer;
  opacity: 0.7;
  transition: opacity 0.2s;
}

.reset-btn:hover {
  opacity: 1;
}
</style>
