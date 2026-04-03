<template>
  <div>
    <!-- 挂载点管理 -->
    <div style="margin-bottom:16px">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
        <div style="font-size:15px;font-weight:700;color:var(--text)">网络挂载点</div>
        <el-button type="primary" size="default" @click="openAddMount">
          <el-icon><Plus /></el-icon> 添加挂载
        </el-button>
      </div>

      <div v-if="mounts.length === 0" style="text-align:center;padding:40px;background:#fff;border-radius:12px;border:1px solid var(--border);color:var(--text-muted)">
        <el-icon size="40" color="#cbd5e1"><Connection /></el-icon>
        <div style="margin-top:12px;font-size:14px">尚未添加任何 WebDAV 挂载点</div>
        <div style="margin-top:4px;font-size:12px">点击「添加挂载」连接坚果云、Nextcloud 等支持 WebDAV 的网盘</div>
      </div>

      <div v-else style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px">
        <div
          v-for="m in mounts"
          :key="m.id"
          :class="['mount-card', selectedMount?.id === m.id ? 'mount-card-active' : '']"
          @click="selectMount(m)"
        >
          <div style="display:flex;align-items:center;justify-content:space-between">
            <div style="display:flex;align-items:center;gap:10px;min-width:0">
              <el-icon size="22" color="#3b82f6"><Connection /></el-icon>
              <div style="min-width:0">
                <div style="font-weight:600;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ m.name }}</div>
                <div style="font-size:11px;color:var(--text-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:180px">{{ m.url }}</div>
              </div>
            </div>
            <div style="display:flex;gap:6px;flex-shrink:0">
              <el-button size="small" circle @click.stop="openEditMount(m)"><el-icon><Edit /></el-icon></el-button>
              <el-button size="small" circle type="danger" @click.stop="deleteMount(m)"><el-icon><Delete /></el-icon></el-button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 文件浏览 -->
    <div v-if="selectedMount" style="background:#fff;border:1px solid var(--border);border-radius:12px;padding:16px">
      <!-- Breadcrumb + toolbar -->
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;flex-wrap:wrap;gap:10px">
        <el-breadcrumb separator="/">
          <el-breadcrumb-item>
            <span class="breadcrumb-link" @click="goToRoot">{{ selectedMount.name }}</span>
          </el-breadcrumb-item>
          <el-breadcrumb-item v-for="(crumb, idx) in pathCrumbs" :key="idx">
            <span class="breadcrumb-link" @click="navigateTo(crumb.path)">{{ crumb.name }}</span>
          </el-breadcrumb-item>
        </el-breadcrumb>
        <div style="display:flex;gap:8px">
          <el-button size="default" @click="loadFiles"><el-icon><Refresh /></el-icon> 刷新</el-button>
          <el-button size="default" @click="triggerUpload" :disabled="uploading">
            <el-icon><Upload /></el-icon> {{ uploading ? '上传中...' : '上传文件' }}
          </el-button>
          <input ref="uploadRef" type="file" multiple style="display:none" @change="handleUpload" />
        </div>
      </div>

      <!-- Loading -->
      <div v-if="browsing" style="text-align:center;padding:60px;color:var(--text-muted)">
        <el-icon class="is-loading" size="32"><Loading /></el-icon>
        <div style="margin-top:12px;font-size:13px">加载中...</div>
      </div>

      <!-- Empty -->
      <div v-else-if="files.length === 0" style="text-align:center;padding:60px;color:var(--text-muted)">
        <el-icon size="48" color="#cbd5e1"><FolderOpened /></el-icon>
        <div style="margin-top:12px;font-size:14px">此目录为空</div>
      </div>

      <!-- Files grid -->
      <div v-else class="files-grid">
        <div
          v-for="f in files"
          :key="f.path"
          class="file-item"
          @dblclick="f.isDirectory ? navigateTo(f.path) : null"
        >
          <div class="file-actions">
            <el-popconfirm
              v-if="!f.isDirectory"
              title="确定要下载此文件吗？"
              confirm-button-text="下载"
              cancel-button-text="取消"
              @confirm="downloadFile(f)"
            >
              <template #reference>
                <div class="file-action-btn" title="下载"><el-icon size="12"><Download /></el-icon></div>
              </template>
            </el-popconfirm>
          </div>
          <div class="file-icon" @click="f.isDirectory ? navigateTo(f.path) : null">
            {{ f.isDirectory ? '📁' : getFileIcon(f.name) }}
          </div>
          <div class="file-name" :title="f.name">{{ f.name }}</div>
          <div class="file-meta">{{ f.isDirectory ? '文件夹' : formatSize(f.size) }}</div>
        </div>
      </div>
    </div>

    <!-- Add/Edit mount dialog -->
    <el-dialog
      v-model="showMountDialog"
      :title="editingMount ? '编辑挂载点' : '添加 WebDAV 挂载'"
      width="480px"
      :close-on-click-modal="false"
    >
      <div style="display:flex;flex-direction:column;gap:14px">
        <div class="form-group">
          <label class="form-label required">名称</label>
          <el-input v-model="mountForm.name" placeholder="如：坚果云、我的网盘" />
        </div>
        <div class="form-group">
          <label class="form-label required">WebDAV 地址 (URL)</label>
          <el-input v-model="mountForm.url" placeholder="如：https://dav.jianguoyun.com/dav/" />
          <div style="font-size:12px;color:var(--text-muted);margin-top:4px">填写 WebDAV 服务的完整地址</div>
        </div>
        <div class="form-group">
          <label class="form-label">用户名</label>
          <el-input v-model="mountForm.username" placeholder="WebDAV 用户名（可选）" />
        </div>
        <div class="form-group">
          <label class="form-label">密码</label>
          <el-input v-model="mountForm.password" type="password" :placeholder="editingMount ? '留空则不修改密码' : 'WebDAV 密码（可选）'" show-password />
        </div>
      </div>
      <template #footer>
        <el-button @click="testConnection" :loading="testing">测试连接</el-button>
        <el-button @click="showMountDialog = false">取消</el-button>
        <el-button type="primary" :loading="savingMount" @click="saveMount">{{ editingMount ? '保存' : '添加' }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, inject, onMounted } from 'vue'
