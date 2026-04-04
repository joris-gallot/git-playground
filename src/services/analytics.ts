import { EventEmitter } from "events";

interface AnalyticsEvent {
  name: string;
  category: "interaction" | "navigation" | "system";
  timestamp: Date;
  properties: Record<string, unknown>;
  userId?: string;
}

interface PageView {
  path: string;
  referrer: string | null;
  timestamp: Date;
  duration?: number;
}

interface UserSession {
  userId: string;
  startedAt: Date;
  lastActiveAt: Date;
  events: AnalyticsEvent[];
  metadata: {
    browser: string;
    os: string;
    screenResolution: string;
  };
}

interface UserStats {
  totalEvents: number;
  totalPageViews: number;
  totalSessions: number;
  averageSessionDuration: number;
  mostVisitedPages: { path: string; count: number }[];
  lastSeenAt: Date | null;
}

type EventHandler = (event: AnalyticsEvent) => void;

const SESSION_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes

export class AnalyticsService {
  private events: AnalyticsEvent[] = [];
  private pageViews: PageView[] = [];
  private sessions: Map<string, UserSession> = new Map();
  private userStats: Map<string, UserStats> = new Map();
  private emitter = new EventEmitter();
  private isEnabled = true;
  private flushInterval: ReturnType<typeof setInterval> | null = null;

  constructor(
    private readonly apiEndpoint: string,
    private readonly flushIntervalMs: number = 10_000,
  ) {
    this.startAutoFlush();
  }

  track(
    name: string,
    properties: Record<string, unknown> = {},
    userId?: string,
  ): void {
    if (!this.isEnabled) return;

    const event: AnalyticsEvent = {
      name,
      category: this.categorizeEvent(name),
      timestamp: new Date(),
      properties,
      userId,
    };

    this.events.push(event);
    this.emitter.emit("track", event);

    if (userId) {
      this.updateSession(userId, event);
      this.updateUserStats(userId, event);
    }

    if (this.events.length >= 100) {
      this.flush();
    }
  }

  trackPageView(
    path: string,
    referrer: string | null = null,
    userId?: string,
  ): void {
    if (!this.isEnabled) return;

    const pageView: PageView = {
      path,
      referrer,
      timestamp: new Date(),
    };

    this.pageViews.push(pageView);
    this.emitter.emit("pageView", pageView);

    if (userId) {
      const stats = this.getOrCreateUserStats(userId);
      stats.totalPageViews++;

      const existing = stats.mostVisitedPages.find((p) => p.path === path);
      if (existing) {
        existing.count++;
      } else {
        stats.mostVisitedPages.push({ path, count: 1 });
      }

      stats.mostVisitedPages.sort((a, b) => b.count - a.count);
      stats.lastSeenAt = new Date();
    }
  }

  async flush(): Promise<void> {
    if (this.events.length === 0 && this.pageViews.length === 0) return;

    const eventBatch = [...this.events];
    const pageViewBatch = [...this.pageViews];
    this.events = [];
    this.pageViews = [];

    try {
      await fetch(this.apiEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Analytics-Version": "2.0",
        },
        body: JSON.stringify({
          events: eventBatch,
          pageViews: pageViewBatch,
          flushedAt: new Date().toISOString(),
        }),
      });
    } catch (error) {
      console.error("Failed to flush analytics:", error);
      this.events.unshift(...eventBatch);
      this.pageViews.unshift(...pageViewBatch);
    }
  }

  on(event: string, handler: EventHandler): void {
    this.emitter.on(event, handler);
  }

  disable(): void {
    this.isEnabled = false;
    this.stopAutoFlush();
  }

  enable(): void {
    this.isEnabled = true;
    this.startAutoFlush();
  }

  getEventCount(): number {
    return this.events.length;
  }

  getPageViews(): PageView[] {
    return [...this.pageViews];
  }

  getUserStats(userId: string): UserStats | null {
    return this.userStats.get(userId) ?? null;
  }

  getActiveSessionCount(): number {
    const now = Date.now();
    let count = 0;
    for (const session of this.sessions.values()) {
      if (now - session.lastActiveAt.getTime() < SESSION_TIMEOUT_MS) {
        count++;
      }
    }
    return count;
  }

  getTopPages(limit: number = 10): { path: string; count: number }[] {
    const pageCounts = new Map<string, number>();

    for (const stats of this.userStats.values()) {
      for (const page of stats.mostVisitedPages) {
        pageCounts.set(
          page.path,
          (pageCounts.get(page.path) ?? 0) + page.count,
        );
      }
    }

    return Array.from(pageCounts.entries())
      .map(([path, count]) => ({ path, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, limit);
  }

  destroy(): void {
    this.stopAutoFlush();
    this.flush();
    this.emitter.removeAllListeners();
  }

  private categorizeEvent(name: string): AnalyticsEvent["category"] {
    if (name.startsWith("page.") || name.startsWith("nav.")) {
      return "navigation";
    }
    if (name.startsWith("sys.") || name.startsWith("error.")) {
      return "system";
    }
    return "interaction";
  }

  private updateSession(userId: string, event: AnalyticsEvent): void {
    const existing = this.sessions.get(userId);
    const now = new Date();

    if (
      existing &&
      now.getTime() - existing.lastActiveAt.getTime() < SESSION_TIMEOUT_MS
    ) {
      existing.lastActiveAt = now;
      existing.events.push(event);
    } else {
      this.sessions.set(userId, {
        userId,
        startedAt: now,
        lastActiveAt: now,
        events: [event],
        metadata: {
          browser: "unknown",
          os: "unknown",
          screenResolution: "unknown",
        },
      });

      const stats = this.getOrCreateUserStats(userId);
      stats.totalSessions++;
    }
  }

  private updateUserStats(userId: string, event: AnalyticsEvent): void {
    const stats = this.getOrCreateUserStats(userId);
    stats.totalEvents++;
    stats.lastSeenAt = new Date();
  }

  private getOrCreateUserStats(userId: string): UserStats {
    let stats = this.userStats.get(userId);
    if (!stats) {
      stats = {
        totalEvents: 0,
        totalPageViews: 0,
        totalSessions: 0,
        averageSessionDuration: 0,
        mostVisitedPages: [],
        lastSeenAt: null,
      };
      this.userStats.set(userId, stats);
    }
    return stats;
  }

  private startAutoFlush(): void {
    if (this.flushInterval) return;
    this.flushInterval = setInterval(() => this.flush(), this.flushIntervalMs);
  }

  private stopAutoFlush(): void {
    if (this.flushInterval) {
      clearInterval(this.flushInterval);
      this.flushInterval = null;
    }
  }
}

export function createAnalyticsService(
  endpoint: string,
  flushIntervalMs?: number,
): AnalyticsService {
  return new AnalyticsService(endpoint, flushIntervalMs);
}
