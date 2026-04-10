
<template>
  <div class="audit-view">
    <div class="audit-hero-card">
      <div>
        <div class="audit-hero-eyebrow">Audit Center</div>
        <h2>数据审核工作台</h2>
        <p>统一处理设备变更申请、审批记录与历史追踪，让流程状态和变更结果一眼看清。</p>
      </div>
      <div class="audit-hero-stats">
        <div
          v-if="authStore.isAdmin"
          class="audit-stat-pill audit-stat-pill-warning is-clickable"
          :class="{ 'is-active': activeTab === 'pending' }"
          @click="switchAuditTab('pending')"
        >待审批 {{ pendingList.length }}</div>
        <div
          class="audit-stat-pill audit-stat-pill-primary is-clickable"
          :class="{ 'is-active': activeTab === 'my' }"
          @click="switchAuditTab('my')"
        >我的申请 {{ myList.length }}</div>
        <div
          v-if="authStore.isAdmin"
          class="audit-stat-pill audit-stat-pill-neutral is-clickable"
          :class="{ 'is-active': activeTab === 'history' }"
          @click="switchAuditTab('history')"
        >历史 {{ historyTotal }}</div>
      </div>
    </div>

    <el-tabs v-model="activeTab" class="audit-tabs" @tab-change="onTabChange">
      <el-tab-pane v-if="authStore.isAdmin" label="待审批" name="pending">
        <div class="tab-toolbar audit-toolbar-card">
          <span class="record-count">共 <b>{{ pendingList.length }}</b> 条待审批</span>
          <el-button size="small" @click="loadPending">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="pendingList" border stripe v-loading="loading.pending" empty-text="暂无待审批记录">
          <el-table-column prop="submittedBy" label="提交人" width="110" />
          <el-table-column label="操作类型" width="100">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="180">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column label="计量编号" min-width="140">
            <template #default="{ row }">{{ deviceMetricNo(row) }}</template>
          </el-table-column>
          <el-table-column prop="submittedAt" label="提交时间" width="165">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="remark" label="备注" min-width="140" show-overflow-tooltip />
          <el-table-column label="操作" width="210" fixed="right">
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
        <div class="tab-toolbar audit-toolbar-card">
          <span class="record-count">最近提交 {{ myList.length }} 条申请</span>
          <el-button size="small" @click="loadMy">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="myList" border stripe v-loading="loading.my" empty-text="暂无申请记录">
          <el-table-column label="操作类型" width="100">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="180">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="submittedAt" label="提交时间" width="165">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="approvedAt" label="审批时间" width="165">
            <template #default="{ row }">{{ formatTime(row.approvedAt) }}</template>
          </el-table-column>
          <el-table-column label="驳回原因" min-width="150" show-overflow-tooltip>
            <template #default="{ row }">
              <span v-if="row.rejectReason" class="reject-text">{{ row.rejectReason }}</span>
              <span v-else class="text-muted">-</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="90" fixed="right">
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
              <div class="wf-step-label">管理员审核与确认</div>
            </div>
            <div class="wf-arrow">→</div>
            <div class="wf-step wf-step-pending">
              <div class="wf-step-icon">3</div>
              <div class="wf-step-label">审批完成后自动生效</div>
            </div>
          </div>
        </div>
      </el-tab-pane>

      <el-tab-pane v-if="authStore.isAdmin" label="审批历史" name="history">
        <div class="tab-toolbar audit-toolbar-card">
          <span class="record-count">累计 {{ historyTotal }} 条历史记录</span>
          <el-button size="small" @click="loadHistory">刷新</el-button>
        </div>

        <el-table class="desktop-table" :data="historyList" border stripe v-loading="loading.history" empty-text="暂无审批历史">
          <el-table-column prop="submittedBy" label="提交人" width="110" />
          <el-table-column label="操作类型" width="100">
            <template #default="{ row }">
              <el-tag :type="typeTagType(row.type)" size="small" effect="light">{{ typeLabel(row.type) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="设备名称" min-width="170">
            <template #default="{ row }"><span class="name-text">{{ deviceName(row) }}</span></template>
          </el-table-column>
          <el-table-column label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="statusTagType(row.status)" size="small" effect="plain">{{ statusLabel(row.status) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="approvedBy" label="审批人" width="110" />
          <el-table-column prop="submittedAt" label="提交时间" width="165">
            <template #default="{ row }">{{ formatTime(row.submittedAt) }}</template>
          </el-table-column>
          <el-table-column prop="approvedAt" label="审批时间" width="165">
            <template #default="{ row }">{{ formatTime(row.approvedAt) }}</template>
          </el-table-column>
          <el-table-column label="操作" width="90" fixed="right">
            <template #default="{ row }">
              <el-button size="small" plain @click="openDetail(row)">查看</el-button>
            </template>
          </el-table-column>
        </el-table>

        <div class="mobile-list">
          <div v-if="loading.history && !historyList.length" class="mobile-empty">加载中...</div>
          <div v-else-if="!historyList.length" class="mobile-empty">暂无审批历史</div>
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

    <el-dialog v-model="detailVisible" :title="detailDialogTitle" width="min(760px, 96vw)" top="4vh" class="audit-detail-dialog">
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
              {{ detailRecord.status === 'PENDING' ? '…' : (detailRecord.status === 'APPROVED' ? '✓' : '!') }}
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
            <span class="diff-header-title">{{ detailRecord.type === 'UPDATE' ? '变更字段' : detailRecord.type === 'CREATE' ? '新增设备数据' : '删除设备数据' }}</span>
            <span v-if="detailRecord.type === 'UPDATE'" class="diff-changed-count">{{ diffRows.length }} 项已修改</span>
          </div>

          <template v-if="detailRecord.type === 'UPDATE'">
            <table class="diff-table">
              <colgroup>
                <col style="width:140px">
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
              <colgroup><col style="width:140px"><col></colgroup>
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
              <colgroup><col style="width:140px"><col></colgroup>
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

    <el-dialog v-model="approveVisible" title="确认审批通过" width="min(440px, 94vw)" class="audit-action-dialog">
      <p class="dialog-tip">操作将立即执行且不可撤销，请确认后提交。</p>
      <el-form label-width="84px">
        <el-form-item label="审批备注">
          <el-input v-model="approveRemark" type="textarea" :rows="3" placeholder="可选填写审批意见" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="approveVisible = false">取消</el-button>
        <el-button type="success" :loading="actionLoading" @click="doApprove">确认审批</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="rejectVisible" title="驳回申请" width="min(440px, 94vw)" class="audit-action-dialog">
      <el-form label-width="84px">
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
  auditCache.save({ activeTab: activeTab.value, pendingList: pendingList.value, myList: myList.value, historyList: historyList.value, historyPage: historyPage.value, historyTotal: historyTotal.value })
}

const FIELD_LABELS = {
  name: '设备名称', meteringNo: '计量编号', metricNo: '计量编号', assetNo: '资产编号', serialNo: '出厂编号', model: '设备型号', manufacturer: '制造厂', dept: '使用部门', location: '设备位置', responsiblePerson: '责任人', useStatus: '使用状态', classification: 'ABC分类', abcClass: 'ABC分类', purchaseDate: '采购日期', purchasePrice: '采购价格', serviceLife: '使用年限', graduationValue: '分度值', testRange: '测试范围', allowedError: '允许误差', allowableError: '允许误差', calibrationCycle: '检定周期', cycle: '检定周期', calDate: '上次校准日期', nextDate: '下次校准日期', calibrationResult: '校准结果', calResult: '校准结果', remark: '备注', imageUrl: '设备图片', imagePath: '设备图片1', imageName: '设备图片1', imagePath2: '设备图片2', imageName2: '设备图片2', certUrl: '校准证书', certPath: '校准证书', certName: '校准证书', validity: '有效性'
}
const SKIP_FIELDS = new Set(['id', 'daysPassed', 'status', 'nextCalDate', 'nextDate', 'validity'])
function fieldLabel(key) { return FIELD_LABELS[key] || key }
function parseRaw(json) { if (!json) return {}; try { return JSON.parse(json) } catch { return {} } }
function showVal(v) { return v !== null && v !== undefined && String(v).trim() !== '' }
function normalizeDiffValue(v) { return v === null || v === undefined ? '' : String(v).trim() }

const diffRows = computed(() => {
  if (!detailRecord.value) return []
  const type = detailRecord.value.type
  const orig = parseRaw(detailRecord.value.originalData)
  const now = parseRaw(detailRecord.value.newData)
  if (type === 'UPDATE') {
    return Object.keys(now)
      .filter(k => !SKIP_FIELDS.has(k))
      .filter(k => showVal(now[k]))
      .map((k) => {
        const origVal = orig[k] ?? ''
        const newVal = now[k]
        return {
          key: k,
          label: fieldLabel(k),
          origVal,
          newVal,
          changed: normalizeDiffValue(origVal) !== normalizeDiffValue(newVal)
        }
      })
      .filter(row => row.changed)
  }
  if (type === 'CREATE') return Object.entries(now).filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v)).map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: '', newVal: v }))
  return Object.entries(orig).filter(([k, v]) => !SKIP_FIELDS.has(k) && showVal(v)).map(([k, v]) => ({ key: k, label: fieldLabel(k), origVal: v, newVal: '' }))
})

