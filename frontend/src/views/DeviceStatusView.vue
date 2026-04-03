<template>
  <div>
    <div class="toolbar">
      <div class="toolbar-left">
        <span style="font-size:13px;color:var(--text-muted)">管理设备使用状态的可选值，设备台账中可选择这些状态</span>
      </div>
      <div class="toolbar-right">
        <button v-if="authStore.canManageStatus" class="btn btn-primary btn-sm" @click="openAdd">+ 添加状态</button>
      </div>
    </div>

    <div class="status-cards-grid" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:16px">
      <div v-for="s in statuses" :key="s.id" class="status-card">
        <div class="status-indicator" :style="{ background: statusColor(s.name) }"></div>
        <div class="status-card-body">
          <div v-if="editingStatusId === s.id" class="status-edit-form">
            <input v-model="editName" class="status-edit-input" @keyup.enter="saveEdit(s.id)" @keyup.escape="cancelEdit" />
            <div class="status-edit-btns">
              <button class="btn btn-primary btn-sm" @click="saveEdit(s.id)">保存</button>
              <button class="btn btn-outline btn-sm" @click="cancelEdit">取消</button>
            </div>
          </div>
          <div v-else>
            <div class="status-name">{{ s.name }}</div>
            <div class="status-actions" v-if="authStore.canManageStatus">
              <button class="action-btn action-btn-edit" @click="startEdit(s)">编辑</button>
              <button class="action-btn action-btn-del" @click="deleteStatus(s.id)">删除</button>
            </div>
          </div>
        </div>
      </div>

      <div v-if="showAddCard" class="status-card add-card">
        <div class="status-indicator" style="background:#94a3b8"></div>
        <div class="status-card-body">
          <input v-model="newName" class="status-edit-input" placeholder="输入状态名称" ref="addInputRef"
                 @keyup.enter="confirmAdd" @keyup.escape="showAddCard=false" />
          <div class="status-edit-btns">
            <button class="btn btn-primary btn-sm" @click="confirmAdd">添加</button>
            <button class="btn btn-outline btn-sm" @click="showAddCard=false">取消</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="statuses.length===0 && !showAddCard" style="text-align:center;padding:60px;color:var(--text-muted)">
      暂无状态数据，点击「添加状态」创建
    </div>

    <!-- Usage info -->
    <div class="card" style="margin-top:24px">
      <div class="card-title">使用说明</div>
      <div class="usage-info-grid" style="display:grid;grid-template-columns:1fr 1fr;gap:16px;font-size:13.5px;color:var(--text-muted)">
        <div>
          <div style="font-weight:600;color:var(--text);margin-bottom:8px">默认状态含义</div>
          <div style="display:flex;flex-direction:column;gap:6px">
            <div><span class="tag tag-green">正常</span> <span style="margin-left:8px">设备运行正常，可正常使用</span></div>
            <div><span class="tag tag-red">故障</span> <span style="margin-left:8px">设备发生故障，需维修处理</span></div>
            <div><span class="tag tag-yellow">维修</span> <span style="margin-left:8px">设备正在维修中，暂停使用</span></div>
            <div><span class="tag tag-gray">报废</span> <span style="margin-left:8px">设备已报废，不可再使用</span></div>
          </div>
        </div>
        <div>
          <div style="font-weight:600;color:var(--text);margin-bottom:8px">操作说明</div>
          <ul style="list-style:none;display:flex;flex-direction:column;gap:6px">
            <li>✅ 可以添加自定义状态值</li>
            <li>✏️ 可以修改现有状态名称</li>
            <li>🗑️ 删除状态不影响已使用该状态的设备</li>
            <li>📋 在「设备台账」新增/编辑设备时可选择使用状态</li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, inject } from 'vue'
import { deviceStatusApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'

const showToast = inject('showToast')
const authStore = useAuthStore()
const statuses = ref([])
const showAddCard = ref(false)
const newName = ref('')
const editingStatusId = ref(null)
const editName = ref('')
const addInputRef = ref(null)

const STATUS_COLORS = { '正常':'#059669','故障':'#dc2626','维修':'#d97706','报废':'#64748b' }
function statusColor(name) { return STATUS_COLORS[name] || '#2563eb' }

async function load() {
  try { statuses.value = (await deviceStatusApi.list()).data } catch(e) {}
}
async function openAdd() {
  showAddCard.value = true
  newName.value = ''
  await nextTick()
  addInputRef.value?.focus()
}
async function confirmAdd() {
  if (!newName.value.trim()) return
  try {
    await deviceStatusApi.create(newName.value)
    showToast('状态已添加'); showAddCard.value = false; load()
  } catch(e) { showToast(e.response?.data?.message||'添加失败','error') }
}
function startEdit(s) { editingStatusId.value = s.id; editName.value = s.name }
function cancelEdit() { editingStatusId.value = null }
async function saveEdit(id) {
  try {
    await deviceStatusApi.update(id, editName.value)
    showToast('已更新'); editingStatusId.value = null; load()
  } catch(e) { showToast(e.response?.data?.message||'更新失败','error') }
}
async function deleteStatus(id) {
  if (!confirm('确定删除该状态吗？')) return
  try { await deviceStatusApi.remove(id); showToast('已删除'); load() }
  catch(e) { showToast('删除失败','error') }
}
useResumeRefresh(load)

onMounted(load)
</script>

<style scoped>
.status-card {
  background: white; border: 1px solid var(--border); border-radius: 12px;
  overflow: hidden; box-shadow: var(--shadow-sm); transition: box-shadow 0.2s;
  display: flex; flex-direction: column;
}
.status-card:hover { box-shadow: var(--shadow-md); }
.status-indicator { height: 4px; }
.status-card-body { padding: 16px; }
.status-name { font-size: 15px; font-weight: 700; margin-bottom: 10px; color: var(--text); }
.status-actions { display: flex; gap: 6px; }
.status-edit-input {
  width: 100%; padding: 8px 10px; border: 1.5px solid var(--primary);
  border-radius: 7px; font-size: 13.5px; outline: none; margin-bottom: 10px;
  box-shadow: 0 0 0 3px rgba(37,99,235,0.1);
}
.status-edit-btns { display: flex; gap: 6px; }
.add-card { border: 1.5px dashed var(--border); border-radius: 12px; }
</style>
