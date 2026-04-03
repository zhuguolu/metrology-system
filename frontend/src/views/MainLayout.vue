<template>
  <div class="app-shell" :class="{ 'sidebar-collapsed': collapsed }">
    <div v-if="mobileOpen" class="sidebar-overlay" @click="mobileOpen = false"></div>

    <aside :class="{ 'sidebar-mobile-open': mobileOpen }">
      <div class="logo">
        <div class="logo-icon"><el-icon><DataAnalysis /></el-icon></div>
        <div class="logo-copy">
          <span class="logo-text">校准管理系统</span>
          <span class="logo-subtitle">Calibration Management System</span>
        </div>
        <button class="sidebar-close-btn" @click="mobileOpen = false" title="关闭">✕</button>
      </div>

      <nav class="nav">
        <div class="nav-section-label">模块导航</div>
        <router-link
          v-for="item in navItems"
          :key="item.path"
          :to="item.path"
          :class="['nav-item', `nav-${item.key}`, isActive(item.path) ? 'active' : '']"
          :data-tip="item.tip"
          @click="handleNavClick(item)"
        >
          <span class="nav-icon">
            <el-icon><component :is="item.icon" /></el-icon>
          </span>
          <span class="nav-label">{{ item.label }}</span>
          <span v-if="item.badge" class="nav-badge">{{ item.badge }}</span>
        </router-link>
      </nav>

        <div class="sidebar-footer">
          <div class="user-info">
            <div class="user-avatar">{{ authStore.username.charAt(0).toUpperCase() }}</div>
            <div class="user-info-text">
              <div class="user-name">{{ authStore.username }}</div>
              <div class="user-role">{{ authStore.isAdmin ? '管理员' : '普通用户' }}</div>
            </div>
          </div>
        <button class="btn-logout" @click="openLogoutDialog">
          <span class="logout-icon"><el-icon><SwitchButton /></el-icon></span>
          <span class="logout-text">退出登录</span>
        </button>
      </div>

      <button
        class="sidebar-collapse-btn"
        @click="toggleCollapse"
        :title="collapsed ? '展开侧边栏' : '收起侧边栏'"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polyline v-if="!collapsed" points="15 18 9 12 15 6"></polyline>
          <polyline v-else points="9 18 15 12 9 6"></polyline>
        </svg>
      </button>
    </aside>

    <main>
      <div class="topbar">
        <div class="topbar-left">
          <button class="hamburger-btn" @click="mobileOpen = true" title="菜单">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
              <line x1="3" y1="6" x2="21" y2="6" />
              <line x1="3" y1="12" x2="21" y2="12" />
              <line x1="3" y1="18" x2="21" y2="18" />
            </svg>
          </button>
          <div class="page-title">{{ pageTitle }}</div>
        </div>
        <div class="topbar-right">
          <button class="workbench-btn" @click="workbenchOpen = true" title="打开工作台">
            <span class="workbench-btn-icon"><el-icon><Menu /></el-icon></span>
            <span class="workbench-btn-text">工作台</span>
          </button>
          <button class="refresh-btn" @click="handleRefresh" title="刷新页面缓存">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="23 4 23 10 17 10" />
              <polyline points="1 20 1 14 7 14" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
          </button>
          <span class="topbar-date">{{ today }}</span>
        </div>
      </div>

      <div class="content">
        <router-view />
      </div>
    </main>

    <transition name="workbench-fade">
      <div v-if="workbenchOpen" class="workbench-mask" @click.self="workbenchOpen = false">
        <div class="workbench-panel">
          <div class="workbench-handle"></div>
          <div class="workbench-header">
            <div>
              <div class="workbench-eyebrow">Module Center</div>
              <div class="workbench-title">工作台</div>
              <div class="workbench-subtitle">点击进入你要操作的模块</div>
            </div>
            <button class="workbench-close" @click="workbenchOpen = false" title="关闭工作台">✕</button>
          </div>

          <div class="workbench-body">
            <section v-for="group in workbenchGroups" :key="group.title" class="workbench-group">
              <div class="workbench-group-title">{{ group.title }}</div>
              <div class="workbench-grid">
                <button
                  v-for="item in group.items"
                  :key="item.path"
                  class="workbench-card"
                  :class="{ active: isActive(item.path) }"
                  @click="goToModule(item)"
                >
                  <span :class="['workbench-icon', `nav-${item.key}`]">
                    <el-icon><component :is="item.icon" /></el-icon>
                  </span>
                  <span class="workbench-card-main">
                    <span class="workbench-card-title">{{ item.label }}</span>
                    <span class="workbench-card-desc">{{ item.desc }}</span>
                  </span>
                  <span v-if="item.badge" class="workbench-card-badge">{{ item.badge }}</span>
                </button>
              </div>
            </section>
          </div>
        </div>
      </div>
    </transition>

    <transition name="logout-fade">
      <div v-if="showLogoutDialog" class="logout-mask" @click.self="closeLogoutDialog">
        <div class="logout-dialog" role="dialog" aria-modal="true" aria-labelledby="logout-title">
          <button class="logout-dialog-close" @click="closeLogoutDialog" title="关闭">✕</button>
          <div class="logout-dialog-badge">Account</div>
          <div class="logout-dialog-icon">
            <el-icon><SwitchButton /></el-icon>
          </div>
          <div id="logout-title" class="logout-dialog-title">退出当前登录</div>
          <div class="logout-dialog-desc">退出后将返回登录页，如需继续使用系统可再次登录。</div>
          <div class="logout-dialog-user">
            <span class="logout-dialog-user-label">当前账号</span>
            <span class="logout-dialog-user-name">{{ authStore.username }}</span>
          </div>
          <div class="logout-dialog-actions">
            <button class="logout-action logout-action-secondary" @click="closeLogoutDialog">再看看</button>
            <button class="logout-action logout-action-danger" @click="confirmLogout">退出登录</button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'
