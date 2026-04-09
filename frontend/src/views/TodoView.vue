<template>
  <div class="query-shell">
    <div class="mobile-query-head todo-mobile-query-head">
      <div class="mobile-query-row">
        <el-input v-model="search" class="mobile-query-search" placeholder="搜索名称、编号、责任人" clearable @input="handleFilterChange" @clear="handleFilterChange" />
      </div>
      <div class="mobile-query-actions todo-mobile-query-actions">
        <el-button class="mobile-query-action is-compact" @click="showMobileFilters = !showMobileFilters">{{ mobileFilterCompactLabel }}</el-button>
        <el-button v-if="activeFilterCount" class="mobile-query-action is-compact" @click="resetFilter">重置</el-button>
        <el-button class="mobile-query-action is-compact is-primary" type="primary" @click="loadData">刷新</el-button>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar todo-filter-bar" :class="{ 'mobile-filter-hidden': isMobile && !showMobileFilters }">
      <div v-if="!isMobile" class="filter-group">
        <div class="filter-label">搜索</div>
        <el-input v-model="search" placeholder="搜索名称/编号/责任人..." clearable size="default" style="width:200px" @input="handleFilterChange" @clear="handleFilterChange" />
      </div>
      <div class="filter-group">
        <div class="filter-label">使用部门</div>
        <el-select v-model="filterDept" placeholder="全部部门" clearable size="default" style="width:130px" @change="handleFilterChange">
          <el-option value="" label="全部部门" />
          <el-option v-for="d in depts" :key="d" :value="d" :label="d" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">紧急程度</div>
        <el-select v-model="filterValidity" placeholder="全部" clearable size="default" style="width:120px" @change="handleFilterChange">
          <el-option value="" label="全部" />
          <el-option value="失效" label="已失效" />
          <el-option value="即将过期" label="即将过期" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">下次校准日期</div>
        <div class="date-range-wrap">
          <input type="date" v-model="filterDateFrom" class="date-input" title="开始日期" @change="handleFilterChange" />
          <span class="date-range-sep">~</span>
          <input type="date" v-model="filterDateTo" class="date-input" title="结束日期" @change="handleFilterChange" />
        </div>
      </div>
      <div class="filter-actions todo-filter-actions">
        <template v-if="isMobile">
          <el-button class="mobile-tools-trigger" size="default" @click="showMobileActionSheet = true">更多功能</el-button>
        </template>
        <template v-else>
          <el-button size="default" @click="resetFilter">重置</el-button>
          <el-button size="default" @click="exportCurrent">导出当前</el-button>
          <el-button size="default" @click="exportAll">导出全部</el-button>
          <el-button size="default" type="primary" @click="loadData">刷新</el-button>
        </template>
      </div>
    </div>

    <div class="page-results-bar">
      <div class="page-results-meta">
        <span class="page-results-chip page-results-chip-strong">待处理 {{ totalItems }} 条</span>
        <span class="page-results-chip" :style="{ background:'#fef2f2', color:'#dc2626', borderColor:'#fca5a5' }">失效 {{ countByV('失效') }}</span>
        <span class="page-results-chip" :style="{ background:'#fffbeb', color:'#b45309', borderColor:'#fcd34d' }">即将过期 {{ countByV('即将过期') }}</span>
        <span v-if="selectedIds.length" class="page-results-chip">已选 {{ selectedIds.length }} 项</span>
      </div>
      <div v-if="activeFilterCount" class="page-results-extra">已启用 {{ activeFilterCount }} 个筛选</div>
    </div>

    <div class="batch-bar">
      <div class="batch-info">已选 <b>{{ selectedIds.length }}</b> 项</div>
      <div class="batch-actions">
        <el-button size="small" @click="toggleSelectCurrentPage">
          {{ allCurrentPageSelected ? '取消当前页' : '全选当前页' }}
        </el-button>
        <el-button size="small" :disabled="!selectedIds.length" @click="clearSelection">清空选择</el-button>
        <el-button v-if="canRecordCalibration" size="small" type="primary" :disabled="!selectedIds.length" @click="openBatchCalib">批量记录校准</el-button>
      </div>
    </div>

    <!-- 汇总卡片 -->
    <div class="stats-grid" style="margin-bottom:16px">
      <div class="stat-card">
        <div class="stat-icon red">
          <el-icon size="22" color="#dc2626"><Warning /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">已失效</div>
          <div class="stat-value red">{{ countByV('失效') }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange">
          <el-icon size="22" color="#d97706"><Bell /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">即将过期</div>
          <div class="stat-value orange">{{ countByV('即将过期') }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon blue">
          <el-icon size="22" color="#2563eb"><List /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">待处理合计</div>
          <div class="stat-value">{{ totalItems }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon blue">
          <el-icon size="22" color="#2563eb"><OfficeBuilding /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">涉及部门</div>
          <div class="stat-value">{{ involvedDepts }}</div>
        </div>
      </div>
    </div>

    <!-- 桌面表格 -->
    <div class="table-wrap">
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th style="width:54px">
                <input type="checkbox" :checked="allCurrentPageSelected" @change="toggleSelectCurrentPage" />
              </th>
              <th>紧急程度</th><th>仪器名称</th><th>计量编号</th><th>使用部门</th>
              <th>使用责任人</th><th>上次校准</th><th>下次校准/到期</th><th>逾期天数</th><th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="filtered.length===0" class="empty-row"><td colspan="10">暂无待办事项</td></tr>
            <tr v-for="d in paged" :key="d.id" :style="{ background: d.validity==='失效'?'#fff5f5':d.validity==='即将过期'?'#fffbeb':'' }">
              <td>
                <input type="checkbox" :checked="isSelected(d.id)" @change="toggleSelection(d.id)" />
              </td>
              <td>
                <span v-if="d.validity==='失效'" class="tag tag-expired">已失效</span>
                <span v-else class="tag tag-warning">即将过期</span>
              </td>
              <td>
                <span class="todo-device-link" @click="openPreview(d)">{{ d.name }}</span>
              </td>
              <td><code style="font-size:12px;background:#f1f5f9;padding:2px 6px;border-radius:4px">{{ d.metricNo }}</code></td>
              <td>{{ d.dept || '-' }}</td>
              <td>{{ d.responsiblePerson || '-' }}</td>
              <td>{{ d.calDate || '-' }}</td>
              <td style="font-weight:600" :style="{ color: d.validity==='失效'?'var(--danger)':'var(--warning)' }">{{ d.nextDate || '-' }}</td>
              <td>
                <span v-if="d.daysPassed" :class="['tag', d.validity==='失效'?'tag-expired':'tag-warning']">
                  {{ d.daysPassed }} 天
                </span>
              </td>
              <td>
                <el-button v-if="canRecordCalibration" size="small" type="primary" plain @click="openCalib(d)">记录校准</el-button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 移动端卡片 -->
    <div class="mobile-list">
      <div v-if="filtered.length===0" style="text-align:center;padding:48px 0;color:var(--text-muted)">暂无待办事项</div>
      <div v-for="d in paged" :key="d.id" class="m-card todo-mobile-card" :style="{ borderLeft: d.validity==='失效'?'4px solid var(--danger)':'4px solid var(--warning)' }">
        <div class="m-card-row todo-mobile-card-head">
          <div class="todo-mobile-card-title-wrap">
            <input type="checkbox" :checked="isSelected(d.id)" @change="toggleSelection(d.id)" />
            <div class="m-card-title todo-device-link" @click="openPreview(d)">{{ d.name }}</div>
          </div>
          <span :class="['tag', d.validity==='失效'?'tag-expired':'tag-warning', 'todo-mobile-validity']">
            {{ d.validity==='失效' ? '失效' : '即将过期' }}
          </span>
        </div>
        <div class="m-card-meta todo-mobile-meta">
          <div class="m-card-meta-item todo-mobile-meta-item"><span class="todo-mobile-meta-label">编号</span><b>{{ d.metricNo }}</b></div>
          <div class="m-card-meta-item todo-mobile-meta-item"><span class="todo-mobile-meta-label">部门</span><b>{{ d.dept||'-' }}</b></div>
          <div class="m-card-meta-item todo-mobile-meta-item"><span class="todo-mobile-meta-label">责任人</span><b>{{ d.responsiblePerson||'-' }}</b></div>
          <div class="m-card-meta-item todo-mobile-meta-item"><span class="todo-mobile-meta-label">下次校准</span><b :class="{ 'text-danger': d.validity==='失效', 'text-warning': d.validity!=='失效' }">{{ d.nextDate||'-' }}</b></div>
          <div v-if="d.daysPassed" class="m-card-meta-item todo-mobile-meta-item todo-mobile-meta-item-span"><span class="todo-mobile-meta-label">已逾期</span><b class="text-danger">{{ d.daysPassed }} 天</b></div>
        </div>
        <div class="m-card-footer todo-mobile-card-footer">
          <div class="mobile-card-kpi todo-mobile-card-kpi">
            <span v-if="d.daysPassed" :class="['tag', d.validity==='失效'?'tag-expired':'tag-warning', 'todo-mobile-urgent']">逾期 {{ d.daysPassed }} 天</span>
          </div>
          <div class="m-card-actions todo-mobile-actions">
            <button v-if="canRecordCalibration" class="action-btn action-btn-view" @click="openQuickEdit(d)">快改</button>
            <button v-if="canRecordCalibration" class="action-btn action-btn-edit" @click="openCalib(d)">校准</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div class="page-pagination">
      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="totalItems"
        :page-sizes="[10, 20, 50]"
        :layout="paginationLayout"
        :small="isMobile"
        background
        @current-change="loadData"
        @size-change="() => { page = 1; loadData() }"
      />
    </div>

    <!-- 设备预览弹窗 -->
    <div v-if="showPreview" class="modal-mask" @click.self="closePreview">
      <div class="modal-box modal-md">
        <div class="modal-header">
          <div class="modal-title">设备信息预览</div>
          <button class="modal-close" @click="closePreview">✕</button>
        </div>
        <div class="modal-body">
          <div class="preview-grid">
            <div class="preview-item"><span class="preview-label">仪器名称</span><span class="preview-val">{{ previewDevice.name || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">计量编号</span><span class="preview-val">{{ previewDevice.metricNo || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">资产编号</span><span class="preview-val">{{ previewDevice.assetNo || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">出厂编号</span><span class="preview-val">{{ previewDevice.serialNo || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用部门</span><span class="preview-val">{{ previewDevice.dept || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">责任人</span><span class="preview-val">{{ previewDevice.responsiblePerson || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用状态</span><span class="preview-val">{{ previewDevice.useStatus || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">有效性</span><span class="preview-val">{{ previewDevice.validity || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">上次校准</span><span class="preview-val">{{ previewDevice.calDate || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">下次校准</span><span class="preview-val">{{ previewDevice.nextDate || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">校准结果</span><span class="preview-val">{{ previewDevice.calibrationResult || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">逾期天数</span><span class="preview-val">{{ previewDevice.daysPassed || 0 }} 天</span></div>
          </div>
          <div v-if="previewDevice.remark" style="margin-top:14px">
            <div class="preview-label" style="margin-bottom:6px">备注</div>
            <div class="preview-remark">{{ previewDevice.remark }}</div>
          </div>
        </div>
        <div class="modal-footer">
          <el-button @click="closePreview">关闭</el-button>
          <el-button v-if="isMobile && canRecordCalibration" plain @click="closePreview(); openQuickEdit(previewDevice)">快速编辑</el-button>
          <el-button v-if="canRecordCalibration" type="primary" @click="closePreview(); openCalib(previewDevice)">记录校准</el-button>
        </div>
      </div>
    </div>

    <!-- 校准记录弹窗 -->
    <div v-if="showCalib" class="modal-mask" @click.self="closeCalib">
      <div class="modal-box modal-sm">
        <div class="modal-header">
          <div class="modal-title">{{ batchMode ? '批量记录校准' : `记录校准 — ${cf.name}` }}</div>
          <button class="modal-close" @click="closeCalib">✕</button>
        </div>
        <form @submit.prevent="saveCalib">
          <div class="modal-body" style="display:flex;flex-direction:column;gap:14px">
            <div class="form-group">
              <label class="form-label required">本次校准时间</label>
              <input v-model="cf.calDate" type="date" required style="width:100%" />
            </div>
            <div class="form-group">
              <label class="form-label">检定周期（可选半年/一年）</label>
              <select v-model.number="cf.cycle" style="width:100%">
                <option :value="6">半年（6个月）</option>
                <option :value="12">一年（12个月）</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">校准结果判定</label>
              <select v-model="cf.calibrationResult" style="width:100%">
                <option value="">请选择</option>
                <option>合格</option><option>不合格</option><option>降级使用</option><option>停用</option>
              </select>
            </div>
            <div v-if="batchMode" class="batch-hint">将同步更新 {{ selectedIds.length }} 条待办记录对应设备。</div>
          </div>
          <div class="modal-footer">
            <el-button @click="closeCalib">取消</el-button>
            <el-button type="primary" native-type="submit" :loading="saving">{{ saving?'保存中...':'保存' }}</el-button>
          </div>
        </form>
      </div>
    </div>

    <div v-if="showQuickEdit" class="modal-mask" @click.self="closeQuickEdit">
      <div class="modal-box modal-sm quick-edit-modal">
        <div class="modal-header">
          <div class="modal-title">快速编辑 - {{ quickEditTarget.name || '设备' }}</div>
          <button class="modal-close" @click="closeQuickEdit">✕</button>
        </div>
        <div class="modal-body quick-edit-body">
          <div class="quick-edit-intro">
            手机端可先快速修正常用信息，再按需要进入完整校准记录。
          </div>
          <div class="form-group">
            <label class="form-label">使用部门</label>
            <input v-model="quickEditForm.dept" list="quick-todo-dept-list" placeholder="选择或输入部门" />
            <datalist id="quick-todo-dept-list">
              <option v-for="d in depts" :key="d" :value="d" />
            </datalist>
          </div>
          <div class="form-grid quick-edit-grid">
            <div class="form-group">
              <label class="form-label">责任人</label>
              <input v-model="quickEditForm.responsiblePerson" placeholder="负责人姓名" />
            </div>
            <div class="form-group">
              <label class="form-label">位置</label>
              <input v-model="quickEditForm.location" placeholder="设备位置" />
            </div>
            <div class="form-group">
              <label class="form-label">使用状态</label>
              <select v-model="quickEditForm.useStatus">
                <option v-for="s in deviceStatuses" :key="s.id" :value="s.name">{{ s.name }}</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">检定周期</label>
              <select v-model.number="quickEditForm.cycle">
                <option :value="6">半年（6个月）</option>
                <option :value="12">一年（12个月）</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">本次校准时间</label>
              <input v-model="quickEditForm.calDate" type="date" />
            </div>
            <div class="form-group">
              <label class="form-label">校准结果</label>
              <select v-model="quickEditForm.calibrationResult">
                <option value="">请选择</option>
                <option value="合格">合格</option>
                <option value="不合格">不合格</option>
                <option value="降级使用">降级使用</option>
                <option value="停用">停用</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">备注</label>
            <textarea v-model="quickEditForm.remark" rows="3" placeholder="补充说明"></textarea>
          </div>
        </div>
        <div class="modal-footer quick-edit-footer">
          <button class="btn btn-outline" @click="closeQuickEdit">取消</button>
          <button class="btn btn-ghost" @click="openFullCalibFromQuick">完整校准</button>
          <button class="btn btn-primary" @click="saveQuickEdit" :disabled="quickEditSaving">{{ quickEditSaving ? '保存中...' : '保存修改' }}</button>
        </div>
      </div>
    </div>

    <transition name="mobile-sheet-pop">
      <div v-if="showMobileActionSheet" class="modal-mask" @click.self="showMobileActionSheet = false">
        <div class="modal-box modal-sm mobile-tools-sheet">
          <div class="mobile-tools-sheet-handle"></div>
          <div class="modal-header">
            <div>
              <div class="mobile-tools-sheet-eyebrow">Quick Actions</div>
              <div class="modal-title">更多功能</div>
            </div>
            <button class="modal-close" @click="showMobileActionSheet = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="mobile-tools-grid">
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(resetFilter)">
                <span class="mobile-tools-btn-title">重置筛选</span>
                <span class="mobile-tools-btn-desc">清空当前筛选条件</span>
              </button>
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(exportCurrent)">
                <span class="mobile-tools-btn-title">导出当前</span>
                <span class="mobile-tools-btn-desc">导出当前待办记录</span>
              </button>
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(exportAll)">
                <span class="mobile-tools-btn-title">导出全部</span>
                <span class="mobile-tools-btn-desc">导出全部待办事项</span>
              </button>
              <button class="btn btn-primary mobile-tools-btn mobile-tools-btn-wide" @click="runMobileAction(loadData)">
                <span class="mobile-tools-btn-title">刷新数据</span>
                <span class="mobile-tools-btn-desc">重新同步最新待办状态</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, inject } from 'vue'
import * as XLSX from 'xlsx'
import { deviceApi, deptApi, deviceStatusApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const showToast = inject('showToast')
const authStore = useAuthStore()
const todoCache = useViewCache('todo-view', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('todo-view')
const canRecordCalibration = computed(() => authStore.canRecordCalibration)
const allTodos = ref([])
const totalItems = ref(0)
const summaryCounts = ref({})
const search = ref(''), filterDept = ref(''), filterValidity = ref('')
const filterDateFrom = ref(''), filterDateTo = ref('')
const deviceStatuses = ref([])
const page = ref(1), pageSize = ref(20)
const showCalib = ref(false), saving = ref(false)
const selectedIds = ref([])
const batchMode = ref(false)
const showPreview = ref(false)
const showQuickEdit = ref(false)
const quickEditSaving = ref(false)
const quickEditTarget = ref({})
const previewDevice = ref({})
const cf = reactive({ id:null, name:'', calDate:'', cycle:12, calibrationResult:'合格' })
const quickEditForm = reactive({
  dept:'',
  responsiblePerson:'',
  location:'',
  useStatus:'正常',
  cycle:12,
  calDate:'',
  calibrationResult:'合格',
  remark:''
})
const depts = ref([])
const deptTree = ref([])
const isMobile = ref(false)
const showMobileFilters = ref(true)
const showMobileActionSheet = ref(false)

function restoreTodoCache() {
  const cached = todoCache.restore()
  if (!cached) return

  allTodos.value = Array.isArray(cached.allTodos) ? cached.allTodos : []
  deviceStatuses.value = Array.isArray(cached.deviceStatuses) ? cached.deviceStatuses : []
  search.value = cached.search || ''
  filterDept.value = cached.filterDept || ''
  filterValidity.value = cached.filterValidity || ''
  filterDateFrom.value = cached.filterDateFrom || ''
  filterDateTo.value = cached.filterDateTo || ''
  page.value = Number(cached.page) || 1
  pageSize.value = Number(cached.pageSize) || 20
  totalItems.value = Number(cached.totalItems) || allTodos.value.length
  summaryCounts.value = cached.summaryCounts || {}
}

function saveTodoCache() {
  todoCache.save({
    allTodos: allTodos.value,
    deviceStatuses: deviceStatuses.value,
    search: search.value,
    filterDept: filterDept.value,
    filterValidity: filterValidity.value,
    filterDateFrom: filterDateFrom.value,
    filterDateTo: filterDateTo.value,
    page: page.value,
    pageSize: pageSize.value,
    totalItems: totalItems.value,
    summaryCounts: summaryCounts.value
  })
}
const involvedDepts = computed(() => new Set(filtered.value.map(d => d.dept).filter(Boolean)).size)
const deptScope = computed(() => {
  if (!filterDept.value) return null
  const scope = new Set()
  const found = appendDeptAndChildren(deptTree.value, filterDept.value, scope)
  if (!found) scope.add(filterDept.value)
  return scope
})

const filtered = computed(() => {
  let list = allTodos.value
  if (search.value) {
    const s = search.value.toLowerCase()
    list = list.filter(d =>
      d.name.toLowerCase().includes(s) ||
      (d.metricNo||'').toLowerCase().includes(s) ||
      (d.responsiblePerson||'').toLowerCase().includes(s)
    )
  }
  if (deptScope.value) list = list.filter(d => d.dept && deptScope.value.has(d.dept))
  if (filterValidity.value) list = list.filter(d => d.validity === filterValidity.value)
  if (filterDateFrom.value || filterDateTo.value) {
    list = list.filter(d => {
      const nd = d.nextDate || ''
      return (!filterDateFrom.value || nd >= filterDateFrom.value) &&
             (!filterDateTo.value   || nd <= filterDateTo.value)
    })
  }
  return list
})

const activeFilterCount = computed(() =>
  [search.value, filterDept.value, filterValidity.value, filterDateFrom.value, filterDateTo.value].filter(Boolean).length
)
const mobileFilterButtonLabel = computed(() =>
  showMobileFilters.value ? '收起筛选' : '筛选' + (activeFilterCount.value ? '(' + activeFilterCount.value + ')' : '')
)
const mobileFilterCompactLabel = computed(() =>
  showMobileFilters.value ? '收起' : '筛选' + (activeFilterCount.value ? '(' + activeFilterCount.value + ')' : '')
)
const paginationLayout = computed(() =>
  isMobile.value ? 'prev, pager, next' : 'total, sizes, prev, pager, next'
)

const paged = computed(() => filtered.value)
const currentPageIds = computed(() => paged.value.map(d => d.id))
const allCurrentPageSelected = computed(() =>
  currentPageIds.value.length > 0 && currentPageIds.value.every(id => selectedIds.value.includes(id))
)

function handleFilterChange() {
  page.value = 1
  clearSelection()
  loadData()
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

function resetFilter() {
  search.value = ''; filterDept.value = ''; filterValidity.value = ''
  filterDateFrom.value = ''; filterDateTo.value = ''; page.value = 1
  clearSelection()
  loadData()
}
function countByV(v) { return Number(summaryCounts.value?.[v] || 0) }
function isSelected(id) { return selectedIds.value.includes(id) }
function toggleSelection(id) {
  selectedIds.value = isSelected(id)
    ? selectedIds.value.filter(item => item !== id)
    : [...selectedIds.value, id]
}
function clearSelection() { selectedIds.value = [] }
function toggleSelectCurrentPage() {
  if (allCurrentPageSelected.value) {
    selectedIds.value = selectedIds.value.filter(id => !currentPageIds.value.includes(id))
    return
  }
  selectedIds.value = Array.from(new Set([...selectedIds.value, ...currentPageIds.value]))
}

async function loadData() {
  try {
    const res = await deviceApi.listPaged({
      search: search.value || undefined,
      dept: filterDept.value || undefined,
      validity: filterValidity.value || undefined,
      nextDateFrom: filterDateFrom.value || undefined,
      nextDateTo: filterDateTo.value || undefined,
      todoOnly: true,
      page: page.value,
      size: pageSize.value
    })
    allTodos.value = res.data.content || []
    totalItems.value = res.data.totalElements || 0
    summaryCounts.value = res.data.summaryCounts || {}
    page.value = res.data.page || page.value
    selectedIds.value = selectedIds.value.filter(id => allTodos.value.some(d => d.id === id))
    saveTodoCache()
  } catch(e) { console.error(e) }
}

function appendDeptAndChildren(nodes, targetName, scope) {
  for (const node of nodes || []) {
    if (node.name === targetName) {
      collectDeptNames(node, scope)
      return true
    }
    if (appendDeptAndChildren(node.children || [], targetName, scope)) return true
  }
  return false
}

function collectDeptNames(node, scope) {
  if (!node) return
  if (node.name) scope.add(node.name)
  for (const child of node.children || []) {
    collectDeptNames(child, scope)
  }
}

function flattenDeptNames(nodes, result = []) {
  for (const node of nodes || []) {
    if (node.name) result.push(node.name)
    flattenDeptNames(node.children || [], result)
  }
  return result
}

function normalizeDepartmentName(name) {
  return typeof name === 'string' ? name.trim() : ''
}

function normalizeUserDepartments() {
  if (Array.isArray(authStore.departments) && authStore.departments.length) {
    return authStore.departments.map(normalizeDepartmentName).filter(Boolean)
  }
  if (typeof authStore.department === 'string' && authStore.department.trim()) {
    return authStore.department
      .replaceAll('，', ',')
      .split(',')
      .map(s => s.trim())
      .filter(Boolean)
  }
  return []
}

function collectAllDeptNames(nodes, set) {
  for (const node of nodes || []) {
    const name = normalizeDepartmentName(node?.name)
    if (name) set.add(name)
    collectAllDeptNames(node?.children || [], set)
  }
}

function collectNodeAndChildren(node, set) {
  if (!node) return
  const name = normalizeDepartmentName(node.name)
  if (name) set.add(name)
  for (const child of node.children || []) {
    collectNodeAndChildren(child, set)
  }
}

function appendDeptScopeByRoot(nodes, rootName, set) {
  for (const node of nodes || []) {
    if (normalizeDepartmentName(node?.name) === rootName) {
      collectNodeAndChildren(node, set)
      return true
    }
    if (appendDeptScopeByRoot(node?.children || [], rootName, set)) return true
  }
  return false
}

function buildAllowedDepartments(tree) {
  const allSet = new Set()
  collectAllDeptNames(tree, allSet)
  if (authStore.isAdmin) return Array.from(allSet)

  const userRoots = normalizeUserDepartments()
  if (!userRoots.length) return Array.from(allSet)

  const scopeSet = new Set()
  for (const root of userRoots) {
    const found = appendDeptScopeByRoot(tree, root, scopeSet)
    if (!found) scopeSet.add(root)
  }
  return Array.from(scopeSet)
}

function defaultResultByUseStatus(useStatus) {
  return useStatus && useStatus !== '正常' ? '不合格' : '合格'
}

function openQuickEdit(d) {
  quickEditTarget.value = d
  Object.assign(quickEditForm, {
    dept: d.dept || '',
    responsiblePerson: d.responsiblePerson || '',
    location: d.location || '',
    useStatus: d.useStatus || '正常',
    cycle: d.cycle || 12,
    calDate: d.calDate || new Date().toISOString().split('T')[0],
    calibrationResult: d.calibrationResult || defaultResultByUseStatus(d.useStatus),
    remark: d.remark || ''
  })
  showQuickEdit.value = true
}
function openCalib(d) {
  batchMode.value = false
  cf.id = d.id
  cf.name = d.name
  cf.cycle = d.cycle || 12
  cf.calibrationResult = d.calibrationResult || defaultResultByUseStatus(d.useStatus)
  cf.calDate = new Date().toISOString().split('T')[0]
  showCalib.value = true
}
function openBatchCalib() {
  batchMode.value = true
  cf.id = null
  cf.name = ''
  cf.cycle = 12
  const selected = allTodos.value.filter(d => selectedIds.value.includes(d.id))
  const hasAbnormal = selected.some(d => d.useStatus && d.useStatus !== '正常')
  cf.calibrationResult = hasAbnormal ? '不合格' : '合格'
  cf.calDate = new Date().toISOString().split('T')[0]
  showCalib.value = true
}
function closeCalib() { showCalib.value = false; batchMode.value = false }
function openPreview(d) { previewDevice.value = d; showPreview.value = true }
function closePreview() { showPreview.value = false }
function closeQuickEdit() {
  showQuickEdit.value = false
  quickEditTarget.value = {}
}
function openFullCalibFromQuick() {
  const target = quickEditTarget.value
  closeQuickEdit()
  openCalib(target)
}

function exportRows(rows, filename) {
  const data = rows.map(d => ({
    紧急程度: d.validity === '失效' ? '已失效' : '即将过期',
    仪器名称: d.name || '',
    计量编号: d.metricNo || '',
    使用部门: d.dept || '',
    使用责任人: d.responsiblePerson || '',
    上次校准: d.calDate || '',
    下次校准: d.nextDate || '',
    逾期天数: d.daysPassed || 0,
    使用状态: d.useStatus || '',
    校准结果判定: d.calibrationResult || '',
    备注: d.remark || ''
  }))
  const wb = XLSX.utils.book_new()
  const ws = XLSX.utils.json_to_sheet(data)
  XLSX.utils.book_append_sheet(wb, ws, '待办事项')
  XLSX.writeFile(wb, filename)
}

async function saveCalib() {
  saving.value = true
  try {
    if (batchMode.value) {
      const count = selectedIds.value.length
      await Promise.all(selectedIds.value.map(id =>
        deviceApi.updateCalibration(id, { calDate:cf.calDate, cycle:cf.cycle, calibrationResult:(cf.calibrationResult || (allTodos.value.find(d => d.id === id && d.useStatus !== '正常') ? '不合格' : '合格')) })
      ))
      clearSelection(); closeCalib()
      showToast(`已批量更新 ${count} 条记录`)
    } else {
      await deviceApi.updateCalibration(cf.id, { calDate:cf.calDate, cycle:cf.cycle, calibrationResult:(cf.calibrationResult || defaultResultByUseStatus(allTodos.value.find(d => d.id === cf.id)?.useStatus)) })
      closeCalib()
      showToast('校准记录已保存')
    }
    loadData()
  } catch(e) { showToast('保存失败','error') }
  finally { saving.value = false }
}

async function saveQuickEdit() {
  if (!quickEditTarget.value?.id) return
  quickEditSaving.value = true
  try {
    const targetId = quickEditTarget.value.id
    await deviceApi.update(targetId, {
      dept: quickEditForm.dept.trim(),
      responsiblePerson: quickEditForm.responsiblePerson.trim(),
      location: quickEditForm.location.trim(),
      useStatus: quickEditForm.useStatus || '正常',
      remark: quickEditForm.remark.trim()
    })
    await deviceApi.updateCalibration(targetId, {
      calDate: quickEditForm.calDate || '',
      cycle: Number(quickEditForm.cycle) || 12,
      calibrationResult: quickEditForm.calibrationResult || defaultResultByUseStatus(quickEditForm.useStatus),
      remark: quickEditForm.remark.trim()
    })
    closeQuickEdit()
    showToast('快速修改已保存')
    loadData()
  } catch(e) {
    showToast('快速修改失败','error')
  } finally {
    quickEditSaving.value = false
  }
}

async function exportCurrent() {
  try { exportRows(filtered.value, '待办事项.xlsx') } catch(e) { showToast('导出失败','error') }
}

async function exportAll() {
  try { exportRows(allTodos.value, '待办事项-全部.xlsx') } catch(e) { showToast('导出失败','error') }
}

function runMobileAction(action) {
  showMobileActionSheet.value = false
  action()
}

useResumeRefresh(loadData)

onMounted(async () => {
  restoreTodoCache()
  syncViewport()
  window.addEventListener('resize', syncViewport)
  loadData()
  try {
    const r = await deptApi.tree()
    deptTree.value = r.data || []
    depts.value = buildAllowedDepartments(deptTree.value)
    if (filterDept.value && !depts.value.includes(filterDept.value)) filterDept.value = ''
  } catch(e) {}
  try {
    const r = await deviceStatusApi.list()
    deviceStatuses.value = r.data
    saveTodoCache()
  } catch(e) {}
})

onUnmounted(() => {
  window.removeEventListener('resize', syncViewport)
})
</script>

<style scoped>
.todo-filter-bar { margin-bottom: 0; }
.batch-bar {
  display:flex; align-items:center; justify-content:space-between;
  gap:12px; padding:10px 14px; margin-bottom:12px;
  background:#fff; border:1px solid var(--border); border-radius:12px;
}
.batch-info { color:var(--text-muted); font-size:13px; }
.batch-actions { display:flex; gap:8px; flex-wrap:wrap; }
.batch-hint {
  padding:10px 12px; border-radius:10px;
  background:#eff6ff; color:#1d4ed8; font-size:13px;
}
.todo-device-link {
  font-weight: 600;
  color: var(--primary);
  cursor: pointer;
}
.todo-device-link:hover { text-decoration: underline; }
.preview-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px 16px;
}
.preview-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.preview-label {
  font-size: 12px;
  color: var(--text-muted);
}
.preview-val {
  font-size: 13.5px;
  color: var(--text);
  font-weight: 600;
}
.preview-remark {
  background: #f8fafc;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px;
  font-size: 13px;
  color: var(--text);
  line-height: 1.6;
}
.quick-edit-modal {
  max-width: min(520px, 96vw);
}
.quick-edit-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.quick-edit-intro {
  padding: 10px 12px;
  border-radius: 10px;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 13px;
  line-height: 1.6;
}
.quick-edit-grid {
  grid-template-columns: 1fr 1fr;
}
.quick-edit-footer .btn-ghost {
  border-color: var(--border);
  background: white;
}
.todo-mobile-query-head { gap: 8px; }
.todo-mobile-query-actions {
  justify-content: flex-end;
  gap: 6px;
}
.todo-mobile-query-actions > * { flex: 0 0 auto !important; }
.todo-mobile-query-actions :deep(.el-button) {
  min-height: 32px;
  padding: 0 12px;
  border-radius: 10px;
  font-size: 12.5px;
  margin-left: 0;
}
.mobile-tools-trigger {
  width: 100%;
  border-radius: 12px;
  background: linear-gradient(135deg, #ffffff, #f8fbff);
  border-color: #dbeafe;
}
.mobile-tools-sheet {
  max-width: min(420px, 96vw);
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.72), transparent 28%),
    linear-gradient(180deg, #ffffff, #f8fbff);
  border: 1px solid rgba(191, 219, 254, 0.9);
}
.mobile-tools-sheet-handle {
  width: 48px;
  height: 5px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.4);
  margin: 10px auto 2px;
}
.mobile-tools-sheet-eyebrow {
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
.mobile-tools-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.mobile-tools-btn {
  width: 100%;
  min-height: 72px;
  justify-content: flex-start;
  align-items: flex-start;
  flex-direction: column;
  gap: 6px;
  padding: 12px 13px;
  border-radius: 16px;
  background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(248,250,252,0.98));
  border-color: #dbe3ef;
  transition: transform 0.18s, box-shadow 0.18s, border-color 0.18s;
}
.mobile-tools-btn:hover {
  transform: translateY(-1px);
  border-color: #bfdbfe;
  box-shadow: 0 12px 24px rgba(37, 99, 235, 0.12);
}

.mobile-tools-btn:active {
  transform: scale(0.985);
  box-shadow: 0 6px 14px rgba(37, 99, 235, 0.10);
}

.mobile-sheet-pop-enter-active,
.mobile-sheet-pop-leave-active {
  transition: opacity 0.22s ease;
}

.mobile-sheet-pop-enter-active .mobile-tools-sheet,
.mobile-sheet-pop-leave-active .mobile-tools-sheet {
  transition: transform 0.28s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.22s ease;
}

.mobile-sheet-pop-enter-from,
.mobile-sheet-pop-leave-to {
  opacity: 0;
}

.mobile-sheet-pop-enter-from .mobile-tools-sheet,
.mobile-sheet-pop-leave-to .mobile-tools-sheet {
  transform: translateY(24px) scale(0.985);
  opacity: 0.9;
}

.mobile-tools-btn-title {
  font-size: 13px;
  font-weight: 800;
  color: #0f172a;
}
.mobile-tools-btn-desc {
  font-size: 11.5px;
  line-height: 1.45;
  color: #64748b;
  text-align: left;
}
.mobile-tools-btn-wide { grid-column: 1 / -1; }
.todo-mobile-card {
  padding: 10px 12px;
  margin-bottom: 10px;
  border-radius: 14px;
}
.todo-mobile-card-head {
  margin-bottom: 6px;
  align-items: center;
  gap: 8px;
}
.todo-mobile-card-title-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1;
}
.todo-mobile-card .m-card-title {
  font-size: 14px;
  line-height: 1.3;
  -webkit-line-clamp: 1;
}
.todo-mobile-validity,
.todo-mobile-urgent {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 999px;
}
.todo-mobile-meta {
  gap: 5px 10px;
  margin-bottom: 8px;
}
.todo-mobile-meta-item {
  gap: 3px;
  font-size: 11.5px;
  line-height: 1.3;
}
.todo-mobile-meta-item-span { grid-column: 1 / -1; }
.todo-mobile-meta-label {
  color: var(--text-muted);
  flex-shrink: 0;
}
.todo-mobile-meta-item b {
  font-size: 12px;
  font-weight: 700;
  color: var(--text);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.todo-mobile-card-footer {
  padding-top: 8px;
  gap: 8px;
  align-items: center;
}
.todo-mobile-card-kpi { gap: 6px; }
.todo-mobile-actions {
  width: auto;
  margin-left: auto;
  gap: 6px;
}
.todo-mobile-actions .action-btn {
  min-height: 28px;
  padding: 5px 10px;
  font-size: 12px;
  border-radius: 10px;
}
@media (max-width: 768px) {
  .mobile-filter-hidden { display: none; }
  .todo-filter-bar.mobile-filter-hidden { display: none !important; }
  .todo-mobile-meta {
    grid-template-columns: 1fr 1fr;
  }
  .todo-filter-bar {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
    padding: 8px 10px;
    align-items: end;
  }
  .todo-filter-bar .filter-group {
    min-width: 0;
    width: auto;
    gap: 4px;
  }
  .todo-filter-bar .filter-label {
    font-size: 11.5px;
    margin-bottom: 0;
  }
  .todo-filter-bar :deep(.el-select),
  .todo-filter-bar :deep(.el-input) {
    width: 100% !important;
  }
  .todo-filter-bar :deep(.el-input__wrapper) {
    min-height: 34px;
    padding: 0 10px;
  }
  .batch-bar {
    flex-direction: column;
    align-items: stretch;
  }
  .todo-filter-actions {
    width: 100%;
    grid-column: 1 / -1;
    padding-top: 4px;
    margin-top: 2px;
  }
  .mobile-tools-grid {
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .todo-mobile-card {
    padding: 9px 11px;
    border-radius: 13px;
  }
  .batch-actions :deep(.el-button) {
    flex: 1 1 calc(50% - 4px);
    margin-left: 0;
  }
  .preview-grid { grid-template-columns: 1fr; }
  .quick-edit-grid {
    grid-template-columns: 1fr;
  }
  .quick-edit-footer {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
  .quick-edit-footer .btn:last-child {
    grid-column: span 2;
  }
}

@media (max-width: 480px) {
  .todo-filter-bar {
    gap: 7px;
    padding: 8px;
  }
  .mobile-tools-grid { grid-template-columns: 1fr; }
  .mobile-tools-btn-wide { grid-column: auto; }
  .todo-mobile-card {
    padding: 8px 10px;
  }
  .todo-mobile-meta {
    gap: 4px 8px;
  }
  .todo-mobile-actions .action-btn {
    padding: 5px 8px;
    min-height: 27px;
    font-size: 11.5px;
  }
}
</style>