import { webDavApi } from '../api/index.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'

const showToast = inject('showToast')

const mounts = ref([])
const selectedMount = ref(null)
const files = ref([])
const browsing = ref(false)
const currentPath = ref('')
const pathCrumbs = ref([])
const uploadRef = ref(null)
const uploading = ref(false)

const showMountDialog = ref(false)
const editingMount = ref(null)
const savingMount = ref(false)
const testing = ref(false)
const mountForm = ref({ name: '', url: '', username: '', password: '' })

async function loadMounts() {
  try {
    const res = await webDavApi.listMounts()
    mounts.value = res.data
  } catch(e) {
    showToast('加载挂载点失败', 'error')
  }
}

function openAddMount() {
  editingMount.value = null
  mountForm.value = { name: '', url: '', username: '', password: '' }
  showMountDialog.value = true
}

function openEditMount(m) {
  editingMount.value = m
  mountForm.value = { name: m.name, url: m.url, username: m.username || '', password: '' }
  showMountDialog.value = true
}

async function saveMount() {
  if (!mountForm.value.name?.trim()) { showToast('请输入名称', 'error'); return }
  if (!mountForm.value.url?.trim()) { showToast('请输入 WebDAV 地址', 'error'); return }
  savingMount.value = true
  try {
    if (editingMount.value) {
      await webDavApi.updateMount(editingMount.value.id, mountForm.value)
      showToast('挂载点已更新')
    } else {
      await webDavApi.createMount(mountForm.value)
      showToast('挂载点已添加')
    }
    showMountDialog.value = false
    await loadMounts()
  } catch(e) {
    showToast(e.response?.data?.message || '操作失败', 'error')
  } finally {
    savingMount.value = false
  }
}

async function deleteMount(m) {
  if (!confirm(`确定要删除挂载点「${m.name}」吗？`)) return
  try {
    await webDavApi.deleteMount(m.id)
    showToast('已删除')
    if (selectedMount.value?.id === m.id) { selectedMount.value = null; files.value = [] }
    await loadMounts()
  } catch(e) {
    showToast(e.response?.data?.message || '删除失败', 'error')
  }
}

