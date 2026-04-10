import axios from 'axios'

const api = axios.create({ baseURL: '/api', timeout: 30000 })
const publicApi = axios.create({ baseURL: '/api', timeout: 30000 })
const transferApi = axios.create({ baseURL: '/api', timeout: 0 })
const publicTransferApi = axios.create({ baseURL: '/api', timeout: 0 })

let authRecheckPromise = null
let authRedirecting = false

function attachAuthRequestInterceptor(client) {
  client.interceptors.request.use(config => {
    const token = localStorage.getItem('token')
    if (token) config.headers.Authorization = `Bearer ${token}`
    return config
  })
}

async function recheckSession() {
  const token = localStorage.getItem('token')
  if (!token) return false
  if (authRecheckPromise) return authRecheckPromise

  authRecheckPromise = axios.get('/api/auth/me', {
    timeout: 10000,
    headers: {
      Authorization: `Bearer ${token}`,
    },
  }).then(() => true)
    .catch(error => error?.response?.status !== 401)
    .finally(() => {
      authRecheckPromise = null
    })

  return authRecheckPromise
}

function redirectToLogin() {
  if (authRedirecting) return
  authRedirecting = true
  localStorage.clear()
  window.location.href = '/login'
}

async function handleAuthResponseError(err) {
  if (err.response?.status === 401) {
    const requestURL = String(err?.config?.url || '')
    if (!requestURL.includes('/auth/login')) {
      const stillValid = await recheckSession()
      if (!stillValid) {
        redirectToLogin()
      }
    }
  } else if (err.response?.status === 403) {
    const token = localStorage.getItem('token')
    if (!token) {
      redirectToLogin()
    }
  } else if (!err.response) {
    console.error('Network error, please check your connection')
  }
  return Promise.reject(err)
}

function handlePublicResponseError(err) {
  if (!err.response) {
    console.error('Network error, please check your connection')
  }
  return Promise.reject(err)
}

export function extractApiError(error, fallbackMessage = '请求失败') {
  const data = error?.response?.data
  const message = data?.message || error?.message
  const code = data?.code
  if (message && String(message).trim()) {
    return {
      code: code || null,
      message: String(message).trim(),
    }
  }
  if (code && String(code).trim()) {
    return {
      code: String(code).trim(),
      message: `${fallbackMessage}：${String(code).trim()}`,
    }
  }
  return {
    code: null,
    message: fallbackMessage,
  }
}

attachAuthRequestInterceptor(api)
attachAuthRequestInterceptor(transferApi)

api.interceptors.response.use(
  res => res,
  err => handleAuthResponseError(err)
)
transferApi.interceptors.response.use(
  res => res,
  err => handleAuthResponseError(err)
)
publicApi.interceptors.response.use(
  res => res,
  err => handlePublicResponseError(err)
)
publicTransferApi.interceptors.response.use(
  res => res,
  err => handlePublicResponseError(err)
)

export const authApi = {
  login: d => api.post('/auth/login', d),
  me: () => api.get('/auth/me'),
  changePassword: d => api.post('/auth/change-password', d),
  changeUsername: d => api.post('/auth/change-username', d),
}

export const deviceApi = {
  list: p => api.get('/devices', { params: p }),
  listPaged: p => api.get('/devices/paged', { params: p }),
  create: d => api.post('/devices', d),
  update: (id, d) => api.put(`/devices/${id}`, d),
  updateCalibration: (id, d) => api.put(`/devices/${id}/calibration`, d),
  remove: id => api.delete(`/devices/${id}`),
  dashboard: () => api.get('/devices/dashboard'),
  export: p => api.get('/devices/export', { params: p, responseType: 'blob' }),
  exportCalibration: p => api.get('/devices/export/calibration', { params: p, responseType: 'blob' }),
  template: () => api.get('/devices/template', { responseType: 'blob' }),
  import: file => {
    const fd = new FormData()
    fd.append('file', file)
    return api.post('/devices/import', fd)
  },
  uploadFile: file => {
    const fd = new FormData()
    fd.append('file', file)
    return api.post('/devices/upload', fd)
  },
  batchUpdate: (ids, data) => Promise.all(ids.map(id => api.put(`/devices/${id}`, data))),
  batchUpdateCalibration: (ids, data) => Promise.all(ids.map(id => api.put(`/devices/${id}/calibration`, data))),
}

export const analysisApi = {
  capability: d => api.post('/analysis/capability', d),
  capabilityReport: d => api.post('/analysis/capability/report', d, { responseType: 'blob' }),
  grr: d => api.post('/analysis/grr', d),
  grrReport: d => api.post('/analysis/grr/report', d, { responseType: 'blob' }),
  repeatabilityReport: d => api.post('/analysis/repeatability/report', d, { responseType: 'blob' }),
  reproducibilityReport: d => api.post('/analysis/reproducibility/report', d, { responseType: 'blob' }),
  linearityReport: d => api.post('/analysis/linearity/report', d, { responseType: 'blob' }),
}

