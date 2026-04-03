<template>
  <div class="dept-page">
    <div class="filter-bar">
      <div class="filter-group">
        <div class="filter-label">&#31579;&#36873;</div>
        <div class="search-wrap dept-search-wrap">
          <input
            v-model="search"
            class="search-input dept-search-input"
            placeholder="&#35831;&#36755;&#20837;&#37096;&#38376;&#21517;&#31216;&#25110;&#32534;&#30721;"
            @input="onSearch"
            @keyup.esc="clearSearch"
          />
          <button v-if="search" class="dept-search-clear" @click="clearSearch">
            &#28165;&#31354;
          </button>
        </div>
        <div class="dept-search-hint">
          &#25353;&#21517;&#31216;&#25110;&#32534;&#30721;&#25628;&#32034;&#65292;&#21305;&#37197;&#26102;&#20250;&#33258;&#21160;&#23637;&#24320;&#30456;&#20851;&#23618;&#32423;
        </div>
      </div>

      <div class="filter-actions">
        <button
          class="btn btn-outline"
          @click="downloadTemplate"
          title="&#19979;&#36733;&#23548;&#20837;&#27169;&#26495;"
        >
          &#27169;&#26495;&#19979;&#36733;
        </button>
        <label class="btn btn-outline" style="cursor:pointer" title="Excel &#23548;&#20837;">
          &#23548;&#20837;
          <input
            ref="importInput"
            type="file"
            accept=".xlsx,.xls"
            style="display:none"
            @change="handleImport"
          />
        </label>
        <button class="btn btn-outline" @click="doExport">
          &#23548;&#20986;&#31579;&#36873;&#32467;&#26524;
        </button>
        <button class="btn btn-outline" @click="doExportAll">
          &#23548;&#20986;&#20840;&#37096;
        </button>
        <button class="btn btn-primary" @click="openCreate()">
          + &#26032;&#24314;&#37096;&#38376;
        </button>
      </div>
    </div>

    <div class="batch-bar">
      <div class="batch-info-rich">
        <div class="batch-info-primary">{{ summaryText }}</div>
        <div class="batch-info-secondary">{{ expandStatusText }}</div>
      </div>
      <div class="batch-actions">
        <button class="btn btn-outline" @click="expandAll">
          &#23637;&#24320;&#20840;&#37096;
        </button>
        <button class="btn btn-outline" @click="collapseAll">
          &#25910;&#36215;&#20840;&#37096;
        </button>
      </div>
    </div>

    <div class="table-wrap">
      <el-table
        :key="tableRenderKey"
        :data="displayTree"
        row-key="id"
        :default-expand-all="defaultExpand"
        border
        size="small"
        stripe
        style="width:100%"
        :tree-props="{ children: 'children', hasChildren: 'hasChildren' }"
        :row-class-name="({ row }) => `dept-row-depth-${Math.min(row._depth || 0, 2)}`"
      >
        <el-table-column label="&#37096;&#38376;&#21517;&#31216;" min-width="260">
          <template #default="{ row }">
            <div class="dept-name-wrap">
              <div :class="['dept-icon', `dept-icon-d${Math.min(row._depth || 0, 2)}`]">
                {{ (row._depth || 0) === 0 ? 'D' : ((row._depth || 0) === 1 ? 'S' : 'L') }}
              </div>
              <span :class="['dept-name', `dept-name-d${Math.min(row._depth || 0, 2)}`]">
                {{ row.name }}
              </span>
              <span v-if="row.children && row.children.length" class="dept-child-badge">
                {{ row.children.length }} &#20010;&#23376;&#37096;&#38376;
              </span>
            </div>
          </template>
        </el-table-column>

        <el-table-column label="&#37096;&#38376;&#32534;&#30721;" width="150">
          <template #default="{ row }">
            <span v-if="row.code" class="tag tag-gray code-tag">{{ row.code }}</span>
            <span v-else class="text-muted text-sm">-</span>
          </template>
        </el-table-column>

        <el-table-column label="&#25490;&#24207;" width="90" align="center">
          <template #default="{ row }">
            <span class="text-sm text-muted">{{ row.sortOrder }}</span>
          </template>
        </el-table-column>

        <el-table-column label="&#25805;&#20316;" width="190" align="center">
          <template #default="{ row }">
            <div class="action-group dept-actions" style="justify-content:center">
              <button class="action-btn action-btn-edit" @click="openCreate(row)">
                &#26032;&#22686;&#19979;&#32423;
              </button>
              <button class="action-btn action-btn-edit" @click="openEdit(row)">
                &#32534;&#36753;
              </button>
              <button class="action-btn action-btn-del" @click="deleteDept(row)">
                &#21024;&#38500;
              </button>
            </div>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <div v-if="showModal" class="modal-mask" @click.self="closeModal">
      <div class="modal-box modal-sm">
        <div class="modal-header">
          <div class="modal-title">{{ editingId ? '\u7f16\u8f91\u90e8\u95e8' : '\u65b0\u5efa\u90e8\u95e8' }}</div>
          <button class="modal-close" @click="closeModal">&times;</button>
        </div>

        <div class="modal-body">
          <div class="form-group" style="margin-bottom:14px">
            <label class="form-label">&#19978;&#32423;&#37096;&#38376;</label>
            <el-select
              v-model="form.parentId"
              placeholder="&#26080;&#65288;&#39030;&#32423;&#37096;&#38376;&#65289;"
              clearable
              style="width:100%"
            >
              <el-option :value="null" label="&#26080;&#65288;&#39030;&#32423;&#37096;&#38376;&#65289;" />
              <el-option
                v-for="d in flatParentOptions"
                :key="d.id"
                :value="d.id"
                :label="d.label"
                :disabled="d.id === editingId"
              />
            </el-select>
          </div>

          <div class="form-group" style="margin-bottom:14px">
            <label class="form-label">
              &#37096;&#38376;&#21517;&#31216; <span style="color:red">*</span>
            </label>
            <input
              v-model="form.name"
              class="form-input"
              placeholder="&#22914;&#65306;&#30740;&#21457;&#37096;&#12289;&#21697;&#36136;&#37096;"
            />
          </div>

          <div class="form-group" style="margin-bottom:14px">
            <label class="form-label">&#37096;&#38376;&#32534;&#30721;</label>
            <input
              v-model="form.code"
              class="form-input"
              placeholder="&#22914;&#65306;RD&#12289;QA01"
            />
          </div>

          <div class="form-group">
            <label class="form-label">&#25490;&#24207;&#20540;</label>
            <input
              v-model.number="form.sortOrder"
              class="form-input"
              type="number"
              min="0"
              placeholder="&#20540;&#36234;&#23567;&#36234;&#38752;&#21069;"
            />
          </div>

          <div v-if="formError" class="form-error">{{ formError }}</div>
        </div>

        <div class="modal-footer">
          <button class="btn btn-outline" @click="closeModal">
            &#21462;&#28040;
          </button>
          <button class="btn btn-primary" @click="saveForm" :disabled="saving">
            {{ saving ? '\u4fdd\u5b58\u4e2d...' : (editingId ? '\u4fdd\u5b58' : '\u521b\u5efa') }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="importResult" class="modal-mask" @click.self="importResult = null">
      <div class="modal-box modal-sm">
        <div class="modal-header">
          <div class="modal-title">&#23548;&#20837;&#32467;&#26524;</div>
          <button class="modal-close" @click="importResult = null">&times;</button>
        </div>

        <div class="modal-body">
          <div style="display:flex;gap:16px;margin-bottom:16px">
            <div class="import-stat import-stat-ok">
              <div class="import-stat-num">{{ importResult.success }}</div>
              <div class="import-stat-label">&#25104;&#21151;</div>
            </div>
            <div class="import-stat import-stat-fail">
              <div class="import-stat-num">{{ importResult.failed }}</div>
              <div class="import-stat-label">&#22833;&#36133;/&#36339;&#36807;</div>
            </div>
          </div>

          <div v-if="importResult.errors && importResult.errors.length" style="max-height:200px;overflow-y:auto">
            <div
              v-for="(e, i) in importResult.errors"
              :key="i"
              style="font-size:12.5px;color:#7f1d1d;padding:4px 0;border-bottom:1px solid #fecaca"
            >
              {{ e }}
            </div>
          </div>
        </div>

        <div class="modal-footer">
          <button class="btn btn-primary" @click="importResult = null">
            &#30830;&#23450;
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, inject, onMounted, reactive, ref } from 'vue'
import { deptApi } from '../api/index.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'

