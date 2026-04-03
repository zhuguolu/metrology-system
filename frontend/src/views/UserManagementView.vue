<template>
  <div class="user-page">
    <div class="toolbar">
      <div class="toolbar-left">
        <span class="page-note">管理系统用户、角色、功能权限与文件夹只读授权</span>
      </div>
      <div class="toolbar-right">
        <el-button type="primary" @click="openCreate">+ 创建用户</el-button>
      </div>
    </div>

    <div class="table-wrap desktop-only">
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th>用户名</th>
              <th>所属部门</th>
              <th>角色</th>
              <th>功能权限</th>
              <th>只读文件夹</th>
              <th>创建时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="users.length === 0" class="empty-row">
              <td colspan="7">暂无用户数据</td>
            </tr>
            <tr v-for="user in users" :key="user.id">
              <td>
                <div class="user-cell">
                  <div class="user-avatar-sm">{{ user.username.charAt(0).toUpperCase() }}</div>
                  <span class="user-name">{{ user.username }}</span>
                  <span v-if="user.username === authStore.username" class="tag tag-blue self-tag">我</span>
                </div>
              </td>
              <td><span class="text-muted">{{ formatDepartments(user) }}</span></td>
              <td>
                <span :class="['tag', isAdmin(user) ? 'tag-purple' : 'tag-gray']">
                  {{ isAdmin(user) ? '管理员' : '普通用户' }}
                </span>
              </td>
              <td>
                <div v-if="isAdmin(user)" class="text-muted text-sm">拥有所有权限</div>
                <div v-else class="perm-badges">
                  <span
                    v-for="perm in ALL_PERMS"
                    :key="perm.code"
                    :class="['perm-badge', user.permissions.includes(perm.code) ? 'perm-on' : 'perm-off']"
                  >
                    {{ perm.label }}
                  </span>
                  <span v-if="user.permissions.length === 0" class="text-muted text-sm">暂无权限</span>
                </div>
              </td>
              <td>
                <div v-if="user.readonlyFolders.length" class="folder-badges">
                  <span v-for="folder in user.readonlyFolders" :key="folder.folderId" class="folder-badge" :title="folder.folderPath">
                    {{ folder.folderName }}
                  </span>
                </div>
                <span v-else class="text-muted text-sm">未授权</span>
              </td>
              <td><span class="text-sm text-muted">{{ formatDate(user.createdAt) }}</span></td>
              <td>
                <div class="action-group">
                  <button class="action-btn action-btn-edit" @click="openEdit(user)">权限设置</button>
                  <button v-if="!isAdmin(user)" class="action-btn action-btn-view" @click="openResetPassword(user)">修改密码</button>
                  <button v-if="user.username !== authStore.username" class="action-btn action-btn-del" @click="deleteUser(user.id)">删除</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="mobile-list mobile-only">
      <div v-if="users.length === 0" class="mobile-empty">暂无用户数据</div>
      <div v-for="user in users" :key="user.id" class="m-card">
        <div class="m-card-row">
          <div class="user-cell user-cell-mobile">
            <div class="user-avatar-sm">{{ user.username.charAt(0).toUpperCase() }}</div>
            <div class="m-card-title">{{ user.username }}</div>
            <span v-if="user.username === authStore.username" class="tag tag-blue self-tag">我</span>
          </div>
          <span :class="['tag', isAdmin(user) ? 'tag-purple' : 'tag-gray']">
            {{ isAdmin(user) ? '管理员' : '普通用户' }}
          </span>
        </div>
        <div class="m-card-meta">
          <div class="m-card-meta-item">部门 <b>{{ formatDepartments(user) }}</b></div>
          <div class="m-card-meta-item">创建时间 <b>{{ formatDate(user.createdAt) }}</b></div>
        </div>
        <div class="mobile-perm-wrap">
          <div v-if="isAdmin(user)" class="text-muted text-sm">拥有所有权限</div>
          <div v-else class="perm-badges">
            <span
              v-for="perm in ALL_PERMS"
              :key="perm.code"
              :class="['perm-badge', user.permissions.includes(perm.code) ? 'perm-on' : 'perm-off']"
            >
              {{ perm.label }}
            </span>
          </div>
        </div>
        <div class="mobile-folder-wrap">
          <div class="mobile-folder-title">只读文件夹</div>
          <div v-if="user.readonlyFolders.length" class="folder-badges">
            <span v-for="folder in user.readonlyFolders" :key="folder.folderId" class="folder-badge" :title="folder.folderPath">
              {{ folder.folderName }}
            </span>
          </div>
          <div v-else class="text-muted text-sm">未授权</div>
        </div>
        <div class="m-card-footer">
          <div></div>
          <div class="m-card-actions">
            <button class="action-btn action-btn-edit" @click="openEdit(user)">权限设置</button>
            <button v-if="!isAdmin(user)" class="action-btn action-btn-view" @click="openResetPassword(user)">修改密码</button>
            <button v-if="user.username !== authStore.username" class="action-btn action-btn-del" @click="deleteUser(user.id)">删除</button>
          </div>
        </div>
      </div>
    </div>

    <el-dialog v-model="showCreateModal" title="创建用户" width="min(760px, 96vw)" :close-on-click-modal="false">
      <div class="modal-form">
        <div class="form-group">
          <label class="form-label">用户名 <span class="required">*</span></label>
          <input class="form-input" v-model="createForm.username" placeholder="请输入用户名" />
        </div>

        <div class="form-group">
          <label class="form-label">密码 <span class="required">*</span></label>
          <div class="password-wrap">
            <input
              class="form-input"
              :type="showCreatePw ? 'text' : 'password'"
              v-model="createForm.password"
              placeholder="请输入密码，至少 6 位"
            />
            <span class="password-toggle" @click="showCreatePw = !showCreatePw">{{ showCreatePw ? '隐藏' : '显示' }}</span>
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">账号角色</label>
          <div class="role-grid">
            <label class="role-option" :class="{ active: createForm.role === 'ADMIN' }" @click="createForm.role = 'ADMIN'">
              <span>管理员</span>
              <small>拥有所有权限</small>
            </label>
            <label class="role-option" :class="{ active: createForm.role === 'USER' }" @click="createForm.role = 'USER'">
              <span>普通用户</span>
              <small>可单独分配权限</small>
            </label>
          </div>
        </div>

        <template v-if="createForm.role === 'USER'">
          <div class="form-group">
            <label class="form-label">所属部门</label>
            <el-select v-model="createForm.departments" multiple collapse-tags collapse-tags-tooltip clearable placeholder="可选" style="width: 100%">
              <el-option v-for="dept in depts" :key="dept.id" :value="dept.name" :label="dept.name" />
            </el-select>
          </div>

          <div class="form-group">
            <label class="form-label">功能权限</label>
            <div class="perm-grid">
              <label v-for="perm in ALL_PERMS" :key="perm.code" class="perm-option" :class="{ active: createForm.permissions.includes(perm.code) }">
                <input type="checkbox" :value="perm.code" v-model="createForm.permissions" style="display:none" />
                <span class="perm-check">{{ createForm.permissions.includes(perm.code) ? '✓' : '' }}</span>
                <div>
                  <div class="perm-option-title">{{ perm.label }}</div>
                  <div class="perm-option-desc">{{ perm.desc }}</div>
                </div>
              </label>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">只读文件夹授权</label>
            <el-select
              v-model="createForm.readonlyFolderIds"
              multiple
              filterable
              collapse-tags
              collapse-tags-tooltip
              clearable
              placeholder="选择开放给该用户的只读文件夹"
              style="width: 100%"
            >
              <el-option v-for="folder in grantableFolders" :key="folder.id" :value="folder.id" :label="folder.path" />
            </el-select>
            <div class="form-tip">授权后，用户无需拥有完整文件管理权限，也可以只读访问这些文件夹。</div>
          </div>
        </template>

        <div v-if="createError" class="form-error">{{ createError }}</div>
      </div>
      <template #footer>
        <el-button @click="closeCreate">取消</el-button>
        <el-button type="primary" :loading="creating" @click="submitCreate">创建用户</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showModal" :title="`权限设置 - ${editForm.username}`" width="min(760px, 96vw)" :close-on-click-modal="false">
      <div class="modal-form">
        <div class="form-group">
          <label class="form-label">账号角色</label>
          <div class="role-grid">
            <label class="role-option" :class="{ active: editForm.role === 'ADMIN' }" @click="editForm.role = 'ADMIN'">
              <span>管理员</span>
              <small>拥有所有权限</small>
            </label>
            <label class="role-option" :class="{ active: editForm.role === 'USER' }" @click="editForm.role = 'USER'">
              <span>普通用户</span>
              <small>可单独分配权限</small>
            </label>
          </div>
        </div>

        <template v-if="editForm.role === 'USER'">
          <div class="form-group">
            <label class="form-label">所属部门</label>
            <el-select v-model="editForm.departments" multiple collapse-tags collapse-tags-tooltip clearable placeholder="可选" style="width: 100%">
              <el-option v-for="dept in depts" :key="dept.id" :value="dept.name" :label="dept.name" />
            </el-select>
          </div>

          <div class="form-group">
            <label class="form-label">功能权限</label>
            <div class="perm-grid">
              <label v-for="perm in ALL_PERMS" :key="perm.code" class="perm-option" :class="{ active: editForm.permissions.includes(perm.code) }">
                <input type="checkbox" :value="perm.code" v-model="editForm.permissions" style="display:none" />
                <span class="perm-check">{{ editForm.permissions.includes(perm.code) ? '✓' : '' }}</span>
                <div>
                  <div class="perm-option-title">{{ perm.label }}</div>
                  <div class="perm-option-desc">{{ perm.desc }}</div>
                </div>
              </label>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">只读文件夹授权</label>
            <el-select
              v-model="editForm.readonlyFolderIds"
              multiple
              filterable
              collapse-tags
              collapse-tags-tooltip
              clearable
              placeholder="选择开放给该用户的只读文件夹"
              style="width: 100%"
            >
              <el-option v-for="folder in grantableFolders" :key="folder.id" :value="folder.id" :label="folder.path" />
            </el-select>
            <div class="form-tip">这些文件夹在用户侧会以只读方式显示，只允许浏览和下载。</div>
          </div>
        </template>
      </div>
      <template #footer>
        <el-button @click="closeModal">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveEdit">保存权限</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showPasswordModal" :title="`修改密码 - ${passwordForm.username}`" width="min(420px, 92vw)" :close-on-click-modal="false">
      <div class="password-tip">管理员可以直接为普通用户重置密码，保存后立即生效。</div>
      <div class="modal-form">
        <div class="form-group">
          <label class="form-label">新密码 <span class="required">*</span></label>
          <div class="password-wrap">
            <input class="form-input" :type="passwordForm.show ? 'text' : 'password'" v-model="passwordForm.password" placeholder="请输入新密码，至少 6 位" />
            <span class="password-toggle" @click="passwordForm.show = !passwordForm.show">{{ passwordForm.show ? '隐藏' : '显示' }}</span>
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">确认密码 <span class="required">*</span></label>
          <div class="password-wrap">
            <input class="form-input" :type="passwordForm.showConfirm ? 'text' : 'password'" v-model="passwordForm.confirmPassword" placeholder="请再次输入新密码" />
            <span class="password-toggle" @click="passwordForm.showConfirm = !passwordForm.showConfirm">{{ passwordForm.showConfirm ? '隐藏' : '显示' }}</span>
          </div>
        </div>

        <div v-if="passwordError" class="form-error">{{ passwordError }}</div>
      </div>
      <template #footer>
        <el-button @click="closeResetPassword">取消</el-button>
        <el-button type="primary" :loading="resettingPassword" @click="submitResetPassword">保存密码</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { inject, onMounted, reactive, ref } from 'vue'