export const settingsApi = {
  get: () => api.get('/settings'),
  save: d => api.put('/settings', d),
  runMaintenance: () => api.post('/settings/maintenance/run'),
}

export const deviceStatusApi = {
  list: () => api.get('/device-statuses'),
  create: name => api.post('/device-statuses', { name }),
  update: (id, name) => api.put(`/device-statuses/${id}`, { name }),
  remove: id => api.delete(`/device-statuses/${id}`),
}

export const userApi = {
  list: () => api.get('/users'),
  create: d => api.post('/users', d),
  updateRolePermissions: (id, data) => api.put(`/users/${id}/role-permissions`, data),
  resetPassword: (id, data) => api.put(`/users/${id}/password`, data),
  remove: id => api.delete(`/users/${id}`),
}

export const fileApi = {
  list: parentId => api.get('/files', { params: parentId != null ? { parentId } : {} }),
  search: q => api.get('/files/search', { params: { q } }),
  breadcrumb: folderId => api.get('/files/breadcrumb', { params: { folderId } }),
  info: id => api.get(`/files/${id}/meta`),
  createFolder: (name, parentId) => api.post('/files/folder', { name, parentId: parentId ?? null }),
  scanSync: parentId => api.post('/files/scan-sync', { parentId: parentId ?? null }),
  grantableFolders: () => api.get('/files/grantable-folders'),
  upload: (file, parentId, options = {}) => {
    const fd = new FormData()
    fd.append('file', file)
    return api.post('/files/upload', fd, {
      params: parentId != null ? { parentId } : {},
      onUploadProgress: options.onUploadProgress,
    })
  },
  download: (id, options = {}) => transferApi.get(`/files/${id}/download`, {
    responseType: 'blob',
    timeout: 0,
    ...options,
  }),
  delete: id => api.delete(`/files/${id}`),
  rename: (id, name) => api.put(`/files/${id}/rename`, { name }),
  move: (id, parentId) => api.put(`/files/${id}/move`, { parentId: parentId ?? null }),
  getShare: id => api.get(`/files/${id}/share`),
  saveShare: (id, data) => api.post(`/files/${id}/share`, data),
  disableShare: id => api.delete(`/files/${id}/share`),
}

export const publicShareApi = {
  get: (token, folderId, password) => publicApi.get(`/public/shares/${token}`, {
    params: {
      ...(folderId != null ? { folderId } : {}),
      ...(password ? { password } : {}),
    },
  }),
  download: (token, id, password, options = {}) => publicTransferApi.get(`/public/shares/${token}/files/${id}/download`, {
    params: password ? { password } : {},
    responseType: 'blob',
    timeout: 0,
    ...options,
  }),
  preview: (token, id, password, options = {}) => publicTransferApi.get(`/public/shares/${token}/files/${id}/raw`, {
    params: password ? { password } : {},
    responseType: 'blob',
    timeout: 0,
    ...options,
  }),
}

export const webDavApi = {
  listMounts: () => api.get('/webdav/mounts'),
  createMount: d => api.post('/webdav/mounts', d),
  updateMount: (id, d) => api.put(`/webdav/mounts/${id}`, d),
  deleteMount: id => api.delete(`/webdav/mounts/${id}`),
  testConnection: d => api.post('/webdav/mounts/test', d),
  browse: (mountId, path) => api.get('/webdav/browse', { params: { mountId, path } }),
  download: (mountId, path, filename, options = {}) => transferApi.get('/webdav/download', {
    params: { mountId, path, filename },
    responseType: 'blob',
    timeout: 0,
    ...options,
  }),
  upload: (mountId, path, file) => {
    const fd = new FormData()
    fd.append('file', file)
    return api.post('/webdav/upload', fd, { params: { mountId, path } })
  },
}

export const deptApi = {
  list: search => api.get('/departments', { params: search ? { search } : {} }),
  tree: () => api.get('/departments/tree'),
  create: d => api.post('/departments', d),
  update: (id, d) => api.put(`/departments/${id}`, d),
  remove: id => api.delete(`/departments/${id}`),
  export: search => api.get('/departments/export', { params: search ? { search } : {}, responseType: 'blob' }),
  exportAll: () => api.get('/departments/export/all', { responseType: 'blob' }),
  template: () => api.get('/departments/template', { responseType: 'blob' }),
  import: file => {
    const fd = new FormData()
    fd.append('file', file)
    return api.post('/departments/import', fd)
  },
}

export const auditApi = {
  pending: () => api.get('/audit/pending'),
  my: () => api.get('/audit/my'),
  all: p => api.get('/audit', { params: p }),
  get: id => api.get(`/audit/${id}`),
  approve: (id, data) => api.post(`/audit/${id}/approve`, data),
  reject: (id, data) => api.post(`/audit/${id}/reject`, data),
  workflow: () => api.get('/audit/workflow'),
  saveWorkflow: steps => api.put('/audit/workflow', steps),
}

export const changeRecordApi = {
  list: p => api.get('/change-records', { params: p }),
  get: id => api.get(`/change-records/${id}`),
}

export default api