function typeLabel(type) { return { CREATE: '新增', UPDATE: '修改', DELETE: '删除' }[type] || type }
function typeTagType(type) { return { CREATE: 'success', UPDATE: 'warning', DELETE: 'danger' }[type] || '' }
function statusLabel(status) { return { PENDING: '待审批', APPROVED: '已通过', REJECTED: '已驳回' }[status] || status }
function statusTagType(status) { return { PENDING: 'warning', APPROVED: 'success', REJECTED: 'danger' }[status] || '' }
function formatTime(time) { if (!time) return ''; return new Date(time).toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }) }
function deviceName(row) { const src = row?.type === 'DELETE' ? row?.originalData : row?.newData; if (!src) return '-'; try { return JSON.parse(src).name || '-' } catch { return '-' } }
function deviceMetricNo(row) { if (row?.metricNo) return row.metricNo; const src = row?.type === 'DELETE' ? row?.originalData : row?.newData; if (!src) return '-'; try { return JSON.parse(src).metricNo || '-' } catch { return '-' } }
const detailDialogTitle = computed(() => { if (!detailRecord.value) return '申请详情'; const typeTitle = { CREATE: '新增设备', UPDATE: '修改设备', DELETE: '删除设备' }[detailRecord.value.type] || '操作'; return `${typeTitle}申请 · ${statusLabel(detailRecord.value.status)}` })
const flowBarClass = computed(() => { if (!detailRecord.value) return ''; return { APPROVED: 'flow-bar-approved', REJECTED: 'flow-bar-rejected', PENDING: 'flow-bar-pending' }[detailRecord.value.status] || '' })