const showToast = inject('showToast', () => {})

const deptTree = ref([])
const allDepts = ref([])
const search = ref('')
const showModal = ref(false)
const saving = ref(false)
const editingId = ref(null)
const formError = ref('')
const importResult = ref(null)
const importInput = ref(null)
const defaultExpand = ref(true)
const tableRenderKey = ref(0)

const form = reactive({
  name: '',
  code: '',
  sortOrder: 0,
  parentId: null
})

const hasSearch = computed(() => Boolean(search.value.trim()))

const flatParentOptions = computed(() => {
  const result = []

  function flatten(nodes, depth) {
    for (const node of nodes) {
      result.push({ id: node.id, label: `${'  '.repeat(depth)}${node.name}` })
      if (node.children && node.children.length) {
        flatten(node.children, depth + 1)
      }
    }
  }

  flatten(deptTree.value, 0)
  return result
})

function cloneTree(nodes) {
  return (nodes || []).map(node => ({
    ...node,
    children: cloneTree(node.children || [])
  }))
}

function addDepth(nodes, depth = 0) {
  return (nodes || []).map(node => ({
    ...node,
    _depth: depth,
    children: node.children && node.children.length ? addDepth(node.children, depth + 1) : []
  }))
}

const displayTree = computed(() => {
  if (!hasSearch.value) {
    return addDepth(deptTree.value)
  }

  const keyword = search.value.trim().toLowerCase()

  function filterNodes(nodes) {
    return (nodes || []).reduce((result, node) => {
      const match = (node.name || '').toLowerCase().includes(keyword) ||
        (node.code || '').toLowerCase().includes(keyword)
      const filteredChildren = match
        ? cloneTree(node.children || [])
        : filterNodes(node.children || [])

      if (match || filteredChildren.length) {
        result.push({
          ...node,
          children: filteredChildren
        })
      }

      return result
    }, [])
  }

  return addDepth(filterNodes(deptTree.value))
})