import { auditApi } from '../api/index.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import {
  Calendar,
  Checked,
  Connection,
  DataAnalysis,
  Document,
  Tickets,
  FolderOpened,
  List,
  Menu,
  OfficeBuilding,
  Setting,
  SwitchButton,
  Tools,
  User
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const mobileOpen = ref(false)
const collapsed = ref(false)
const workbenchOpen = ref(false)
const showLogoutDialog = ref(false)
const pendingAuditCount = ref(0)
const today = new Date().toLocaleDateString('zh-CN', {
  year: 'numeric',
  month: 'long',
  day: 'numeric'
})

const TITLES = {
  '/dashboard': '总览看板',
  '/equipment': '设备台账',
  '/device-status': '使用状态管理',
  '/calibration': '校准管理',
  '/todo': '我的待办',
  '/files': '我的文件',
  '/webdav': '网络挂载',
  '/departments': '部门管理',
  '/users': '用户管理',
  '/settings': '系统设置',
  '/audit': '数据审核',
  '/change-records': '变更记录'
}

const pageTitle = computed(() => TITLES[route.path] || '计量管理系统')

const navItems = computed(() => {
  const items = [
    {
      key: 'dashboard',
      path: '/dashboard',
      label: '总览看板',
      tip: '总览看板',
      desc: '查看系统数据总览和趋势',
      icon: DataAnalysis,
      show: true,
      badge: 0
    },
    {
      key: 'equipment',
      path: '/equipment',
      label: '设备台账',
      tip: '设备台账',
      desc: '新增、查询和编辑设备资料',
      icon: Tools,
      show: true,
      badge: 0
    },
    {
      key: 'calibration',
      path: '/calibration',
      label: '校准管理',
      tip: '校准管理',
      desc: '记录校准并管理有效期',
      icon: Calendar,
      show: true,
      badge: 0
    },
    {
      key: 'todo',
      path: '/todo',
      label: '我的待办',
      tip: '我的待办',
      desc: '集中处理待校准任务',
      icon: List,
      show: true,
      badge: 0
    },
    {
      key: 'files',
      path: '/files',
      label: '我的文件',
      tip: '我的文件',
      desc: '查看和管理上传文件',
      icon: FolderOpened,
      show: authStore.canAccessFiles,
      badge: 0
    },
    {
      key: 'audit',
      path: '/audit',
      label: '数据审核',
      tip: '数据审核',
      desc: '审批设备变更和操作记录',
      icon: Document,
      show: true,
      badge: authStore.isAdmin ? pendingAuditCount.value : 0
    },
    {
      key: 'status',
      path: '/device-status',
      label: '使用状态',
      tip: '使用状态',
      desc: '维护设备状态选项',
      icon: Checked,
      show: true,
      badge: 0
    },
    {
      key: 'dept',
      path: '/departments',
      label: '部门管理',
      tip: '部门管理',
      desc: '维护部门树和层级关系',
      icon: OfficeBuilding,
      show: authStore.isAdmin,
      badge: 0
    },
    {
      key: 'changes',
      path: '/change-records',
      label: '变更记录',
      tip: '变更记录',
      desc: '查看设备新增、修改和删除记录',
      icon: Tickets,
      show: true,
      badge: 0
    },
    {
      key: 'webdav',
      path: '/webdav',
      label: '网络挂载',
      tip: '网络挂载',
      desc: '通过 WebDAV 管理目录',
      icon: Connection,
      show: authStore.canAccessWebdav,
      badge: 0
    },
    {
      key: 'users',
      path: '/users',
      label: '用户管理',
      tip: '用户管理',
      desc: '分配账号角色和权限',
      icon: User,
      show: authStore.canManageUsers,
      badge: 0
    },
    {
      key: 'settings',
      path: '/settings',
      label: '系统设置',
      tip: '系统设置',
      desc: '调整全局参数和策略',
      icon: Setting,
      show: true,
      badge: 0
    }
  ]

  return items.filter(item => item.show)
})

