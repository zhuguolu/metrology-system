export function useViewCache(key, options = {}) {
  const storageKey = `view-cache:${key}`
  const { ttlMs = 30 * 60 * 1000, version = 1 } = options

  function isAvailable() {
    return typeof window !== 'undefined' && typeof window.sessionStorage !== 'undefined'
  }

  function restore() {
    if (!isAvailable()) return null

    try {
      // Disable view-level cache restore so pages always fetch live data on open.
      window.sessionStorage.removeItem(storageKey)
    } catch {
      return null
    }

    return null
  }

  function save(payload) {
    void payload
    void ttlMs
    void version
  }

  function clear() {
    if (!isAvailable()) return
    try { window.sessionStorage.removeItem(storageKey) } catch {}
  }

  return { restore, save, clear }
}