import { deptApi, fileApi, userApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'

const showToast = inject('showToast', null)
const authStore = useAuthStore()

const users = ref([])
const depts = ref([])
const grantableFolders = ref([])

const showModal = ref(false)
const saving = ref(false)
const editForm = reactive({
  id: null,
  username: '',
  role: 'USER',
  permissions: [],
  departments: [],
  readonlyFolderIds: [],
})

const showCreateModal = ref(false)
const creating = ref(false)
const createError = ref('')
const showCreatePw = ref(false)
const createForm = reactive({
  username: '',
  password: '',
  role: 'USER',
  permissions: [],
  departments: [],
  readonlyFolderIds: [],
})

const showPasswordModal = ref(false)
const resettingPassword = ref(false)
const passwordError = ref('')
const passwordForm = reactive({
  id: null,
  username: '',
  password: '',
  confirmPassword: '',
  show: false,
  showConfirm: false,
})

const ALL_PERMS = [
  { code: 'DEVICE_VIEW', label: '查看设备', desc: '查看设备列表和详情' },
  { code: 'DEVICE_CREATE', label: '新增设备', desc: '提交新增设备记录' },
  { code: 'DEVICE_UPDATE', label: '修改设备', desc: '编辑设备基础信息' },
  { code: 'DEVICE_DELETE', label: '删除设备', desc: '删除设备记录' },
  { code: 'CALIBRATION_RECORD', label: '校准记录', desc: '登记设备校准信息' },
  { code: 'STATUS_MANAGE', label: '状态管理', desc: '维护设备使用状态' },
  { code: 'FILE_ACCESS', label: '文件访问', desc: '完整访问我的文件模块' },
  { code: 'WEBDAV_ACCESS', label: '网络挂载', desc: '访问 WebDAV 挂载功能' },
]

function toast(message, type = 'success') {
  if (showToast) showToast(message, type)
  else if (type === 'error') console.error(message)
  else console.log(message)
}

function isAdmin(user) {
  return user?.role === 'ADMIN'
}

function formatDate(value) {
  if (!value) return '-'
  return String(value).split('T')[0]
}

function flattenDepartments(list, result = []) {
  if (!Array.isArray(list)) return result
  for (const item of list) {
    if (!item) continue
    result.push({ id: item.id, name: item.name })
    if (Array.isArray(item.children) && item.children.length) {
      flattenDepartments(item.children, result)
    }
  }
  return result
}

function normalizeDepartments(user) {
  if (Array.isArray(user?.departments)) {
    return user.departments.filter(Boolean).map(v => String(v).trim()).filter(Boolean)
  }
  if (typeof user?.department === 'string' && user.department.trim()) {
    return user.department.replaceAll('，', ',').split(',').map(s => s.trim()).filter(Boolean)
  }
  return []
}

function normalizeReadonlyFolderIds(user) {
  if (!Array.isArray(user?.readonlyFolderIds)) return []
  return user.readonlyFolderIds.map(value => Number(value)).filter(value => Number.isFinite(value))
}

function formatDepartments(user) {
  const parts = normalizeDepartments(user)
  return parts.length ? parts.join('、') : '-'
}

async function load() {
  try {
    const list = (await userApi.list()).data || []
    users.value = list.map(user => ({
      ...user,
      permissions: Array.isArray(user.permissions) ? user.permissions : [],
      departments: normalizeDepartments(user),
      readonlyFolders: Array.isArray(user.readonlyFolders) ? user.readonlyFolders : [],
      readonlyFolderIds: normalizeReadonlyFolderIds(user),
    }))
  } catch (error) {
    console.error(error)
  }
}

async function loadDepts() {
  try {
    const response = await deptApi.list()
    depts.value = flattenDepartments(response.data || [])
  } catch (error) {
    console.error(error)
  }
}

async function loadGrantableFolders() {
  try {
    const response = await fileApi.grantableFolders()
    grantableFolders.value = Array.isArray(response.data) ? response.data : []
  } catch (error) {
    console.error(error)
    grantableFolders.value = []
  }
}

function openCreate() {
  createForm.username = ''
  createForm.password = ''
  createForm.role = 'USER'
  createForm.permissions = []
  createForm.departments = []
  createForm.readonlyFolderIds = []
  createError.value = ''
  showCreatePw.value = false
  showCreateModal.value = true
}

function closeCreate() {
  showCreateModal.value = false
}

async function submitCreate() {
  createError.value = ''
  if (!createForm.username.trim()) {
    createError.value = '请输入用户名'
    return
  }
  if (!createForm.password || createForm.password.length < 6) {
    createError.value = '密码至少 6 位'
    return
  }

  creating.value = true
  try {
    await userApi.create({
      username: createForm.username.trim(),
      password: createForm.password,
      role: createForm.role,
      departments: createForm.role === 'USER' ? createForm.departments : [],
      permissions: createForm.role === 'ADMIN' ? [] : createForm.permissions,
      readonlyFolderIds: createForm.role === 'USER' ? createForm.readonlyFolderIds : [],
    })
    toast('用户创建成功')
    closeCreate()
    await load()
  } catch (error) {
    createError.value = error.response?.data?.message || '创建失败'
  } finally {
    creating.value = false
  }
}

function openEdit(user) {
  editForm.id = user.id
  editForm.username = user.username
  editForm.role = user.role || 'USER'
  editForm.permissions = [...(user.permissions || [])]
  editForm.departments = normalizeDepartments(user)
  editForm.readonlyFolderIds = normalizeReadonlyFolderIds(user)
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function saveEdit() {
  saving.value = true
  try {
    await userApi.updateRolePermissions(editForm.id, {
      role: editForm.role,
      departments: editForm.role === 'USER' ? editForm.departments : [],
      permissions: editForm.role === 'ADMIN' ? [] : editForm.permissions,
      readonlyFolderIds: editForm.role === 'USER' ? editForm.readonlyFolderIds : [],
    })
    toast('权限已更新')
    closeModal()
    await load()
  } catch (error) {
    toast(error.response?.data?.message || '更新失败', 'error')
  } finally {
    saving.value = false
  }
}

function openResetPassword(user) {
  passwordForm.id = user.id
  passwordForm.username = user.username
  passwordForm.password = ''
  passwordForm.confirmPassword = ''
  passwordForm.show = false
  passwordForm.showConfirm = false
  passwordError.value = ''
  showPasswordModal.value = true
}

function closeResetPassword() {
  showPasswordModal.value = false
}

async function submitResetPassword() {
  passwordError.value = ''
  if (!passwordForm.password || passwordForm.password.length < 6) {
    passwordError.value = '新密码至少 6 位'
    return
  }
  if (passwordForm.password !== passwordForm.confirmPassword) {
    passwordError.value = '两次输入的密码不一致'
    return
  }

  resettingPassword.value = true
  try {
    await userApi.resetPassword(passwordForm.id, { password: passwordForm.password })
    toast(`已更新 ${passwordForm.username} 的密码`)
    closeResetPassword()
  } catch (error) {
    passwordError.value = error.response?.data?.message || '密码修改失败'
  } finally {
    resettingPassword.value = false
  }
}

async function deleteUser(id) {
  if (!confirm('确定要删除该用户吗？此操作不可撤销。')) return
  try {
    await userApi.remove(id)
    toast('用户已删除')
    await load()
  } catch (error) {
    toast(error.response?.data?.message || '删除失败', 'error')
  }
}

async function refreshUserManagementPage() {
  await Promise.all([load(), loadDepts(), loadGrantableFolders()])
}

useResumeRefresh(refreshUserManagementPage)

onMounted(() => {
  load()
  loadDepts()
  loadGrantableFolders()
})
</script>

<style scoped>
.page-note {
  font-size: 13px;
  color: var(--text-muted);
}

.desktop-only {
  display: block;
}

.mobile-only {
  display: none;
}

.user-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

.user-cell-mobile {
  flex: 1;
  min-width: 0;
}

.user-name {
  font-weight: 600;
}

.self-tag {
  font-size: 11px;
  flex-shrink: 0;
}

.mobile-empty {
  text-align: center;
  padding: 48px 0;
  color: var(--text-muted);
}

.perm-badges,
.folder-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.folder-badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: 999px;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 12px;
}

.mobile-perm-wrap,
.mobile-folder-wrap {
  margin-bottom: 10px;
}

.mobile-folder-title {
  margin-bottom: 6px;
  font-size: 12px;
  color: var(--text-muted);
}

.required {
  color: #ef4444;
}

.modal-form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.password-wrap {
  position: relative;
}

.password-wrap .form-input {
  padding-right: 64px;
}

.password-toggle {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  cursor: pointer;
  font-size: 12px;
  color: var(--primary);
}

.form-error {
  padding: 10px 14px;
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #991b1b;
  border-radius: 8px;
  font-size: 13px;
}

.form-tip,
.password-tip {
  padding: 10px 12px;
  border-radius: 10px;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 13px;
  line-height: 1.5;
}

.user-avatar-sm {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #2563eb, #7c3aed);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  color: white;
  flex-shrink: 0;
}

.role-grid {
  display: flex;
  gap: 10px;
}

.role-option {
  flex: 1;
  padding: 14px 16px;
  border-radius: 12px;
  border: 2px solid var(--border);
  cursor: pointer;
  display: flex;
  flex-direction: column;
  gap: 3px;
  transition: all 0.2s;
}

.role-option span {
  font-size: 14px;
  font-weight: 700;
}

.role-option small {
  font-size: 12px;
  color: var(--text-muted);
}

.role-option.active {
  border-color: var(--primary);
  background: var(--primary-light);
}

.perm-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.perm-option {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 12px;
  border-radius: 10px;
  border: 1.5px solid var(--border);
  cursor: pointer;
  transition: all 0.2s;
}

.perm-option.active {
  border-color: var(--primary);
  background: var(--primary-light);
}

.perm-check {
  width: 18px;
  height: 18px;
  border-radius: 4px;
  border: 2px solid var(--border);
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  margin-top: 1px;
  background: white;
  color: var(--primary);
}

.perm-option.active .perm-check {
  border-color: var(--primary);
  background: var(--primary);
  color: white;
}

.perm-option-title {
  font-weight: 600;
  font-size: 13.5px;
}

.perm-option-desc {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

@media (max-width: 768px) {
  .desktop-only {
    display: none;
  }

  .mobile-only {
    display: block;
  }

  .role-grid,
  .perm-grid {
    grid-template-columns: 1fr;
    display: grid;
  }
}
</style>
