import { onActivated, onMounted, onUnmounted } from 'vue'

export function useResumeRefresh(refresh, options = {}) {
  const { minIntervalMs = 15000 } = options

  let lastRunAt = 0
  let inFlight = null

  function isHidden() {
    return typeof document !== 'undefined' && document.visibilityState === 'hidden'
  }

  function shouldSkip(reason) {
    return (reason === 'focus' || reason === 'visibilitychange' || reason === 'activated') && isHidden()
  }

  function triggerResumeRefresh(reason = 'manual', force = false) {
    if (shouldSkip(reason)) return Promise.resolve(null)

    const now = Date.now()
    if (!force && now - lastRunAt < minIntervalMs) {
      return inFlight || Promise.resolve(null)
    }
    if (inFlight) return inFlight

    lastRunAt = now
    inFlight = Promise.resolve(refresh(reason))
      .catch(() => null)
      .finally(() => {
        inFlight = null
      })

    return inFlight
  }

  function handleVisibilityChange() {
    if (typeof document === 'undefined' || document.visibilityState !== 'visible') return
    triggerResumeRefresh('visibilitychange')
  }

  function handleFocus() {
    triggerResumeRefresh('focus')
  }

  function handleOnline() {
    triggerResumeRefresh('online', true)
  }

  function handlePageShow(event) {
    if (event?.persisted) triggerResumeRefresh('pageshow', true)
  }

  onMounted(() => {
    lastRunAt = Date.now()
    window.addEventListener('focus', handleFocus)
    window.addEventListener('online', handleOnline)
    window.addEventListener('pageshow', handlePageShow)
    document.addEventListener('visibilitychange', handleVisibilityChange)
  })

  onActivated(() => {
    triggerResumeRefresh('activated')
  })

  onUnmounted(() => {
    window.removeEventListener('focus', handleFocus)
    window.removeEventListener('online', handleOnline)
    window.removeEventListener('pageshow', handlePageShow)
    document.removeEventListener('visibilitychange', handleVisibilityChange)
  })

  return { triggerResumeRefresh }
}
