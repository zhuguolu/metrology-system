<template>
  <router-view />
  <div class="toast-wrap">
    <transition-group name="toast">
      <div v-for="t in toasts" :key="t.id" :class="['toast', `toast-${t.type}`]">
        <span class="toast-symbol" aria-hidden="true">{{ t.type === 'success' ? '✓' : t.type === 'error' ? '!' : 'i' }}</span>
        {{ t.message }}
      </div>
    </transition-group>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, provide, reactive, watchEffect } from 'vue'
import { useRoute } from 'vue-router'

const toasts = reactive([])
let tid = 0
const route = useRoute()
const isPublicShareRoute = computed(() => route.path.startsWith('/share/'))

watchEffect(() => {
  if (typeof document === 'undefined') return
  document.body.classList.toggle('public-share-body', isPublicShareRoute.value)
  document.getElementById('app')?.classList.toggle('public-share-host', isPublicShareRoute.value)
})

function showToast(message, type = 'success') {
  const id = ++tid
  toasts.push({ id, message, type })
  setTimeout(() => {
    const i = toasts.findIndex(t => t.id === id)
    if (i !== -1) toasts.splice(i, 1)
  }, 3000)
}

provide('showToast', showToast)

onBeforeUnmount(() => {
  if (typeof document === 'undefined') return
  document.body.classList.remove('public-share-body')
  document.getElementById('app')?.classList.remove('public-share-host')
})
</script>

<style>
#app.public-share-host {
  display: block;
  height: auto;
  min-height: 100dvh;
  overflow: auto;
}

#app.public-share-host > *:first-child {
  width: 100%;
}

body.public-share-body {
  overscroll-behavior-y: auto;
}

.toast-symbol {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 900;
  flex-shrink: 0;
  background: rgba(255, 255, 255, 0.72);
}

.toast-enter-active, .toast-leave-active { transition: all 0.25s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateX(40px); }
</style>
