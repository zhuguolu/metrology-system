<template>
  <div class="audit-view">
    <el-tabs v-model="activeTab" @tab-change="onTabChange">
      <el-tab-pane v-if="authStore.isAdmin" label="待审批" name="pending">
        <div class="tab-toolbar">
          <span class="record-count">共 <b>{{ pendingList.length }}</b> 条待审批</span>
          <el-button size="small" @click="loadPending">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="pendingList" border stripe v-loading="loading.pending" empty-text="暂无待审批记录">
          <el-table-column prop="submittedBy" label="提交人" width="100" />
          <el-table-column label="操作类型" width="90">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="160">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column prop="submittedAt" label="提交时间" width="155">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="remark" label="备注" min-width="120" show-overflow-tooltip />
          <el-table-column label="操作" width="200" fixed="right">
            <template #default="{ row }">
              <el-button size="small" plain @click="openDetail(row)">查看详情</el-button>
              <el-button size="small" type="success" @click="openApprove(row)">审批通过</el-button>
            </template>
          </el-table-column>
        </el-table>

        <div class="mobile-list">
          <div v-if="loading.pending && !pendingList.length" class="mobile-empty">加载中...</div>
          <div v-else-if="!pendingList.length" class="mobile-empty">暂无待审批记录</div>
          <div v-else v-for="row in pendingList" :key="row.id" class="audit-card">
            <div class="audit-card-head">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
              <span class="audit-card-time">{{ formatTime(row.submittedAt) }}</span>
            </div>
            <div class="audit-card-title">{{ deviceName(row) }}</div>
            <div class="audit-card-subtitle">计量编号：{{ deviceMetricNo(row) }}</div>
            <div class="audit-card-meta">
              <span>提交人：{{ row.submittedBy || '-' }}</span>
              <span>备注：{{ row.remark || '-' }}</span>
            </div>
            <div class="audit-card-actions">
              <el-button size="small" plain @click="openDetail(row)">查看详情</el-button>
              <el-button size="small" type="success" @click="openApprove(row)">审批通过</el-button>
            </div>
          </div>
        </div>
      </el-tab-pane>

      <el-tab-pane label="我的申请" name="my">
        <div class="tab-toolbar">
          <el-button size="small" @click="loadMy">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="myList" border stripe v-loading="loading.my" empty-text="暂无申请记录">
          <el-table-column label="操作类型" width="90">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="160">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="95">
            <template #default="{ row }">
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="submittedAt" label="提交时间" width="155">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="approvedAt" label="审批时间" width="155">
            <template #default="{ row }">{{ formatTime(row.approvedAt) }}</template>
          </el-table-column>
          <el-table-column label="驳回原因" min-width="130" show-overflow-tooltip>
            <template #default="{ row }">
              <span v-if="row.rejectReason" class="reject-text">{{ row.rejectReason }}</span>
              <span v-else class="text-muted">-</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="85" fixed="right">
            <template #default="{ row }">
              <el-button size="small" plain @click="openDetail(row)">查看</el-button>
            </template>
          </el-table-column>
        </el-table>

        <div class="mobile-list">
          <div v-if="loading.my && !myList.length" class="mobile-empty">加载中...</div>
          <div v-else-if="!myList.length" class="mobile-empty">暂无申请记录</div>
          <div v-else v-for="row in myList" :key="row.id" class="audit-card">
            <div class="audit-card-head">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </div>
            <div class="audit-card-title">{{ deviceName(row) }}</div>
            <div class="audit-card-subtitle">计量编号：{{ deviceMetricNo(row) }}</div>
            <div class="audit-card-meta">
              <span>提交：{{ formatTime(row.submittedAt) || '-' }}</span>
              <span>审批：{{ formatTime(row.approvedAt) || '-' }}</span>
              <span v-if="row.rejectReason" class="reject-text">驳回：{{ row.rejectReason }}</span>
            </div>
            <div class="audit-card-actions">
              <el-button size="small" plain @click="openDetail(row)">查看</el-button>
            </div>
          </div>
        </div>

        <div class="workflow-hint">
          <div class="workflow-title">审批流程说明</div>
          <div class="workflow-steps-row">
            <div class="wf-step wf-step-done">
              <div class="wf-step-icon">1</div>
              <div class="wf-step-label">普通用户提交变更申请</div>
            </div>
            <div class="wf-arrow">→</div>
            <div class="wf-step wf-step-active">
              <div class="wf-step-icon">2</div>
              <div class="wf-step-label">管理员审核审批</div>
            </div>
            <div class="wf-arrow">→</div>
            <div class="wf-step wf-step-pending">
              <div class="wf-step-icon">3</div>
              <div class="wf-step-label">审批通过后自动生效</div>
            </div>
          </div>
        </div>
      </el-tab-pane>

      <el-tab-pane v-if="authStore.isAdmin" label="审批历史" name="history">
        <div class="tab-toolbar">
          <el-button size="small" @click="loadHistory">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="historyList" border stripe v-loading="loading.history" empty-text="暂无历史记录">
          <el-table-column prop="submittedBy" label="提交人" width="100" />
          <el-table-column label="操作类型" width="90">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="150">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="95">
            <template #default="{ row }">
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="approvedBy" label="审批人" width="100" />
          <el-table-column prop="submittedAt" label="提交时间" width="155">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="approvedAt" label="审批时间" width="155">
            <template #default="{ row }">{{ formatTime(row.approvedAt) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="85" fixed="right">
            <template #default="{ row }">
              <el-button size="small" plain @click="openDetail(row)">查看</el-button>
            </template>
          </el-table-column>
        </el-table>

        <div class="mobile-list">
          <div v-if="loading.history && !historyList.length" class="mobile-empty">加载中...</div>
          <div v-else-if="!historyList.length" class="mobile-empty">暂无历史记录</div>
          <div v-else v-for="row in historyList" :key="row.id" class="audit-card">
            <div class="audit-card-head">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </div>
            <div class="audit-card-title">{{ deviceName(row) }}</div>
            <div class="audit-card-subtitle">计量编号：{{ deviceMetricNo(row) }}</div>
            <div class="audit-card-meta">
              <span>提交人：{{ row.submittedBy || '-' }}</span>
              <span>审批人：{{ row.approvedBy || '-' }}</span>
              <span>提交：{{ formatTime(row.submittedAt) || '-' }}</span>
              <span>审批：{{ formatTime(row.approvedAt) || '-' }}</span>
            </div>
            <div class="audit-card-actions">
              <el-button size="small" plain @click="openDetail(row)">查看</el-button>
            </div>
          </div>
        </div>

        <div class="pagination-bar">
          <el-pagination
            v-model:current-page="historyPage"
            :page-size="20"
            :total="historyTotal"
            layout="total, prev, pager, next"
            @current-change="loadHistory"
            small
          />
        </div>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="detailVisible" :title="detailDialogTitle" width="min(720px, 96vw)" top="4vh">
      <div v-if="detailRecord">
        <div class="flow-bar" :class="flowBarClass">
          <div class="flow-step">
            <div class="flow-dot done-dot">✓</div>
            <div class="flow-info">
              <div class="flow-title">提交申请</div>
              <div class="flow-sub">{{ detailRecord.submittedBy || '-' }} · {{ formatTime(detailRecord.submittedAt) || '-' }}</div>
            </div>
          </div>
          <div class="flow-line"></div>
          <div class="flow-step">
            <div class="flow-dot" :class="{ 'done-dot': detailRecord.status !== 'PENDING', 'active-dot': detailRecord.status === 'PENDING', 'error-dot': detailRecord.status === 'REJECTED' }">
              {{ detailRecord.status === 'PENDING' ? '…' : (detailRecord.status === 'APPROVED' ? '✓' : '✕') }}
            </div>
            <div class="flow-info">
              <div class="flow-title">管理员审核</div>
              <div class="flow-sub">
                <span v-if="detailRecord.status === 'PENDING'" style="color:#f59e0b">等待审批</span>
                <span v-else>{{ detailRecord.approvedBy || '-' }} · {{ formatTime(detailRecord.approvedAt) || '-' }}</span>
              </div>
            </div>
          </div>
        </div>

        <div v-if="detailRecord.remark" class="remark-bar">
          <span class="remark-label">备注</span>{{ detailRecord.remark }}
        </div>

        <div class="diff-wrap">
          <div class="diff-header">
            <span class="diff-header-title">
              {{ detailRecord.type === 'UPDATE' ? '变更字段' : detailRecord.type === 'CREATE' ? '新增设备数据' : '删除设备数据' }}
            </span>
            <span v-if="detailRecord.type === 'UPDATE'" class="diff-changed-count">{{ diffRows.length }} 项已修改</span>
          </div>

          <template v-if="detailRecord.type === 'UPDATE'">
            <table class="diff-table">
              <colgroup>
                <col style="width:120px">
                <col>
                <col>
              </colgroup>
              <thead>
                <tr>
                  <th class="dt-th-label">字段</th>
                  <th class="dt-th-orig">修改前</th>
                  <th class="dt-th-new">修改后</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="diffRows.length === 0">
                  <td colspan="3" class="empty-row">未检测到字段变更</td>
                </tr>
                <tr v-for="r in diffRows" :key="r.key" class="dt-row-changed">
                  <td class="dt-cell-label">{{ r.label }}</td>
                  <td class="dt-cell-orig"><span v-if="showVal(r.origVal)" class="val-del">{{ r.origVal }}</span><span v-else class="val-empty">-</span></td>
                  <td class="dt-cell-new"><span v-if="showVal(r.newVal)" class="val-add">{{ r.newVal }}</span><span v-else class="val-empty">-</span></td>
                </tr>
              </tbody>
            </table>
          </template>

          <template v-else-if="detailRecord.type === 'CREATE'">
            <table class="diff-table">
              <colgroup><col style="width:120px"><col></colgroup>
              <tbody>
                <tr v-for="r in diffRows" :key="r.key">
                  <td class="dt-cell-label">{{ r.label }}</td>
                  <td class="dt-cell-new"><span class="val-add">{{ r.newVal }}</span></td>
                </tr>
              </tbody>
            </table>
          </template>

          <template v-else>
            <table class="diff-table">
              <colgroup><col style="width:120px"><col></colgroup>
              <tbody>
                <tr v-for="r in diffRows" :key="r.key">
                  <td class="dt-cell-label">{{ r.label }}</td>
                  <td class="dt-cell-orig"><span class="val-del">{{ r.origVal }}</span></td>
                </tr>
              </tbody>
            </table>
          </template>
        </div>
      </div>

      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
        <template v-if="authStore.isAdmin && detailRecord?.status === 'PENDING'">
          <el-button type="danger" plain @click="openReject(detailRecord)">驳回</el-button>
          <el-button type="success" @click="openApproveFromDetail(detailRecord)">审批通过</el-button>
        </template>
      </template>
    </el-dialog>

    <el-dialog v-model="approveVisible" title="确认审批通过" width="min(420px, 94vw)">
      <p class="dialog-tip">操作将立即执行，不可撤销。请确认后提交。</p>
      <el-form label-width="76px">
        <el-form-item label="审批备注">
          <el-input v-model="approveRemark" type="textarea" :rows="3" placeholder="可选填写审批意见" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="approveVisible = false">取消</el-button>
        <el-button type="success" :loading="actionLoading" @click="doApprove">确认审批</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rejectVisible" title="驳回申请" width="min(420px, 94vw)">
      <el-form label-width="76px">
        <el-form-item label="驳回原因">
          <el-input v-model="rejectReason" type="textarea" :rows="3" placeholder="可选填写驳回原因，申请人可见" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rejectVisible = false">取消</el-button>
        <el-button type="danger" :loading="actionLoading" @click="doReject">确认驳回</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth.js'
