export interface CacheEntry<T> {
  value: T
  expiresAt: number
}

export class MemoryCache<T> {
  private entries = new Map<string, CacheEntry<T>>()

  get(key: string): T | undefined {
    const entry = this.entries.get(key)
    if (!entry) return undefined
    if (entry.expiresAt < Date.now()) {
      this.entries.delete(key)
      return undefined
    }
    return entry.value
  }

  set(key: string, value: T, ttlMs: number): void {
    this.entries.set(key, { value, expiresAt: Date.now() + ttlMs })
  }
}