const workbenchGroups = computed(() => {
  const workbenchPaths = new Set(['/equipment', '/calibration', '/todo', '/audit', '/files'])
  const items = navItems.value.filter(item => workbenchPaths.has(item.path))

  return items.length
    ? [{ title: '工作模块', items }]
    : []
})

function isActive(path) {
  return route.path === path
}

function toggleCollapse() {
  collapsed.value = !collapsed.value
  localStorage.setItem('sidebar-collapsed', collapsed.value ? '1' : '0')
}

function handleRefresh() {
  const token = localStorage.getItem('token')
  const username = localStorage.getItem('username')
  const userId = localStorage.getItem('userId')
  const role = localStorage.getItem('role')
  const permissions = localStorage.getItem('permissions')
  const sidebarState = localStorage.getItem('sidebar-collapsed')

  localStorage.clear()

  if (token) localStorage.setItem('token', token)
  if (username) localStorage.setItem('username', username)
  if (userId) localStorage.setItem('userId', userId)
  if (role) localStorage.setItem('role', role)
  if (permissions) localStorage.setItem('permissions', permissions)
  if (sidebarState) localStorage.setItem('sidebar-collapsed', sidebarState)

  window.location.reload()
}

function openLogoutDialog() {
  showLogoutDialog.value = true
}

function closeLogoutDialog() {
  showLogoutDialog.value = false
}

function confirmLogout() {
  closeLogoutDialog()
  authStore.logout()
  router.push('/login')
}

async function loadPendingCount() {
  if (!authStore.isAdmin) return
  try {
    const response = await auditApi.pending()
    pendingAuditCount.value = response.data.length
  } catch (error) {}
}

async function refreshLayoutState() {
  await authStore.refreshPermissions()
  await loadPendingCount()
}

function handleNavClick(item) {
  mobileOpen.value = false
  if (item.path === '/audit') {
    loadPendingCount()
  }
}

