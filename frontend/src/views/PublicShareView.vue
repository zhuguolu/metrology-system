<template>
  <div class="share-page">
    <div class="share-shell">
      <section class="share-hero">
        <div class="share-hero-copy">
          <div class="share-badge">公开分享</div>
          <h1 class="share-title">{{ shareTitle }}</h1>
          <p class="share-subtitle">
            {{ requiresPassword ? '输入访问密码后继续浏览分享内容。' : '无需登录即可浏览当前分享目录，并在授权时直接下载文件。' }}
          </p>

          <div v-if="shareMeta" class="share-meta">
            <span class="share-meta-pill">{{ shareMeta.allowDownload ? '可下载' : '仅浏览' }}</span>
            <span class="share-meta-pill">{{ folderCount }} 个文件夹 / {{ fileCount }} 个文件</span>
            <span v-if="shareMeta.expiresAt" class="share-meta-pill">截止 {{ formatDateTime(shareMeta.expiresAt) }}</span>
          </div>
        </div>

        <div v-if="!requiresPassword" class="share-hero-panel">
          <div class="share-hero-panel-label">当前目录</div>
          <div class="share-hero-panel-name">{{ currentFolderName }}</div>
          <div class="share-hero-panel-desc">{{ currentFolderSummary }}</div>
          <div class="share-hero-panel-actions">
            <button type="button" class="hero-action primary" @click="goRoot">返回根目录</button>
            <button
              v-if="activeItem && isFolder(activeItem)"
              type="button"
              class="hero-action"
              @click="enterFolder(activeItem)"
            >
              进入文件夹
            </button>
            <button
              v-else-if="activeItem && canDownload(activeItem)"
              type="button"
              class="hero-action"
              @click="downloadItem(activeItem)"
            >
              下载文件
            </button>
          </div>
        </div>
      </section>

      <section class="share-portal">
        <div ref="shareSidebarRef" class="share-sidebar">
          <div class="share-sidebar-top">
            <div class="share-sidebar-kicker">浏览器</div>
            <div class="share-breadcrumb">
              <button type="button" class="share-root-btn" @click="goRoot">根目录</button>
              <button
                v-for="crumb in breadcrumbs"
                :key="crumb.id"
                type="button"
                class="share-breadcrumb-item"
                @click="openFolder(crumb.id)"
              >
                {{ crumb.name }}
              </button>
            </div>
            <el-button v-if="accessPassword" text class="share-reset-btn" @click="resetPassword">重新输入密码</el-button>
          </div>

          <div v-if="requiresPassword" class="share-password-card">
            <div class="share-password-title">此分享已加密</div>
            <div class="share-password-desc">{{ errorMessage || '请输入访问密码后继续查看。' }}</div>
            <el-input
              v-model="passwordInput"
              type="password"
              show-password
              placeholder="请输入访问密码"
              maxlength="64"
              @keyup.enter="submitPassword"
            />
            <el-button type="primary" :loading="loading" @click="submitPassword">进入分享</el-button>
          </div>

          <div v-else-if="loading" class="share-state-card">加载中...</div>
          <div v-else-if="errorMessage" class="share-state-card error">{{ errorMessage }}</div>
          <div v-else-if="!items.length" class="share-state-card empty">当前目录暂无内容</div>

          <div v-else class="share-explorer">
            <div class="share-list-head">
              <div>
                <div class="share-list-title">目录内容</div>
                <div class="share-list-subtitle">点击左侧条目，右侧查看详情或预览。</div>
              </div>
              <div class="share-list-count">{{ filteredItems.length }} / {{ items.length }} 项</div>
            </div>

            <div class="share-search-wrap">
              <el-input
                v-model="searchQuery"
                clearable
                placeholder="搜索当前目录文件名"
              />
            </div>

            <div v-if="!filteredItems.length" class="share-search-empty">
              当前目录没有匹配的文件或文件夹
            </div>

            <div v-else class="share-list">
              <article
                v-for="item in filteredItems"
                :key="item.id"
                class="share-item-card"
                :class="{
                  active: activeItem?.id === item.id,
                  folder: isFolder(item),
                  locked: !isFolder(item) && !canDownload(item),
                }"
                @click="selectItem(item)"
              >
                <div class="share-item-mark" :class="{ thumb: showImageThumb(item) }">
                  <img
                    v-if="showImageThumb(item)"
                    :src="publicPreviewUrl(item)"
                    :alt="item.name"
                    class="share-item-thumb"
                    loading="lazy"
                  />
                  <span v-else class="share-item-mark-text">{{ itemBadge(item) }}</span>
                </div>

                <div class="share-item-body">
                  <div class="share-item-name">{{ item.name }}</div>
                  <div class="share-item-meta">
                    <span>{{ fileTypeLabel(item) }}</span>
                    <span v-if="!isFolder(item)">{{ formatSize(item.fileSize) }}</span>
                    <span>{{ formatDateTime(item.createdAt) }}</span>
                  </div>
                </div>

                <div class="share-item-actions">
                  <button
                    v-if="isFolder(item)"
                    type="button"
                    class="share-inline-btn"
                    @click.stop="enterFolder(item)"
                  >
                    进入
                  </button>
                  <button
                    v-else-if="canDownload(item)"
                    type="button"
                    class="share-inline-btn"
                    @click.stop="downloadItem(item)"
                  >
                    下载
                  </button>
                  <span v-else class="share-inline-tag">仅浏览</span>
                </div>
              </article>
            </div>
          </div>
        </div>

        <div class="share-stage">
          <div v-if="requiresPassword" class="share-stage-placeholder">
            <div class="share-stage-kicker">访问受保护</div>
            <div class="share-stage-title">输入密码后查看分享内容</div>
            <div class="share-stage-text">密码验证通过后，这里会展示文件详情、目录结构与在线预览面板。</div>
          </div>

          <div v-else-if="loading" class="share-stage-placeholder">
            <div class="share-stage-kicker">准备中</div>
            <div class="share-stage-title">正在载入分享内容</div>
            <div class="share-stage-text">请稍候，目录结构和文件详情马上显示。</div>
          </div>

          <div v-else-if="errorMessage" class="share-stage-placeholder error">
            <div class="share-stage-kicker">访问异常</div>
            <div class="share-stage-title">当前分享暂时无法打开</div>
            <div class="share-stage-text">{{ errorMessage }}</div>
          </div>

          <div v-else-if="!items.length" class="share-stage-placeholder">
            <div class="share-stage-kicker">空目录</div>
            <div class="share-stage-title">{{ currentFolderName }}</div>
            <div class="share-stage-text">当前文件夹没有可展示的文件或子目录。</div>
          </div>

          <template v-else>
            <div class="share-stage-header">
              <div>
                <div class="share-stage-kicker">{{ activeStageKicker }}</div>
                <h2 class="share-stage-title">{{ activeStageTitle }}</h2>
                <p class="share-stage-text">{{ activeStageText }}</p>
              </div>
              <div class="share-stage-pills">
                <span class="share-stage-pill">{{ activeStageType }}</span>
                <span class="share-stage-pill">{{ activeStageTime }}</span>
              </div>
            </div>

            <div class="share-stage-grid">
              <div class="share-preview-card">
                <button
                  v-if="isMobilePreview && activeItem"
                  type="button"
                  class="share-mobile-close"
                  @click="clearActivePreview"
                >
                  关闭预览
                </button>
                <div class="share-panel-head">
                  <span>预览窗口</span>
                  <span>{{ previewPanelLabel }}</span>
                </div>

                <div v-if="!activeItem" class="share-preview-empty">
                  选择左侧条目后，这里会展示预览或详情摘要。
                </div>

                <template v-else-if="isFolder(activeItem)">
                  <div class="share-folder-overview">
                    <div class="share-folder-symbol">DIR</div>
                    <div class="share-folder-overview-title">{{ activeItem.name }}</div>
                    <div class="share-folder-overview-text">这是一个文件夹。你可以继续进入，浏览内部的目录与文件。</div>
                    <button type="button" class="hero-action primary" @click="enterFolder(activeItem)">进入此文件夹</button>
                  </div>
                </template>

                <div v-else-if="previewLoading" class="share-preview-empty">
                  正在加载文件预览...
                </div>

                <div v-else-if="previewError" class="share-preview-empty error">
                  {{ previewError }}
                </div>

                <div v-else-if="previewType === 'image'" class="share-preview-frame image">
                  <div class="share-touch-tools">
                    <span class="share-touch-tip">双指缩放，单指拖动</span>
                    <button type="button" class="share-touch-reset" :disabled="!previewZoom.isZoomed" @click="previewZoom.reset">重置</button>
                  </div>
                  <div
                    ref="sharePreviewTouchWrapRef"
                    class="share-preview-touch-wrap"
                    @touchstart.passive="previewZoom.onTouchStart"
                    @touchmove="previewZoom.onTouchMove"
                    @touchend="previewZoom.onTouchEnd"
                    @touchcancel="previewZoom.onTouchEnd"
                  >
                    <img
                      ref="sharePreviewTouchImageRef"
                      :src="previewUrl"
                      :alt="activeItem.name"
                      class="share-preview-image"
                      :style="previewZoom.transformStyle"
                      @load="previewZoom.reset"
                    />
                  </div>
                </div>

                <div v-else-if="previewType === 'pdf' && isMobilePreview" class="share-preview-frame document">
                  <div class="share-preview-pdf-stack">
                    <div class="share-preview-pdf-modebar">
                      <span class="share-preview-pdf-badge">图片模式</span>
                      <span class="share-preview-pdf-hint">上下滚动查看整份 PDF</span>
                    </div>
                    <div v-if="pdfPageImages.length" class="share-preview-pdf-pages">
                      <div v-for="page in pdfPageImages" :key="page.pageNumber" class="share-preview-pdf-page">
                        <img
                          :src="page.url"
                          :alt="`${activeItem.name} 第 ${page.pageNumber} 页`"
                          class="share-preview-pdf-image"
                        />
                      </div>
                    </div>
                    <div v-else-if="!previewLoading" class="share-preview-empty error pdf-image-empty">
                      当前 PDF 暂时无法渲染为图片，请直接下载查看。
                    </div>
                  </div>
                </div>

                <div v-else-if="previewType === 'pdf' && !isMobilePreview" class="share-preview-frame document">
                  <iframe :src="previewUrl" title="PDF 预览" class="share-preview-iframe"></iframe>
                </div>

                <div v-else-if="previewType === 'office'" class="share-preview-frame document">
                  <iframe :src="previewUrl" title="Office 预览" class="share-preview-iframe"></iframe>
                </div>

                <div v-else-if="previewType === 'video'" class="share-preview-frame media">
                  <video :src="previewUrl" controls class="share-preview-media"></video>
                </div>

                <div v-else-if="previewType === 'audio'" class="share-preview-frame audio">
                  <audio :src="previewUrl" controls class="share-preview-audio"></audio>
                </div>

                <div v-else-if="previewType === 'text'" class="share-preview-frame text">
                  <pre class="share-preview-text">{{ previewText }}</pre>
                </div>

                <div v-else class="share-preview-empty">
                  当前文件暂不支持在线预览，可通过右侧操作直接下载查看。
                </div>
              </div>

              <div class="share-info-stack">
                <div class="share-info-card">
                  <div class="share-panel-head">
                    <span>条目详情</span>
                    <span>{{ activeItem ? '已选中' : '未选择' }}</span>
                  </div>
                  <div v-if="activeItem" class="share-detail-list">
                    <div class="share-detail-row">
                      <span>名称</span>
                      <strong>{{ activeItem.name }}</strong>
                    </div>
                    <div class="share-detail-row">
                      <span>类型</span>
                      <strong>{{ fileTypeLabel(activeItem) }}</strong>
                    </div>
                    <div class="share-detail-row">
                      <span>大小</span>
                      <strong>{{ isFolder(activeItem) ? '-' : formatSize(activeItem.fileSize) }}</strong>
                    </div>
                    <div class="share-detail-row">
                      <span>时间</span>
                      <strong>{{ formatDateTime(activeItem.createdAt) }}</strong>
                    </div>
                    <div class="share-detail-row">
                      <span>权限</span>
                      <strong>{{ canDownload(activeItem) ? '允许下载' : (isFolder(activeItem) ? '可进入浏览' : '允许预览') }}</strong>
                    </div>
                  </div>
                  <div v-else class="share-info-empty">左侧选中文件或文件夹后查看详情。</div>
                </div>

                <div class="share-info-card">
                  <div class="share-panel-head">
                    <span>快捷操作</span>
                    <span>访客入口</span>
                  </div>
                  <div class="share-action-list">
                    <button type="button" class="stage-action primary" @click="goRoot">查看根目录</button>
                    <button
                      v-if="activeItem && isFolder(activeItem)"
                      type="button"
                      class="stage-action"
                      @click="enterFolder(activeItem)"
                    >
                      进入当前文件夹
                    </button>
                    <button
                      v-else-if="activeItem && canDownload(activeItem)"
                      type="button"
                      class="stage-action"
                      @click="downloadItem(activeItem)"
                    >
                      下载当前文件
                    </button>
                    <div v-else class="share-action-note">
                      当前分享未开放下载时，仍可浏览目录，并预览支持的文件格式。
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </template>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { GlobalWorkerOptions, getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs'
import pdfWorkerUrl from 'pdfjs-dist/legacy/build/pdf.worker.min.mjs?url'
import { publicShareApi } from '../api/index.js'
import { usePinchZoom } from '../composables/usePinchZoom.js'

const route = useRoute()
const router = useRouter()

const TEXT_PREVIEW_LIMIT = 2 * 1024 * 1024
const PREVIEW_MAX_BYTES = 20 * 1024 * 1024

const loading = ref(false)
const requiresPassword = ref(false)
const errorMessage = ref('')
const passwordInput = ref('')
const accessPassword = ref('')
const searchQuery = ref('')
const sharePayload = ref(null)
const activeItemId = ref(null)

const previewLoading = ref(false)
const previewType = ref('')
const previewUrl = ref('')
const previewText = ref('')
const previewError = ref('')
const isMobilePreview = ref(false)
const pdfPageImages = ref([])
const shareSidebarRef = ref(null)
const previewZoom = usePinchZoom()
const sharePreviewTouchWrapRef = previewZoom.containerRef
const sharePreviewTouchImageRef = previewZoom.contentRef

let activePreviewUrl = ''
let previewRequestId = 0
let previewAbortController = null
let activePdfRenderToken = 0
let activePdfDocument = null

GlobalWorkerOptions.workerSrc = pdfWorkerUrl

const shareToken = computed(() => String(route.params.token || ''))
const currentFolderId = computed(() => {
  const raw = route.query.folder
  if (!raw) return null
  const value = Number(raw)
  return Number.isFinite(value) ? value : null
})
const shareMeta = computed(() => sharePayload.value?.share || null)
const shareTitle = computed(() => shareMeta.value?.folderName || '文件分享')
const currentFolderName = computed(() => sharePayload.value?.currentFolderName || shareTitle.value)
const breadcrumbs = computed(() => sharePayload.value?.breadcrumbs || [])
const items = computed(() => sharePayload.value?.items || [])
const filteredItems = computed(() => {
  const keyword = String(searchQuery.value || '').trim().toLowerCase()
  if (!keyword) return items.value
  return items.value.filter(item => String(item?.name || '').toLowerCase().includes(keyword))
})
const activeItem = computed(() => filteredItems.value.find(item => item.id === activeItemId.value) || null)
const folderCount = computed(() => items.value.filter(isFolder).length)
const fileCount = computed(() => items.value.filter(item => !isFolder(item)).length)
const currentFolderSummary = computed(() => {
  if (!items.value.length) return '当前目录为空，可以返回上级目录继续浏览。'
  return `当前目录包含 ${folderCount.value} 个文件夹和 ${fileCount.value} 个文件。`
})
const activeStageKicker = computed(() => {
  if (!activeItem.value) return '目录概览'
  return isFolder(activeItem.value) ? '文件夹概览' : '文件预览'
})
const activeStageTitle = computed(() => activeItem.value?.name || currentFolderName.value)
const activeStageText = computed(() => {
  if (!activeItem.value) return currentFolderSummary.value
  if (isFolder(activeItem.value)) return '这是一个子目录。进入后可以继续查看其内部文件与层级结构。'
  if (canDownload(activeItem.value)) return '当前文件支持下载，常见格式会直接在本页预览。'
  return '当前文件未开放下载，但支持的格式仍可在本页直接浏览。'
})
const activeStageType = computed(() => activeItem.value ? fileTypeLabel(activeItem.value) : '当前目录')
const activeStageTime = computed(() => activeItem.value?.createdAt ? formatDateTime(activeItem.value.createdAt) : `${items.value.length} 项内容`)
const previewPanelLabel = computed(() => {
  if (!activeItem.value) return '等待选择'
  if (isFolder(activeItem.value)) return '目录卡片'
  if (previewLoading.value) return '加载中'
  if (previewError.value) return '不可预览'
  return previewTypeLabel(previewType.value)
})

function syncMobilePreviewState() {
  if (typeof window === 'undefined') return
  isMobilePreview.value = window.innerWidth <= 768
}

watch(
  () => [shareToken.value, currentFolderId.value],
  () => {
    searchQuery.value = ''
    loadShare()
  },
  { immediate: true }
)

watch(filteredItems, nextItems => {
  if (!nextItems.length) {
    activeItemId.value = null
    resetPreviewState()
    return
  }

  const stillExists = nextItems.some(item => item.id === activeItemId.value)
  if (stillExists) return

  const firstFile = nextItems.find(item => !isFolder(item))
  activeItemId.value = (firstFile || nextItems[0]).id
})

watch(activeItem, item => {
  loadPreviewForItem(item)
})

function isFolder(item) {
  return item?.isFolder === true || item?.type === 'FOLDER'
}

function selectItem(item) {
  activeItemId.value = item?.id ?? null
}

function itemBadge(item) {
  if (isFolder(item)) return 'DIR'
  const ext = getFileExt(item?.name)
  return ext ? ext.toUpperCase().slice(0, 4) : 'FILE'
}

function fileTypeLabel(item) {
  if (isFolder(item)) return '文件夹'
  const ext = getFileExt(item?.name)
  return ext ? `${ext.toUpperCase()} 文件` : '文件'
}

function getFileExt(name) {
  if (!name || !name.includes('.')) return ''
  return name.slice(name.lastIndexOf('.') + 1).toLowerCase()
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return '-'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}

function formatDateTime(value) {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  const pad = n => String(n).padStart(2, '0')
  return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function previewTypeLabel(type) {
  const labels = {
    image: '图片预览',
    pdf: 'PDF 预览',
    office: 'Office 预览',
    video: '视频预览',
    audio: '音频预览',
    text: '文本预览',
    unsupported: '详情模式',
  }
  return labels[type] || '详情模式'
}

function resolvePreviewType(item) {
  const mime = String(item?.mimeType || '').toLowerCase()
  const ext = getFileExt(item?.name)
  const imageExts = new Set(['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'])
  const textExts = new Set(['txt', 'md', 'json', 'csv', 'log', 'xml', 'html', 'htm', 'js', 'ts', 'css', 'java', 'sql', 'yml', 'yaml'])
  const videoExts = new Set(['mp4', 'webm', 'ogg', 'mov'])
  const audioExts = new Set(['mp3', 'wav', 'ogg', 'm4a', 'flac'])
  const officeExts = new Set(['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'])

  if (mime.startsWith('image/') || imageExts.has(ext)) return 'image'
  if (mime.includes('pdf') || ext === 'pdf') return 'pdf'
  if (officeExts.has(ext)) return 'office'
  if (mime.startsWith('video/') || videoExts.has(ext)) return 'video'
  if (mime.startsWith('audio/') || audioExts.has(ext)) return 'audio'
  if (mime.startsWith('text/') || textExts.has(ext) || mime.includes('json') || mime.includes('xml')) return 'text'
  return 'unsupported'
}

function publicPreviewUrl(item) {
  if (!item?.id) return ''
  const query = accessPassword.value ? `?password=${encodeURIComponent(accessPassword.value)}` : ''
  return `/api/public/shares/${encodeURIComponent(shareToken.value)}/files/${item.id}/raw${query}`
}

function publicPreviewAbsoluteUrl(item) {
  if (typeof window === 'undefined') return ''
  const path = publicPreviewUrl(item)
  return path ? new URL(path, window.location.origin).toString() : ''
}

function isLocalHost(hostname) {
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1'
}

function showImageThumb(item) {
  return !isFolder(item) && resolvePreviewType(item) === 'image'
}

function clearPdfPreviewState() {
  activePdfRenderToken += 1
  pdfPageImages.value = []
  if (activePdfDocument && typeof activePdfDocument.destroy === 'function') {
    activePdfDocument.destroy()
  }
  activePdfDocument = null
}

async function renderPdfAsImages(pdfData) {
  const renderToken = ++activePdfRenderToken
  pdfPageImages.value = []
  activePdfDocument = null

  try {
    const loadingTask = getDocument({
      data: pdfData,
      useWorkerFetch: false,
      isEvalSupported: false,
    })
    const pdfDocument = await loadingTask.promise
    if (renderToken !== activePdfRenderToken) {
      pdfDocument.destroy()
      return
    }

    activePdfDocument = pdfDocument
    const containerWidth = typeof window === 'undefined'
      ? 720
      : Math.max(280, Math.min(window.innerWidth - 28, 960))

    for (let pageNumber = 1; pageNumber <= pdfDocument.numPages; pageNumber += 1) {
      if (renderToken !== activePdfRenderToken) return

      const page = await pdfDocument.getPage(pageNumber)
      const baseViewport = page.getViewport({ scale: 1 })
      const scale = containerWidth / Math.max(baseViewport.width, 1)
      const viewport = page.getViewport({ scale })
      const outputScale = typeof window === 'undefined' ? 1 : Math.min(window.devicePixelRatio || 1, 2)
      const canvas = document.createElement('canvas')
      const context = canvas.getContext('2d', { alpha: false })

      if (!context) {
        throw new Error('PDF canvas context unavailable')
      }

      canvas.width = Math.floor(viewport.width * outputScale)
      canvas.height = Math.floor(viewport.height * outputScale)

      await page.render({
        canvasContext: context,
        viewport,
        transform: outputScale === 1 ? undefined : [outputScale, 0, 0, outputScale, 0, 0],
      }).promise

      if (renderToken !== activePdfRenderToken) return

      pdfPageImages.value = [
        ...pdfPageImages.value,
        {
          pageNumber,
          url: canvas.toDataURL('image/jpeg', 0.92),
        },
      ]

      if (pageNumber === 1) {
        previewLoading.value = false
      }
    }
  } catch (error) {
    console.error('Public share PDF render failed', error)
    previewError.value = '移动端 PDF 预览失败，请下载后查看。'
  } finally {
    if (renderToken === activePdfRenderToken) {
      previewLoading.value = false
    }
  }
}

function clearActivePreview() {
  activeItemId.value = null
  nextTick(() => {
    shareSidebarRef.value?.scrollIntoView?.({ behavior: 'smooth', block: 'start' })
  })
}

function resetPreviewState() {
  cancelPreviewRequest()
  previewZoom.reset()
  clearPdfPreviewState()
  previewLoading.value = false
  previewType.value = ''
  previewText.value = ''
  previewError.value = ''
  if (activePreviewUrl) {
    window.URL.revokeObjectURL(activePreviewUrl)
    activePreviewUrl = ''
  }
  previewUrl.value = ''
}

function cancelPreviewRequest() {
  if (previewAbortController) {
    previewAbortController.abort()
    previewAbortController = null
  }
}

function isPreviewRequestCanceled(error) {
  return error?.code === 'ERR_CANCELED' || error?.name === 'CanceledError'
}

async function loadPreviewForItem(item) {
  cancelPreviewRequest()
  const requestId = ++previewRequestId
  resetPreviewState()

  if (!item || isFolder(item)) return

  previewType.value = resolvePreviewType(item)

  if (previewType.value === 'unsupported') {
    return
  }

  if (previewType.value === 'office') {
    if (accessPassword.value) {
      previewError.value = '加密分享暂不支持 Office 在线预览，请下载后查看。'
      return
    }
    if (typeof window !== 'undefined' && isLocalHost(window.location.hostname)) {
      previewError.value = '本地地址无法被 Office 在线预览服务访问，部署到可访问地址后即可使用。'
      return
    }
    const absoluteUrl = publicPreviewAbsoluteUrl(item)
    if (!absoluteUrl) {
      previewError.value = '未能生成 Office 预览地址。'
      return
    }
    previewUrl.value = `https://view.officeapps.live.com/op/embed.aspx?src=${encodeURIComponent(absoluteUrl)}`
    return
  }

  if (previewType.value === 'image' || previewType.value === 'video' || previewType.value === 'audio') {
    previewUrl.value = publicPreviewUrl(item)
    return
  }

  if (previewType.value === 'pdf') {
    if (!isMobilePreview.value) {
      previewUrl.value = publicPreviewUrl(item)
      return
    }

    previewLoading.value = true
    previewAbortController = new AbortController()
    try {
      const res = await publicShareApi.preview(
        shareToken.value,
        item.id,
        accessPassword.value || undefined,
        { signal: previewAbortController.signal },
      )
      if (requestId !== previewRequestId) return

      const blob = new Blob([res.data], { type: res.headers['content-type'] || item.mimeType || 'application/pdf' })
      const pdfBuffer = await blob.arrayBuffer()
      await renderPdfAsImages(new Uint8Array(pdfBuffer))
    } catch (error) {
      if (isPreviewRequestCanceled(error)) return
      if (requestId !== previewRequestId) return
      previewError.value = error.response?.data?.message || '移动端 PDF 预览失败，请下载后查看。'
      previewLoading.value = false
    } finally {
      if (requestId === previewRequestId) {
        previewAbortController = null
      }
    }
    return
  }

  if (previewType.value === 'text' && (item.fileSize || 0) > PREVIEW_MAX_BYTES) {
    previewError.value = '文本文件较大，已切换为详情模式，请直接下载后查看。'
    return
  }

  previewLoading.value = true
  previewAbortController = new AbortController()
  try {
    const res = await publicShareApi.preview(
      shareToken.value,
      item.id,
      accessPassword.value || undefined,
      { signal: previewAbortController.signal },
    )
    if (requestId !== previewRequestId) return

    const blob = new Blob([res.data], { type: res.headers['content-type'] || item.mimeType || 'application/octet-stream' })
    if (blob.size > TEXT_PREVIEW_LIMIT) {
      previewError.value = '文本文件较大，暂不直接展开，请下载后查看。'
    } else {
      previewText.value = await blob.text()
    }
  } catch (error) {
    if (isPreviewRequestCanceled(error)) return
    if (requestId !== previewRequestId) return
    previewError.value = error.response?.data?.message || '文件预览失败，请稍后重试。'
  } finally {
    if (requestId === previewRequestId) {
      previewAbortController = null
      previewLoading.value = false
    }
  }
}

async function loadShare() {
  if (!shareToken.value) return
  loading.value = true
  errorMessage.value = ''
  try {
    const res = await publicShareApi.get(shareToken.value, currentFolderId.value, accessPassword.value || undefined)
    sharePayload.value = res.data || null
    requiresPassword.value = false
  } catch (error) {
    sharePayload.value = null
    activeItemId.value = null
    resetPreviewState()
    const status = error.response?.status
    const message = error.response?.data?.message || '分享加载失败'
    errorMessage.value = message
    requiresPassword.value = status === 401
  } finally {
    loading.value = false
  }
}

function goRoot() {
  router.replace({ path: `/share/${shareToken.value}` })
}

function openFolder(folderId) {
  const rootId = shareMeta.value?.folderId
  if (!folderId || folderId === rootId) {
    goRoot()
    return
  }
  router.replace({ path: `/share/${shareToken.value}`, query: { folder: folderId } })
}

function enterFolder(item) {
  if (!item || !isFolder(item)) return
  openFolder(item.id)
}

function resetPassword() {
  accessPassword.value = ''
  passwordInput.value = ''
  searchQuery.value = ''
  requiresPassword.value = true
  errorMessage.value = ''
  sharePayload.value = null
  activeItemId.value = null
  resetPreviewState()
}

function submitPassword() {
  accessPassword.value = passwordInput.value.trim()
  loadShare()
}

function canDownload(item) {
  return !isFolder(item) && shareMeta.value?.allowDownload
}

async function downloadItem(item) {
  try {
    const res = await publicShareApi.download(shareToken.value, item.id, accessPassword.value || undefined)
    const blob = new Blob([res.data], { type: res.headers['content-type'] || 'application/octet-stream' })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = item.name || 'download'
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '下载失败')
  }
}

onMounted(() => {
  syncMobilePreviewState()
  window.addEventListener('resize', syncMobilePreviewState)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', syncMobilePreviewState)
  previewRequestId += 1
  resetPreviewState()
})
</script>

<style scoped>
.share-page {
  --share-surface: rgba(255, 255, 255, 0.84);
  --share-border: rgba(148, 163, 184, 0.2);
  --share-shadow: 0 24px 60px rgba(15, 23, 42, 0.08);
  --share-text: #10203d;
  --share-muted: #607089;
  --share-blue: #2563eb;
  --share-blue-soft: rgba(37, 99, 235, 0.12);
  --share-gold-soft: rgba(244, 183, 64, 0.15);
  width: 100%;
  min-height: 100vh;
  padding: 28px 18px 36px;
  background:
    radial-gradient(circle at top left, rgba(96, 165, 250, 0.22), transparent 28%),
    radial-gradient(circle at top right, rgba(125, 211, 252, 0.16), transparent 24%),
    linear-gradient(180deg, #f5f9ff 0%, #eef4ff 48%, #f8fbff 100%);
}

.share-shell {
  width: min(1380px, 100%);
  margin: 0 auto;
}

.share-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(300px, 0.9fr);
  gap: 18px;
  margin-bottom: 18px;
}

.share-hero-copy,
.share-hero-panel,
.share-sidebar,
.share-stage {
  border: 1px solid var(--share-border);
  background: var(--share-surface);
  box-shadow: var(--share-shadow);
  backdrop-filter: blur(18px);
}

.share-hero-copy {
  padding: 34px 34px 30px;
  border-radius: 34px;
  background:
    radial-gradient(circle at top left, rgba(191, 219, 254, 0.8), transparent 34%),
    linear-gradient(135deg, rgba(255, 255, 255, 0.94), rgba(247, 250, 255, 0.9));
}

.share-badge {
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  padding: 0 14px;
  border-radius: 999px;
  background: var(--share-blue-soft);
  color: var(--share-blue);
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.share-title {
  margin: 18px 0 10px;
  font-size: clamp(34px, 4.5vw, 58px);
  line-height: 0.98;
  letter-spacing: -0.04em;
  color: var(--share-text);
}

.share-subtitle {
  max-width: 720px;
  color: var(--share-muted);
  font-size: 16px;
  line-height: 1.7;
}

.share-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 18px;
}

.share-meta-pill,
.share-stage-pill {
  display: inline-flex;
  align-items: center;
  min-height: 34px;
  padding: 0 14px;
  border-radius: 999px;
  border: 1px solid rgba(148, 163, 184, 0.18);
  background: rgba(255, 255, 255, 0.78);
  color: #314159;
  font-size: 12px;
  font-weight: 700;
}

.share-hero-panel {
  display: grid;
  align-content: start;
  gap: 10px;
  padding: 28px 28px 26px;
  border-radius: 30px;
  background:
    radial-gradient(circle at 0% 0%, rgba(244, 183, 64, 0.18), transparent 34%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(249, 250, 255, 0.92));
}

.share-hero-panel-label,
.share-sidebar-kicker,
.share-list-title,
.share-stage-kicker {
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #7c8ca3;
  font-weight: 800;
}

.share-hero-panel-name {
  font-size: 28px;
  line-height: 1.1;
  color: var(--share-text);
  font-weight: 800;
  word-break: break-word;
}

.share-hero-panel-desc {
  color: var(--share-muted);
  line-height: 1.7;
}

.share-hero-panel-actions,
.share-action-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 8px;
}

