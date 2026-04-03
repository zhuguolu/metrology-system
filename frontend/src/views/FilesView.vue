<template>
  <div class="files-page">
    <div v-if="isDragOver" class="page-drag-overlay">
      <div class="page-drag-overlay-card">
        <div class="page-drag-overlay-title">松开即可上传到当前目录</div>
        <div class="page-drag-overlay-desc">当前目录：{{ currentFolderLabel }}</div>
      </div>
    </div>

    <div class="toolbar file-toolbar">
      <div class="toolbar-left file-toolbar-left">
        <div class="file-nav-actions">
          <el-button size="default" class="file-nav-btn file-home-btn" @click="goToRoot">
            文件首页
          </el-button>
          <el-button size="default" class="file-nav-btn" :disabled="!canGoParent" @click="goToParent">
            返回上层
          </el-button>
        </div>
        <div class="file-breadcrumb-wrap">
          <div v-if="breadcrumbs.length" class="file-breadcrumb-list">
            <template v-for="(crumb, index) in breadcrumbs" :key="crumb.id">
              <button
                type="button"
                class="file-crumb-btn"
                :class="{ active: index === breadcrumbs.length - 1 }"
                :disabled="index === breadcrumbs.length - 1"
                @click="openFolder(crumb.id)"
              >
                {{ crumb.name }}
              </button>
              <span v-if="index !== breadcrumbs.length - 1" class="file-crumb-separator">/</span>
            </template>
          </div>
        </div>
      </div>
      <div class="toolbar-right file-toolbar-right">
        <div class="file-search-row">
          <el-input
            v-model="searchQuery"
            placeholder="搜索当前文件夹"
            clearable
            size="default"
            class="file-search"
            @input="onSearchInput"
            @clear="clearSearch"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>
        <div v-if="showWriteActions" class="file-action-grid">
          <el-button type="primary" size="default" @click="triggerUpload">
            <el-icon><Upload /></el-icon> 上传文件
          </el-button>
          <el-button size="default" @click="openCreateFolder">
            <el-icon><FolderAdd /></el-icon> 新建文件夹
          </el-button>
          <el-button size="default" :loading="scanSyncLoading" @click="handleScanSync">
            扫描同步
          </el-button>
          <el-button size="default" :type="selectionMode ? 'primary' : 'default'" @click="toggleSelectionMode">
            {{ selectionMode ? '完成多选' : '多选' }}
          </el-button>
        </div>
        <div class="file-toolbar-tail">
          <button type="button" class="view-switch" @click="toggleViewMode">
            <span class="view-switch-current">{{ viewMode === 'grid' ? '图标' : '列表' }}</span>
            <span class="view-switch-arrow">↹</span>
            <span class="view-switch-next">{{ viewMode === 'grid' ? '切换到列表' : '切换到图标' }}</span>
          </button>
        </div>
        <input ref="uploadRef" type="file" multiple style="display:none" @change="handleUpload" />
      </div>
    </div>

    <div v-if="currentFolderAccess.readOnly" class="files-access-note">
      当前目录为只读授权目录，仅支持查看和下载。
    </div>

    <div v-if="uploadTasks.length" class="upload-board">
      <div class="upload-board-header">
        <div>
          <div class="upload-board-title">上传进度</div>
          <div class="upload-board-subtitle">{{ uploadSummary }}</div>
        </div>
        <button v-if="hasFinishedUploads" class="upload-board-clear" @click="clearFinishedUploads">清除已完成</button>
      </div>

      <div class="upload-overall">
        <div class="upload-overall-meta">
          <span>批量总进度</span>
          <strong>{{ totalUploadProgress }}%</strong>
        </div>
        <div class="upload-overall-bar">
          <div class="upload-overall-bar-fill" :style="{ width: `${totalUploadProgress}%` }"></div>
        </div>
      </div>

      <div class="upload-task-list">
        <div v-for="task in uploadTasks" :key="task.id" class="upload-task" :class="{ fading: task.fading }">
          <div class="upload-task-main">
            <div class="upload-task-name" :title="task.name">{{ task.name }}</div>
            <div class="upload-task-meta">
              <span>{{ formatSize(task.size) }}</span>
              <span>{{ uploadStatusText(task.status, task.progress) }}</span>
            </div>
          </div>
          <div class="upload-task-bar">
            <div class="upload-task-bar-fill" :class="task.status.toLowerCase()" :style="{ width: `${task.progress}%` }"></div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="showWriteActions && selectionMode && selectedIds.length" class="selection-toolbar">
      <div class="selection-toolbar-copy">
        已选 <strong>{{ selectedIds.length }}</strong> 项
      </div>
      <div class="selection-toolbar-actions">
        <button type="button" class="selection-toolbar-btn" @click="clearSelection">清空</button>
        <button type="button" class="selection-toolbar-btn danger" @click="openDeleteConfirmForSelection">删除已选</button>
      </div>
    </div>

    <div v-if="loading" class="files-state">
      <el-icon class="is-loading" size="32"><Loading /></el-icon>
      <div class="files-state-text">加载中...</div>
    </div>

    <div v-else-if="displayItems.length === 0" class="files-state empty">
      <el-icon size="56" color="#cbd5e1"><FolderOpened /></el-icon>
      <div class="files-state-title">{{ searchQuery ? '没有找到匹配文件' : '当前文件夹为空' }}</div>
      <div class="files-state-text">{{ searchQuery ? '换个关键字试试' : '可以拖拽上传文件或新建文件夹' }}</div>
    </div>

    <div
      v-else
      ref="gridWrapRef"
      class="files-grid-wrap"
      @mousedown.left="onSelectionStart"
    >
      <div
        v-if="selectionBox.visible"
        class="selection-box"
        :style="selectionBoxStyle"
      ></div>

      <div v-if="viewMode === 'list'" class="files-list-head">
        <div class="files-list-head-spacer" aria-hidden="true"></div>
        <div class="files-list-head-gap" aria-hidden="true"></div>
        <div>名称</div>
        <div>类型</div>
        <div>大小</div>
        <div>创建时间</div>
      </div>

      <div class="files-grid" :class="`${viewMode}-mode`">
      <div
        v-for="item in displayItems"
        :key="item.id"
        class="file-item"
        :class="{ selected: isSelected(item.id), 'drop-target': dragTargetFolderId === item.id }"
        :data-file-id="item.id"
        :draggable="canDragItem(item)"
        @dblclick="isFolder(item) ? openFolder(item.id) : handlePrimaryAction(item)"
        @click.stop="handleItemClick(item)"
        @contextmenu.prevent.stop="openContextMenu($event, item)"
        @touchstart.passive="onItemTouchStart($event, item)"
        @touchmove.passive="onItemTouchMove"
        @touchend="onItemTouchEnd"
        @touchcancel="onItemTouchEnd"
        @dragstart="onItemDragStart($event, item)"
        @dragend="onItemDragEnd"
        @dragenter.prevent="onFolderDragEnter($event, item)"
        @dragover.prevent="onFolderDragOver($event, item)"
        @dragleave.prevent="onFolderDragLeave($event, item)"
        @drop.prevent="onFolderDrop($event, item)"
      >
        <div class="file-thumb" @click.stop="handleItemPrimary(item)">
          <span v-if="isSharedFolder(item)" class="file-share-badge">分享</span>
          <img
            v-if="showImageCover(item)"
            :src="publicFileUrl(item)"
            :alt="item.name"
            class="file-cover-image"
            loading="lazy"
            @error="markThumbError(item.id)"
          />
          <div
            v-else
            :class="[
              'file-thumb-fallback',
              `tone-${fileTone(item)}`,
              isFolder(item) ? 'folder' : 'document'
            ]"
          >
            <span class="file-thumb-glyph">{{ fileGlyph(item) }}</span>
            <span class="file-thumb-ext">{{ fileExtLabel(item) }}</span>
          </div>
        </div>

        <div class="file-info">
          <div class="file-primary">
            <div
              class="file-name"
              :class="{ 'is-clickable': !isFolder(item) }"
              :title="item.name"
              @click.stop="handleItemPrimary(item)"
            >
              {{ item.name }}
            </div>

            <div v-if="viewMode !== 'list' && !isFolder(item)" class="file-meta">
              {{ formatSize(fileSize(item)) }}
            </div>
          </div>

          <template v-if="viewMode === 'list'">
            <div class="file-list-meta">{{ fileTypeLabel(item) }}</div>
            <div class="file-list-meta">{{ isFolder(item) ? '-' : formatSize(fileSize(item)) }}</div>
            <div class="file-list-meta">{{ formatFileTime(item) }}</div>
          </template>
        </div>
      </div>
    </div>
    </div>

    <div
      v-if="contextMenu.visible"
      class="file-context-backdrop"
      @click="closeContextMenu"
      @contextmenu.prevent="closeContextMenu"
    ></div>
    <div
      v-if="contextMenu.visible && contextMenu.item"
      class="file-context-menu"
      :style="contextMenuStyle"
      @click.stop
    >
      <button type="button" class="file-context-item" @click="handleContextAction('open')">
        {{ isFolder(contextMenu.item) ? '打开' : (isOfficePreviewable(contextMenu.item) ? '在线预览' : '预览') }}
      </button>
      <button
        v-if="!isFolder(contextMenu.item)"
        type="button"
        class="file-context-item"
        @click="handleContextAction('download')"
      >
        下载
      </button>
      <button v-if="!isItemReadOnly(contextMenu.item)" type="button" class="file-context-item" @click="handleContextAction('move')">
        {{ contextMoveLabel }}
      </button>
      <button
        v-if="isFolder(contextMenu.item) && !isItemReadOnly(contextMenu.item)"
        type="button"
        class="file-context-item"
        @click="handleContextAction('share')"
      >
        外链分享
      </button>
      <button v-if="!isItemReadOnly(contextMenu.item)" type="button" class="file-context-item" @click="handleContextAction('rename')">重命名</button>
      <button v-if="!isItemReadOnly(contextMenu.item)" type="button" class="file-context-item danger" @click="handleContextAction('delete')">
        {{ contextDeleteLabel }}
      </button>
    </div>

    <el-dialog
      v-model="showMoveDialog"
      width="min(460px, 92vw)"
      :close-on-click-modal="false"
      align-center
      class="move-dialog"
    >
      <div class="move-card">
        <div class="move-icon">→</div>
        <div class="move-title">选择目标文件夹</div>
        <div class="move-desc">{{ moveDialogText }}</div>
        <div class="move-folder-list" v-loading="moveDialogLoading">
          <button
            v-for="option in moveFolderOptions"
            :key="option.id"
            type="button"
            class="move-folder-item"
            :class="{ active: moveTargetId === option.id, disabled: option.disabled }"
            :style="{ paddingLeft: `${16 + option.depth * 18}px` }"
            :disabled="option.disabled"
            @click="selectMoveTarget(option)"
          >
            <span class="move-folder-name">{{ option.name }}</span>
            <span v-if="option.id === MOVE_ROOT_ID" class="move-folder-badge">根目录</span>
          </button>
        </div>
      </div>
      <template #footer>
        <el-button @click="showMoveDialog = false">取消</el-button>
        <el-button type="primary" :disabled="!moveTargetId" :loading="moveConfirmLoading" @click="confirmMoveAction">
          移动
        </el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showShareDialog"
      width="min(520px, 94vw)"
      :close-on-click-modal="false"
      align-center
      class="share-dialog"
    >
      <div class="share-card-panel" v-loading="shareLoading">
        <div class="share-card-icon">↗</div>
        <div class="share-card-title">文件夹外链分享</div>
        <div class="share-card-desc">
          {{ shareFolder?.name ? `为“${shareFolder.name}”生成公开访问链接。` : '生成一个无需登录即可访问的分享链接。' }}
        </div>

        <div class="share-form">
          <div class="share-link-box">
            <div class="share-link-label">分享链接</div>
            <div class="share-link-row">
              <el-input :model-value="shareLink" readonly placeholder="保存后生成分享链接" />
              <el-button :disabled="!shareLink" @click="copyShareLink">复制</el-button>
            </div>
          </div>

          <div v-if="authStore.isAdmin" class="share-field">
            <label class="form-label">链接后缀</label>
            <el-input
              v-model="shareTokenDraft"
              maxlength="64"
              placeholder="可自定义，例如 manuals_2026"
            />
            <div class="share-field-hint">仅管理员可设置。支持字母、数字、中划线和下划线，长度 4-64。</div>
          </div>

          <div class="share-option-row">
            <span>允许下载文件</span>
            <el-switch v-model="shareAllowDownload" />
          </div>

          <div class="share-field">
            <label class="form-label">失效时间</label>
            <el-date-picker
              v-model="shareExpiresAt"
              type="datetime"
              value-format="YYYY-MM-DDTHH:mm:ss"
              placeholder="不设置则长期有效"
              clearable
              style="width: 100%"
            />
          </div>

          <div class="share-option-row">
            <span>访问密码</span>
            <el-switch v-model="sharePasswordProtected" />
          </div>

          <div v-if="sharePasswordProtected" class="share-field">
            <label class="form-label">{{ shareHasPassword ? '设置新密码' : '访问密码' }}</label>
            <el-input
              v-model="sharePasswordValue"
              type="password"
              show-password
              maxlength="64"
              :placeholder="shareHasPassword ? '留空则保留当前密码' : '请输入访问密码'"
            />
          </div>
        </div>
      </div>
      <template #footer>
        <div class="share-dialog-footer">
          <el-button v-if="shareLink" type="danger" plain :loading="shareDisabling" @click="disableShareAction">
            关闭分享
          </el-button>
          <el-button @click="showShareDialog = false">取消</el-button>
          <el-button type="primary" :loading="shareSaving" @click="saveShareAction">保存分享</el-button>
        </div>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showDeleteConfirmDialog"
      width="min(420px, 92vw)"
      :close-on-click-modal="false"
      align-center
      class="delete-confirm-dialog"
    >
      <div class="delete-confirm-card">
        <div class="delete-confirm-icon">!</div>
        <div class="delete-confirm-title">确认删除</div>
        <div class="delete-confirm-desc">{{ deleteConfirmText }}</div>
      </div>
      <template #footer>
        <el-button @click="showDeleteConfirmDialog = false">取消</el-button>
        <el-button type="danger" :loading="deleteConfirmLoading" @click="confirmDeleteAction">删除</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showCreateFolderDialog"
      title="新建文件夹"
      width="400px"
      :close-on-click-modal="false"
    >
      <div class="form-group">
        <label class="form-label required">文件夹名称</label>
        <el-input
          v-model="newFolderName"
          placeholder="请输入文件夹名称"
          maxlength="100"
          show-word-limit
          @keyup.enter="createFolder"
          autofocus
        />
      </div>
      <template #footer>
        <el-button @click="showCreateFolderDialog = false">取消</el-button>
        <el-button type="primary" :loading="createFolderLoading" @click="createFolder">创建</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showRenameDialog"
      title="重命名"
      width="400px"
      :close-on-click-modal="false"
    >
      <div class="form-group">
        <label class="form-label required">新名称</label>
        <el-input
          v-model="renameValue"
          placeholder="请输入新名称"
          maxlength="200"
          @keyup.enter="doRename"
        />
      </div>
      <template #footer>
        <el-button @click="showRenameDialog = false">取消</el-button>
        <el-button type="primary" :loading="renameLoading" @click="doRename">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog
      v-model="showPreviewDialog"
      :title="previewItem?.name || '文件预览'"
      width="min(960px, 92vw)"
      :top="isMobilePreview ? '0' : '5vh'"
      :fullscreen="isMobilePreview"
      destroy-on-close
      @closed="closePreview"
      class="file-preview-dialog"
    >
      <div class="file-preview-wrap" v-loading="previewLoading">
        <button
          v-if="isMobilePreview"
          type="button"
          class="file-preview-mobile-close"
          aria-label="关闭预览"
          @click="closePreview"
        >
          ×
        </button>
        <div v-if="previewItem" class="file-preview-meta">
          <span>{{ previewItem.name }}</span>
          <span>{{ formatSize(fileSize(previewItem)) }}</span>
          <span>{{ previewTypeLabel }}</span>
        </div>

        <div v-if="previewError" class="file-preview-empty">
          {{ previewError }}
        </div>

        <div v-else-if="previewType === 'image'" class="file-preview-body image">
          <div class="file-preview-touch-tools">
            <span class="file-preview-touch-tip">双指缩放，单指拖动</span>
            <el-button size="small" text :disabled="!previewZoom.isZoomed" @click="previewZoom.reset">重置</el-button>
          </div>
          <div
            ref="previewTouchWrapRef"
            class="file-preview-touch-wrap"
            @touchstart.passive="previewZoom.onTouchStart"
            @touchmove="previewZoom.onTouchMove"
            @touchend="previewZoom.onTouchEnd"
            @touchcancel="previewZoom.onTouchEnd"
          >
            <img
              ref="previewTouchImageRef"
              :src="previewUrl"
              :alt="previewItem?.name || '预览图片'"
              class="file-preview-image"
              :style="previewZoom.transformStyle"
              @load="previewZoom.reset"
            />
          </div>
        </div>

        <div v-else-if="previewType === 'pdf'" class="file-preview-body document">
          <template v-if="isMobilePreview">
            <div class="file-preview-pdf-stack">
              <div class="file-preview-pdf-modebar">
                <span class="file-preview-pdf-badge">图片模式</span>
                <span class="file-preview-pdf-hint">上下滚动查看整份 PDF</span>
              </div>
              <div v-if="pdfPageImages.length" class="file-preview-pdf-pages">
                <div v-for="page in pdfPageImages" :key="page.pageNumber" class="file-preview-pdf-page">
                  <img
                    :src="page.url"
                    :alt="`${previewItem?.name || 'PDF'} 第 ${page.pageNumber} 页`"
                    class="file-preview-pdf-image"
                  />
                </div>
              </div>
              <div v-else-if="!previewLoading" class="file-preview-empty pdf-image-empty">
                当前 PDF 暂时无法渲染为图片，请直接下载查看。
              </div>
            </div>
          </template>
          <iframe v-else :src="previewUrl" class="file-preview-frame"></iframe>
        </div>

        <div v-else-if="previewType === 'video'" class="file-preview-body media">
          <video :src="previewUrl" class="file-preview-video" controls preload="metadata"></video>
        </div>

        <div v-else-if="previewType === 'audio'" class="file-preview-body media audio">
          <audio :src="previewUrl" controls class="file-preview-audio"></audio>
        </div>

        <div v-else-if="previewType === 'text'" class="file-preview-body text">
          <pre class="file-preview-text">{{ previewText }}</pre>
        </div>

        <div v-else-if="!previewLoading" class="file-preview-empty">
          当前类型暂不支持在线预览，请直接下载查看。
        </div>
      </div>
      <template #footer>
        <el-button @click="closePreview">关闭</el-button>
        <el-button v-if="previewItem" type="primary" @click="downloadFile(previewItem)">下载文件</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, inject, onBeforeUnmount, onMounted, ref } from 'vue'