function countNodes(nodes) {
  return (nodes || []).reduce((sum, node) => {
    return sum + 1 + countNodes(node.children || [])
  }, 0)
}

const visibleDeptCount = computed(() => countNodes(displayTree.value))

const summaryText = computed(() => {
  return hasSearch.value
    ? `\u5f53\u524d\u5339\u914d ${visibleDeptCount.value} \u4e2a\u90e8\u95e8`
    : `\u5171 ${allDepts.value.length} \u4e2a\u90e8\u95e8\uff08\u6811\u5f62\uff09`
})

const expandStatusText = computed(() => {
  if (hasSearch.value) {
    return defaultExpand.value
      ? '\u641c\u7d22\u7ed3\u679c\u5df2\u81ea\u52a8\u5c55\u5f00\u5339\u914d\u5c42\u7ea7'
      : '\u641c\u7d22\u7ed3\u679c\u5df2\u6536\u8d77\uff0c\u53ef\u70b9\u51fb\u201c\u5c55\u5f00\u5168\u90e8\u201d'
  }

  return defaultExpand.value
    ? '\u5f53\u524d\u4e3a\u5c55\u5f00\u72b6\u6001'
    : '\u5f53\u524d\u4e3a\u6536\u8d77\u72b6\u6001'
})

function refreshTable() {
  tableRenderKey.value += 1
}

async function load() {
  try {
    const [treeRes, flatRes] = await Promise.all([deptApi.tree(), deptApi.list()])
    deptTree.value = treeRes.data || []
    allDepts.value = flatRes.data || []
    refreshTable()
  } catch (error) {
    console.error(error)
  }
}

function onSearch() {
  if (hasSearch.value) {
    defaultExpand.value = true
  }
  refreshTable()
}

function clearSearch() {
  if (!search.value) {
    return
  }

  search.value = ''
  defaultExpand.value = true
  refreshTable()
}

function expandAll() {
  defaultExpand.value = true
  refreshTable()
}

function collapseAll() {
  defaultExpand.value = false
  refreshTable()
}