import { auditApi } from '../api/index.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const authStore = useAuthStore()
const auditCache = useViewCache('audit-view', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('audit-view')
const activeTab = ref(authStore.isAdmin ? 'pending' : 'my')

const pendingList = ref([])
const myList = ref([])
const historyList = ref([])
const historyPage = ref(1)
const historyTotal = ref(0)
const loading = ref({ pending: false, my: false, history: false })

const detailVisible = ref(false)
const detailRecord = ref(null)
const approveVisible = ref(false)
const approveRecord = ref(null)
const approveRemark = ref('')
const rejectVisible = ref(false)
const rejectRecord = ref(null)
const rejectReason = ref('')
const actionLoading = ref(false)

function restoreAuditCache() {
  const cached = auditCache.restore()
  if (!cached) return

  activeTab.value = cached.activeTab || activeTab.value
  pendingList.value = Array.isArray(cached.pendingList) ? cached.pendingList : []
  myList.value = Array.isArray(cached.myList) ? cached.myList : []
  historyList.value = Array.isArray(cached.historyList) ? cached.historyList : []
  historyPage.value = Number(cached.historyPage) || 1
  historyTotal.value = Number(cached.historyTotal) || 0
}

function saveAuditCache() {
  auditCache.save({
    activeTab: activeTab.value,
    pendingList: pendingList.value,
    myList: myList.value,
    historyList: historyList.value,
    historyPage: historyPage.value,
    historyTotal: historyTotal.value
  })
}

const FIELD_LABELS = {
  name: '设备名称',
  meteringNo: '计量编号',
  metricNo: '计量编号',
  assetNo: '资产编号',
  serialNo: '出厂编号',
  model: '型号',
  manufacturer: '制造厂',
  dept: '部门',
  location: '存放位置',
  responsiblePerson: '责任人',
  useStatus: '使用状态',
  classification: 'ABC分类',
  purchaseDate: '采购日期',
  purchasePrice: '采购价格',
  serviceLife: '使用年限',
  graduationValue: '分度值',
  testRange: '测试范围',
  allowedError: '允许误差',
  calibrationCycle: '检定周期',
  calDate: '上次校准日期',
  calResult: '校准结果',
  remark: '备注',
  imageUrl: '设备图片',
  imagePath: '设备图片1',
  imageName: '设备图片1',
  imagePath2: '设备图片2',
  imageName2: '设备图片2',
  certUrl: '校准证书'
}
const SKIP_FIELDS = new Set(['id', 'nextCalDate', 'nextDate', 'validity', 'daysPassed'])

function fieldLabel(key) {
  return FIELD_LABELS[key] || key
}
function parseRaw(json) {
  if (!json) return {}
  try { return JSON.parse(json) } catch { return {} }
}
function showVal(v) {
  return v !== null && v !== undefined && String(v).trim() !== ''
}

const diffRows = computed(() => {
  if (!detailRecord.value) return []
  const type = detailRecord.value.type
  const orig = parseRaw(detailRecord.value.originalData)
  const now = parseRaw(detailRecord.value.newData)

  if (type === 'UPDATE') {
    const changedKeys = Object.keys(now)
      .filter(k => !SKIP_FIELDS.has(k))
    return changedKeys
      .map(k => {
        const newRaw = now[k]
        const submitted = newRaw !== null && newRaw !== undefined
        const origVal = orig[k] ?? ''
        const newVal = submitted ? newRaw : ''
        return { key: k, label: fieldLabel(k), origVal, newVal, submitted, changed: submitted && String(origVal) !== String(newVal) }
      })
      .filter(r => r.submitted && r.changed)
  }
  if (type === 'CREATE') {
    return Object.entries(now)
      .filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v))
      .map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: '', newVal: v }))
  }
  return Object.entries(orig)
    .filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v))
    .map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: v, newVal: '' }))
})