function goToModule(item) {
  workbenchOpen.value = false
  mobileOpen.value = false

  if (item.path === '/audit') {
    loadPendingCount()
  }

  if (route.path !== item.path) {
    router.push(item.path)
  }
}

watch(
  () => route.path,
  () => {
    mobileOpen.value = false
    workbenchOpen.value = false
  }
)

useResumeRefresh(refreshLayoutState, { minIntervalMs: 12000 })

onMounted(() => {
  collapsed.value = localStorage.getItem('sidebar-collapsed') === '1'
  loadPendingCount()
})
</script>

<style scoped>
.app-shell {
  display: flex;
  width: 100%;
  height: 100vh;
  overflow: hidden;
  --sidebar-w: 240px;
  --sidebar-w-collapsed: 64px;
}

.sidebar-collapse-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 40px;
  border: none;
  background: transparent;
  cursor: pointer;
  color: #94a3b8;
  border-top: 1px solid #f1f5f9;
  transition: color 0.18s, background 0.18s;
  flex-shrink: 0;
}

.sidebar-collapse-btn:hover {
  background: #f8fafc;
  color: #2563eb;
}

.nav-label {
  transition: opacity 0.2s, width 0.2s;
  white-space: nowrap;
}

.user-info-text {
  overflow: hidden;
  transition: opacity 0.2s;
}

.logout-text {
  transition: opacity 0.2s;
  white-space: nowrap;
}

.logout-icon {
  flex-shrink: 0;
}

.app-shell.sidebar-collapsed :deep(aside) {
  width: var(--sidebar-w-collapsed);
}

.app-shell.sidebar-collapsed :deep(.logo-text) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.logo-subtitle) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.logo-copy) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.nav-section-label) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.nav-label) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.nav-item) {
  justify-content: center;
  padding: 10px;
}

.app-shell.sidebar-collapsed :deep(.nav-badge) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.user-info-text) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.user-info) {
  justify-content: center;
  padding: 8px;
}

.app-shell.sidebar-collapsed :deep(.logout-text) {
  display: none;
}

.app-shell.sidebar-collapsed :deep(.btn-logout) {
  justify-content: center;
}

.app-shell.sidebar-collapsed :deep(.sidebar-footer) {
  padding: 8px 6px 0;
}

@media (max-width: 768px) {
  .sidebar-collapse-btn {
    display: none;
  }
}

.refresh-btn,
.workbench-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(219, 234, 254, 0.95);
  background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  color: #64748b;
  cursor: pointer;
  transition: all 0.18s;
  flex-shrink: 0;
  box-shadow: 0 10px 22px rgba(37, 99, 235, 0.08);
}

.refresh-btn {
  width: 32px;
  height: 32px;
  border-radius: 12px;
}

.refresh-btn:hover,
.workbench-btn:hover {
  background: linear-gradient(135deg, #ffffff, #eff6ff);
  color: #2563eb;
  border-color: #bfdbfe;
  transform: translateY(-1px);
  box-shadow: 0 14px 28px rgba(37, 99, 235, 0.14);
}

.workbench-btn {
  display: none;
  gap: 8px;
  padding: 0 15px;
  height: 36px;
  border-radius: 999px;
  font-size: 12.5px;
  font-weight: 800;
  position: relative;
  overflow: hidden;
  color: #1d4ed8;
  border-color: rgba(147, 197, 253, 0.95);
  background:
    linear-gradient(135deg, rgba(219, 234, 254, 0.5), rgba(255, 255, 255, 0) 42%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  box-shadow:
    0 10px 22px rgba(96, 165, 250, 0.12),
    inset 0 1px 0 rgba(255, 255, 255, 0.75);
}

.workbench-btn::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(255,255,255,0.55), rgba(255,255,255,0) 46%);
  pointer-events: none;
}

.workbench-btn::after {
  content: '';
  position: absolute;
  inset: 1px;
  border-radius: inherit;
  border: 1px solid rgba(255,255,255,0.68);
  pointer-events: none;
}

