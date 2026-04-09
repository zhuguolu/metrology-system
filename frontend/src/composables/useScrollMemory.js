import { nextTick, onBeforeUnmount, onMounted } from 'vue'

export function useScrollMemory(key, options = {}) {
  const storageKey = `scroll-memory:${key}`
  const {
    ttlMs = 30 * 60 * 1000,
    getTarget = () => window,
    restoreDelays = [0, 120, 320, 800, 1600, 2600]
  } = options

  let scrollTarget = null
  let restoreTimers = []
  let saveFrame = 0

  function isAvailable() {
    return typeof window !== 'undefined' && typeof window.sessionStorage !== 'undefined'
  }

  function resolveTarget() {
    if (typeof window === 'undefined') return null
    try {
      return getTarget?.() ?? window
    } catch {
      return window
    }
  }

  function readScrollTop(target) {
    if (!target || typeof window === 'undefined') return 0
    if (target === window) {
      return window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0
    }
    return Number(target.scrollTop) || 0
  }

  function writeScrollTop(target, top) {
    if (!target || typeof window === 'undefined') return
    const normalizedTop = Math.max(0, Number(top) || 0)
    if (target === window) {
      window.scrollTo({ top: normalizedTop, behavior: 'auto' })
      return
    }
    target.scrollTop = normalizedTop
  }

  function restoreOnce() {
    if (!isAvailable()) return
    const target = resolveTarget()
    if (!target) return

    try {
      const raw = window.sessionStorage.getItem(storageKey)
      if (!raw) return

      const parsed = JSON.parse(raw)
      if (!parsed || typeof parsed !== 'object') return
      if (typeof parsed.expiresAt !== 'number' || parsed.expiresAt <= Date.now()) {
        window.sessionStorage.removeItem(storageKey)
        return
      }
      if (typeof parsed.top !== 'number' || parsed.top <= 0) return
      writeScrollTop(target, parsed.top)
    } catch {}
  }

  function scheduleRestoreScroll() {
    if (!isAvailable()) return
    restoreTimers.forEach(timer => clearTimeout(timer))
    restoreTimers = []

    nextTick(() => {
      restoreTimers = restoreDelays.map(delay =>
        window.setTimeout(() => {
          restoreOnce()
        }, delay)
      )
    })
  }

  function saveScrollPosition() {
    if (!isAvailable()) return

    try {
      const target = scrollTarget || resolveTarget()
      const top = readScrollTop(target)
      window.sessionStorage.setItem(storageKey, JSON.stringify({
        savedAt: Date.now(),
        expiresAt: Date.now() + Math.max(1000, Number(ttlMs) || 0),
        top
      }))
    } catch {}
  }

  function onScroll() {
    if (typeof window === 'undefined') return
    if (saveFrame) window.cancelAnimationFrame(saveFrame)
    saveFrame = window.requestAnimationFrame(() => {
      saveFrame = 0
      saveScrollPosition()
    })
  }

  onMounted(() => {
    scrollTarget = resolveTarget()
    if (scrollTarget?.addEventListener) {
      scrollTarget.addEventListener('scroll', onScroll, { passive: true })
    }
    scheduleRestoreScroll()
  })

  onBeforeUnmount(() => {
    if (saveFrame && typeof window !== 'undefined') {
      window.cancelAnimationFrame(saveFrame)
      saveFrame = 0
    }
    restoreTimers.forEach(timer => clearTimeout(timer))
    restoreTimers = []
    saveScrollPosition()
    if (scrollTarget?.removeEventListener) {
      scrollTarget.removeEventListener('scroll', onScroll)
    }
  })

  return {
    saveScrollPosition,
    scheduleRestoreScroll
  }
}
