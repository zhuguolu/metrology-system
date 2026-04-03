import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '../api/index.js'

export const useAuthStore = defineStore('auth', () => {
  const token      = ref(localStorage.getItem('token') || '')
  const username   = ref(localStorage.getItem('username') || '')
  const userId     = ref(localStorage.getItem('userId') || '')
  const role       = ref(localStorage.getItem('role') || 'USER')
  const permissions = ref(JSON.parse(localStorage.getItem('permissions') || '[]'))
  const fileReadonlyFolders = ref(JSON.parse(localStorage.getItem('fileReadonlyFolders') || '[]'))
  const department = ref(localStorage.getItem('department') || '')
  const departments = ref(JSON.parse(localStorage.getItem('departments') || '[]'))

  const isAdmin = computed(() => role.value === 'ADMIN')
  const canView   = computed(() => isAdmin.value || permissions.value.includes('DEVICE_VIEW'))
  const canCreate = computed(() => isAdmin.value || permissions.value.includes('DEVICE_CREATE'))
  const canUpdate = computed(() => isAdmin.value || permissions.value.includes('DEVICE_UPDATE'))
  const canDelete = computed(() => isAdmin.value || permissions.value.includes('DEVICE_DELETE'))
  const canRecordCalibration = computed(() => isAdmin.value || permissions.value.includes('CALIBRATION_RECORD'))
  const canManageStatus = computed(() => isAdmin.value || permissions.value.includes('STATUS_MANAGE'))
  const canManageUsers  = computed(() => isAdmin.value || permissions.value.includes('USER_MANAGE'))
  const canAccessFiles  = computed(() => isAdmin.value || permissions.value.includes('FILE_ACCESS') || fileReadonlyFolders.value.length > 0)
  const canAccessWebdav = computed(() => isAdmin.value || permissions.value.includes('WEBDAV_ACCESS'))

  function setAuth(data) {
    token.value = data.token
    username.value = data.username
    userId.value = data.userId
    role.value = data.role || 'USER'
    permissions.value = data.permissions || []
    fileReadonlyFolders.value = data.fileReadonlyFolders || []
    department.value = data.department || ''
    departments.value = data.departments || []
    localStorage.setItem('token', data.token)
    localStorage.setItem('username', data.username)
    localStorage.setItem('userId', data.userId)
    localStorage.setItem('role', role.value)
    localStorage.setItem('permissions', JSON.stringify(permissions.value))
    localStorage.setItem('fileReadonlyFolders', JSON.stringify(fileReadonlyFolders.value))
    localStorage.setItem('department', department.value)
    localStorage.setItem('departments', JSON.stringify(departments.value))
  }

  function clearAuth() {
    token.value = ''; username.value = ''; userId.value = ''
    role.value = 'USER'; permissions.value = []
    fileReadonlyFolders.value = []
    department.value = ''; departments.value = []
    localStorage.removeItem('token'); localStorage.removeItem('username')
    localStorage.removeItem('userId'); localStorage.removeItem('role')
    localStorage.removeItem('permissions')
    localStorage.removeItem('fileReadonlyFolders')
    localStorage.removeItem('department'); localStorage.removeItem('departments')
  }

  async function login(credentials) {
    const res = await authApi.login(credentials)
    setAuth(res.data)
  }

  async function register(credentials) {
    const res = await authApi.register(credentials)
    setAuth(res.data)
  }

  function logout() { clearAuth() }

  function updateFromResponse(data) {
    setAuth(data)
  }

  /** 向后端刷新当前用户权限（无需重新登录），管理员更改权限后立即生效 */
  async function refreshPermissions() {
    if (!token.value) return
    try {
      const res = await authApi.me()
      if (res.data) {
        permissions.value = res.data.permissions || []
        fileReadonlyFolders.value = res.data.fileReadonlyFolders || []
        role.value = res.data.role || 'USER'
        department.value = res.data.department || ''
        departments.value = res.data.departments || []
        localStorage.setItem('permissions', JSON.stringify(permissions.value))
        localStorage.setItem('fileReadonlyFolders', JSON.stringify(fileReadonlyFolders.value))
        localStorage.setItem('role', role.value)
        localStorage.setItem('department', department.value)
        localStorage.setItem('departments', JSON.stringify(departments.value))
      }
    } catch { /* 静默失败，不影响现有会话 */ }
  }

  return {
    token, username, userId, role, permissions, fileReadonlyFolders, department, departments,
    isAdmin, canView, canCreate, canUpdate, canDelete, canRecordCalibration, canManageStatus, canManageUsers,
    canAccessFiles, canAccessWebdav,
    login, register, logout, updateFromResponse, refreshPermissions
  }
})