import { GlobalWorkerOptions, getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs'
import pdfWorkerUrl from 'pdfjs-dist/legacy/build/pdf.worker.min.mjs?url'
import { fileApi } from '../api/index.js'
import { usePinchZoom } from '../composables/usePinchZoom.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useAuthStore } from '../stores/auth.js'

const showToast = inject('showToast')
const authStore = useAuthStore()

const loading = ref(false)
const items = ref([])
const breadcrumbs = ref([])
const currentFolderId = ref(null)
const currentFolderAccess = ref({ readOnly: false, canWrite: authStore.canAccessFiles })
const uploadRef = ref(null)
const gridWrapRef = ref(null)

const searchQuery = ref('')
const searchResults = ref([])
const isSearching = ref(false)
const selectionMode = ref(false)
const selectedIds = ref([])
const viewMode = ref(getInitialViewMode())

const showCreateFolderDialog = ref(false)
const newFolderName = ref('')
const createFolderLoading = ref(false)
const scanSyncLoading = ref(false)

const MOVE_ROOT_ID = '__root__'
const showMoveDialog = ref(false)
const moveDialogLoading = ref(false)
const moveConfirmLoading = ref(false)
const moveSourceMode = ref('single')
const moveSourceItem = ref(null)
const moveSourceIds = ref([])
const moveFolderOptions = ref([])
const moveTargetId = ref('')

const showDeleteConfirmDialog = ref(false)
const deleteConfirmLoading = ref(false)
const deleteConfirmMode = ref('single')
const deleteConfirmItem = ref(null)
const deleteConfirmIds = ref([])

const showRenameDialog = ref(false)
const renameItem = ref(null)
const renameValue = ref('')
const renameLoading = ref(false)

const showShareDialog = ref(false)
const shareLoading = ref(false)
const shareSaving = ref(false)
const shareDisabling = ref(false)
const shareFolder = ref(null)
const shareTokenValue = ref('')
const shareTokenDraft = ref('')
const shareHasPassword = ref(false)
const shareAllowDownload = ref(true)
const shareExpiresAt = ref('')
const sharePasswordProtected = ref(false)
const sharePasswordValue = ref('')

const showPreviewDialog = ref(false)
const previewItem = ref(null)
const previewLoading = ref(false)
const previewType = ref('')
const previewUrl = ref('')
const previewText = ref('')
const previewError = ref('')
const isMobilePreview = ref(false)
const pdfPageImages = ref([])
const uploadTasks = ref([])
const isDragOver = ref(false)
const thumbErrors = ref({})
const draggingItemId = ref(null)
const dragTargetFolderId = ref(null)
const contextMenu = ref({
  visible: false,
  x: 0,
  y: 0,
  item: null,
})
const selectionBox = ref({
  active: false,
  visible: false,
  append: false,
  startX: 0,
  startY: 0,
  currentX: 0,
  currentY: 0,
})

let searchTimer = null
let activePreviewUrl = ''
let previewAbortController = null
let previewRequestToken = 0
let activePdfRenderToken = 0
let activePdfDocument = null
let dragCounter = 0
let longPressTimer = null
let longPressTouch = null
let suppressPointerUntil = 0
const uploadCleanupTimers = new Map()
const TEXT_PREVIEW_LIMIT = 2 * 1024 * 1024
const previewZoom = usePinchZoom()
const previewTouchWrapRef = previewZoom.containerRef
const previewTouchImageRef = previewZoom.contentRef

GlobalWorkerOptions.workerSrc = pdfWorkerUrl

const displayItems = computed(() => (isSearching.value ? searchResults.value : items.value))
const currentFolderLabel = computed(() => breadcrumbs.value.at(-1)?.name || '根目录')
const canWriteCurrentFolder = computed(() => !!currentFolderAccess.value?.canWrite)
const showWriteActions = computed(() => canWriteCurrentFolder.value && !isSearching.value)
const canGoParent = computed(() => currentFolderId.value != null)
const parentFolderId = computed(() => {
  if (currentFolderId.value == null) return null
  if (breadcrumbs.value.length <= 1) return null
  return breadcrumbs.value[breadcrumbs.value.length - 2]?.id ?? null
})
const hasFinishedUploads = computed(() => uploadTasks.value.some(task => task.status === 'DONE' || task.status === 'ERROR'))
const selectionBoxStyle = computed(() => {
  if (!selectionBox.value.visible || !gridWrapRef.value) return {}
  const rect = gridWrapRef.value.getBoundingClientRect()
  const left = Math.min(selectionBox.value.startX, selectionBox.value.currentX) - rect.left
  const top = Math.min(selectionBox.value.startY, selectionBox.value.currentY) - rect.top
  const width = Math.abs(selectionBox.value.currentX - selectionBox.value.startX)
  const height = Math.abs(selectionBox.value.currentY - selectionBox.value.startY)
  return {
    left: `${left}px`,
    top: `${top}px`,
    width: `${width}px`,
    height: `${height}px`,
  }
})
const contextMenuStyle = computed(() => ({
  left: `${contextMenu.value.x}px`,
  top: `${contextMenu.value.y}px`,
}))
const shareLink = computed(() => {
  if (!shareTokenValue.value || typeof window === 'undefined') return ''
  return `${window.location.origin}/share/${shareTokenValue.value}`
})
const totalUploadProgress = computed(() => {
  if (!uploadTasks.value.length) return 0
  const totalBytes = uploadTasks.value.reduce((sum, task) => sum + Math.max(task.size || 0, 1), 0)
  if (!totalBytes) return 0
  const uploadedBytes = uploadTasks.value.reduce((sum, task) => {
    const size = Math.max(task.size || 0, 1)
    const ratio = Math.min(1, Math.max(0, (task.progress || 0) / 100))
    return sum + size * ratio
  }, 0)
  return Math.min(100, Math.round((uploadedBytes / totalBytes) * 100))
})
const uploadSummary = computed(() => {
  const total = uploadTasks.value.length
  const uploading = uploadTasks.value.filter(task => task.status === 'UPLOADING').length
  const done = uploadTasks.value.filter(task => task.status === 'DONE').length
  const failed = uploadTasks.value.filter(task => task.status === 'ERROR').length
  return `共 ${total} 个，上传中 ${uploading} 个，完成 ${done} 个，失败 ${failed} 个，总进度 ${totalUploadProgress.value}%`
})
const previewTypeLabel = computed(() => {
  const labels = {
    image: '图片预览',
    pdf: 'PDF 预览',
    video: '视频预览',
    audio: '音频预览',
    text: '文本预览',
    unsupported: '暂不支持预览',
  }
  return labels[previewType.value] || '文件预览'
})

function syncMobilePreviewState() {
  if (typeof window === 'undefined') return
  isMobilePreview.value = window.innerWidth <= 768
}
const contextDeleteLabel = computed(() => {
  if (!contextMenu.value.item) return '删除'
  return selectedIds.value.length > 1 && selectedIds.value.includes(contextMenu.value.item.id) ? '删除已选' : '删除'
})
const contextMoveLabel = computed(() => {
  if (!contextMenu.value.item) return '移动'
  return selectedIds.value.length > 1 && selectedIds.value.includes(contextMenu.value.item.id) ? '移动已选' : '移动'
})
const moveDialogText = computed(() => {
  if (moveSourceMode.value === 'batch') {
    return `请选择目标文件夹，当前将移动 ${moveSourceIds.value.length} 项。`
  }
  const name = moveSourceItem.value?.name || '该项'
  return `请选择“${name}”要移动到的目标文件夹。`
})
const deleteConfirmText = computed(() => {
  if (deleteConfirmMode.value === 'batch') {
    return `确定要删除已选中的 ${deleteConfirmIds.value.length} 项吗？删除后将无法恢复。`
  }
  const name = deleteConfirmItem.value?.name || '该项'
  return `确定要删除“${name}”吗？删除后将无法恢复。`
})

function isFolder(item) {
  return item?.isFolder === true || item?.type === 'FOLDER'
}

function isSharedFolder(item) {
  return isFolder(item) && item?.shareEnabled === true
}

function getInitialViewMode() {
  if (typeof window === 'undefined') return 'grid'
  const stored = window.localStorage.getItem('files-view-mode')
  return stored === 'list' ? 'list' : 'grid'
}

function setViewMode(mode) {
  viewMode.value = mode === 'list' ? 'list' : 'grid'
  if (typeof window !== 'undefined') {
    window.localStorage.setItem('files-view-mode', viewMode.value)
  }
}

function toggleViewMode() {
  setViewMode(viewMode.value === 'grid' ? 'list' : 'grid')
}

function toggleSelectionMode() {
  selectionMode.value = !selectionMode.value
  if (!selectionMode.value) {
    clearSelection()
  }
}

function fileSize(item) {
  return item?.size ?? item?.fileSize ?? 0
}

function fileTypeLabel(item) {
  if (isFolder(item)) return '文件夹'
  const ext = getFileExt(item?.name)
  if (!ext) return '文件'
  return `${ext.toUpperCase()} 文件`
}

function formatFileTime(item) {
  const value = item?.createdAt || item?.created_at || item?.createdTime
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '-'
  const pad = n => String(n).padStart(2, '0')
  return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`
}

async function collectMoveFolderOptions(parentId = null, depth = 0, visited = new Set()) {
  const res = await fileApi.list(parentId)
  const folders = extractListItems(res.data).filter(item => isFolder(item) && !isItemReadOnly(item))
  const options = []

  for (const folder of folders) {
    if (visited.has(folder.id)) continue
    visited.add(folder.id)
    options.push({
      id: folder.id,
      name: folder.name,
      depth,
      disabled: moveSourceIds.value.includes(folder.id),
    })
    const children = await collectMoveFolderOptions(folder.id, depth + 1, visited)
    options.push(...children)
  }

  return options
}

async function loadMoveFolderOptions() {
  moveDialogLoading.value = true
  try {
    const children = await collectMoveFolderOptions()
    moveFolderOptions.value = [
      { id: MOVE_ROOT_ID, name: '根目录', depth: 0, disabled: false },
      ...children,
    ]
  } catch {
    moveFolderOptions.value = [{ id: MOVE_ROOT_ID, name: '根目录', depth: 0, disabled: false }]
    showToast('加载文件夹列表失败', 'error')
  } finally {
    moveDialogLoading.value = false
  }
}

async function loadFiles(folderId = null) {
  loading.value = true
  try {
    const res = await fileApi.list(folderId)
    items.value = extractListItems(res.data)
    currentFolderAccess.value = extractListAccess(res.data)
    if (!isSearching.value) {
      pruneSelection(items.value)
    }
  } catch {
    showToast('加载文件列表失败', 'error')
  } finally {
    loading.value = false
  }
}

async function loadBreadcrumb(folderId) {
  if (!folderId) {
    breadcrumbs.value = []
    return
  }
  try {
    const res = await fileApi.breadcrumb(folderId)
    breadcrumbs.value = res.data || []
  } catch {
    breadcrumbs.value = []
  }
}

function goToRoot() {
  currentFolderId.value = null
  breadcrumbs.value = []
  isSearching.value = false
  searchQuery.value = ''
  searchResults.value = []
  clearSelection()
  loadFiles(null)
}

function goToParent() {
  if (currentFolderId.value == null) return
  if (parentFolderId.value == null) {
    goToRoot()
    return
  }
  openFolder(parentFolderId.value)
}

function openFolder(id) {
  currentFolderId.value = id
  isSearching.value = false
  searchQuery.value = ''
  searchResults.value = []
  clearSelection()
  loadFiles(id)
  loadBreadcrumb(id)
}

function onSearchInput(val) {
  if (searchTimer) clearTimeout(searchTimer)
  if (!val || !val.trim()) {
    clearSearch()
    return
  }
  searchTimer = setTimeout(() => doSearch(val.trim()), 300)
}

function filterItemsByQuery(sourceItems, q) {
  const keyword = String(q || '').trim().toLowerCase()
  if (!keyword) return []
  return (sourceItems || []).filter(item => String(item?.name || '').toLowerCase().includes(keyword))
}

function doSearch(q) {
  isSearching.value = true
  clearSelection()
  searchResults.value = filterItemsByQuery(items.value, q)
  pruneSelection(searchResults.value)
}

function clearSearch() {
  if (searchTimer) clearTimeout(searchTimer)
  isSearching.value = false
  searchResults.value = []
  clearSelection()
  pruneSelection(items.value)
}

function extractListItems(payload) {
  if (Array.isArray(payload)) return payload
  return payload?.items || []
}

function extractListAccess(payload) {
  if (Array.isArray(payload)) {
    return { readOnly: false, canWrite: authStore.canAccessFiles }
  }
  return {
    readOnly: !!payload?.access?.readOnly,
    canWrite: payload?.access?.canWrite !== false,
  }
}

function isItemReadOnly(item) {
  return item?.readOnly === true
}

async function handleScanSync() {
  scanSyncLoading.value = true
  try {
    const response = await fileApi.scanSync(currentFolderId.value)
    const result = response.data || {}
    const createdFolders = Number(result.foldersCreated || 0)
    const updatedFolders = Number(result.foldersUpdated || 0)
    const createdFiles = Number(result.filesCreated || 0)
    const updatedFiles = Number(result.filesUpdated || 0)
    const deletedFolders = Number(result.foldersDeleted || 0)
    const deletedFiles = Number(result.filesDeleted || 0)
    const unchanged = Number(result.unchanged || 0)
    const conflicts = Number(result.conflicts || 0)

    const summary = [
      createdFolders ? `新增文件夹 ${createdFolders} 个` : '',
      updatedFolders ? `更新文件夹 ${updatedFolders} 个` : '',
      createdFiles ? `新增文件 ${createdFiles} 个` : '',
      updatedFiles ? `更新文件 ${updatedFiles} 个` : '',
      deletedFolders ? `删除文件夹 ${deletedFolders} 个` : '',
      deletedFiles ? `删除文件 ${deletedFiles} 个` : '',
      unchanged ? `未变化 ${unchanged} 项` : '',
      conflicts ? `冲突 ${conflicts} 项` : '',
    ].filter(Boolean).join('，')

    showToast(summary || '扫描完成，当前目录没有需要同步的内容')

    if (isSearching.value && searchQuery.value.trim()) {
      await doSearch(searchQuery.value.trim())
    } else {
      await loadFiles(currentFolderId.value)
    }
    await loadBreadcrumb(currentFolderId.value)
  } catch (e) {
    showToast(e.response?.data?.message || '扫描同步失败', 'error')
  } finally {
    scanSyncLoading.value = false
  }
}

function isSelected(id) {
  return selectedIds.value.includes(id)
}

function toggleSelection(id) {
  const item = displayItems.value.find(entry => entry.id === id)
  if (item && isItemReadOnly(item)) return
  selectedIds.value = isSelected(id)
    ? selectedIds.value.filter(item => item !== id)
    : [...selectedIds.value, id]
}

function pointerActionSuppressed() {
  return Date.now() < suppressPointerUntil
}

function handleItemClick(item) {
  if (pointerActionSuppressed()) return
  closeContextMenu()
  if (selectionMode.value) {
    toggleSelection(item.id)
    return
  }
  handleItemPrimary(item)
}

function handleItemPrimary(item) {
  if (pointerActionSuppressed()) return
  closeContextMenu()
  if (selectionMode.value) {
    toggleSelection(item.id)
    return
  }
  if (isFolder(item)) {
    openFolder(item.id)
    return
  }
  handlePrimaryAction(item)
}

function canDragItem(item) {
  return !pointerActionSuppressed() && !selectionBox.value.active && !!item?.id && !isItemReadOnly(item)
}

function clearSelection() {
  selectedIds.value = []
}

function setSelection(ids) {
  selectedIds.value = Array.from(new Set(ids))
}

function pruneSelection(validItems = displayItems.value) {
  const validIds = new Set((validItems || []).map(item => item.id))
  selectedIds.value = selectedIds.value.filter(id => validIds.has(id))
}

function buildSelectionRect(startX, startY, currentX, currentY) {
  return {
    left: Math.min(startX, currentX),
    right: Math.max(startX, currentX),
    top: Math.min(startY, currentY),
    bottom: Math.max(startY, currentY),
  }
}

function rectIntersects(a, b) {
  return !(a.right < b.left || a.left > b.right || a.bottom < b.top || a.top > b.bottom)
}

function syncSelectionFromBox() {
  if (!gridWrapRef.value) return
  const visibleIdMap = new Map(displayItems.value.map(item => [String(item.id), item.id]))
  const readOnlyIdSet = new Set(displayItems.value.filter(isItemReadOnly).map(item => item.id))
  const rect = buildSelectionRect(
    selectionBox.value.startX,
    selectionBox.value.startY,
    selectionBox.value.currentX,
    selectionBox.value.currentY
  )
  const hitIds = Array.from(gridWrapRef.value.querySelectorAll('.file-item[data-file-id]'))
    .filter(node => {
      const nodeRect = node.getBoundingClientRect()
      return rectIntersects(rect, nodeRect)
    })
    .map(node => visibleIdMap.get(node.dataset.fileId))
    .filter(id => id !== undefined && !readOnlyIdSet.has(id))

  setSelection(selectionBox.value.append ? [...selectedIds.value, ...hitIds] : hitIds)
}

function onSelectionMove(event) {
  if (!selectionBox.value.active) return
  selectionBox.value.currentX = event.clientX
  selectionBox.value.currentY = event.clientY
  const width = Math.abs(selectionBox.value.currentX - selectionBox.value.startX)
  const height = Math.abs(selectionBox.value.currentY - selectionBox.value.startY)
  selectionBox.value.visible = width > 6 || height > 6
  if (selectionBox.value.visible) {
    syncSelectionFromBox()
  }
}

function stopSelectionTracking() {
  window.removeEventListener('mousemove', onSelectionMove)
  window.removeEventListener('mouseup', onSelectionEnd)
}

function onSelectionEnd() {
  if (!selectionBox.value.active) return
  stopSelectionTracking()
  selectionBox.value.active = false
  window.setTimeout(() => {
    selectionBox.value.visible = false
  }, 0)
}

function onSelectionStart(event) {
  if (!selectionMode.value) return
  if (!showWriteActions.value) return
  if (event.button !== 0) return
  if (event.target instanceof Element && event.target.closest('.file-item, .file-context-menu')) return
  if (!gridWrapRef.value) return

  draggingItemId.value = null
  dragTargetFolderId.value = null
  closeContextMenu()
  event.preventDefault()
  selectionBox.value.active = true
  selectionBox.value.visible = false
  selectionBox.value.append = event.ctrlKey || event.metaKey
  selectionBox.value.startX = event.clientX
  selectionBox.value.startY = event.clientY
  selectionBox.value.currentX = event.clientX
  selectionBox.value.currentY = event.clientY

  if (!selectionBox.value.append) {
    clearSelection()
  }

  window.addEventListener('mousemove', onSelectionMove)
  window.addEventListener('mouseup', onSelectionEnd)
}

function onItemDragStart(event, item) {
  if (!canDragItem(item)) {
    event.preventDefault()
    return
  }
  draggingItemId.value = item.id
  dragTargetFolderId.value = null
  closeContextMenu()
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', String(item.id))
  }
}

function onItemDragEnd() {
  draggingItemId.value = null
  dragTargetFolderId.value = null
}

function getDraggedItemIds(sourceId) {
  if (!sourceId) return []
  return selectedIds.value.includes(sourceId) ? [...selectedIds.value] : [sourceId]
}

function canDropIntoFolder(item) {
  if (!draggingItemId.value || !isFolder(item) || isItemReadOnly(item)) return false
  const draggedIds = getDraggedItemIds(draggingItemId.value)
  return draggedIds.length > 0 && !draggedIds.includes(item.id)
}

function onFolderDragEnter(event, item) {
  if (!canDropIntoFolder(item)) return
  event.preventDefault()
  dragTargetFolderId.value = item.id
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move'
  }
}

function onFolderDragOver(event, item) {
  if (!canDropIntoFolder(item)) return
  event.preventDefault()
  dragTargetFolderId.value = item.id
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move'
  }
}

function onFolderDragLeave(event, item) {
  if (dragTargetFolderId.value !== item.id) return
  const currentTarget = event.currentTarget
  const relatedTarget = event.relatedTarget
  if (currentTarget instanceof Element && relatedTarget instanceof Node && currentTarget.contains(relatedTarget)) {
    return
  }
  dragTargetFolderId.value = null
}

async function moveItemsToFolder(itemIds, folderId) {
  if (!itemIds.length) return

  const results = await Promise.allSettled(itemIds.map(id => fileApi.move(id, folderId)))
  const successCount = results.filter(result => result.status === 'fulfilled').length
  const failed = results.filter(result => result.status === 'rejected')
  const failedIds = itemIds.filter((_, index) => results[index]?.status === 'rejected')

  if (successCount > 0) {
    showToast(successCount === 1 ? '已移动到目标文件夹' : `已移动 ${successCount} 项到目标文件夹`)
    selectedIds.value = selectedIds.value.filter(id => !itemIds.includes(id))
    await refreshFilesPage()
  }

  if (failed.length) {
    const firstError = normalizeMoveError(
      failed[0]?.reason?.response?.data?.message || failed[0]?.reason?.message || '移动失败'
    )
    showToast(successCount > 0 ? `有 ${failed.length} 项移动失败：${firstError}` : firstError, 'error')
  }

  return {
    successCount,
    failedCount: failed.length,
    failedIds,
  }
}

function normalizeMoveError(message) {
  if (!message) return '移动失败'
  if (message.includes('same name already exists')) return '目标文件夹中已存在同名文件或文件夹'
  if (message.includes('Target must be a folder')) return '目标位置必须是文件夹'
  if (message.includes('into itself')) return '不能移动到自身'
  if (message.includes('child folder')) return '不能把文件夹移动到它的子文件夹中'
  if (message.includes('File not found')) return '文件不存在'
  if (message.includes('No permission')) return '无权访问该文件'
  return message
}

async function onFolderDrop(event, item) {
  if (!canDropIntoFolder(item)) return
  event.preventDefault()
  const sourceId = draggingItemId.value
  const sourceIds = getDraggedItemIds(sourceId)
  dragTargetFolderId.value = null
  draggingItemId.value = null
  if (!sourceIds.length) return
  await moveItemsToFolder(sourceIds, item.id)
}

async function confirmMoveAction() {
  if (moveConfirmLoading.value || !moveTargetId.value) return
  moveConfirmLoading.value = true
  try {
    const targetParentId = moveTargetId.value === MOVE_ROOT_ID ? null : moveTargetId.value
    await moveItemsToFolder([...moveSourceIds.value], targetParentId)
    showMoveDialog.value = false
  } finally {
    moveConfirmLoading.value = false
  }
}

function clearLongPressState() {
  if (longPressTimer) {
    clearTimeout(longPressTimer)
    longPressTimer = null
  }
  longPressTouch = null
}

function openContextMenuAt(x, y, item) {
  const menuWidth = 168
  const menuHeight = 208
  const maxX = Math.max(12, window.innerWidth - menuWidth - 12)
  const maxY = Math.max(12, window.innerHeight - menuHeight - 12)
  contextMenu.value = {
    visible: true,
    x: Math.min(Math.max(12, x), maxX),
    y: Math.min(Math.max(12, y), maxY),
    item,
  }
}

function openContextMenu(event, item) {
  clearLongPressState()
  if (selectionMode.value && !isSelected(item.id) && !isItemReadOnly(item)) {
    setSelection([item.id])
  }
  openContextMenuAt(event.clientX, event.clientY, item)
}

function closeContextMenu() {
  contextMenu.value = {
    visible: false,
    x: 0,
    y: 0,
    item: null,
  }
}

function onItemTouchStart(event, item) {
  const touch = event.touches?.[0]
  if (!touch) return
  clearLongPressState()
  longPressTouch = {
    x: touch.clientX,
    y: touch.clientY,
    item,
  }
  longPressTimer = window.setTimeout(() => {
    suppressPointerUntil = Date.now() + 750
    if (selectionMode.value && !isSelected(item.id) && !isItemReadOnly(item)) {
      setSelection([item.id])
    }
    openContextMenuAt(touch.clientX, touch.clientY, item)
    clearLongPressState()
  }, 520)
}

function onItemTouchMove(event) {
  if (!longPressTouch) return
  const touch = event.touches?.[0]
  if (!touch) return
  const movedX = Math.abs(touch.clientX - longPressTouch.x)
  const movedY = Math.abs(touch.clientY - longPressTouch.y)
  if (movedX > 10 || movedY > 10) {
    clearLongPressState()
  }
}

function onItemTouchEnd() {
  clearLongPressState()
}

async function handleContextAction(action) {
  const item = contextMenu.value.item
  closeContextMenu()
  if (!item) return

  if (action === 'open') {
    if (isFolder(item)) {
      openFolder(item.id)
    } else {
      handlePrimaryAction(item)
    }
    return
  }
  if (action === 'download') {
    await downloadFile(item)
    return
  }
  if (action === 'move') {
    if (selectedIds.value.length > 1 && selectedIds.value.includes(item.id)) {
      await openMoveDialogForSelection()
    } else {
      await openMoveDialogForItem(item)
    }
    return
  }
  if (action === 'rename') {
    openRename(item)
    return
  }
  if (action === 'share') {
    await openShareDialogForItem(item)
    return
  }
  if (action === 'delete') {
    if (selectedIds.value.length > 1 && selectedIds.value.includes(item.id)) {
      openDeleteConfirmForSelection()
    } else {
      openDeleteConfirmForItem(item)
    }
  }
}

async function openMoveDialogForItem(item) {
  if (!item) return
  moveSourceMode.value = 'single'
  moveSourceItem.value = item
  moveSourceIds.value = [item.id]
  moveTargetId.value = ''
  showMoveDialog.value = true
  await loadMoveFolderOptions()
}

async function openMoveDialogForSelection() {
  if (!selectedIds.value.length) return
  moveSourceMode.value = 'batch'
  moveSourceItem.value = null
  moveSourceIds.value = [...selectedIds.value]
  moveTargetId.value = ''
  showMoveDialog.value = true
  await loadMoveFolderOptions()
}

function selectMoveTarget(option) {
  if (!option || option.disabled) return
  moveTargetId.value = option.id
}

async function openShareDialogForItem(item) {
  if (!item || !isFolder(item)) return
  shareFolder.value = item
  shareTokenValue.value = ''
  shareTokenDraft.value = ''
  shareHasPassword.value = false
  shareAllowDownload.value = true
  shareExpiresAt.value = ''
  sharePasswordProtected.value = false
  sharePasswordValue.value = ''
  showShareDialog.value = true
  shareLoading.value = true
  try {
    const res = await fileApi.getShare(item.id)
    const data = res.data || {}
    shareTokenValue.value = data.enabled ? (data.token || '') : ''
    shareTokenDraft.value = data.token || ''
    shareHasPassword.value = !!data.hasPassword
    shareAllowDownload.value = data.allowDownload !== false
    shareExpiresAt.value = data.expiresAt || ''
    sharePasswordProtected.value = !!data.hasPassword
  } catch (e) {
    showToast(e.response?.data?.message || '加载分享配置失败', 'error')
  } finally {
    shareLoading.value = false
  }
}

async function saveShareAction() {
  if (!shareFolder.value || shareSaving.value) return
  shareSaving.value = true
  try {
    const res = await fileApi.saveShare(shareFolder.value.id, {
      allowDownload: shareAllowDownload.value,
      expiresAt: shareExpiresAt.value || null,
      passwordProtected: sharePasswordProtected.value,
      password: sharePasswordValue.value.trim(),
      ...(authStore.isAdmin ? { shareToken: shareTokenDraft.value.trim() } : {}),
    })
    const data = res.data || {}
    shareTokenValue.value = data.token || ''
    shareTokenDraft.value = data.token || ''
    shareHasPassword.value = !!data.hasPassword
    shareAllowDownload.value = data.allowDownload !== false
    shareExpiresAt.value = data.expiresAt || ''
    sharePasswordProtected.value = !!data.hasPassword
    sharePasswordValue.value = ''
    showToast('分享链接已保存')
  } catch (e) {
    showToast(e.response?.data?.message || '保存分享失败', 'error')
  } finally {
    shareSaving.value = false
  }
}

async function disableShareAction() {
  if (!shareFolder.value || shareDisabling.value) return
  shareDisabling.value = true
  try {
    await fileApi.disableShare(shareFolder.value.id)
    shareTokenValue.value = ''
    shareTokenDraft.value = ''
    shareHasPassword.value = false
    shareAllowDownload.value = true
    shareExpiresAt.value = ''
    sharePasswordProtected.value = false
    sharePasswordValue.value = ''
    showToast('分享已关闭')
  } catch (e) {
    showToast(e.response?.data?.message || '关闭分享失败', 'error')
  } finally {
    shareDisabling.value = false
  }
}

async function copyShareLink() {
  if (!shareLink.value) return
  try {
    if (navigator?.clipboard?.writeText) {
      await navigator.clipboard.writeText(shareLink.value)
    } else {
      const input = document.createElement('input')
      input.value = shareLink.value
      document.body.appendChild(input)
      input.select()
      document.execCommand('copy')
      input.remove()
    }
    showToast('分享链接已复制')
  } catch {
    showToast('复制失败，请手动复制链接', 'error')
  }
}

function openCreateFolder() {
  if (!showWriteActions.value) return
  newFolderName.value = ''
  showCreateFolderDialog.value = true
}

async function createFolder() {
  const name = newFolderName.value.trim()
  if (!name) {
    showToast('请输入文件夹名称', 'error')
    return
  }
  createFolderLoading.value = true
  try {
    await fileApi.createFolder(name, currentFolderId.value)
    showToast('文件夹创建成功')
    showCreateFolderDialog.value = false
    loadFiles(currentFolderId.value)
  } catch (e) {
    showToast(e.response?.data?.message || '创建失败', 'error')
  } finally {
    createFolderLoading.value = false
  }
}

function triggerUpload() {
  if (!showWriteActions.value) return
  uploadRef.value?.click()
}

function hasDraggedFiles(event) {
  const types = event.dataTransfer?.types
  return Array.isArray(types)
    ? types.includes('Files')
    : !!types?.contains?.('Files')
}

function handleUpload(e) {
  const files = Array.from(e.target.files || [])
  if (files.length) uploadFiles(files)
  e.target.value = ''
}

function onDragEnter(event) {
  if (!showWriteActions.value) return
  if (!hasDraggedFiles(event)) return
  event.preventDefault()
  dragCounter += 1
  isDragOver.value = true
}

function onDragOver(event) {
  if (!showWriteActions.value) return
  if (!hasDraggedFiles(event)) return
  event.preventDefault()
  isDragOver.value = true
}

function onDragLeave(event) {
  if (!showWriteActions.value) return
  if (!hasDraggedFiles(event)) return
  event.preventDefault()
  dragCounter = Math.max(0, dragCounter - 1)
  if (dragCounter === 0) isDragOver.value = false
}

function onDrop(event) {
  if (!showWriteActions.value) return
  if (!hasDraggedFiles(event)) return
  event.preventDefault()
  dragCounter = 0
  isDragOver.value = false
  const files = Array.from(event.dataTransfer?.files || [])
  if (files.length) uploadFiles(files)
}

function addUploadTask(file) {
  const task = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    name: file.name,
    size: file.size || 0,
    progress: 0,
    status: 'WAITING',
    fading: false,
  }
  uploadTasks.value = [task, ...uploadTasks.value].slice(0, 12)
  return task.id
}

function clearUploadCleanupTimer(id) {
  const timer = uploadCleanupTimers.get(id)
  if (timer) {
    clearTimeout(timer)
    uploadCleanupTimers.delete(id)
  }
}

function removeUploadTask(id) {
  clearUploadCleanupTimer(id)
  uploadTasks.value = uploadTasks.value.filter(task => task.id !== id)
}

function scheduleUploadTaskFade(id) {
  clearUploadCleanupTimer(id)
  const fadeTimer = window.setTimeout(() => {
    updateUploadTask(id, { fading: true })
    const cleanupTimer = window.setTimeout(() => {
      removeUploadTask(id)
    }, 420)
    uploadCleanupTimers.set(id, cleanupTimer)
  }, 1400)
  uploadCleanupTimers.set(id, fadeTimer)
}

function updateUploadTask(id, patch) {
  const index = uploadTasks.value.findIndex(task => task.id === id)
  if (index === -1) return
  const nextTask = { ...uploadTasks.value[index], ...patch }
  if (patch.status && patch.status !== 'DONE') {
    nextTask.fading = false
  }
  uploadTasks.value[index] = nextTask

  if (patch.status === 'DONE') {
    scheduleUploadTaskFade(id)
  } else if (patch.status && patch.status !== 'DONE') {
    clearUploadCleanupTimer(id)
  }
}

function uploadStatusText(status, progress) {
  if (status === 'WAITING') return '等待上传'
  if (status === 'UPLOADING') return `${progress}%`
  if (status === 'DONE') return '上传成功'
  return '上传失败'
}

async function uploadFiles(files) {
  let successCount = 0
  await Promise.all(files.map(async file => {
    const taskId = addUploadTask(file)
    updateUploadTask(taskId, { status: 'UPLOADING', progress: 0 })
    try {
      await fileApi.upload(file, currentFolderId.value, {
        onUploadProgress: event => {
          const total = event.total || file.size || 1
          const percent = Math.min(100, Math.round((event.loaded / total) * 100))
          updateUploadTask(taskId, { progress: percent, status: 'UPLOADING' })
        },
      })
      successCount += 1
      updateUploadTask(taskId, { progress: 100, status: 'DONE' })
    } catch {
      updateUploadTask(taskId, { status: 'ERROR' })
    }
  }))

  if (successCount > 0) {
    showToast(`成功上传 ${successCount} 个文件`)
    await loadFiles(currentFolderId.value)
    if (isSearching.value && searchQuery.value.trim()) {
      doSearch(searchQuery.value.trim())
    }
    await loadBreadcrumb(currentFolderId.value)
  }
  if (successCount < files.length) {
    showToast(`有 ${files.length - successCount} 个文件上传失败`, 'error')
  }
}

function clearFinishedUploads() {
  uploadTasks.value
    .filter(task => task.status === 'DONE' || task.status === 'ERROR')
    .forEach(task => clearUploadCleanupTimer(task.id))
  uploadTasks.value = uploadTasks.value.filter(task => task.status === 'WAITING' || task.status === 'UPLOADING')
}

async function downloadFile(item) {
  try {
    const res = await fileApi.download(item.id)
    const url = URL.createObjectURL(res.data)
    const a = document.createElement('a')
    a.href = url
    a.download = item.name
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    showToast('下载失败', 'error')
  }
}

function getFileExt(name) {
  if (!name || !name.includes('.')) return ''
  return name.split('.').pop().toLowerCase()
}

function publicFileUrl(item) {
  if (!item?.filePath) return ''
  return `${window.location.origin}/uploads${item.filePath}`
}

function resolvePreviewType(item) {
  const mime = (item?.mimeType || '').toLowerCase()
  const ext = getFileExt(item?.name)
  const imageExts = new Set(['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'])
  const textExts = new Set(['txt', 'md', 'json', 'csv', 'log', 'xml', 'html', 'htm', 'js', 'ts', 'css', 'java', 'sql', 'yml', 'yaml'])
  const videoExts = new Set(['mp4', 'webm', 'ogg', 'mov'])
  const audioExts = new Set(['mp3', 'wav', 'ogg', 'm4a', 'flac'])

  if (mime.startsWith('image/') || imageExts.has(ext)) return 'image'
  if (mime.includes('pdf') || ext === 'pdf') return 'pdf'
  if (mime.startsWith('video/') || videoExts.has(ext)) return 'video'
  if (mime.startsWith('audio/') || audioExts.has(ext)) return 'audio'
  if (mime.startsWith('text/') || textExts.has(ext) || mime.includes('json') || mime.includes('xml')) return 'text'
  return 'unsupported'
}

function isImagePreviewable(item) {
  return resolvePreviewType(item) === 'image'
}

function isOfficePreviewable(item) {
  const ext = getFileExt(item?.name)
  return ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].includes(ext)
}

function showImageCover(item) {
  return !isFolder(item) && isImagePreviewable(item) && !!item?.filePath && !thumbErrors.value[item.id]
}

function markThumbError(id) {
  thumbErrors.value = { ...thumbErrors.value, [id]: true }
}

function fileTone(item) {
  if (isFolder(item)) return 'folder'
  const ext = getFileExt(item?.name)
  if (['pdf'].includes(ext)) return 'pdf'
  if (['doc', 'docx'].includes(ext)) return 'doc'
  if (['xls', 'xlsx', 'csv'].includes(ext)) return 'sheet'
  if (['ppt', 'pptx'].includes(ext)) return 'slide'
  if (['zip', 'rar', '7z', 'tar', 'gz'].includes(ext)) return 'archive'
  if (['mp4', 'avi', 'mov', 'mkv', 'webm'].includes(ext)) return 'video'
  if (['mp3', 'wav', 'flac', 'm4a', 'ogg'].includes(ext)) return 'audio'
  if (['js', 'ts', 'vue', 'html', 'css', 'json', 'java', 'sql', 'xml', 'yml', 'yaml'].includes(ext)) return 'code'
  return 'file'
}

function fileGlyph(item) {
  if (isFolder(item)) return 'DIR'
  const ext = getFileExt(item?.name)
  if (!ext) return 'FILE'
  if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)) return 'IMG'
  return ext.toUpperCase().slice(0, 4)
}

function fileExtLabel(item) {
  if (isFolder(item)) return '文件夹'
  const ext = getFileExt(item?.name)
  return ext ? ext.toUpperCase() : 'FILE'
}

function buildOfficePreviewUrl(item) {
  const source = publicFileUrl(item)
  if (!source) return ''
  return `https://view.officeapps.live.com/op/view.aspx?src=${encodeURIComponent(source)}`
}

function isLocalHost(hostname) {
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1'
}

function openOnlinePreview(item) {
  const previewLink = buildOfficePreviewUrl(item)
  if (!previewLink) {
    showToast('当前文件没有可预览地址', 'error')
    return
  }
  if (isLocalHost(window.location.hostname)) {
    showToast('本地地址无法被 Office 在线预览服务访问，部署到可访问地址后即可使用', 'info')
    return
  }
  window.open(previewLink, '_blank', 'noopener')
}

function handlePrimaryAction(item) {
  if (isOfficePreviewable(item)) {
    openOnlinePreview(item)
    return
  }
  previewFile(item)
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
    console.error('PDF render failed', error)
    previewError.value = '移动端 PDF 预览失败，请下载后查看。'
  } finally {
    if (renderToken === activePdfRenderToken) {
      previewLoading.value = false
    }
  }
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
    URL.revokeObjectURL(activePreviewUrl)
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

function closePreview() {
  showPreviewDialog.value = false
  previewItem.value = null
  resetPreviewState()
}

async function previewFile(item) {
  cancelPreviewRequest()
  const requestToken = ++previewRequestToken
  previewItem.value = item
  showPreviewDialog.value = true
  resetPreviewState()
  previewAbortController = new AbortController()
  previewLoading.value = true
  previewType.value = resolvePreviewType(item)

  if (previewType.value === 'unsupported') {
    previewLoading.value = false
    return
  }

  try {
    const res = await fileApi.download(item.id, { signal: previewAbortController.signal })
    if (requestToken !== previewRequestToken || !showPreviewDialog.value) return
    const blob = res.data
    if (previewType.value === 'text') {
      if (blob.size > TEXT_PREVIEW_LIMIT) {
        previewError.value = '文本文件较大，暂不直接展开，请下载后查看。'
      } else {
        previewText.value = await blob.text()
      }
    } else {
      activePreviewUrl = URL.createObjectURL(blob)
      previewUrl.value = activePreviewUrl
      if (previewType.value === 'pdf' && isMobilePreview.value) {
        const pdfBuffer = await blob.arrayBuffer()
        if (requestToken !== previewRequestToken || !showPreviewDialog.value) return
        await renderPdfAsImages(new Uint8Array(pdfBuffer))
      }
    }
  } catch (error) {
    if (isPreviewRequestCanceled(error)) return
    previewError.value = error?.response?.data?.message || '文件预览失败，请稍后重试。'
  } finally {
    if (requestToken === previewRequestToken) {
      previewAbortController = null
    }
    if (requestToken === previewRequestToken && !(previewType.value === 'pdf' && isMobilePreview.value)) {
      previewLoading.value = false
    }
  }
}

async function deleteItem(item) {
  try {
    await fileApi.delete(item.id)
    showToast('已删除')
    selectedIds.value = selectedIds.value.filter(id => id !== item.id)
    items.value = items.value.filter(i => i.id !== item.id)
    if (isSearching.value) {
      searchResults.value = searchResults.value.filter(i => i.id !== item.id)
    }
    return true
  } catch (e) {
    showToast(e.response?.data?.message || '删除失败', 'error')
    return false
  }
}

function openDeleteConfirmForItem(item) {
  if (!item) return
  deleteConfirmMode.value = 'single'
  deleteConfirmItem.value = item
  deleteConfirmIds.value = [item.id]
  showDeleteConfirmDialog.value = true
}

function openDeleteConfirmForSelection() {
  if (!selectedIds.value.length) return
  deleteConfirmMode.value = 'batch'
  deleteConfirmItem.value = null
  deleteConfirmIds.value = [...selectedIds.value]
  showDeleteConfirmDialog.value = true
}

async function confirmDeleteAction() {
  if (deleteConfirmLoading.value) return
  const ids = [...deleteConfirmIds.value]
  if (!ids.length) return

  deleteConfirmLoading.value = true
  try {
    if (deleteConfirmMode.value === 'single' && deleteConfirmItem.value) {
      const success = await deleteItem(deleteConfirmItem.value)
      if (success) {
        showDeleteConfirmDialog.value = false
      }
      return
    }

    let successCount = 0

    await Promise.all(ids.map(async id => {
      try {
        await fileApi.delete(id)
        successCount += 1
      } catch {
        // Keep batch deletion resilient; failures are summarized after all requests finish.
      }
    }))

    if (successCount > 0) {
      showToast(`已删除 ${successCount} 项`)
      clearSelection()
      await refreshFilesPage()
    }

    if (successCount < ids.length) {
      showToast(`有 ${ids.length - successCount} 项删除失败`, 'error')
      return
    }

    showDeleteConfirmDialog.value = false
  } finally {
    deleteConfirmLoading.value = false
  }
}

function openRename(item) {
  renameItem.value = item
  renameValue.value = item.name
  showRenameDialog.value = true
}

async function doRename() {
  const name = renameValue.value.trim()
  if (!name) {
    showToast('请输入名称', 'error')
    return
  }
  if (name === renameItem.value?.name) {
    showRenameDialog.value = false
    return
  }
  renameLoading.value = true
  try {
    await fileApi.rename(renameItem.value.id, name)
    showToast('重命名成功')
    showRenameDialog.value = false
    const itemIndex = items.value.findIndex(i => i.id === renameItem.value.id)
    if (itemIndex !== -1) items.value[itemIndex] = { ...items.value[itemIndex], name }
    if (isSearching.value) {
      const idx = searchResults.value.findIndex(i => i.id === renameItem.value.id)
      if (idx !== -1) searchResults.value[idx] = { ...searchResults.value[idx], name }
    }
  } catch (e) {
    showToast(e.response?.data?.message || '重命名失败', 'error')
  } finally {
    renameLoading.value = false
  }
}

function formatSize(bytes) {
  if (!bytes || bytes === 0) return '-'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}

async function refreshFilesPage() {
  await loadFiles(currentFolderId.value)
  if (isSearching.value && searchQuery.value.trim()) {
    doSearch(searchQuery.value.trim())
  }
  await loadBreadcrumb(currentFolderId.value)
}

useResumeRefresh(refreshFilesPage)

onMounted(() => {
  syncMobilePreviewState()
  window.addEventListener('dragenter', onDragEnter)
  window.addEventListener('dragover', onDragOver)
  window.addEventListener('dragleave', onDragLeave)
  window.addEventListener('drop', onDrop)
  window.addEventListener('resize', closeContextMenu)
  window.addEventListener('resize', syncMobilePreviewState)
  window.addEventListener('scroll', closeContextMenu, true)
  loadFiles(null)
})

onBeforeUnmount(() => {
  window.removeEventListener('dragenter', onDragEnter)
  window.removeEventListener('dragover', onDragOver)
  window.removeEventListener('dragleave', onDragLeave)
  window.removeEventListener('drop', onDrop)
  window.removeEventListener('resize', closeContextMenu)
  window.removeEventListener('resize', syncMobilePreviewState)
  window.removeEventListener('scroll', closeContextMenu, true)
  clearLongPressState()
  closeContextMenu()
  stopSelectionTracking()
  uploadCleanupTimers.forEach(timer => clearTimeout(timer))
  uploadCleanupTimers.clear()
  cancelPreviewRequest()
  resetPreviewState()
})
</script>

<style scoped>
.file-toolbar {
  margin-bottom: 14px;
  align-items: flex-start;
  gap: 12px;
}
.file-toolbar-right {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 10px;
}
.file-search-row {
  display: flex;
  align-items: center;
}
.file-action-grid {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 10px;
}
.file-toolbar-tail {
  display: flex;
  align-items: center;
  justify-content: flex-end;
}
.files-access-note {
  margin: -2px 0 14px;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid #dbeafe;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 13px;
}
.page-drag-overlay {
  position: fixed;
  inset: 0;
  z-index: 35;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: rgba(15, 23, 42, 0.12);
  backdrop-filter: blur(3px);
  pointer-events: none;
}
.page-drag-overlay-card {
  min-width: min(420px, calc(100vw - 48px));
  padding: 22px 26px;
  border-radius: 20px;
  border: 1px solid rgba(96, 165, 250, 0.32);
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 22px 48px rgba(37, 99, 235, 0.16);
  text-align: center;
}
.page-drag-overlay-title {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
}
.page-drag-overlay-desc {
  margin-top: 8px;
  font-size: 13px;
  color: #64748b;
}
.file-toolbar-left {
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1 1 320px;
}
.file-nav-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.file-nav-btn {
  min-width: 96px;
}
.file-home-btn {
  min-width: 104px;
}
.file-breadcrumb-wrap {
  min-width: 0;
  flex: 1 1 auto;
  overflow: auto hidden;
  padding-bottom: 2px;
}
.file-breadcrumb-list {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-width: max-content;
  white-space: nowrap;
}
.file-crumb-btn {
  height: 38px;
  padding: 0 14px;
  border: 1px solid #dbeafe;
  border-radius: 12px;
  background: rgba(248, 251, 255, 0.92);
  color: #2563eb;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.16s ease;
}
.file-crumb-btn:hover:not(:disabled) {
  border-color: #93c5fd;
  background: linear-gradient(135deg, #f8fbff, #eef5ff);
  box-shadow: 0 10px 24px rgba(37, 99, 235, 0.1);
}
.file-crumb-btn.active,
.file-crumb-btn:disabled {
  border-color: #bfdbfe;
  background: linear-gradient(135deg, #eff6ff, #dbeafe);
  color: #1d4ed8;
  cursor: default;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.72);
}
.file-crumb-separator {
  color: #94a3b8;
  font-size: 12px;
  font-weight: 700;
}
.file-search {
  width: 260px;
}
.upload-board {
  margin-bottom: 16px;
  padding: 16px;
  border-radius: 18px;
  border: 1px solid var(--border);
  background: #fff;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.05);
}
.upload-board-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}
.upload-board-title {
  font-size: 14px;
  font-weight: 800;
  color: #0f172a;
}
.upload-board-subtitle {
  margin-top: 4px;
  font-size: 12px;
  color: #64748b;
}
.upload-board-clear {
  border: 0;
  background: transparent;
  color: #2563eb;
  cursor: pointer;
  font-size: 12px;
  font-weight: 700;
}
.upload-overall {
  margin-bottom: 14px;
  padding: 12px 14px;
  border-radius: 16px;
  border: 1px solid rgba(59, 130, 246, 0.12);
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.08), rgba(14, 165, 233, 0.05));
}
.upload-overall-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
  font-size: 13px;
  color: #475569;
}
.upload-overall-meta strong {
  font-size: 18px;
  line-height: 1;
  color: #0f172a;
}
.upload-overall-bar {
  height: 9px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.18);
}
.upload-overall-bar-fill {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #2563eb, #0ea5e9);
  transition: width 0.2s ease;
}
.upload-task-list {
  display: grid;
  gap: 10px;
}
.upload-task {
  padding: 10px 12px;
  border-radius: 14px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  transition: opacity 0.38s ease, transform 0.38s ease;
}
.upload-task.fading {
  opacity: 0;
  transform: translateY(-8px) scale(0.98);
}
.upload-task-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 8px;
}
.upload-task-name {
  min-width: 0;
  font-size: 13px;
  font-weight: 700;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.upload-task-meta {
  flex-shrink: 0;
  display: flex;
  gap: 10px;
  font-size: 11.5px;
  color: #64748b;
}
.upload-task-bar {
  height: 8px;
  border-radius: 999px;
  background: #e2e8f0;
  overflow: hidden;
}
.upload-task-bar-fill {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(135deg, #60a5fa, #2563eb);
  transition: width 0.18s ease;
}
.upload-task-bar-fill.done {
  background: linear-gradient(135deg, #34d399, #059669);
}
.upload-task-bar-fill.error {
  background: linear-gradient(135deg, #fb7185, #dc2626);
}
.selection-toolbar {
  position: fixed;
  right: 20px;
  bottom: 20px;
  z-index: 30;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-width: 280px;
  padding: 10px 12px;
  border-radius: 18px;
  border: 1px solid rgba(96, 165, 250, 0.24);
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.12);
  backdrop-filter: blur(12px);
}
.selection-toolbar-copy {
  font-size: 13px;
  color: #334155;
}
.selection-toolbar-copy strong {
  color: #0f172a;
}
.selection-toolbar-actions {
  display: flex;
  gap: 8px;
}
.selection-toolbar-btn {
  min-height: 32px;
  padding: 0 12px;
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.9);
  color: #334155;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
}
.selection-toolbar-btn.danger {
  border-color: #fecaca;
  background: #fff1f2;
  color: #dc2626;
}
.view-switch {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-width: 140px;
  height: 38px;
  padding: 0 12px;
  border: 1px solid #dbeafe;
  border-radius: 12px;
  background: rgba(248, 251, 255, 0.92);
  cursor: pointer;
  color: #2563eb;
  transition: all 0.16s ease;
}
.view-switch:hover {
  border-color: #93c5fd;
  background: linear-gradient(135deg, #f8fbff, #eef5ff);
  box-shadow: 0 10px 24px rgba(37, 99, 235, 0.1);
}
.view-switch-current {
  font-size: 13px;
  font-weight: 700;
  color: #1d4ed8;
}
.view-switch-arrow {
  font-size: 13px;
  color: #93a4bf;
}
.view-switch-next {
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
}
.files-state {
  padding: 70px 0;
  text-align: center;
  color: var(--text-muted);
}
.files-state.empty {
  padding: 84px 0;
}
.files-state-title {
  margin-top: 16px;
  font-size: 15px;
  font-weight: 700;
  color: #64748b;
}
.files-state-text {
  margin-top: 8px;
  font-size: 13px;
}
.files-grid-wrap {
  position: relative;
}
.files-list-head {
  display: grid;
  grid-template-columns: 36px 10px minmax(0, 1.7fr) 120px 90px 128px;
  gap: 16px;
  margin-bottom: 6px;
  padding: 0 16px 8px 16px;
  color: #64748b;
  font-size: 12px;
  font-weight: 700;
  align-items: center;
}
.files-list-head-spacer {
  width: 36px;
  height: 1px;
}
.files-list-head-gap {
  width: 10px;
  height: 1px;
}
.selection-box {
  position: absolute;
  z-index: 3;
  border: 1px solid rgba(37, 99, 235, 0.45);
  background: rgba(59, 130, 246, 0.14);
  border-radius: 12px;
  pointer-events: none;
  box-shadow: inset 0 0 0 1px rgba(191, 219, 254, 0.5);
}
.files-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(168px, 1fr));
  gap: 14px;
}
.file-item {
  position: relative;
  padding: 12px 12px 14px;
  border: 1px solid var(--border);
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease;
}
.file-item:hover {
  transform: translateY(-2px);
  border-color: #bfdbfe;
  box-shadow: 0 14px 28px rgba(37, 99, 235, 0.08);
}
.file-item.selected {
  border-color: #60a5fa;
  background: linear-gradient(180deg, #f8fbff, #ffffff);
  box-shadow: 0 16px 30px rgba(37, 99, 235, 0.12);
}
.file-item.selected::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  box-shadow: inset 0 0 0 1px rgba(147, 197, 253, 0.6);
  pointer-events: none;
}
.file-item.drop-target {
  border-color: #2563eb;
  background: linear-gradient(180deg, #eff6ff, #ffffff);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.12);
}
.file-item.drop-target::before {
  content: '移动到此文件夹';
  position: absolute;
  right: 10px;
  bottom: 10px;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.12);
  color: #1d4ed8;
  font-size: 11px;
  font-weight: 700;
  pointer-events: none;
}
.file-context-backdrop {
  position: fixed;
  inset: 0;
  z-index: 39;
}
.file-context-menu {
  position: fixed;
  z-index: 40;
  min-width: 156px;
  padding: 6px;
  border-radius: 14px;
  border: 1px solid rgba(148, 163, 184, 0.2);
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.18);
  backdrop-filter: blur(10px);
}
.file-context-item {
  width: 100%;
  min-height: 36px;
  padding: 0 12px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: #0f172a;
  font-size: 13px;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}
