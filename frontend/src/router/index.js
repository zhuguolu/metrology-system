import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'
import LoginView from '../views/LoginView.vue'
import MainLayout from '../views/MainLayout.vue'
import DashboardView from '../views/DashboardView.vue'
import EquipmentView from '../views/EquipmentView.vue'
import CalibrationView from '../views/CalibrationView.vue'
import SettingsView from '../views/SettingsView.vue'
import DeviceStatusView from '../views/DeviceStatusView.vue'
import UserManagementView from '../views/UserManagementView.vue'
import TodoView from '../views/TodoView.vue'
import DepartmentView from '../views/DepartmentView.vue'
import FilesView from '../views/FilesView.vue'
import WebDavView from '../views/WebDavView.vue'
import AuditView from '../views/AuditView.vue'
import ChangeRecordView from '../views/ChangeRecordView.vue'
import PublicShareView from '../views/PublicShareView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: LoginView },
    { path: '/share/:token', component: PublicShareView },
    {
      path: '/',
      component: MainLayout,
      meta: { requiresAuth: true },
      children: [
        { path: '', redirect: '/dashboard' },
        { path: 'dashboard', component: DashboardView },
        { path: 'equipment', component: EquipmentView },
        { path: 'device-status', component: DeviceStatusView },
        { path: 'calibration', component: CalibrationView },
        { path: 'todo', component: TodoView },
        { path: 'departments', component: DepartmentView, meta: { requiresAdmin: true } },
        { path: 'users', component: UserManagementView },
        { path: 'settings', component: SettingsView },
        { path: 'files', component: FilesView },
        { path: 'webdav', component: WebDavView },
        { path: 'audit', component: AuditView },
        { path: 'change-records', component: ChangeRecordView },
      ]
    }
  ]
})

router.beforeEach((to) => {
  const token = localStorage.getItem('token')
  if (to.meta.requiresAuth && !token) return '/login'
  if (to.path === '/login' && token) return '/dashboard'
  // 部门管理仅管理员可访问
  if (to.meta.requiresAdmin) {
    const role = localStorage.getItem('role')
    if (role !== 'ADMIN') return '/dashboard'
  }
  // 每次路由跳转时静默刷新权限，使管理员授权变更立即生效
  if (token) {
    try {
      const authStore = useAuthStore()
      authStore.refreshPermissions()
    } catch {}
  }
})

export default router