function typeLabel(t) { return { CREATE: '新增', UPDATE: '修改', DELETE: '删除' }[t] || t }
function typeTagType(t) { return { CREATE: 'success', UPDATE: 'warning', DELETE: 'danger' }[t] || '' }
function statusLabel(s) { return { PENDING: '待审批', APPROVED: '已通过', REJECTED: '已驳回' }[s] || s }
function statusTagType(s) { return { PENDING: 'warning', APPROVED: 'success', REJECTED: 'danger' }[s] || '' }
function formatTime(t) {
  if (!t) return ''
  return new Date(t).toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}
function deviceName(row) {
  const src = row.type === 'DELETE' ? row.originalData : row.newData
  if (!src) return '-'
  try { return JSON.parse(src).name || '-' } catch { return '-' }
}
function deviceMetricNo(row) {
  if (row?.metricNo) return row.metricNo
  const src = row?.type === 'DELETE' ? row?.originalData : row?.newData
  if (!src) return '-'
  try { return JSON.parse(src).metricNo || '-' } catch { return '-' }
}

const detailDialogTitle = computed(() => {
  if (!detailRecord.value) return '申请详情'
  const tl = { CREATE: '新增设备', UPDATE: '修改设备', DELETE: '删除设备' }[detailRecord.value.type] || '操作'
  const sl = statusLabel(detailRecord.value.status)
  return `${tl}申请 · ${sl}`
})
const flowBarClass = computed(() => {
  if (!detailRecord.value) return ''
  return { APPROVED: 'flow-bar-approved', REJECTED: 'flow-bar-rejected', PENDING: 'flow-bar-pending' }[detailRecord.value.status] || ''
})

