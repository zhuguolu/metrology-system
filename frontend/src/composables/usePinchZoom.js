import { computed, ref } from 'vue'

const MIN_SCALE = 1
const MAX_SCALE = 4

export function usePinchZoom() {
  const containerRef = ref(null)
  const contentRef = ref(null)
  const scale = ref(1)
  const translateX = ref(0)
  const translateY = ref(0)
  const gesture = {
    dragging: false,
    pinching: false,
    startX: 0,
    startY: 0,
    startTranslateX: 0,
    startTranslateY: 0,
    startDistance: 0,
    startScale: 1,
  }

  const isZoomed = computed(() => scale.value > 1.01)
  const transformStyle = computed(() => ({
    transform: `translate3d(${translateX.value}px, ${translateY.value}px, 0) scale(${scale.value})`,
    transition: gesture.dragging || gesture.pinching ? 'none' : 'transform 0.18s ease',
  }))

  function clampScale(nextScale) {
    return Math.min(MAX_SCALE, Math.max(MIN_SCALE, nextScale))
  }

  function getDistance(touchA, touchB) {
    const dx = touchB.clientX - touchA.clientX
    const dy = touchB.clientY - touchA.clientY
    return Math.hypot(dx, dy)
  }

  function getBounds(nextScale = scale.value) {
    const container = containerRef.value
    const content = contentRef.value
    if (!container || !content) {
      return { maxX: 0, maxY: 0 }
    }

    const contentWidth = content.offsetWidth || container.clientWidth
    const contentHeight = content.offsetHeight || container.clientHeight
    const scaledWidth = contentWidth * nextScale
    const scaledHeight = contentHeight * nextScale

    return {
      maxX: Math.max(0, (scaledWidth - container.clientWidth) / 2),
      maxY: Math.max(0, (scaledHeight - container.clientHeight) / 2),
    }
  }

  function clampPosition(nextX, nextY, nextScale = scale.value) {
    const { maxX, maxY } = getBounds(nextScale)
    return {
      x: Math.min(maxX, Math.max(-maxX, nextX)),
      y: Math.min(maxY, Math.max(-maxY, nextY)),
    }
  }

  function applyScale(nextScale) {
    const normalizedScale = clampScale(nextScale)
    scale.value = normalizedScale
    const nextPos = clampPosition(translateX.value, translateY.value, normalizedScale)
    translateX.value = nextPos.x
    translateY.value = nextPos.y
  }

  function reset() {
    scale.value = 1
    translateX.value = 0
    translateY.value = 0
    gesture.dragging = false
    gesture.pinching = false
  }

  function onTouchStart(event) {
    if (event.touches.length === 2) {
      gesture.pinching = true
      gesture.dragging = false
      gesture.startDistance = getDistance(event.touches[0], event.touches[1])
      gesture.startScale = scale.value
      return
    }

    if (event.touches.length === 1 && scale.value > 1) {
      const touch = event.touches[0]
      gesture.dragging = true
      gesture.pinching = false
      gesture.startX = touch.clientX
      gesture.startY = touch.clientY
      gesture.startTranslateX = translateX.value
      gesture.startTranslateY = translateY.value
    }
  }

  function onTouchMove(event) {
    if (gesture.pinching && event.touches.length === 2) {
      event.preventDefault()
      const distance = getDistance(event.touches[0], event.touches[1])
      if (!gesture.startDistance) return
      applyScale(gesture.startScale * (distance / gesture.startDistance))
      return
    }

    if (gesture.dragging && event.touches.length === 1) {
      event.preventDefault()
      const touch = event.touches[0]
      const nextPos = clampPosition(
        gesture.startTranslateX + (touch.clientX - gesture.startX),
        gesture.startTranslateY + (touch.clientY - gesture.startY),
      )
      translateX.value = nextPos.x
      translateY.value = nextPos.y
    }
  }

  function onTouchEnd() {
    if (scale.value <= 1) {
      reset()
      return
    }
    gesture.dragging = false
    gesture.pinching = false
    const nextPos = clampPosition(translateX.value, translateY.value)
    translateX.value = nextPos.x
    translateY.value = nextPos.y
  }

  return {
    containerRef,
    contentRef,
    scale,
    isZoomed,
    transformStyle,
    reset,
    onTouchStart,
    onTouchMove,
    onTouchEnd,
  }
}
