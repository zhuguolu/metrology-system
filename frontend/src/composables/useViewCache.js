export function useViewCache(key, options = {}) {
  const storageKey = `view-cache:${key}`
  const { ttlMs = 30 * 60 * 1000, version = 1 } = options

  function isAvailable() {
    return typeof window !== 'undefined' && typeof window.sessionStorage !== 'undefined'
  }

  function restore() {
    if (!isAvailable()) return null

    try {
      const raw = window.sessionStorage.getItem(storageKey)
      if (!raw) return null

      const parsed = JSON.parse(raw)
      if (!parsed || typeof parsed !== 'object') {
        window.sessionStorage.removeItem(storageKey)
        return null
      }

      if (parsed.version !== version) {
        window.sessionStorage.removeItem(storageKey)
        return null
      }

      if (typeof parsed.expiresAt !== 'number' || parsed.expiresAt <= Date.now()) {
        window.sessionStorage.removeItem(storageKey)
        return null
      }

      return parsed.payload ?? null
    } catch {
      return null
    }
  }

  function save(payload) {
    if (!isAvailable()) return

    try {
      window.sessionStorage.setItem(storageKey, JSON.stringify({
        version,
        savedAt: Date.now(),
        expiresAt: Date.now() + Math.max(1000, Number(ttlMs) || 0),
        payload
      }))
    } catch {}
  }

  function clear() {
    if (!isAvailable()) return
    try { window.sessionStorage.removeItem(storageKey) } catch {}
  }

  return { restore, save, clear }
}