async function loadPending() {
  loading.value.pending = true
  try {
    pendingList.value = (await auditApi.pending()).data || []
    saveAuditCache()
  }
  catch { ElMessage.error('加载待审批失败') }
  finally { loading.value.pending = false }
}
async function loadMy() {
  loading.value.my = true
  try {
    myList.value = (await auditApi.my()).data || []
    saveAuditCache()
  }
  catch { ElMessage.error('加载申请记录失败') }
  finally { loading.value.my = false }
}
async function loadHistory(page) {
  if (typeof page === 'number') historyPage.value = page
  loading.value.history = true
  try {
    const d = (await auditApi.all({ page: historyPage.value, size: 20 })).data || {}
    historyList.value = d.content ?? d.items ?? (Array.isArray(d) ? d : [])
    historyTotal.value = d.total ?? d.totalElements ?? historyList.value.length
    saveAuditCache()
  } catch {
    ElMessage.error('加载历史记录失败')
  } finally {
    loading.value.history = false
  }
}
function onTabChange(tab) {
  if (tab === 'pending' && pendingList.value.length === 0) loadPending()
  else if (tab === 'my' && myList.value.length === 0) loadMy()
  else if (tab === 'history' && historyList.value.length === 0) loadHistory()
}

function openDetail(row) { detailRecord.value = row; detailVisible.value = true }
function openApprove(row) { approveRecord.value = row; approveRemark.value = ''; approveVisible.value = true }
function openApproveFromDetail(row) { detailVisible.value = false; openApprove(row) }
function openReject(row) { detailVisible.value = false; rejectRecord.value = row; rejectReason.value = ''; rejectVisible.value = true }