.hero-action,
.stage-action,
.share-inline-btn {
  border: 0;
  border-radius: 14px;
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
}

.hero-action,
.stage-action {
  min-height: 44px;
  padding: 0 16px;
  background: rgba(15, 23, 42, 0.06);
  color: #163153;
  font-weight: 700;
}

.hero-action.primary,
.stage-action.primary {
  background: linear-gradient(135deg, #2563eb, #1d4ed8);
  color: #fff;
  box-shadow: 0 14px 28px rgba(37, 99, 235, 0.22);
}

.hero-action:hover,
.stage-action:hover,
.share-inline-btn:hover {
  transform: translateY(-1px);
}

.share-portal {
  display: grid;
  grid-template-columns: minmax(320px, 380px) minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}

.share-sidebar {
  position: sticky;
  top: 18px;
  max-height: calc(100vh - 36px);
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 18px;
  padding: 18px;
  border-radius: 30px;
}

.share-sidebar-top {
  display: grid;
  gap: 12px;
}

.share-breadcrumb {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.share-root-btn,
.share-breadcrumb-item {
  min-height: 34px;
  padding: 0 12px;
  border: 1px solid rgba(191, 219, 254, 0.7);
  border-radius: 999px;
  background: rgba(239, 246, 255, 0.92);
  color: #2563eb;
  font-weight: 700;
  cursor: pointer;
}

.share-reset-btn {
  justify-self: start;
  padding: 0;
}

.share-password-card,
.share-state-card,
.share-explorer {
  min-height: 220px;
  border-radius: 24px;
  border: 1px solid rgba(191, 219, 254, 0.48);
  background: rgba(255, 255, 255, 0.78);
}

.share-password-card {
  display: grid;
  align-content: center;
  gap: 14px;
  padding: 26px;
  text-align: center;
}

.share-password-title {
  font-size: 24px;
  line-height: 1.15;
  color: var(--share-text);
  font-weight: 800;
}

.share-password-desc,
.share-state-card,
.share-list-subtitle,
.share-info-empty,
.share-action-note,
.share-folder-overview-text {
  color: var(--share-muted);
  line-height: 1.7;
}

.share-state-card {
  display: grid;
  place-items: center;
  padding: 24px;
  text-align: center;
}

.share-state-card.error {
  color: #c62828;
}

.share-explorer {
  display: grid;
  grid-template-rows: auto 1fr;
  min-height: 0;
}

.share-list-head {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 18px 14px;
  border-bottom: 1px solid rgba(226, 232, 240, 0.88);
}

.share-search-wrap {
  padding: 14px 16px 0;
}

.share-search-empty {
  display: grid;
  place-items: center;
  min-height: 180px;
  padding: 20px;
  text-align: center;
  color: var(--share-muted);
}

.share-list-title {
  margin-bottom: 2px;
}

.share-list-count {
  align-self: start;
  min-height: 28px;
  padding: 0 12px;
  border-radius: 999px;
  background: var(--share-gold-soft);
  color: #9a6b00;
  font-size: 12px;
  font-weight: 800;
  line-height: 28px;
  white-space: nowrap;
}

.share-list {
  display: grid;
  gap: 10px;
  padding: 16px;
  overflow-y: auto;
}

.share-item-card {
  display: grid;
  grid-template-columns: 58px minmax(0, 1fr) auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  border-radius: 22px;
  border: 1px solid rgba(203, 213, 225, 0.82);
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(246, 249, 255, 0.92));
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
}

.share-item-card:hover,
.share-item-card.active {
  transform: translateY(-1px);
  border-color: rgba(96, 165, 250, 0.72);
  box-shadow: 0 16px 30px rgba(37, 99, 235, 0.08);
}

.share-item-card.folder {
  border-color: rgba(244, 183, 64, 0.52);
  background: linear-gradient(180deg, rgba(255, 252, 238, 0.96), rgba(255, 255, 255, 0.92));
}

.share-item-card.locked {
  opacity: 0.9;
}

.share-item-mark {
  display: grid;
  place-items: center;
  width: 58px;
  height: 58px;
  border-radius: 18px;
  background:
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.8), transparent 36%),
    linear-gradient(135deg, rgba(191, 219, 254, 0.92), rgba(219, 234, 254, 0.6));
  color: #1247a6;
}