function openCreate(parentRow) {
  editingId.value = null
  form.name = ''
  form.code = ''
  form.sortOrder = 0
  form.parentId = parentRow ? parentRow.id : null
  formError.value = ''
  showModal.value = true
}

function openEdit(dept) {
  editingId.value = dept.id
  form.name = dept.name || ''
  form.code = dept.code || ''
  form.sortOrder = dept.sortOrder ?? 0
  form.parentId = dept.parentId || null
  formError.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function saveForm() {
  formError.value = ''

  if (!form.name.trim()) {
    formError.value = '\u8bf7\u8f93\u5165\u90e8\u95e8\u540d\u79f0'
    return
  }

  saving.value = true
  const payload = {
    name: form.name.trim(),
    code: form.code.trim(),
    sortOrder: String(form.sortOrder ?? 0),
    parentId: form.parentId != null ? String(form.parentId) : ''
  }

  try {
    if (editingId.value) {
      await deptApi.update(editingId.value, payload)
      showToast('\u90e8\u95e8\u66f4\u65b0\u6210\u529f')
    } else {
      await deptApi.create(payload)
      showToast('\u90e8\u95e8\u521b\u5efa\u6210\u529f')
    }

    closeModal()
    await load()
  } catch (error) {
    formError.value = error.response?.data?.message || '\u64cd\u4f5c\u5931\u8d25'
  } finally {
    saving.value = false
  }
}

async function deleteDept(dept) {
  const hasChildren = dept.children && dept.children.length > 0
  const message = hasChildren
    ? `\u90e8\u95e8\u300c${dept.name}\u300d\u5b58\u5728\u5b50\u90e8\u95e8\uff0c\u5220\u9664\u540e\u5b50\u90e8\u95e8\u5c06\u63d0\u5347\u4e3a\u9876\u7ea7\u90e8\u95e8\uff0c\u662f\u5426\u7ee7\u7eed\uff1f`
    : `\u786e\u5b9a\u5220\u9664\u90e8\u95e8\u300c${dept.name}\u300d\u5417\uff1f`

  if (!confirm(message)) {
    return
  }

  try {
    await deptApi.remove(dept.id)
    showToast('\u5220\u9664\u6210\u529f')
    await load()
  } catch (error) {
    showToast(error.response?.data?.message || '\u5220\u9664\u5931\u8d25', 'error')
  }
}

function saveBlob(blob, filename) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}

async function doExport() {
  try {
    const response = await deptApi.export(search.value || undefined)
    saveBlob(response.data, '\u90e8\u95e8\u6570\u636e-\u7b5b\u9009\u7ed3\u679c.xlsx')
  } catch (error) {
    showToast('\u5bfc\u51fa\u5931\u8d25', 'error')
  }
}

async function doExportAll() {
  try {
    const response = await deptApi.exportAll()
    saveBlob(response.data, '\u90e8\u95e8\u6570\u636e-\u5168\u90e8.xlsx')
  } catch (error) {
    showToast('\u5bfc\u51fa\u5931\u8d25', 'error')
  }
}

async function downloadTemplate() {
  try {
    const response = await deptApi.template()
    saveBlob(response.data, '\u90e8\u95e8\u5bfc\u5165\u6a21\u677f.xlsx')
  } catch (error) {
    showToast('\u4e0b\u8f7d\u5931\u8d25', 'error')
  }
}

async function handleImport(event) {
  const file = event.target.files[0]
  if (!file) {
    return
  }

  try {
    const response = await deptApi.import(file)
    importResult.value = response.data
    await load()
  } catch (error) {
    showToast('\u5bfc\u5165\u5931\u8d25', 'error')
  } finally {
    if (importInput.value) {
      importInput.value.value = ''
    }
  }
}

useResumeRefresh(load)

onMounted(() => {
  load()
})
</script>

<style scoped>
:deep(.filter-bar) {
  padding: 10px 12px;
  margin-bottom: 8px;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: #fff;
}

:deep(.filter-group) {
  gap: 4px;
}

:deep(.filter-actions) {
  gap: 6px;
  display: flex;
  flex-wrap: wrap;
}

:deep(.filter-actions .btn) {
  min-height: 32px;
  padding: 6px 10px;
  font-size: 12.5px;
  border-radius: 8px;
}

