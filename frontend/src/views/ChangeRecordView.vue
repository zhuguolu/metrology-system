<template>
  <div class="query-shell change-record-view">
    <div class="mobile-query-head change-mobile-query-head">
      <div class="mobile-query-row">
        <el-input
          v-model="keyword"
          class="mobile-query-search"
          placeholder="搜索设备名称、编号、备注"
          clearable
          @keyup.enter="applyFilter"
          @clear="applyFilter"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
      </div>
      <div class="mobile-query-actions change-mobile-query-actions">
        <el-button class="mobile-query-action is-compact" @click="showMobileFilters = !showMobileFilters">{{ mobileFilterCompactLabel }}</el-button>
        <el-button v-if="activeFilterCount" class="mobile-query-action is-compact" @click="resetFilter">重置</el-button>
      </div>
    </div>

    <div class="filter-bar change-filter-bar" :class="{ 'mobile-filter-hidden': isMobile && !showMobileFilters }">
      <div v-if="!isMobile" class="filter-group change-filter-search">
        <div class="filter-label">搜索</div>
        <el-input v-model="keyword" placeholder="设备名称 / 设备编号 / 备注" clearable class="search-input" @keyup.enter="applyFilter" @clear="applyFilter">
          <template #prefix>
            <el-icon><Search /></el-icon></template>
        </el-input>
      </div>
      <div class="filter-group">
        <div class="filter-label">操作类型</div>
        <el-select v-model="type" placeholder="操作类型" clearable style="width:120px" @change="applyFilter">
          <el-option label="新增" value="CREATE" />
          <el-option label="修改" value="UPDATE" />
          <el-option label="删除" value="DELETE" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">处理状态</div>
        <el-select v-model="status" placeholder="处理状态" clearable style="width:120px" @change="applyFilter">
          <el-option label="待审批" value="PENDING" />
          <el-option label="已通过" value="APPROVED" />
          <el-option label="已驳回" value="REJECTED" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">开始日期</div>
        <input v-model="dateFrom" type="date" class="date-input" @change="applyFilter" />
      </div>
      <div class="filter-group">
        <div class="filter-label">结束日期</div>
        <input v-model="dateTo" type="date" class="date-input" @change="applyFilter" />
      </div>
      <div v-if="authStore.isAdmin" class="filter-group">
        <div class="filter-label">提交人</div>
        <el-input v-model="submittedBy" placeholder="提交人" clearable style="width:120px" @keyup.enter="applyFilter" @clear="applyFilter" />
      </div>
      <div class="filter-actions change-filter-actions">
        <el-button @click="resetFilter">重置</el-button>
        <el-button type="primary" @click="applyFilter">查询</el-button>
      </div>
    </div>

    <div class="page-results-bar change-results-bar">
      <div class="page-results-meta">
        <span class="page-results-chip page-results-chip-strong">共 {{ total }} 条</span>
        <span class="page-results-chip">当前第 {{ page }} / {{ totalPages || 1 }} 页</span>
        <span v-if="activeFilterCount" class="page-results-chip">筛选 {{ activeFilterCount }} 项</span>
        <span v-if="authStore.isAdmin" class="page-results-chip">涉及 {{ stats.submitterCount || 0 }} 位用户</span>
      </div>
      <div v-if="keyword" class="page-results-extra">关键词：{{ keyword }}</div>
    </div>

    <div class="table-wrap">
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th>操作类型</th>
              <th>设备名称</th>
              <th>设备编号</th>
              <th v-if="authStore.isAdmin">提交人</th>
              <th>状态</th>
              <th>变更项</th>
              <th>提交时间</th>
              <th>处理时间</th>
              <th>处理人</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="rows.length===0" class="empty-row">
              <td :colspan="authStore.isAdmin ? 10 : 9">{{ loading ? '加载中...' : '暂无变更记录' }}</td>
            </tr>
            <tr v-for="row in rows" :key="row.id">
              <td><span :class="['tag', changeTypeTag(row.type)]">{{ typeLabel(row.type) }}</span></td>
              <td><span class="change-name-link" @click="openDetail(row)">{{ row.deviceName || '-' }}</span></td>
              <td><code class="change-record-code">{{ row.metricNo || '-' }}</code></td>
              <td v-if="authStore.isAdmin">{{ row.submittedBy || '-' }}</td>
              <td><span :class="['tag', changeStatusTag(row.status)]">{{ statusLabel(row.status) }}</span></td>
              <td>{{ row.changedFieldCount || 0 }}</td>
              <td>{{ formatTime(row.submittedAt) || '-' }}</td>
              <td>{{ formatTime(row.approvedAt) || '-' }}</td>
              <td>{{ row.approvedBy || '-' }}</td>
              <td>
                <div class="action-group">
                  <button class="action-btn action-btn-view" @click="openDetail(row)">查看</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="mobile-list">
      <div v-if="loading && !rows.length" class="mobile-empty">加载中...</div>
      <div v-else-if="!rows.length" class="mobile-empty">暂无变更记录</div>
      <div v-else v-for="row in rows" :key="row.id" class="m-card change-mobile-card">
        <div class="m-card-row change-mobile-card-head">
          <div class="change-mobile-card-title-wrap">
            <div class="m-card-title change-name-link" @click="openDetail(row)">{{ row.deviceName || '-' }}</div>
          </div>
          <span :class="['tag', changeStatusTag(row.status), 'change-mobile-status']">{{ statusLabel(row.status) }}</span>
        </div>
        <div class="m-card-meta change-mobile-meta">
          <div class="m-card-meta-item change-mobile-meta-item">
            <span class="change-mobile-meta-label">操作</span>
            <b>{{ typeLabel(row.type) }}</b>
          </div>
          <div class="m-card-meta-item change-mobile-meta-item">
            <span class="change-mobile-meta-label">编号</span>
            <b>{{ row.metricNo || '-' }}</b>
          </div>
          <div v-if="authStore.isAdmin" class="m-card-meta-item change-mobile-meta-item">
            <span class="change-mobile-meta-label">提交人</span>
            <b>{{ row.submittedBy || '-' }}</b>
          </div>
          <div class="m-card-meta-item change-mobile-meta-item">
            <span class="change-mobile-meta-label">变更项</span>
            <b>{{ row.changedFieldCount || 0 }}</b>
          </div>
          <div class="m-card-meta-item change-mobile-meta-item change-mobile-meta-item-span">
            <span class="change-mobile-meta-label">处理结果</span>
            <b>{{ row.approvedBy ? `${row.approvedBy} · ${formatTime(row.approvedAt) || '-'}` : (row.status === 'PENDING' ? '等待处理' : '-') }}</b>
          </div>
        </div>
        <div class="m-card-footer change-mobile-card-footer">
          <div class="mobile-card-kpi change-mobile-card-kpi">
            <span :class="['tag', changeTypeTag(row.type), 'change-mobile-type']">{{ typeLabel(row.type) }}</span>
          </div>
          <div class="m-card-actions change-mobile-actions">
            <button class="action-btn action-btn-view" @click="openDetail(row)">查看</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="total > 0" class="page-pagination">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :page-sizes="[10, 20, 50, 100]"
        :total="total"
        :layout="paginationLayout"
        :small="isMobile"
        background
        @size-change="() => loadData(1)"
        @current-change="loadData"
      />
    </div>

    <el-dialog v-model="detailVisible" :title="detailDialogTitle" width="min(720px, 96vw)" top="4vh">
      <div v-if="detailLoading" class="mobile-empty">加载中...</div>
      <div v-else-if="detailRecord">
        <div class="change-detail-hero">
          <div class="change-detail-hero-main">
            <div class="change-detail-hero-title">{{ detailDeviceName || '-' }}</div>
            <div class="change-detail-hero-sub">
              <code class="change-detail-code">{{ detailMetricNo || '-' }}</code>
              <span class="change-detail-dot">•</span>
              <span>{{ typeLabel(detailRecord.type) }}记录</span>
            </div>
          </div>
          <div class="change-detail-badges">
            <span :class="['tag', changeTypeTag(detailRecord.type)]">{{ typeLabel(detailRecord.type) }}</span>
            <span :class="['tag', changeStatusTag(detailRecord.status)]">{{ statusLabel(detailRecord.status) }}</span>
          </div>
        </div>

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
              <div class="flow-title">处理结果</div>
              <div class="flow-sub">
                <span v-if="detailRecord.status === 'PENDING'" style="color:#f59e0b">等待管理员处理</span>
                <span v-else>{{ detailRecord.approvedBy || '-' }} · {{ formatTime(detailRecord.approvedAt) || '-' }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="change-detail-section">
          <div class="change-detail-section-title">记录信息</div>
          <div class="preview-grid change-detail-grid">
            <div class="preview-item"><span class="preview-label">设备名称</span><span class="preview-val">{{ detailDeviceName || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">设备编号</span><span class="preview-val"><code class="change-detail-code">{{ detailMetricNo || '-' }}</code></span></div>
            <div class="preview-item"><span class="preview-label">操作类型</span><span class="preview-val"><span :class="['tag', changeTypeTag(detailRecord.type)]">{{ typeLabel(detailRecord.type) }}</span></span></div>
            <div class="preview-item"><span class="preview-label">处理状态</span><span class="preview-val"><span :class="['tag', changeStatusTag(detailRecord.status)]">{{ statusLabel(detailRecord.status) }}</span></span></div>
            <div class="preview-item"><span class="preview-label">提交人</span><span class="preview-val">{{ detailRecord.submittedBy || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">处理人</span><span class="preview-val">{{ detailRecord.approvedBy || (detailRecord.status === 'PENDING' ? '等待处理' : '-') }}</span></div>
            <div class="preview-item"><span class="preview-label">提交时间</span><span class="preview-val">{{ formatTime(detailRecord.submittedAt) || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">处理时间</span><span class="preview-val">{{ formatTime(detailRecord.approvedAt) || '-' }}</span></div>
          </div>
        </div>

        <div v-if="detailRecord.remark" class="remark-bar">
          <span class="remark-label">备注</span>{{ detailRecord.remark }}
        </div>
        <div v-if="detailRecord.rejectReason" class="remark-bar reject-bar">
          <span class="remark-label">驳回原因</span>{{ detailRecord.rejectReason }}
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
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { changeRecordApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const authStore = useAuthStore()
const changeRecordCache = useViewCache('change-record-view', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('change-record-view')
const loading = ref(false)
const detailLoading = ref(false)
const rows = ref([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const isMobile = ref(false)
const showMobileFilters = ref(true)

const keyword = ref('')
const type = ref('')
const status = ref('')
const submittedBy = ref('')
const dateFrom = ref('')
const dateTo = ref('')

const stats = ref({
  total: 0,
  pending: 0,
  approved: 0,
  rejected: 0,
  createCount: 0,
  updateCount: 0,
  deleteCount: 0,
  submitterCount: 0
})

const detailVisible = ref(false)
const detailRecord = ref(null)

function restoreChangeRecordCache() {
  const cached = changeRecordCache.restore()
  if (!cached) return

  rows.value = Array.isArray(cached.rows) ? cached.rows : []
  total.value = Number(cached.total) || 0
  page.value = Number(cached.page) || 1
  pageSize.value = Number(cached.pageSize) || 20
  keyword.value = cached.keyword || ''
  type.value = cached.type || ''
  status.value = cached.status || ''
  submittedBy.value = cached.submittedBy || ''
  dateFrom.value = cached.dateFrom || ''
  dateTo.value = cached.dateTo || ''
  stats.value = { ...stats.value, ...(cached.stats || {}) }
}

function saveChangeRecordCache() {
  changeRecordCache.save({
    rows: rows.value,
    total: total.value,
    page: page.value,
    pageSize: pageSize.value,
    keyword: keyword.value,
    type: type.value,
    status: status.value,
    submittedBy: submittedBy.value,
    dateFrom: dateFrom.value,
    dateTo: dateTo.value,
    stats: stats.value
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
  cycle: '校准周期',
  calDate: '上次校准日期',
  calResult: '校准结果',
  calibrationResult: '校准结果',
  remark: '备注',
  imageUrl: '设备图片',
  imagePath: '设备图片',
  imageName: '设备图片1',
  imagePath2: '设备图片2',
  imageName2: '设备图片2',
  certUrl: '校准证书',
  certPath: '校准证书'
}
const SKIP_FIELDS = new Set(['id', 'nextCalDate', 'nextDate', 'validity', 'daysPassed'])

const activeFilterCount = computed(() =>
  [keyword.value, type.value, submittedBy.value, dateFrom.value, dateTo.value].filter(Boolean).length
)
const mobileFilterCompactLabel = computed(() =>
  showMobileFilters.value ? '收起' : '筛选' + (activeFilterCount.value ? `(${activeFilterCount.value})` : '')
)
const paginationLayout = computed(() =>
  isMobile.value ? 'prev, pager, next' : 'total, sizes, prev, pager, next, jumper'
)
const totalPages = computed(() => Math.max(1, Math.ceil((total.value || 0) / (pageSize.value || 1))))

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
function normalizeComparableValue(v) {
  if (v === null || v === undefined) return null
  const normalized = String(v).trim()
  return normalized === '' ? null : normalized
}

const diffRows = computed(() => {
  if (!detailRecord.value) return []
  const recordType = detailRecord.value.type
  const orig = parseRaw(detailRecord.value.originalData)
  const now = parseRaw(detailRecord.value.newData)

  if (recordType === 'UPDATE') {
    return Object.keys(now)
      .filter(k => !SKIP_FIELDS.has(k))
      .map(k => {
        const newRaw = now[k]
        const submitted = newRaw !== null && newRaw !== undefined
        const origVal = orig[k] ?? ''
        const newVal = submitted ? newRaw : ''
        return {
          key: k,
          label: fieldLabel(k),
          origVal,
          newVal,
          submitted,
          changed: submitted && normalizeComparableValue(origVal) !== normalizeComparableValue(newVal)
        }
      })
      .filter(r => r.submitted && r.changed)
  }
  if (recordType === 'CREATE') {
    return Object.entries(now)
      .filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v))
      .map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: '', newVal: v }))
  }
  return Object.entries(orig)
    .filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v))
    .map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: v, newVal: '' }))
})

const detailDialogTitle = computed(() => {
  if (!detailRecord.value) return '变更详情'
  return `${typeLabel(detailRecord.value.type)}记录 · ${statusLabel(detailRecord.value.status)}`
})
const detailDeviceName = computed(() => firstNonBlank(
  parseRaw(detailRecord.value?.newData).name,
  parseRaw(detailRecord.value?.originalData).name
))
const detailMetricNo = computed(() => firstNonBlank(
  parseRaw(detailRecord.value?.newData).metricNo,
  parseRaw(detailRecord.value?.originalData).metricNo
))
const flowBarClass = computed(() => {
  if (!detailRecord.value) return ''
  return { APPROVED: 'flow-bar-approved', REJECTED: 'flow-bar-rejected', PENDING: 'flow-bar-pending' }[detailRecord.value.status] || ''
})

function typeLabel(t) { return { CREATE: '新增', UPDATE: '修改', DELETE: '删除' }[t] || t }
function statusLabel(s) { return { PENDING: '待审批', APPROVED: '已通过', REJECTED: '已驳回' }[s] || s }
function changeTypeTag(t) { return { CREATE: 'tag-green', UPDATE: 'tag-blue', DELETE: 'tag-expired' }[t] || 'tag-blue' }
function changeStatusTag(s) { return { PENDING: 'tag-warning', APPROVED: 'tag-valid', REJECTED: 'tag-expired' }[s] || 'tag-blue' }
function formatTime(t) {
  if (!t) return ''
  return new Date(t).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}
function firstNonBlank(...values) {
  for (const value of values) {
    if (value !== null && value !== undefined && String(value).trim() !== '') return value
  }
  return ''
}

async function loadData(targetPage = page.value) {
  page.value = targetPage
  loading.value = true
  try {
    const response = await changeRecordApi.list({
      page: page.value,
      size: pageSize.value,
      keyword: keyword.value || undefined,
      type: type.value || undefined,
      status: status.value || undefined,
      submittedBy: authStore.isAdmin ? (submittedBy.value || undefined) : undefined,
      dateFrom: dateFrom.value || undefined,
      dateTo: dateTo.value || undefined
    })
    const data = response.data || {}
    rows.value = data.items || []
    total.value = data.total || 0
    stats.value = { ...stats.value, ...(data.stats || {}) }
    saveChangeRecordCache()
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '加载变更记录失败')
  } finally {
    loading.value = false
  }
}

function applyFilter() {
  loadData(1)
}

function resetFilter() {
  keyword.value = ''
  type.value = ''
  status.value = ''
  submittedBy.value = ''
  dateFrom.value = ''
  dateTo.value = ''
  loadData(1)
}

async function openDetail(row) {
  detailVisible.value = true
  detailLoading.value = true
  detailRecord.value = null
  try {
    detailRecord.value = (await changeRecordApi.get(row.id)).data
  } catch (error) {
    ElMessage.error(error.response?.data?.message || '加载详情失败')
    detailVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

function syncViewport() {
  const mobile = window.innerWidth <= 768
  if (mobile !== isMobile.value) {
    isMobile.value = mobile
    showMobileFilters.value = !mobile
    return
  }
  isMobile.value = mobile
}

useResumeRefresh(() => loadData(page.value))

onMounted(() => {
  restoreChangeRecordCache()
  syncViewport()
  window.addEventListener('resize', syncViewport)
  loadData()
})

onUnmounted(() => {
  window.removeEventListener('resize', syncViewport)
})
</script>

<style scoped>
.change-record-view { padding: 0 2px; }
.preview-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px 20px;
  margin-top: 8px;
}
.preview-item { display: flex; flex-direction: column; gap: 2px; }
.preview-label { font-size: 11.5px; color: var(--text-muted); }
.preview-val { font-size: 13.5px; color: var(--text); }
.change-name-link {
  font-weight: 600;
  color: var(--primary);
  cursor: pointer;
}
.change-record-code {
  font-size: 12px;
  background: #f1f5f9;
  padding: 2px 6px;
  border-radius: 4px;
}
.change-mobile-card {
  padding: 10px 12px;
  margin-bottom: 10px;
  border-radius: 14px;
}
.change-mobile-card-head {
  margin-bottom: 6px;
  align-items: center;
  gap: 8px;
}
.change-mobile-card-title-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1;
}
.change-mobile-card .m-card-title {
  font-size: 14px;
  line-height: 1.3;
  -webkit-line-clamp: 1;
}
.change-mobile-status,
.change-mobile-type {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 999px;
}
.change-mobile-meta {
  gap: 5px 10px;
  margin-bottom: 6px;
}
.change-mobile-meta-item {
  gap: 3px;
  font-size: 11px;
  line-height: 1.25;
}
.change-mobile-meta-item-span {
  grid-column: 1 / -1;
}
.change-mobile-meta-label {
  color: var(--text-muted);
  flex-shrink: 0;
}
.change-mobile-meta-item b {
  font-size: 11.5px;
  font-weight: 700;
  color: var(--text);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.change-mobile-card-footer {
  padding-top: 6px;
  gap: 8px;
  align-items: center;
}
.change-mobile-card-kpi { gap: 6px; }
.change-mobile-actions {
  width: auto;
  margin-left: auto;
  gap: 6px;
}
.change-mobile-actions .action-btn {
  min-height: 27px;
  padding: 5px 9px;
  font-size: 11.5px;
  border-radius: 10px;
}
.change-detail-hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  margin-bottom: 12px;
  border-radius: 14px;
  border: 1px solid #dbeafe;
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.55), transparent 30%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
}
.change-detail-hero-main {
  min-width: 0;
}
.change-detail-hero-title {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.25;
}
.change-detail-hero-sub {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  margin-top: 6px;
  font-size: 12px;
  color: #64748b;
}
.change-detail-dot {
  color: #cbd5e1;
}
.change-detail-code {
  font-size: 12px;
  background: #eff6ff;
  padding: 2px 7px;
  border-radius: 999px;
  color: #1d4ed8;
}
.change-detail-badges {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 6px;
}
.change-detail-section {
  margin-bottom: 12px;
}
.change-detail-section-title {
  margin-bottom: 4px;
  font-size: 12px;
  font-weight: 700;
  color: #64748b;
}
.change-detail-grid {
  padding: 4px 0 0;
}
.flow-bar {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  border-radius: 12px;
  margin-bottom: 14px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.flow-bar-approved { border-color: #bbf7d0; background: #f0fdf4; }
.flow-bar-rejected { border-color: #fecaca; background: #fff5f5; }
.flow-bar-pending { border-color: #fde68a; background: #fffbeb; }
.flow-step { display: flex; align-items: center; gap: 10px; flex: 1; }
.flow-line { height: 2px; flex: 0 0 32px; background: #e2e8f0; }
.flow-dot {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  font-weight: 700;
  border: 2px solid transparent;
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
.reject-bar {
  background: #fff5f5;
  color: #b91c1c;
}
.remark-label { font-weight: 600; margin-right: 8px; }
.diff-wrap { border: 1px solid #e2e8f0; border-radius: 10px; overflow: hidden; }
.diff-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
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
  display: inline-block;
  background: #fee2e2;
  color: #991b1b;
  border-radius: 4px;
  padding: 1px 6px;
  text-decoration: line-through;
  text-decoration-color: #dc2626;
}
.val-add {
  display: inline-block;
  background: #dcfce7;
  color: #14532d;
  border-radius: 4px;
  padding: 1px 6px;
}
.val-empty { color: #94a3b8; }

@media (max-width: 768px) {
  .mobile-filter-hidden { display: none; }
  .change-filter-bar.mobile-filter-hidden { display: none !important; }
  .change-filter-bar {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
    padding: 8px 10px;
    align-items: end;
  }
  .change-filter-bar .filter-group {
    min-width: 0;
    width: auto;
    gap: 4px;
  }
  .change-filter-bar .filter-label {
    font-size: 11.5px;
    margin-bottom: 0;
  }
  .change-filter-bar :deep(.el-select),
  .change-filter-bar :deep(.el-input) {
    width: 100% !important;
  }
  .change-filter-bar :deep(.el-input__wrapper) {
    min-height: 34px;
    padding: 0 10px;
  }
  .change-filter-actions {
    width: 100%;
    grid-column: 1 / -1;
    padding-top: 4px;
    margin-top: 2px;
  }
  .change-mobile-meta {
    grid-template-columns: 1fr 1fr;
  }
  .change-mobile-card {
    padding: 9px 11px;
    border-radius: 13px;
  }
}

@media (max-width: 640px) {
  .change-detail-hero {
    flex-direction: column;
    align-items: stretch;
    padding: 12px 13px;
  }
  .change-detail-badges {
    justify-content: flex-start;
  }
  .preview-grid {
    grid-template-columns: 1fr;
    gap: 8px;
  }
  .flow-bar {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }
  .flow-line {
    width: 2px;
    height: 16px;
    flex: none;
    margin-left: 14px;
  }
}

@media (max-width: 480px) {
  .change-filter-bar {
    gap: 7px;
    padding: 8px;
  }
  .change-mobile-card {
    padding: 8px 9px;
  }
  .change-mobile-meta {
    gap: 4px 7px;
  }
  .change-mobile-actions .action-btn {
    padding: 4px 8px;
    min-height: 27px;
    font-size: 11px;
  }
}
</style>
