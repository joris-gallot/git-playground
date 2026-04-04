import { EventEmitter } from "events";

interface AnalyticsEvent {
  name: string;
  timestamp: Date;
  properties: Record<string, unknown>;
}

interface PageView {
  path: string;
  referrer: string | null;
  timestamp: Date;
}

type EventHandler = (event: AnalyticsEvent) => void;

export class AnalyticsService {
  private events: AnalyticsEvent[] = [];
  private pageViews: PageView[] = [];
  private emitter = new EventEmitter();
  private isEnabled = true;

  constructor(private readonly apiEndpoint: string) {}

  track(name: string, properties: Record<string, unknown> = {}): void {
    if (!this.isEnabled) return;

    const event: AnalyticsEvent = {
      name,
      timestamp: new Date(),
      properties,
    };

    this.events.push(event);
    this.emitter.emit("track", event);

    if (this.events.length >= 50) {
      this.flush();
    }
  }

  trackPageView(path: string, referrer: string | null = null): void {
    if (!this.isEnabled) return;

    const pageView: PageView = {
      path,
      referrer,
      timestamp: new Date(),
    };

    this.pageViews.push(pageView);
  }

  async flush(): Promise<void> {
    if (this.events.length === 0) return;

    const batch = [...this.events];
    this.events = [];

    try {
      await fetch(this.apiEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ events: batch }),
      });
    } catch (error) {
      console.error("Failed to flush analytics:", error);
      this.events.unshift(...batch);
    }
  }

  on(event: string, handler: EventHandler): void {
    this.emitter.on(event, handler);
  }

  disable(): void {
    this.isEnabled = false;
  }

  enable(): void {
    this.isEnabled = true;
  }

  getEventCount(): number {
    return this.events.length;
  }

  getPageViews(): PageView[] {
    return [...this.pageViews];
  }
}

export function createAnalyticsService(endpoint: string): AnalyticsService {
  return new AnalyticsService(endpoint);
}
