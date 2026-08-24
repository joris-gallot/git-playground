// Sliding window, sized to match the upstream quota refill.

const WINDOW_MS = 60_000

export class RateLimiter {
  private hits: number[] = []

  allow(limit: number): boolean {
    const now = Date.now()
    this.hits = this.hits.filter((t) => now - t < WINDOW_MS)
    if (this.hits.length >= limit) {
      return false
    }
    this.hits.push(now)
    return true
  }
}

export const DEFAULT_LIMIT = 100