.dept-search-input {
  width: 320px;
  max-width: 100%;
  padding-right: 72px;
}

.dept-search-wrap {
  display: inline-flex;
  align-items: center;
}

.dept-search-clear {
  position: absolute;
  top: 50%;
  right: 8px;
  transform: translateY(-50%);
  border: none;
  background: transparent;
  color: var(--text-muted);
  font-size: 12px;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 6px;
}

.dept-search-clear:hover {
  background: #f1f5f9;
  color: var(--primary);
}

.dept-search-hint {
  font-size: 12px;
  color: var(--text-muted);
}

:deep(.el-table th.el-table__cell) {
  padding: 8px 10px;
  font-size: 11.5px;
}

:deep(.el-table td.el-table__cell) {
  padding: 8px 10px;
}

:deep(.el-table .cell) {
  line-height: 1.35;
}

:deep(.dept-row-depth-0) td {
  background: #f7fbff !important;
}

:deep(.dept-row-depth-1) td {
  background: #f8fdf9 !important;
}

:deep(.dept-row-depth-2) td {
  background: #fffdf6 !important;
}

.dept-name-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dept-icon {
  width: 24px;
  height: 24px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  flex-shrink: 0;
  color: #0f172a;
}

.dept-icon-d0 {
  background: linear-gradient(135deg, #bfdbfe, #a5b4fc);
}

.dept-icon-d1 {
  background: linear-gradient(135deg, #bbf7d0, #6ee7b7);
}

.dept-icon-d2 {
  background: linear-gradient(135deg, #fde68a, #fcd34d);
}

.dept-name {
  font-weight: 600;
}

.dept-name-d0 {
  color: #1d4ed8;
  font-size: 13px;
}

.dept-name-d1,
.dept-name-d2 {
  font-size: 12.5px;
}

.dept-name-d1 {
  color: #065f46;
}

.dept-name-d2 {
  color: #92400e;
}

.dept-child-badge {
  font-size: 10.5px;
  padding: 1px 6px;
  border-radius: 20px;
  background: #e0e7ff;
  color: #4338ca;
  font-weight: 500;
}

.code-tag {
  font-size: 12px;
}

.dept-actions {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.dept-actions .action-btn {
  min-height: 28px;
  padding: 4px 8px;
  font-size: 11.5px;
}

.import-stat {
  flex: 1;
  padding: 14px;
  border-radius: 10px;
  text-align: center;
}

.import-stat-ok {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
}

.import-stat-fail {
  background: #fef2f2;
  border: 1px solid #fecaca;
}

.import-stat-num {
  font-size: 28px;
  font-weight: 800;
}

.import-stat-ok .import-stat-num {
  color: #16a34a;
}

.import-stat-fail .import-stat-num {
  color: #dc2626;
}

.import-stat-label {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.form-error {
  margin-top: 12px;
  padding: 10px 14px;
  background: #fef2f2;
  border: 1px solid #fecaca;
  color: #991b1b;
  border-radius: 8px;
  font-size: 13px;
}

.batch-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 10px;
  margin-bottom: 8px;
  background: #fff;
  border: 1px solid var(--border);
  border-radius: 10px;
}

.batch-info-rich {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.batch-info-primary {
  color: var(--text);
  font-size: 13px;
  font-weight: 600;
}

.batch-info-secondary {
  color: var(--text-muted);
  font-size: 12px;
}

.batch-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.dept-page .table-wrap {
  margin-top: 0;
  border-radius: 10px;
}

@media (max-width: 768px) {
  .dept-search-input {
    width: 100%;
  }

  :deep(.filter-bar) {
    padding: 10px;
  }

  :deep(.filter-group),
  :deep(.filter-actions),
  .batch-actions {
    width: 100%;
  }

  :deep(.filter-actions .btn) {
    min-height: 34px;
    padding: 7px 10px;
    font-size: 12.5px;
    flex: 1 1 calc(50% - 6px);
    justify-content: center;
  }

  .batch-bar {
    gap: 6px;
    margin-bottom: 4px;
    flex-wrap: wrap;
  }

  .batch-actions .btn {
    flex: 1 1 0;
  }

  .dept-actions .action-btn {
    min-width: 64px;
  }
}
</style>