async function loadPending() { loading.value.pending = true; try { pendingList.value = (await auditApi.pending()).data || []; saveAuditCache() } catch { ElMessage.error('加载待审批记录失败') } finally { loading.value.pending = false } }
async function loadMy() { loading.value.my = true; try { myList.value = (await auditApi.my()).data || []; saveAuditCache() } catch { ElMessage.error('加载申请记录失败') } finally { loading.value.my = false } }
async function loadHistory(page) { if (typeof page === 'number') historyPage.value = page; loading.value.history = true; try { const data = (await auditApi.all({ page: historyPage.value, size: 20 })).data || {}; historyList.value = data.content ?? data.items ?? (Array.isArray(data) ? data : []); historyTotal.value = data.total ?? data.totalElements ?? historyList.value.length; saveAuditCache() } catch { ElMessage.error('加载审批历史失败') } finally { loading.value.history = false } }
function onTabChange(tab) { if (tab === 'pending' && pendingList.value.length === 0) loadPending(); else if (tab === 'my' && myList.value.length === 0) loadMy(); else if (tab === 'history' && historyList.value.length === 0) loadHistory() }
function switchAuditTab(tab) {
  if (!tab || activeTab.value === tab) return
  activeTab.value = tab
  onTabChange(tab)
  saveAuditCache()
}
function openDetail(row) { detailRecord.value = row; detailVisible.value = true }
function openApprove(row) { approveRecord.value = row; approveRemark.value = ''; approveVisible.value = true }
function openApproveFromDetail(row) { detailVisible.value = false; openApprove(row) }
function openReject(row) { detailVisible.value = false; rejectRecord.value = row; rejectReason.value = ''; rejectVisible.value = true }
async function doApprove() { if (!approveRecord.value) return; actionLoading.value = true; try { await auditApi.approve(approveRecord.value.id, { remark: approveRemark.value }); ElMessage.success('审批已通过，操作已执行'); approveVisible.value = false; loadPending(); if (activeTab.value === 'history') loadHistory() } catch (error) { ElMessage.error(error?.response?.data?.message || '审批失败') } finally { actionLoading.value = false } }
async function doReject() { if (!rejectRecord.value) return; actionLoading.value = true; try { await auditApi.reject(rejectRecord.value.id, { reason: rejectReason.value }); ElMessage.success('申请已驳回'); rejectVisible.value = false; loadPending(); if (activeTab.value === 'history') loadHistory() } catch (error) { ElMessage.error(error?.response?.data?.message || '驳回失败') } finally { actionLoading.value = false } }
async function refreshAuditPage() { if (activeTab.value === 'history') { await loadHistory(historyPage.value); return } if (activeTab.value === 'pending' && authStore.isAdmin) { await loadPending(); return } await loadMy() }
useResumeRefresh(refreshAuditPage)
onMounted(() => { restoreAuditCache(); if (authStore.isAdmin) loadPending(); else loadMy() })
</script>
<style scoped>
.audit-view { padding: 0 2px 16px; }
.audit-hero-card { display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; margin-bottom: 18px; padding: 22px 24px; border-radius: 28px; border: 1px solid rgba(191, 219, 254, 0.82); background: radial-gradient(circle at top right, rgba(219, 234, 254, 0.82), transparent 28%), linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96)); box-shadow: 0 24px 60px rgba(15, 23, 42, 0.08); }
.audit-hero-eyebrow { display: inline-flex; align-items: center; min-height: 28px; padding: 0 12px; border-radius: 999px; background: rgba(37, 99, 235, 0.1); color: #2563eb; font-size: 12px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; }
.audit-hero-card h2 { margin: 14px 0 8px; font-size: 30px; line-height: 1.15; color: #0f172a; }
.audit-hero-card p { margin: 0; max-width: 760px; color: #64748b; line-height: 1.7; }
.audit-hero-stats { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 10px; min-width: 220px; }
.audit-stat-pill { display: inline-flex; align-items: center; min-height: 40px; padding: 0 16px; border-radius: 999px; font-size: 14px; font-weight: 700; border: 1px solid transparent; }
.audit-stat-pill-primary { color: #2563eb; background: rgba(219, 234, 254, 0.76); border-color: rgba(147, 197, 253, 0.88); }
.audit-stat-pill-warning { color: #b45309; background: rgba(254, 243, 199, 0.92); border-color: rgba(252, 211, 77, 0.88); }
.audit-stat-pill-neutral { color: #475569; background: rgba(241, 245, 249, 0.96); border-color: rgba(226, 232, 240, 0.96); }
.audit-tabs :deep(.el-tabs__header) { margin-bottom: 16px; }
.audit-tabs :deep(.el-tabs__item) { min-height: 42px; font-size: 14px; font-weight: 700; }
.audit-toolbar-card { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 14px; padding: 14px 16px; border-radius: 20px; border: 1px solid rgba(226, 232, 240, 0.95); background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.95)); box-shadow: 0 14px 30px rgba(15, 23, 42, 0.05); }
.record-count { color: #64748b; font-size: 13px; }
.record-count b, .name-text { color: #0f172a; font-weight: 700; }
.pagination-bar { display: flex; justify-content: flex-end; margin-top: 16px; }
.text-muted { color: #94a3b8; }
.dialog-tip { color: #475569; line-height: 1.7; margin-bottom: 16px; }
.desktop-table { display: block; }
.mobile-list { display: none; }
.mobile-empty { padding: 20px 10px; color: #94a3b8; text-align: center; font-size: 13px; }
.audit-card { border-radius: 22px; border: 1px solid rgba(226, 232, 240, 0.94); background: radial-gradient(circle at top right, rgba(239, 246, 255, 0.62), transparent 24%), linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96)); padding: 14px 16px; margin-bottom: 12px; box-shadow: 0 16px 32px rgba(15, 23, 42, 0.06); }
.audit-card-head { display: flex; justify-content: space-between; align-items: center; gap: 10px; margin-bottom: 8px; }
.audit-card-time { font-size: 12px; color: #64748b; white-space: nowrap; }
.audit-card-title { font-size: 16px; font-weight: 800; color: #0f172a; margin-bottom: 8px; line-height: 1.35; word-break: break-word; }
.audit-card-subtitle { font-size: 13px; color: #64748b; margin-bottom: 8px; line-height: 1.5; word-break: break-word; }
.audit-card-meta { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px 12px; margin-bottom: 12px; font-size: 12.5px; color: #475569; }
.audit-card-meta span { min-width: 0; line-height: 1.45; word-break: break-word; }
.audit-card-meta span:last-child:nth-child(odd) { grid-column: 1 / -1; }
.audit-card-actions { display: flex; flex-wrap: wrap; gap: 8px; }
.audit-card-actions :deep(.el-button), .audit-card-actions .el-button { min-height: 32px; padding: 6px 12px; border-radius: 10px; font-size: 12px; }
.reject-text { color: #dc2626; }
.workflow-hint { margin-top: 24px; padding: 20px 22px; border-radius: 24px; border: 1px solid rgba(191, 219, 254, 0.82); background: linear-gradient(135deg, rgba(239,246,255,0.88), rgba(248,250,252,0.96)); box-shadow: 0 16px 34px rgba(37, 99, 235, 0.06); }
.workflow-title { font-size: 12px; font-weight: 700; color: #64748b; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.08em; }
.workflow-steps-row { display: flex; align-items: center; gap: 0; flex-wrap: wrap; }
.wf-step { display: flex; align-items: center; gap: 12px; flex: 1; min-width: 160px; }
.wf-step-icon { width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 800; flex-shrink: 0; }
.wf-step-done .wf-step-icon { background: #d1fae5; color: #059669; }
.wf-step-active .wf-step-icon { background: #fef3c7; color: #d97706; }
.wf-step-pending .wf-step-icon { background: #dbeafe; color: #2563eb; }
.wf-step-label { font-size: 13px; color: #334155; line-height: 1.5; }
.wf-arrow { font-size: 18px; color: #94a3b8; padding: 0 10px; flex-shrink: 0; }
.flow-bar { display: flex; align-items: center; padding: 18px 20px; border-radius: 20px; margin-bottom: 16px; border: 1px solid #e2e8f0; background: #f8fafc; }
.flow-bar-approved { border-color: #bbf7d0; background: #f0fdf4; }
.flow-bar-rejected { border-color: #fecaca; background: #fff5f5; }
.flow-bar-pending { border-color: #fde68a; background: #fffbeb; }
.flow-step { display: flex; align-items: center; gap: 12px; flex: 1; }
.flow-line { height: 2px; flex: 0 0 36px; background: #dbe3ef; }
.flow-dot { width: 34px; height: 34px; border-radius: 50%; flex-shrink: 0; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 800; border: 2px solid transparent; }
.done-dot { background: #d1fae5; color: #059669; border-color: #6ee7b7; }
.active-dot { background: #fef3c7; color: #d97706; border-color: #fcd34d; }
.error-dot { background: #fee2e2; color: #dc2626; border-color: #fca5a5; }
.flow-info { min-width: 0; }
.flow-title { font-size: 13px; font-weight: 700; color: #1f2937; }
.flow-sub { font-size: 12px; color: #64748b; margin-top: 4px; word-break: break-all; }
.remark-bar { padding: 10px 14px; border-radius: 12px; font-size: 13px; background: #eff6ff; color: #1d4ed8; margin-bottom: 14px; }
.remark-label { font-weight: 700; margin-right: 8px; }
.diff-wrap { border: 1px solid rgba(226, 232, 240, 0.96); border-radius: 18px; overflow: hidden; box-shadow: inset 0 1px 0 rgba(255,255,255,0.7); }
.diff-header { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 14px 16px; background: linear-gradient(180deg, rgba(248,250,252,0.98), rgba(241,245,249,0.96)); border-bottom: 1px solid #e2e8f0; }
.diff-header-title { font-size: 14px; font-weight: 700; color: #1f2937; }
.diff-changed-count { font-size: 12px; color: #d97706; font-weight: 700; }
.diff-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.dt-th-label, .dt-th-orig, .dt-th-new { padding: 10px 12px; text-align: left; font-weight: 700; border-bottom: 1px solid #e2e8f0; }
.dt-th-label { background: #f1f5f9; color: #475569; }
.dt-th-orig { background: #fff7ed; color: #92400e; border-left: 1px solid #fed7aa; }
.dt-th-new { background: #f0fdf4; color: #14532d; border-left: 1px solid #bbf7d0; }
.dt-row-changed td { background: #fffbeb; }
.dt-cell-label, .dt-cell-orig, .dt-cell-new { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; }
.dt-cell-label { color: #475569; font-weight: 600; white-space: nowrap; }
.dt-cell-orig { border-left: 1px solid #fed7aa; word-break: break-all; }
.dt-cell-new { border-left: 1px solid #bbf7d0; word-break: break-all; }
.empty-row { text-align: center; color: #94a3b8; padding: 18px; }
.val-del, .val-add { display: inline-block; border-radius: 999px; padding: 3px 10px; line-height: 1.4; }
.val-del { background: #fee2e2; color: #991b1b; text-decoration: line-through; text-decoration-color: #dc2626; }
.val-add { background: #dcfce7; color: #14532d; }
.val-empty { color: #94a3b8; }
@media (max-width: 900px) { .audit-hero-card { flex-direction: column; } .audit-hero-stats { justify-content: flex-start; } }
@media (max-width: 640px) { .audit-hero-card { padding: 18px; border-radius: 22px; } .audit-hero-card h2 { font-size: 24px; } .audit-toolbar-card, .tab-toolbar { flex-wrap: wrap; justify-content: space-between; gap: 8px; margin-bottom: 10px; padding: 12px 14px; border-radius: 16px; } .desktop-table { display: none; } .mobile-list { display: block; } .pagination-bar { justify-content: center; } :deep(.el-tabs__item) { padding: 0 10px; font-size: 13px; height: 38px; line-height: 38px; } .flow-bar { flex-direction: column; align-items: flex-start; gap: 12px; } .flow-line { width: 2px; height: 18px; flex: none; margin-left: 16px; } .workflow-hint { margin-top: 16px; padding: 14px; border-radius: 18px; } .wf-arrow { display: none; } .workflow-steps-row { gap: 10px; } .wf-step { flex: none; } .audit-card-meta { grid-template-columns: 1fr; } .diff-table { font-size: 12px; } }
</style>