async function testConnection() {
  if (!mountForm.value.url?.trim()) { showToast('请先填写 WebDAV 地址', 'error'); return }
  testing.value = true
  try {
    const res = await webDavApi.testConnection({
      url: mountForm.value.url,
      username: mountForm.value.username,
      password: mountForm.value.password
    })
    if (res.data.success) {
      showToast('连接测试成功！')
    } else {
      showToast('连接失败，请检查地址和账号密码', 'error')
    }
  } catch(e) {
    showToast('连接测试失败', 'error')
  } finally {
    testing.value = false
  }
}

function selectMount(m) {
  selectedMount.value = m
  currentPath.value = ''
  pathCrumbs.value = []
  loadFiles()
}

async function loadFiles() {
  if (!selectedMount.value) return
  browsing.value = true
  try {
    const res = await webDavApi.browse(selectedMount.value.id, currentPath.value || undefined)
    files.value = res.data
  } catch(e) {
    showToast('加载文件列表失败: ' + (e.response?.data?.message || e.message), 'error')
    files.value = []
  } finally {
    browsing.value = false
  }
}

function goToRoot() {
  currentPath.value = ''
  pathCrumbs.value = []
  loadFiles()
}

function navigateTo(path) {
  currentPath.value = path
  // Build breadcrumbs from path
  const parts = path.replace(/\/$/, '').split('/').filter(p => p)
  pathCrumbs.value = []
  let accumulated = ''
  for (const part of parts) {
    accumulated += '/' + part
    pathCrumbs.value.push({ name: part, path: accumulated + '/' })
  }
  loadFiles()
}

function triggerUpload() { uploadRef.value?.click() }

async function handleUpload(e) {
  const fileList = Array.from(e.target.files)
  if (!fileList.length) return
  uploading.value = true
  let ok = 0
  for (const f of fileList) {
    try {
      await webDavApi.upload(selectedMount.value.id, currentPath.value || '/', f)
      ok++
    } catch(err) {
      showToast(`上传 ${f.name} 失败`, 'error')
    }
  }
  if (ok > 0) { showToast(`成功上传 ${ok} 个文件`); loadFiles() }
  e.target.value = ''
  uploading.value = false
}

async function downloadFile(f) {
  try {
    const res = await webDavApi.download(selectedMount.value.id, f.path, f.name)
    const url = URL.createObjectURL(res.data)
    const a = document.createElement('a')
    a.href = url; a.download = f.name; a.click()
    URL.revokeObjectURL(url)
  } catch(e) {
    showToast('下载失败', 'error')
  }
}

function getFileIcon(name) {
  if (!name) return '📄'
  const ext = name.split('.').pop().toLowerCase()
  const map = {
    pdf: '📕', doc: '📘', docx: '📘', xls: '📗', xlsx: '📗',
    ppt: '📙', pptx: '📙', txt: '📄', csv: '📊',
    jpg: '🖼️', jpeg: '🖼️', png: '🖼️', gif: '🖼️', bmp: '🖼️', webp: '🖼️',
    mp4: '🎬', avi: '🎬', mov: '🎬', mkv: '🎬',
    mp3: '🎵', wav: '🎵', flac: '🎵',
    zip: '🗜️', rar: '🗜️', '7z': '🗜️', tar: '🗜️', gz: '🗜️',
    js: '💻', ts: '💻', vue: '💻', html: '💻', css: '💻', json: '💻',
  }
  return map[ext] || '📄'
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return '-'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB'
  return (bytes / 1024 / 1024 / 1024).toFixed(2) + ' GB'
}

async function refreshWebDavPage() {
  await loadMounts()
  if (!selectedMount.value) return
  const matchedMount = mounts.value.find(m => m.id === selectedMount.value.id)
  if (!matchedMount) {
    selectedMount.value = null
    files.value = []
    return
  }
  selectedMount.value = matchedMount
  await loadFiles()
}

useResumeRefresh(refreshWebDavPage)

onMounted(loadMounts)
</script>

<style scoped>
.mount-card {
  background: #fff;
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 14px 16px;
  cursor: pointer;
  transition: all 0.15s;
}
.mount-card:hover { border-color: var(--primary); box-shadow: 0 2px 8px rgba(37,99,235,0.08); }
.mount-card-active { border-color: var(--primary); background: #eff6ff; box-shadow: 0 2px 8px rgba(37,99,235,0.12); }
.breadcrumb-link { cursor: pointer; color: var(--primary); font-weight: 500; transition: color 0.15s; }
.breadcrumb-link:hover { color: var(--primary-dark); text-decoration: underline; }
</style>
