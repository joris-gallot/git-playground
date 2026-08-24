export async function retry<T>(fn: () => Promise<T>, attempts: number): Promise<T> {
  let lastError: unknown
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error
    }
  }
  throw lastError
}

export function backoff(attempt: number): number {
  return attempt * 1000
}