.workbench-btn-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 6px;
  background: rgba(219, 234, 254, 0.55);
  font-size: 13px;
  color: #2563eb;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.45);
}

.workbench-btn:hover .workbench-btn-icon {
  background: rgba(219, 234, 254, 0.82);
  color: #1d4ed8;
}

.workbench-btn-text {
  position: relative;
  z-index: 1;
  letter-spacing: 0.01em;
}

.workbench-mask {
  position: fixed;
  inset: 0;
  z-index: 420;
  background: rgba(15, 23, 42, 0.42);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding: 18px 12px calc(18px + env(safe-area-inset-bottom, 0px));
}

.workbench-panel {
  width: min(100%, 720px);
  max-height: 84vh;
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.75), transparent 28%),
    linear-gradient(180deg, #ffffff, #f8fbff);
  border: 1px solid rgba(191, 219, 254, 0.9);
  border-radius: 24px;
  box-shadow: 0 24px 56px rgba(15, 23, 42, 0.28);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  animation: workbenchIn 0.28s cubic-bezier(0.22, 1, 0.36, 1);
}

.workbench-handle {
  width: 52px;
  height: 5px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.42);
  margin: 10px auto 2px;
}

.workbench-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding: 18px 18px 14px;
  border-bottom: 1px solid #e2e8f0;
  background: linear-gradient(135deg, rgba(219, 234, 254, 0.92), rgba(255, 255, 255, 0.96));
}

.workbench-eyebrow {
  display: inline-flex;
  align-items: center;
  margin-bottom: 8px;
  padding: 4px 9px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.1);
  color: #1d4ed8;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.workbench-title {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
}

.workbench-subtitle {
  margin-top: 4px;
  font-size: 12.5px;
  color: #64748b;
}

.workbench-close {
  width: 32px;
  height: 32px;
  border: 1px solid #dbe3ef;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.86);
  color: #475569;
  cursor: pointer;
  font-size: 16px;
  line-height: 1;
  flex-shrink: 0;
}

.workbench-close:hover {
  background: #eff6ff;
  color: #1d4ed8;
  border-color: #bfdbfe;
}

.workbench-body {
  padding: 16px 18px 18px;
  overflow: auto;
}

.workbench-group + .workbench-group {
  margin-top: 18px;
}

.workbench-group-title {
  margin-bottom: 10px;
  font-size: 12px;
  font-weight: 800;
  color: #475569;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.workbench-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.workbench-card {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  text-align: left;
  padding: 14px 14px 14px 12px;
  border-radius: 18px;
  border: 1px solid rgba(219, 227, 239, 0.9);
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(248, 250, 252, 0.98));
  cursor: pointer;
  transition: transform 0.18s, box-shadow 0.18s, border-color 0.18s, background 0.18s;
}

.workbench-card:hover {
  transform: translateY(-2px);
  border-color: #bfdbfe;
  box-shadow: 0 14px 28px rgba(37, 99, 235, 0.14);
}

.workbench-card:active {
  transform: translateY(0) scale(0.985);
  box-shadow: 0 8px 18px rgba(37, 99, 235, 0.14);
}

.workbench-card.active {
  border-color: #93c5fd;
  background:
    linear-gradient(135deg, rgba(219, 234, 254, 0.92), rgba(255, 255, 255, 0.98));
  box-shadow: 0 14px 30px rgba(37, 99, 235, 0.16);
}

.workbench-icon {
  width: 44px;
  height: 44px;
  border-radius: 14px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 19px;
  flex-shrink: 0;
}

.workbench-card-main {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.workbench-card-title {
  font-size: 14px;
  font-weight: 700;
  color: #0f172a;
}

.workbench-card-desc {
  font-size: 12px;
  line-height: 1.45;
  color: #64748b;
}

.workbench-card::after {
  content: '';
  position: absolute;
  right: 14px;
  bottom: 14px;
  width: 20px;
  height: 20px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.12);
  opacity: 0;
  transform: translateX(-2px);
  transition: opacity 0.18s, transform 0.18s;
}

