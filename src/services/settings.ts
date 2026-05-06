export interface AppSettings {
  theme: 'light' | 'dark' | 'system';
  language: string;
  notifications: NotificationSettings;
  privacy: PrivacySettings;
}

export interface NotificationSettings {
  email: boolean;
  push: boolean;
  frequency: 'realtime' | 'daily' | 'weekly';
}

export interface PrivacySettings {
  analyticsEnabled: boolean;
  crashReportsEnabled: boolean;
  shareUsageData: boolean;
}

const STORAGE_KEY = 'app_settings';

const DEFAULT_SETTINGS: AppSettings = {
  theme: 'system',
  language: 'fr',
  notifications: {
    email: true,
    push: false,
    frequency: 'daily',
  },
  privacy: {
    analyticsEnabled: true,
    crashReportsEnabled: true,
    shareUsageData: false,
  },
};

export class SettingsService {
  private settings: AppSettings;
  private listeners: Array<(settings: AppSettings) => void> = [];

  constructor() {
    this.settings = this.load();
  }

  get(): AppSettings {
    return { ...this.settings };
  }

  update(partial: Partial<AppSettings>): AppSettings {
    this.settings = { ...this.settings, ...partial };
    this.save();
    this.notify();
    return this.get();
  }

  updateNotifications(partial: Partial<NotificationSettings>): void {
    this.settings.notifications = { ...this.settings.notifications, ...partial };
    this.save();
    this.notify();
  }

  updatePrivacy(partial: Partial<PrivacySettings>): void {
    this.settings.privacy = { ...this.settings.privacy, ...partial };
    this.save();
    this.notify();
  }

  reset(): AppSettings {
    this.settings = { ...DEFAULT_SETTINGS };
    this.save();
    this.notify();
    return this.get();
  }

  onChange(listener: (settings: AppSettings) => void): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== listener);
    };
  }

  private load(): AppSettings {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        return { ...DEFAULT_SETTINGS, ...JSON.parse(stored) };
      }
    } catch (e) {
      console.warn('[Settings] Failed to load settings from storage:', e);
    }
    return { ...DEFAULT_SETTINGS };
  }

  private save(): void {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.settings));
    } catch (e) {
      console.warn('[Settings] Failed to save settings:', e);
    }
  }

  private notify(): void {
    const current = this.get();
    this.listeners.forEach((listener) => listener(current));
  }
}

export const settingsService = new SettingsService();