.file-context-item:hover {
  background: #eff6ff;
  color: #2563eb;
}
.file-context-item.danger {
  color: #dc2626;
}
.file-context-item.danger:hover {
  background: #fff1f2;
}
.file-thumb {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 56px;
  margin-bottom: 10px;
  border-radius: 12px;
  overflow: hidden;
  cursor: pointer;
  background: linear-gradient(180deg, #f8fafc, #eff6ff);
  border: 1px solid #e2e8f0;
}
.file-share-badge {
  position: absolute;
  top: 6px;
  right: 6px;
  z-index: 2;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 34px;
  height: 18px;
  padding: 0 6px;
  border-radius: 999px;
  background: linear-gradient(135deg, #2563eb, #38bdf8);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.02em;
  box-shadow: 0 8px 16px rgba(37, 99, 235, 0.18);
  pointer-events: none;
}
.file-cover-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  background: #fff;
}
.file-thumb-fallback {
  position: relative;
  width: calc(100% - 10px);
  height: calc(100% - 10px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  isolation: isolate;
}
.file-thumb-fallback.document {
  width: 38px;
  height: 48px;
  border-radius: 4px 10px 4px 4px;
  border: 1px solid rgba(148, 163, 184, 0.22);
  background: linear-gradient(180deg, #ffffff 0%, #fbfdff 100%);
  box-shadow:
    0 10px 18px rgba(15, 23, 42, 0.08),
    inset 0 1px 0 rgba(255,255,255,0.92);
}
.file-thumb-fallback.document::before {
  content: '';
  position: absolute;
  top: 0;
  right: 0;
  width: 13px;
  height: 13px;
  border-top-right-radius: 9px;
  background: linear-gradient(135deg, #d5d8dd 0%, #f7f8fa 70%);
  clip-path: polygon(100% 0, 0 0, 100% 100%);
  box-shadow: -1px 1px 0 rgba(148, 163, 184, 0.18);
}
.file-thumb-fallback.document::after {
  content: '';
  position: absolute;
  left: 8px;
  right: 7px;
  bottom: 7px;
  height: 14px;
  border-radius: 2px;
  background:
    repeating-linear-gradient(
      180deg,
      rgba(148, 163, 184, 0.68) 0 2px,
      transparent 2px 5px
    );
  opacity: 0.72;
}
.file-thumb-fallback.folder {
  width: 54px;
  height: 36px;
  margin-top: 8px;
  border-radius: 6px;
  border: 1px solid rgba(245, 158, 11, 0.22);
  background: linear-gradient(180deg, #ffe08a 0%, #ffd15a 58%, #ffc947 100%);
  box-shadow:
    0 8px 16px rgba(217, 119, 6, 0.16),
    inset 0 1px 0 rgba(255,255,255,0.54);
}
.file-thumb-fallback.folder::before {
  content: '';
  position: absolute;
  top: -7px;
  left: 8px;
  width: 24px;
  height: 11px;
  border-radius: 7px 7px 0 0;
  background: linear-gradient(180deg, #ffbe27 0%, #ffb300 100%);
  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.32),
    0 2px 4px rgba(217, 119, 6, 0.12);
}
.file-thumb-fallback.folder::after {
  content: '';
  position: absolute;
  top: 2px;
  left: 2px;
  right: 2px;
  height: 7px;
  border-radius: 5px 5px 3px 3px;
  background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(255,255,255,0.34));
}
.file-thumb-fallback.folder .file-thumb-glyph,
.file-thumb-fallback.folder .file-thumb-ext {
  display: none;
}
.tone-folder { --thumb-surface-1: #ffe08a; --thumb-surface-2: #ffc947; color: #a16207; }
.tone-pdf { --thumb-surface-1: #fee2e2; --thumb-surface-2: #fecaca; color: #b91c1c; }
.tone-doc { --thumb-surface-1: #dbeafe; --thumb-surface-2: #bfdbfe; color: #1d4ed8; }
.tone-sheet { --thumb-surface-1: #dcfce7; --thumb-surface-2: #bbf7d0; color: #15803d; }
.tone-slide { --thumb-surface-1: #ffedd5; --thumb-surface-2: #fed7aa; color: #c2410c; }
.tone-archive { --thumb-surface-1: #ede9fe; --thumb-surface-2: #ddd6fe; color: #6d28d9; }
.tone-video { --thumb-surface-1: #cffafe; --thumb-surface-2: #a5f3fc; color: #0e7490; }
.tone-audio { --thumb-surface-1: #fce7f3; --thumb-surface-2: #fbcfe8; color: #be185d; }
.tone-code { --thumb-surface-1: #e2e8f0; --thumb-surface-2: #cbd5e1; color: #334155; }
.tone-file { --thumb-surface-1: #e0f2fe; --thumb-surface-2: #dbeafe; color: #1e40af; }
.file-thumb-glyph {
  position: relative;
  z-index: 1;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.03em;
  line-height: 1;
}
.file-thumb-ext {
  position: relative;
  z-index: 1;
  padding: 2px 5px;
  border-radius: 999px;
  background: rgba(255,255,255,0.86);
  font-size: 7px;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.08);
}
.file-thumb-fallback.document .file-thumb-glyph {
  position: absolute;
  top: 16px;
  left: 50%;
  min-width: 22px;
  height: 18px;
  padding: 0 5px;
  transform: translateX(-50%);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 3px;
  border: 2px solid rgba(255,255,255,0.94);
  background: linear-gradient(180deg, var(--thumb-surface-2), var(--thumb-surface-1));
  color: #ffffff;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.02em;
  line-height: 1;
  box-shadow:
    0 4px 10px rgba(15, 23, 42, 0.1),
    inset 0 1px 0 rgba(255,255,255,0.18);
}
.file-thumb-fallback.document .file-thumb-ext {
  position: absolute;
  left: 50%;
  bottom: 5px;
  padding: 0;
  transform: translateX(-50%);
  background: transparent;
  color: currentColor;
  font-size: 6px;
  font-weight: 900;
  letter-spacing: 0.04em;
  box-shadow: none;
}
.file-info {
  min-width: 0;
}
.file-primary {
  min-width: 0;
}
.file-name {
  font-size: 14px;
  font-weight: 700;
  color: var(--text);
  line-height: 1.45;
  word-break: break-word;
}
.file-name.is-clickable {
  cursor: pointer;
}
.file-name.is-clickable:hover {
  color: var(--primary);
}
.file-meta {
  margin-top: 8px;
  font-size: 12px;
  color: var(--text-muted);
}
.files-grid.list-mode {
  grid-template-columns: 1fr;
  gap: 6px;
}
.files-grid.list-mode .file-item {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  min-height: 48px;
  padding: 8px 16px;
  border-radius: 12px;
  box-shadow: none;
}
.files-grid.list-mode .file-item:hover {
  transform: none;
  box-shadow: none;
  background: #f8fbff;
}
.files-grid.list-mode .file-item.drop-target::before {
  right: 12px;
  bottom: 50%;
  transform: translateY(50%);
}
.files-grid.list-mode .file-thumb {
  width: 36px;
  height: 36px;
  margin-bottom: 0;
  border-radius: 10px;
}
.files-grid.list-mode .file-info {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) 120px 90px 128px;
  align-items: center;
  gap: 16px;
}
.files-grid.list-mode .file-primary {
  min-width: 0;
  justify-self: start;
  width: 100%;
  text-align: left;
}
.files-grid.list-mode .file-name {
  font-size: 13px;
  line-height: 1.25;
  text-align: left;
}
.file-list-meta {
  color: #64748b;
  font-size: 12px;
  white-space: nowrap;
}
.breadcrumb-link {
  cursor: pointer;
  color: var(--primary);
  font-weight: 500;
  transition: color 0.15s;
}
.breadcrumb-link:hover {
  color: var(--primary-dark);
  text-decoration: underline;
}
.file-preview-wrap {
  min-height: 240px;
}
.file-preview-mobile-close {
  display: none;
}
.file-preview-dialog :deep(.el-dialog) {
  overflow: hidden;
  border-radius: 22px;
}
.file-preview-dialog :deep(.el-dialog__body) {
  padding-top: 16px;
}
.move-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 8px 8px 4px;
}
.move-icon {
  width: 54px;
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  background: linear-gradient(135deg, #dbeafe, #bfdbfe);
  color: #2563eb;
  font-size: 28px;
  font-weight: 800;
  box-shadow: inset 0 0 0 1px rgba(96, 165, 250, 0.26);
}
.move-title {
  margin-top: 14px;
  font-size: 20px;
  font-weight: 800;
  color: #0f172a;
}
.move-desc {
  margin-top: 10px;
  color: #64748b;
  font-size: 14px;
  line-height: 1.7;
}
.move-folder-list {
  width: 100%;
  max-height: 320px;
  margin-top: 16px;
  padding: 8px;
  overflow: auto;
  border: 1px solid #e2e8f0;
  border-radius: 18px;
  background: #f8fafc;
}
.move-folder-item {
  width: 100%;
  min-height: 42px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-right: 14px;
  border: 0;
  border-radius: 12px;
  background: transparent;
  color: #0f172a;
  text-align: left;
  cursor: pointer;
}
.move-folder-item:hover {
  background: #eff6ff;
}
.move-folder-item.active {
  background: linear-gradient(135deg, #eff6ff, #dbeafe);
  color: #2563eb;
}
.move-folder-item.disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
.move-folder-name {
  min-width: 0;
  font-size: 13px;
  font-weight: 600;
  word-break: break-word;
}
.move-folder-badge {
  flex-shrink: 0;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.1);
  color: #1d4ed8;
  font-size: 11px;
  font-weight: 700;
}
.move-dialog :deep(.el-dialog) {
  border-radius: 22px;
  padding: 8px 6px 6px;
}
.move-dialog :deep(.el-dialog__header) {
  display: none;
}
.move-dialog :deep(.el-dialog__body) {
  padding: 18px 22px 10px;
}
.move-dialog :deep(.el-dialog__footer) {
  padding: 0 22px 20px;
}
.share-card-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 8px 8px 4px;
}
.share-card-icon {
  width: 54px;
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  background: linear-gradient(135deg, #dbeafe, #bfdbfe);
  color: #2563eb;
  font-size: 28px;
  font-weight: 800;
  box-shadow: inset 0 0 0 1px rgba(96, 165, 250, 0.24);
}
.share-card-title {
  margin-top: 14px;
  font-size: 20px;
  font-weight: 800;
  color: #0f172a;
}
.share-card-desc {
  margin-top: 10px;
  color: #64748b;
  font-size: 14px;
  line-height: 1.7;
}
.share-form {
  width: 100%;
  margin-top: 18px;
  display: grid;
  gap: 14px;
  text-align: left;
}
.share-link-box,
.share-field,
.share-option-row {
  padding: 14px;
  border-radius: 16px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.share-link-label {
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 700;
  color: #334155;
}
.share-field-hint {
  margin-top: 8px;
  font-size: 12px;
  line-height: 1.6;
  color: #64748b;
}
.share-link-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
}
.share-option-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  color: #0f172a;
  font-size: 14px;
  font-weight: 600;
}
.share-dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  flex-wrap: wrap;
}
.share-dialog :deep(.el-dialog) {
  border-radius: 22px;
  padding: 8px 6px 6px;
}
.share-dialog :deep(.el-dialog__header) {
  display: none;
}
.share-dialog :deep(.el-dialog__body) {
  padding: 18px 22px 10px;
}
.share-dialog :deep(.el-dialog__footer) {
  padding: 0 22px 20px;
}
.delete-confirm-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 8px 8px 4px;
}
.delete-confirm-icon {
  width: 54px;
  height: 54px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 18px;
  background: linear-gradient(135deg, #fee2e2, #fecaca);
  color: #dc2626;
  font-size: 28px;
  font-weight: 800;
  box-shadow: inset 0 0 0 1px rgba(248, 113, 113, 0.26);
}
.delete-confirm-title {
  margin-top: 14px;
  font-size: 20px;
  font-weight: 800;
  color: #0f172a;
}
.delete-confirm-desc {
  margin-top: 10px;
  color: #64748b;
  font-size: 14px;
  line-height: 1.7;
}
.delete-confirm-dialog :deep(.el-dialog) {
  border-radius: 22px;
  padding: 8px 6px 6px;
}
.delete-confirm-dialog :deep(.el-dialog__header) {
  display: none;
}
.delete-confirm-dialog :deep(.el-dialog__body) {
  padding: 18px 22px 10px;
}
.delete-confirm-dialog :deep(.el-dialog__footer) {
  padding: 0 22px 20px;
}
.file-preview-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 14px;
  color: var(--text-muted);
  font-size: 12px;
}
.file-preview-body {
  border: 1px solid var(--border);
  border-radius: 14px;
  background: #f8fafc;
  overflow: hidden;
}
.file-preview-body.image,
.file-preview-body.media,
.file-preview-body.text,
.file-preview-body.document {
  min-height: 320px;
}
.file-preview-image {
  display: block;
  max-width: 100%;
  max-height: 70vh;
  margin: 0 auto;
  object-fit: contain;
  background: #fff;
}
.file-preview-touch-tools {
  display: none;
}
.file-preview-touch-wrap {
  width: 100%;
}
.file-preview-frame {
  width: 100%;
  height: 70vh;
  border: 0;
  background: #fff;
}
.file-preview-pdf-stack {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-height: 0;
  background: #eef2f7;
}
.file-preview-pdf-modebar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border-bottom: 1px solid rgba(148, 163, 184, 0.2);
  background: rgba(255, 255, 255, 0.92);
}
.file-preview-pdf-badge {
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
.file-preview-pdf-hint {
  color: #64748b;
  font-size: 12px;
  font-weight: 600;
}
.file-preview-pdf-pages {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 12px 12px 16px;
}
.file-preview-pdf-page + .file-preview-pdf-page {
  margin-top: 12px;
}
.file-preview-pdf-image {
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
.file-preview-video {
  width: 100%;
  max-height: 70vh;
  background: #000;
}
.file-preview-body.audio {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px 20px;
  min-height: 120px;
}
.file-preview-audio {
  width: min(100%, 560px);
}
.file-preview-text {
  margin: 0;
  padding: 16px;
  min-height: 320px;
  max-height: 70vh;
  overflow: auto;
  background: #0f172a;
  color: #e2e8f0;
  font-size: 13px;
  line-height: 1.65;
  white-space: pre-wrap;
  word-break: break-word;
}
.file-preview-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 240px;
  padding: 24px;
  border: 1px dashed var(--border);
  border-radius: 14px;
  color: var(--text-muted);
  text-align: center;
  background: #f8fafc;
}
@media (max-width: 768px) {
  .file-toolbar {
    gap: 8px;
  }
  .file-toolbar-left {
    width: 100%;
    flex: none;
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
  }
  .file-nav-actions {
    width: 100%;
    flex: none;
  }
  .file-nav-btn {
    flex: 1;
    width: auto;
    min-width: 0;
  }
  .file-breadcrumb-wrap {
    width: 100%;
    flex: none;
    padding: 0 2px 2px 0;
  }
  .file-breadcrumb-list {
    gap: 6px;
  }
  .file-crumb-btn {
    height: 34px;
    padding: 0 12px;
    font-size: 12px;
  }
  .file-toolbar-right {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 8px;
    padding: 10px;
    border: 1px solid rgba(219, 234, 254, 0.95);
    border-radius: 16px;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(248, 251, 255, 0.94));
    box-shadow: 0 10px 28px rgba(148, 163, 184, 0.12);
    width: 100%;
  }
  .file-search-row,
  .file-action-grid,
  .file-toolbar-tail {
    width: 100%;
  }
  .file-search-row {
    display: block;
  }
  .file-action-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
  }
  .file-toolbar-tail {
    justify-content: flex-end;
    padding-top: 2px;
  }
  .file-search {
    width: 100%;
  }
  .file-search-row :deep(.el-input) {
    width: 100% !important;
  }
  .file-action-grid :deep(.el-button) {
    width: 100%;
    margin: 0;
    min-height: 36px;
    border-radius: 12px;
  }
  .view-switch {
    width: auto;
    min-width: 120px;
    max-width: 100%;
    margin-left: auto;
    justify-content: center;
    padding: 0 10px;
    height: 36px;
  }
  .view-switch-current {
    font-size: 12px;
  }
  .view-switch-next {
    font-size: 11px;
  }
  .upload-task-main {
    flex-direction: column;
    align-items: flex-start;
  }
  .selection-toolbar {
    left: 12px;
    right: 12px;
    bottom: 12px;
    min-width: 0;
    flex-direction: column;
    align-items: stretch;
  }
  .selection-toolbar-actions {
    width: 100%;
  }
  .selection-toolbar-btn {
    flex: 1;
  }
  .share-link-row {
    grid-template-columns: 1fr;
  }
  .share-dialog-footer {
    width: 100%;
  }
  .share-dialog-footer :deep(.el-button) {
    flex: 1;
    margin: 0;
  }
  .files-list-head {
    display: none;
  }
  .files-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
  }
  .file-item {
    padding: 10px 10px 12px;
    border-radius: 14px;
  }
  .file-item.drop-target::before {
    right: 8px;
    bottom: 8px;
    font-size: 10px;
  }
  .file-thumb {
    height: 52px;
    border-radius: 12px;
  }
  .file-share-badge {
    top: 4px;
    right: 4px;
    min-width: 30px;
    height: 16px;
    padding: 0 5px;
    font-size: 9px;
  }
  .file-thumb-glyph {
    font-size: 11px;
  }
  .file-name {
    font-size: 13px;
  }
  .files-grid.list-mode {
    grid-template-columns: 1fr;
  }
  .files-grid.list-mode .file-item {
    grid-template-columns: 36px minmax(0, 1fr);
    gap: 8px;
    min-height: 0;
    padding: 8px 10px;
    border-radius: 12px;
  }
  .files-grid.list-mode .file-thumb {
    width: 36px;
    height: 36px;
    border-radius: 10px;
  }
  .files-grid.list-mode .file-info {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    align-content: center;
    gap: 3px 8px;
    min-width: 0;
  }
  .files-grid.list-mode .file-primary {
    flex: 0 0 100%;
  }
  .files-grid.list-mode .file-name {
    font-size: 12px;
    line-height: 1.3;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .files-grid.list-mode .file-list-meta {
    font-size: 10.5px;
    line-height: 1.2;
  }
  .files-grid.list-mode .file-list-meta + .file-list-meta::before {
    content: '·';
    margin-right: 6px;
    color: #cbd5e1;
  }
  .file-preview-frame,
  .file-preview-video,
  .file-preview-text,
  .file-preview-image {
    max-height: 60vh;
  }
  .file-preview-dialog :deep(.el-dialog.is-fullscreen) {
    display: flex;
    flex-direction: column;
    margin: 0;
    width: 100vw;
    max-width: none;
    height: 100dvh;
    max-height: 100dvh;
    border-radius: 0;
    padding: 0;
  }
  .file-preview-dialog :deep(.el-dialog__header) {
    margin: 0;
    padding: calc(10px + env(safe-area-inset-top, 0px)) 16px 10px;
    border-bottom: 1px solid #e2e8f0;
    background: rgba(255, 255, 255, 0.98);
  }
  .file-preview-dialog :deep(.el-dialog__title) {
    display: block;
    max-width: calc(100vw - 104px);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 15px;
    font-weight: 700;
  }
  .file-preview-dialog :deep(.el-dialog__body) {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    padding: 10px 10px 0;
    background: #fff;
  }
  .file-preview-dialog :deep(.el-dialog__footer) {
    display: flex;
    flex-shrink: 0;
    gap: 10px;
    margin-top: auto;
    padding: 10px 12px calc(12px + env(safe-area-inset-bottom, 0px));
    border-top: 1px solid #e2e8f0;
    background: rgba(255, 255, 255, 0.98);
  }
  .file-preview-dialog :deep(.el-dialog__footer .el-button) {
    flex: 1;
    margin: 0;
  }
  .file-preview-wrap {
    display: flex;
    flex: 1;
    flex-direction: column;
    min-height: 0;
    overflow: hidden;
  }
  .file-preview-mobile-close {
    position: fixed;
    top: calc(12px + env(safe-area-inset-top, 0px));
    right: 12px;
    z-index: 8;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 42px;
    height: 42px;
    border: 0;
    border-radius: 999px;
    background: rgba(15, 23, 42, 0.72);
    color: #fff;
    font-size: 26px;
    line-height: 1;
    box-shadow: 0 10px 24px rgba(15, 23, 42, 0.24);
    backdrop-filter: blur(10px);
  }
  .file-preview-meta {
    gap: 6px 8px;
    margin-bottom: 10px;
    padding: 0 56px 0 2px;
    font-size: 11px;
  }
  .file-preview-body {
    display: flex;
    flex: 1;
    min-height: 0;
    border-radius: 16px;
  }
  .file-preview-body.image,
  .file-preview-body.media,
  .file-preview-body.text,
  .file-preview-body.document {
    min-height: 0;
    height: 100%;
  }
  .file-preview-body.image {
    align-items: center;
    justify-content: center;
    padding: 8px;
    overflow: auto;
    background: #f1f5f9;
    position: relative;
  }
  .file-preview-touch-tools {
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
  .file-preview-touch-tip {
    color: #475569;
    font-size: 11px;
    font-weight: 600;
  }
  .file-preview-touch-wrap {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    min-height: 0;
    width: 100%;
    overflow: hidden;
    touch-action: none;
  }
  .file-preview-body.document {
    padding: 0;
    background: #e2e8f0;
  }
  .file-preview-pdf-modebar {
    padding: 10px;
  }
  .file-preview-pdf-hint {
    font-size: 11px;
  }
  .file-preview-pdf-pages {
    padding: 10px 10px 14px;
  }
  .file-preview-image,
  .file-preview-frame,
  .file-preview-video,
  .file-preview-text {
    width: 100%;
    height: 100%;
    max-height: none;
  }
  .file-preview-image {
    width: auto;
    max-width: 100%;
    height: auto;
    background: #fff;
    border-radius: 12px;
    transform-origin: center center;
    touch-action: none;
    user-select: none;
    -webkit-user-drag: none;
  }
  .file-preview-frame {
    min-height: 0;
    height: 100%;
    flex: 1;
  }
  .file-preview-video {
    object-fit: contain;
  }
  .file-preview-text {
    min-height: 0;
    padding: 14px;
    border-radius: 0;
  }
  .file-preview-empty {
    flex: 1;
    min-height: 0;
    border-radius: 16px;
  }
  .move-folder-list {
    max-height: 280px;
  }
}
</style>