.workbench-card:hover::after,
.workbench-card.active::after {
  opacity: 1;
  transform: translateX(0);
}

.workbench-card:active::after {
  opacity: 1;
  transform: translateX(0) scale(0.92);
}

.workbench-card-badge {
  position: absolute;
  top: 10px;
  right: 10px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: #ef4444;
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.nav-dashboard .nav-icon,
.workbench-icon.nav-dashboard {
  background: linear-gradient(135deg, #dbeafe, #bfdbfe);
  color: #1d4ed8;
}

.nav-equipment .nav-icon,
.workbench-icon.nav-equipment {
  background: linear-gradient(135deg, #ccfbf1, #99f6e4);
  color: #0f766e;
}

.nav-calibration .nav-icon,
.workbench-icon.nav-calibration {
  background: linear-gradient(135deg, #ffedd5, #fed7aa);
  color: #c2410c;
}

.nav-todo .nav-icon,
.workbench-icon.nav-todo {
  background: linear-gradient(135deg, #fee2e2, #fecaca);
  color: #b91c1c;
}

.nav-status .nav-icon,
.workbench-icon.nav-status {
  background: linear-gradient(135deg, #dcfce7, #bbf7d0);
  color: #15803d;
}

.nav-files .nav-icon,
.workbench-icon.nav-files {
  background: linear-gradient(135deg, #e0e7ff, #c7d2fe);
  color: #4338ca;
}

.nav-webdav .nav-icon,
.workbench-icon.nav-webdav {
  background: linear-gradient(135deg, #cffafe, #a5f3fc);
  color: #0e7490;
}

.nav-dept .nav-icon,
.workbench-icon.nav-dept {
  background: linear-gradient(135deg, #fef3c7, #fde68a);
  color: #a16207;
}

.nav-users .nav-icon,
.workbench-icon.nav-users {
  background: linear-gradient(135deg, #fce7f3, #fbcfe8);
  color: #be185d;
}

.nav-audit .nav-icon,
.workbench-icon.nav-audit {
  background: linear-gradient(135deg, #ede9fe, #ddd6fe);
  color: #6d28d9;
}

.nav-changes .nav-icon,
.workbench-icon.nav-changes {
  background: linear-gradient(135deg, #dbeafe, #c7d2fe);
  color: #1d4ed8;
}

.nav-settings .nav-icon,
.workbench-icon.nav-settings {
  background: linear-gradient(135deg, #e2e8f0, #cbd5e1);
  color: #475569;
}

.nav-item.active .nav-icon {
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.12);
  transform: translateY(-1px);
}

@media (max-width: 768px) {
  .workbench-btn {
    display: inline-flex;
  }
}

@media (max-width: 640px) {
  .workbench-mask {
    padding: 12px 10px calc(12px + env(safe-area-inset-bottom, 0px));
  }

  .workbench-panel {
    width: 100%;
    max-height: 88vh;
    border-radius: 22px;
  }

  .workbench-header {
    padding: 16px 16px 12px;
  }

  .workbench-body {
    padding: 14px 16px 16px;
  }

  .workbench-grid {
    grid-template-columns: 1fr;
  }

  .workbench-card {
    padding: 13px 13px 13px 12px;
  }
}

@keyframes workbenchIn {
  from {
    transform: translateY(24px) scale(0.98);
    opacity: 0.84;
  }
  to {
    transform: translateY(0) scale(1);
    opacity: 1;
  }
}

.workbench-fade-enter-active,
.workbench-fade-leave-active {
  transition: opacity 0.22s ease;
}

.workbench-fade-enter-active .workbench-panel,
.workbench-fade-leave-active .workbench-panel {
  transition: transform 0.28s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.22s ease;
}

.workbench-fade-enter-from,
.workbench-fade-leave-to {
  opacity: 0;
}

.workbench-fade-enter-from .workbench-panel,
.workbench-fade-leave-to .workbench-panel {
  transform: translateY(18px) scale(0.985);
  opacity: 0.88;
}

.logout-mask {
  position: fixed;
  inset: 0;
  z-index: 430;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 18px;
  background: rgba(15, 23, 42, 0.48);
  backdrop-filter: blur(10px);
}

.logout-dialog {
  position: relative;
  width: min(100%, 420px);
  padding: 24px 24px 22px;
  border-radius: 28px;
  border: 1px solid rgba(191, 219, 254, 0.9);
  background:
    radial-gradient(circle at top right, rgba(254, 202, 202, 0.72), transparent 28%),
    radial-gradient(circle at top left, rgba(219, 234, 254, 0.88), transparent 34%),
    linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: 0 28px 70px rgba(15, 23, 42, 0.34);
  text-align: center;
}

.logout-dialog-close {
  position: absolute;
  top: 14px;
  right: 14px;
  width: 34px;
  height: 34px;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: rgba(255, 255, 255, 0.86);
  color: #64748b;
  font-size: 16px;
  line-height: 1;
  cursor: pointer;
}

.logout-dialog-close:hover {
  border-color: #fecaca;
  background: #fff1f2;
  color: #dc2626;
}

.logout-dialog-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.1);
  color: #1d4ed8;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.logout-dialog-icon {
  width: 72px;
  height: 72px;
  margin: 16px auto 12px;
  border-radius: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #fee2e2, #fecaca);
  color: #dc2626;
  font-size: 30px;
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.65), 0 14px 28px rgba(239, 68, 68, 0.18);
}

.logout-dialog-title {
  font-size: 24px;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -0.02em;
}

.logout-dialog-desc {
  margin-top: 10px;
  font-size: 14px;
  line-height: 1.65;
  color: #64748b;
}

.logout-dialog-user {
  margin-top: 18px;
  padding: 12px 14px;
  border-radius: 16px;
  border: 1px solid #dbeafe;
  background: rgba(239, 246, 255, 0.84);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  text-align: left;
}

.logout-dialog-user-label {
  font-size: 12px;
  color: #64748b;
}

.logout-dialog-user-name {
  font-size: 14px;
  font-weight: 800;
  color: #1e3a8a;
  word-break: break-word;
}

.logout-dialog-actions {
  margin-top: 20px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.logout-action {
  min-height: 46px;
  border-radius: 14px;
  border: 1px solid transparent;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
  transition: transform 0.16s ease, box-shadow 0.16s ease, border-color 0.16s ease, background 0.16s ease;
}

.logout-action:hover {
  transform: translateY(-1px);
}

.logout-action-secondary {
  border-color: #dbe3ef;
  background: #fff;
  color: #475569;
}

.logout-action-secondary:hover {
  border-color: #bfdbfe;
  background: #eff6ff;
  color: #1d4ed8;
}

.logout-action-danger {
  background: linear-gradient(135deg, #ef4444, #dc2626);
  color: #fff;
  box-shadow: 0 12px 24px rgba(239, 68, 68, 0.24);
}

.logout-action-danger:hover {
  box-shadow: 0 16px 28px rgba(239, 68, 68, 0.28);
}

.logout-fade-enter-active,
.logout-fade-leave-active {
  transition: opacity 0.2s ease;
}

.logout-fade-enter-active .logout-dialog,
.logout-fade-leave-active .logout-dialog {
  transition: transform 0.24s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.2s ease;
}

.logout-fade-enter-from,
.logout-fade-leave-to {
  opacity: 0;
}

.logout-fade-enter-from .logout-dialog,
.logout-fade-leave-to .logout-dialog {
  transform: translateY(16px) scale(0.97);
  opacity: 0.9;
}

@media (max-width: 640px) {
  .logout-mask {
    padding: 16px;
  }

  .logout-dialog {
    width: 100%;
    padding: 22px 18px 18px;
    border-radius: 24px;
  }

  .logout-dialog-title {
    font-size: 22px;
  }

  .logout-dialog-actions {
    grid-template-columns: 1fr;
  }
}
</style>

