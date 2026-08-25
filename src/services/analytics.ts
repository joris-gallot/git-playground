import { EventEmitter } from "events";

interface AnalyticsEvent {
  name: string;
  severity: "low" | "medium" | "high";
  timestamp: Date;
  properties: Record<string, unknown>;
  source: string;
}

interface PageView {
  path: string;
  title: string;
  referrer: string | null;
  timestamp: Date;
  loadTimeMs: number;
}

type EventHandler = (event: AnalyticsEvent) => void;

const MAX_BATCH_SIZE = 200;

export class AnalyticsService {
  private events: AnalyticsEvent[] = [];
  private pageViews: PageView[] = [];
  private emitter = new EventEmitter();
  private isEnabled = true;
  private retryCount = 0;
  private readonly maxRetries = 3;

  constructor(
    private readonly apiEndpoint: string,
    private readonly apiKey: string,
  ) {}

  track(
    name: string,
    properties: Record<string, unknown> = {},
    source: string = "app",
  ): void {
    if (!this.isEnabled) return;

    const event: AnalyticsEvent = {
      name,
      severity: this.inferSeverity(name),
      timestamp: new Date(),
      properties,
      source,
    };

    this.events.push(event);
    this.emitter.emit("track", event);

    if (this.events.length >= MAX_BATCH_SIZE) {
      this.flush();
    }
  }

  trackPageView(
    path: string,
    title: string,
    referrer: string | null = null,
    loadTimeMs: number = 0,
  ): void {
    if (!this.isEnabled) return;

    const pageView: PageView = {
      path,
      title,
      referrer,
      timestamp: new Date(),
      loadTimeMs,
    };

    this.pageViews.push(pageView);
    this.emitter.emit("pageView", pageView);
  }

  async flush(): Promise<void> {
    if (this.events.length === 0) return;

    const batch = [...this.events];
    this.events = [];

    try {
      const response = await fetch(this.apiEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          events: batch,
          sentAt: new Date().toISOString(),
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      this.retryCount = 0;
    } catch (error) {
      console.error("Failed to flush analytics:", error);
      if (this.retryCount < this.maxRetries) {
        this.retryCount++;
        this.events.unshift(...batch);
      }
    }
  }

  on(event: string, handler: EventHandler): void {
    this.emitter.on(event, handler);
  }

  disable(): void {
    this.isEnabled = false;
    this.flush();
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

  private inferSeverity(name: string): AnalyticsEvent["severity"] {
    if (name.startsWith("error.") || name.startsWith("crash.")) return "high";
    if (name.startsWith("warn.")) return "medium";
    return "low";
  }
}

export function createAnalyticsService(
  endpoint: string,
  apiKey: string,
): AnalyticsService {
  return new AnalyticsService(endpoint, apiKey);
}

export const TELEMETRY_ENDPOINT = "https://telemetry.example.com/v2"