.share-item-card.folder .share-item-mark {
  background:
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.9), transparent 36%),
    linear-gradient(135deg, rgba(254, 240, 138, 0.88), rgba(255, 251, 235, 0.72));
  color: #8a5a00;
}

.share-item-mark.thumb {
  overflow: hidden;
  padding: 0;
  background: rgba(226, 232, 240, 0.7);
}

.share-item-thumb {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.share-item-mark-text {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.share-item-body {
  min-width: 0;
  display: grid;
  gap: 6px;
}

.share-item-name {
  color: var(--share-text);
  font-size: 15px;
  font-weight: 800;
  line-height: 1.4;
  word-break: break-word;
}

.share-item-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  color: var(--share-muted);
  font-size: 12px;
}

.share-item-actions {
  display: grid;
  justify-items: end;
  gap: 8px;
}

.share-inline-btn {
  min-height: 36px;
  padding: 0 14px;
  background: rgba(37, 99, 235, 0.08);
  color: #1d4ed8;
  font-weight: 700;
}

.share-inline-tag {
  font-size: 12px;
  color: #8a5a00;
  font-weight: 700;
}

.share-stage {
  min-height: calc(100vh - 36px);
  padding: 24px;
  border-radius: 34px;
}

.share-stage-placeholder {
  min-height: calc(100vh - 84px);
  display: grid;
  align-content: center;
  justify-items: start;
  gap: 8px;
  padding: 12px;
}

.share-stage-placeholder.error .share-stage-title,
.share-stage-placeholder.error .share-stage-text {
  color: #b91c1c;
}

.share-stage-header {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

.share-stage-title {
  margin: 6px 0 8px;
  font-size: clamp(28px, 3vw, 42px);
  line-height: 1.02;
  letter-spacing: -0.04em;
  color: var(--share-text);
  word-break: break-word;
}

.share-stage-text {
  color: var(--share-muted);
  line-height: 1.7;
  max-width: 760px;
}

.share-stage-pills {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.share-stage-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(280px, 0.78fr);
  gap: 18px;
  align-items: start;
}

.share-preview-card,
.share-info-card {
  border-radius: 26px;
  border: 1px solid rgba(203, 213, 225, 0.8);
  background: rgba(255, 255, 255, 0.82);
}

.share-preview-card {
  min-height: 620px;
  overflow: hidden;
}

.share-mobile-close {
  display: none;
}

.share-info-stack {
  display: grid;
  gap: 18px;
}

.share-panel-head {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 20px;
  border-bottom: 1px solid rgba(226, 232, 240, 0.88);
  color: #54657f;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.share-preview-empty,
.share-folder-overview {
  min-height: 560px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: 14px;
  padding: 28px;
  text-align: center;
  color: var(--share-muted);
}

.share-preview-empty.error {
  color: #b91c1c;
}

.share-folder-symbol {
  display: grid;
  place-items: center;
  width: 88px;
  height: 88px;
  border-radius: 28px;
  background: var(--share-gold-soft);
  color: #8a5a00;
  font-size: 20px;
  font-weight: 800;
  letter-spacing: 0.08em;
}

.share-folder-overview-title {
  color: var(--share-text);
  font-size: 26px;
  font-weight: 800;
}

.share-preview-frame {
  min-height: 560px;
  padding: 18px;
  background: linear-gradient(180deg, rgba(247, 250, 255, 0.92), rgba(255, 255, 255, 0.96));
}

.share-preview-frame.image,
.share-preview-frame.document,
.share-preview-frame.media,
.share-preview-frame.text {
  display: flex;
  align-items: center;
  justify-content: center;
}

.share-preview-frame.document {
  align-items: stretch;
  justify-content: stretch;
}

.share-preview-frame.audio {
  display: grid;
  place-items: center;
}

.share-preview-pdf-stack {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-height: 0;
  width: 100%;
  background: #eef2f7;
}

.share-preview-pdf-modebar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border-bottom: 1px solid rgba(148, 163, 184, 0.2);
  background: rgba(255, 255, 255, 0.92);
}

.share-preview-pdf-badge {
  display: inline-flex;
  align-items: center;
  height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  background: linear-gradient(135deg, #dbeafe, #bfdbfe);
  color: #1d4ed8;
  font-size: 12px;
  font-weight: 700;
}

.share-preview-pdf-hint {
  color: #64748b;
  font-size: 12px;
  font-weight: 600;
}

.share-preview-pdf-pages {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 12px 12px 16px;
}

.share-preview-pdf-page + .share-preview-pdf-page {
  margin-top: 12px;
}

.share-preview-pdf-image {
  display: block;
  width: 100%;
  height: auto;
  border-radius: 12px;
  background: #fff;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.1);
}

.pdf-image-empty {
  flex: 1;
  margin: 12px;
}

.share-preview-image,
.share-preview-iframe,
.share-preview-media {
  width: 100%;
  height: 100%;
  min-height: 524px;
  border: 0;
  border-radius: 20px;
  background: rgba(15, 23, 42, 0.04);
}

.share-preview-image {
  object-fit: contain;
}

.share-touch-tools {
  display: none;
}

.share-preview-touch-wrap {
  width: 100%;
}

.share-preview-audio {
  width: min(100%, 640px);
}

.share-preview-text {
  width: 100%;
  min-height: 524px;
  padding: 20px;
  border-radius: 20px;
  background: #0f172a;
  color: #dbeafe;
  overflow: auto;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: "Cascadia Code", "Consolas", monospace;
  line-height: 1.65;
}

.share-info-card {
  padding-bottom: 4px;
}

.share-detail-list {
  display: grid;
  gap: 10px;
  padding: 18px 20px 20px;
}

.share-detail-row {
  display: grid;
  gap: 6px;
  padding: 12px 14px;
  border-radius: 16px;
  background: rgba(248, 250, 252, 0.96);
}

.share-detail-row span {
  color: #74839a;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.share-detail-row strong {
  color: var(--share-text);
  font-size: 14px;
  line-height: 1.6;
  word-break: break-word;
}

.share-info-empty,
.share-action-list {
  padding: 18px 20px 20px;
}

.share-action-list {
  display: grid;
  gap: 10px;
}

@media (max-width: 1180px) {
  .share-hero,
  .share-portal,
  .share-stage-grid {
    grid-template-columns: 1fr;
  }

  .share-sidebar {
    position: static;
    max-height: none;
  }

  .share-stage {
    min-height: auto;
  }

  .share-stage-placeholder {
    min-height: 360px;
  }

  .share-preview-card,
  .share-preview-empty,
  .share-folder-overview,
  .share-preview-frame,
  .share-preview-image,
  .share-preview-iframe,
  .share-preview-media,
  .share-preview-text {
    min-height: 380px;
  }
}

@media (max-width: 768px) {
  .share-page {
    padding: 14px 10px 22px;
  }

  .share-hero-copy,
  .share-hero-panel,
  .share-sidebar,
  .share-stage {
    border-radius: 24px;
  }

  .share-hero-copy,
  .share-hero-panel,
  .share-sidebar,
  .share-stage {
    padding-left: 16px;
    padding-right: 16px;
  }

  .share-hero-copy {
    padding-top: 24px;
    padding-bottom: 22px;
  }

  .share-hero-panel {
    padding-top: 20px;
    padding-bottom: 20px;
  }

  .share-sidebar {
    gap: 14px;
    padding-top: 16px;
    padding-bottom: 16px;
  }

  .share-stage {
    padding-top: 18px;
    padding-bottom: 18px;
  }

  .share-title {
    font-size: 34px;
  }

  .share-stage-title {
    font-size: 28px;
  }

  .share-stage-header,
  .share-list-head,
  .share-panel-head {
    flex-direction: column;
    align-items: flex-start;
  }

  .share-item-card {
    grid-template-columns: 52px minmax(0, 1fr);
  }

  .share-item-actions {
    grid-column: 2;
    justify-items: start;
  }

  .share-preview-card,
  .share-preview-empty,
  .share-folder-overview,
  .share-preview-frame,
  .share-preview-image,
  .share-preview-iframe,
  .share-preview-media,
  .share-preview-text {
    min-height: 300px;
  }

  .share-preview-card {
    overflow: hidden;
  }

  .share-mobile-close {
    position: fixed;
    right: 14px;
    bottom: calc(16px + env(safe-area-inset-bottom, 0px));
    z-index: 12;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 102px;
    height: 42px;
    padding: 0 16px;
    border: 0;
    border-radius: 999px;
    background: rgba(15, 23, 42, 0.78);
    color: #fff;
    font-size: 13px;
    font-weight: 700;
    box-shadow: 0 12px 30px rgba(15, 23, 42, 0.24);
    backdrop-filter: blur(10px);
  }

  .share-preview-frame {
    min-height: calc(100dvh - 320px);
    padding: 10px;
  }

  .share-preview-frame.document {
    padding: 0;
    background: #e2e8f0;
  }

  .share-preview-pdf-modebar {
    padding: 10px;
  }

  .share-preview-pdf-hint {
    font-size: 11px;
  }

  .share-preview-pdf-pages {
    padding: 10px 10px 14px;
  }

  .share-preview-frame.image {
    padding: 8px;
    background: #f1f5f9;
    overflow: auto;
    position: relative;
  }

  .share-touch-tools {
    position: absolute;
    top: 8px;
    left: 8px;
    right: 8px;
    z-index: 2;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    padding: 8px 10px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.92);
    backdrop-filter: blur(10px);
    box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08);
  }

  .share-touch-tip {
    color: #475569;
    font-size: 11px;
    font-weight: 600;
  }

  .share-touch-reset {
    border: 0;
    background: transparent;
    color: #2563eb;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
  }

  .share-touch-reset:disabled {
    opacity: 0.4;
    cursor: default;
  }

  .share-preview-touch-wrap {
    display: flex;
    width: 100%;
    min-height: calc(100dvh - 340px);
    align-items: center;
    justify-content: center;
    overflow: hidden;
    touch-action: none;
  }

  .share-preview-image,
  .share-preview-iframe,
  .share-preview-media,
  .share-preview-text {
    min-height: calc(100dvh - 340px);
    border-radius: 16px;
  }

  .share-preview-image {
    width: auto;
    max-width: 100%;
    height: auto;
    margin: 0 auto;
    background: #fff;
    transform-origin: center center;
    touch-action: none;
    user-select: none;
    -webkit-user-drag: none;
  }

  .share-preview-iframe,
  .share-preview-media {
    height: calc(100dvh - 340px);
  }

  .share-preview-text {
    padding: 14px;
  }
}
</style>