async function doApprove() {
  if (!approveRecord.value) return
  actionLoading.value = true
  try {
    await auditApi.approve(approveRecord.value.id, { remark: approveRemark.value })
    ElMessage.success('审批通过，操作已执行')
    approveVisible.value = false
    loadPending()
    if (activeTab.value === 'history') loadHistory()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '审批失败')
  } finally {
    actionLoading.value = false
  }
}
async function doReject() {
  if (!rejectRecord.value) return
  actionLoading.value = true
  try {
    await auditApi.reject(rejectRecord.value.id, { reason: rejectReason.value })
    ElMessage.success('已驳回申请')
    rejectVisible.value = false
    loadPending()
    if (activeTab.value === 'history') loadHistory()
  } catch (e) {
    ElMessage.error(e.response?.data?.message || '驳回失败')
  } finally {
    actionLoading.value = false
  }
}

async function refreshAuditPage() {
  if (activeTab.value === 'history') {
    await loadHistory(historyPage.value)
    return
  }
  if (activeTab.value === 'pending' && authStore.isAdmin) {
    await loadPending()
    return
  }
  await loadMy()
}

useResumeRefresh(refreshAuditPage)

onMounted(() => {
  restoreAuditCache()
  if (authStore.isAdmin) loadPending()
  else loadMy()
})
</script>

<style scoped>
.audit-view { padding: 0 2px; }
.tab-toolbar { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
.record-count { color: #64748b; font-size: 12px; }
.name-text { font-weight: 500; }
.pagination-bar { display: flex; justify-content: flex-end; margin-top: 14px; }
.text-muted { color: #94a3b8; }
.dialog-tip { color: #374151; margin-bottom: 14px; }

.desktop-table { display: block; }
.mobile-list { display: none; }
.mobile-empty { padding: 18px 10px; color: #94a3b8; text-align: center; font-size: 12px; }
.audit-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 10px 12px;
  margin-bottom: 8px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, .04);
}
.audit-card-head { display: flex; justify-content: space-between; align-items: center; gap: 6px; margin-bottom: 6px; }
.audit-card-time { font-size: 11px; color: #64748b; white-space: nowrap; }
.audit-card-title { font-size: 13px; font-weight: 700; color: #1f2937; margin-bottom: 6px; line-height: 1.35; word-break: break-word; }
.audit-card-subtitle { font-size: 11.5px; color: #64748b; margin-bottom: 6px; line-height: 1.35; word-break: break-word; }
.audit-card-meta {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px 10px;
  margin-bottom: 8px;
  font-size: 11.5px;
  color: #64748b;
}
.audit-card-meta span {
  min-width: 0;
  line-height: 1.35;
  word-break: break-word;
}
.audit-card-meta span:last-child:nth-child(odd) {
  grid-column: 1 / -1;
}
.audit-card-actions { display: flex; flex-wrap: wrap; gap: 6px; }
.audit-card-actions :deep(.el-button),
.audit-card-actions .el-button {
  min-height: 28px;
  padding: 6px 10px;
  border-radius: 9px;
  font-size: 12px;
}
.reject-text { color: #dc2626; }

.workflow-hint {
  margin-top: 24px;
  padding: 18px 20px;
  background: #f8fafc;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
}
.workflow-title { font-size: 12px; font-weight: 600; color: #64748b; margin-bottom: 14px; text-transform: uppercase; letter-spacing: .5px; }
.workflow-steps-row { display: flex; align-items: center; gap: 0; flex-wrap: wrap; }
.wf-step { display: flex; align-items: center; gap: 10px; flex: 1; min-width: 140px; }
.wf-step-icon {
  width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-size: 13px; font-weight: 700; flex-shrink: 0;
}
.wf-step-done .wf-step-icon { background: #d1fae5; color: #059669; }
.wf-step-active .wf-step-icon { background: #fef3c7; color: #d97706; }
.wf-step-pending .wf-step-icon { background: #e0e7ff; color: #4338ca; }
.wf-step-label { font-size: 12px; color: #475569; line-height: 1.4; }
.wf-arrow { font-size: 18px; color: #cbd5e1; padding: 0 8px; flex-shrink: 0; }

.flow-bar {
  display: flex; align-items: center;
  padding: 16px 20px; border-radius: 12px; margin-bottom: 14px;
  border: 1px solid #e2e8f0; background: #f8fafc;
}
.flow-bar-approved { border-color: #bbf7d0; background: #f0fdf4; }
.flow-bar-rejected { border-color: #fecaca; background: #fff5f5; }
.flow-bar-pending { border-color: #fde68a; background: #fffbeb; }
.flow-step { display: flex; align-items: center; gap: 10px; flex: 1; }
.flow-line { height: 2px; flex: 0 0 32px; background: #e2e8f0; }
.flow-dot {
  width: 30px; height: 30px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  font-size: 13px; font-weight: 700; border: 2px solid transparent;
}
.done-dot { background: #d1fae5; color: #059669; border-color: #6ee7b7; }
.active-dot { background: #fef3c7; color: #d97706; border-color: #fcd34d; }
.error-dot { background: #fee2e2; color: #dc2626; border-color: #fca5a5; }
.flow-info { min-width: 0; }
.flow-title { font-size: 12px; font-weight: 600; color: #374151; }
.flow-sub { font-size: 11px; color: #64748b; margin-top: 2px; word-break: break-all; }

.remark-bar {
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 13px;
  background: #eff6ff;
  color: #1d4ed8;
  margin-bottom: 12px;
}
.remark-label { font-weight: 600; margin-right: 8px; }

.diff-wrap { border: 1px solid #e2e8f0; border-radius: 10px; overflow: hidden; }
.diff-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; background: #f8fafc; border-bottom: 1px solid #e2e8f0;
}
.diff-header-title { font-size: 13px; font-weight: 600; color: #374151; }
.diff-changed-count { font-size: 12px; color: #d97706; }
.diff-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.dt-th-label { background: #f1f5f9; padding: 8px 12px; text-align: left; font-weight: 600; color: #475569; border-bottom: 1px solid #e2e8f0; }
.dt-th-orig { background: #fff7ed; padding: 8px 12px; text-align: left; font-weight: 600; color: #92400e; border-bottom: 1px solid #e2e8f0; border-left: 1px solid #fed7aa; }
.dt-th-new { background: #f0fdf4; padding: 8px 12px; text-align: left; font-weight: 600; color: #14532d; border-bottom: 1px solid #e2e8f0; border-left: 1px solid #bbf7d0; }
.dt-row-changed td { background: #fffbeb; }
.dt-cell-label { padding: 8px 12px; color: #64748b; font-weight: 500; border-bottom: 1px solid #f1f5f9; white-space: nowrap; }
.dt-cell-orig { padding: 8px 12px; border-bottom: 1px solid #f1f5f9; border-left: 1px solid #fed7aa; word-break: break-all; }
.dt-cell-new { padding: 8px 12px; border-bottom: 1px solid #f1f5f9; border-left: 1px solid #bbf7d0; word-break: break-all; }
.empty-row { text-align: center; color: #94a3b8; padding: 16px; }
.val-del {
  display: inline-block; background: #fee2e2; color: #991b1b;
  border-radius: 4px; padding: 1px 6px; text-decoration: line-through; text-decoration-color: #dc2626;
}
.val-add { display: inline-block; background: #dcfce7; color: #14532d; border-radius: 4px; padding: 1px 6px; }
.val-empty { color: #94a3b8; }

@media (max-width: 640px) {
  .tab-toolbar { flex-wrap: wrap; justify-content: space-between; gap: 8px; margin-bottom: 8px; }
  .desktop-table { display: none; }
  .mobile-list { display: block; }
  .pagination-bar { justify-content: center; }
  :deep(.el-tabs__header) { margin-bottom: 10px; }
  :deep(.el-tabs__nav-wrap::after) { height: 1px; }
  :deep(.el-tabs__item) { padding: 0 8px; font-size: 13px; height: 38px; line-height: 38px; }
  .tab-toolbar :deep(.el-button),
  .tab-toolbar .el-button {
    min-height: 30px;
    padding: 6px 12px;
    border-radius: 9px;
    font-size: 12px;
  }
  .flow-bar { flex-direction: column; align-items: flex-start; gap: 10px; }
  .flow-line { width: 2px; height: 16px; flex: none; margin-left: 14px; }
  .workflow-hint { margin-top: 14px; padding: 10px 12px; border-radius: 10px; }
  .wf-arrow { display: none; }
  .workflow-steps-row { gap: 8px; }
  .wf-step { flex: none; }
  .diff-table { font-size: 12px; }
}
</style>
