<template>
  <div class="repro-shell">
    <div class="repro-card">
      <div class="repro-card-title">再现性参数</div>
      <div class="repro-form-grid">
        <div class="repro-input-group">
          <label>操作者数</label>
          <input v-model="form.appraiserCount" type="number" min="2" max="10" step="1" />
        </div>
        <div class="repro-input-group">
          <label>零件数</label>
          <input v-model="form.partCount" type="number" min="2" max="30" step="1" />
        </div>
        <div class="repro-input-group">
          <label>重复次数</label>
          <input v-model="form.trialCount" type="number" min="2" max="10" step="1" />
        </div>
        <div class="repro-input-group">
          <label>公差（可选）</label>
          <input v-model="form.tolerance" type="number" step="0.001" />
        </div>
      </div>
      <div class="repro-hint">
        与 GRR 模板一致：行为操作者+重复次数，列为零件。当前已识别 {{ sampleCount }} / {{ requiredCount }}。
      </div>
      <div v-if="isResultStale" class="repro-stale-banner">
        当前再现性结果已与输入数据不一致，请重新计算后再导出专业报告。
      </div>
      <div class="repro-actions">
        <el-button :loading="calculating" type="primary" @click="calculate">计算再现性</el-button>
        <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
        <el-button @click="clearData">清空数据</el-button>
      </div>
    </div>

    <div class="repro-main-grid">
      <div class="repro-card">
        <div class="repro-title-row">
          <div class="repro-card-title">再现性结果</div>
          <div class="repro-title-actions">
            <el-button :loading="calculating" type="primary" @click="calculate">计算再现性</el-button>
            <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
          </div>
        </div>
        <div class="repro-stats-grid">
          <template v-if="result">
            <div class="repro-stat-row">
              <span>样本点数</span>
              <b>{{ result.sampleCount }}</b>
              <span>操作者/零件/重复</span>
              <b>{{ result.appraiserCount }}/{{ result.partCount }}/{{ result.trialCount }}</b>
            </div>
            <div class="repro-stat-row">
              <span>AV (6σ)</span>
              <b :class="toneClass(result.pctStudyVarReproducibility)">{{ fmt(result.svReproducibility, 4) }}</b>
              <span>EV (6σ)</span>
              <b>{{ fmt(result.svRepeatability, 4) }}</b>
            </div>
            <div class="repro-stat-row">
              <span>%StudyVar AV</span>
              <b :class="toneClass(result.pctStudyVarReproducibility)">{{ fmt(result.pctStudyVarReproducibility, 2) }}%</b>
              <span>%Tolerance AV</span>
              <b :class="toneClass(result.pctToleranceReproducibility)">{{ result.pctToleranceReproducibility == null ? '-' : fmt(result.pctToleranceReproducibility, 2) + '%' }}</b>
            </div>
            <div class="repro-stat-row">
              <span>操作者均值极差</span>
              <b>{{ fmt(result.operatorMeanDiff, 5) }}</b>
              <span>评价</span>
              <b :class="toneClass(result.pctStudyVarReproducibility)">{{ result.summaryLocal }}</b>
            </div>
          </template>
          <div v-else class="repro-empty-tip">点击“计算再现性”后显示结果</div>
        </div>
      </div>

      <div class="repro-card">
        <div class="repro-sheet-toolbar">
          <span class="repro-sheet-title">再现性录入模板</span>
          <span class="repro-sheet-meta">支持按模板整块复制粘贴</span>
        </div>
        <div class="repro-sheet-wrap">
          <table class="repro-table">
            <thead>
              <tr>
                <th colspan="2" rowspan="2" class="th-tester">测试人</th>
                <th :colspan="partCountInt">零件编号及测试记录</th>
              </tr>
              <tr>
                <th v-for="part in partCountInt" :key="'part-' + part">{{ part }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in displayRows" :key="row.key">
                <td class="td-serial">{{ row.serialLabel }}</td>
                <td class="td-marker">{{ row.markerLabel }}</td>
                <td v-for="partIndex in partCountInt" :key="row.key + '-p-' + partIndex">
                  <input
                    :data-cell="`${row.operatorIndex}-${row.trialIndex}-${partIndex - 1}`"
                    v-model="measurements[row.operatorIndex][row.trialIndex][partIndex - 1]"
                    class="repro-cell-input"
                    type="text"
                    @keydown.enter.prevent="focusNextRow(row.operatorIndex, row.trialIndex, partIndex - 1)"
                    @paste="handlePaste($event, row.operatorIndex, row.trialIndex, partIndex - 1)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="repro-card repro-charts-card">
        <div class="repro-card-title">图表分析</div>
        <div class="repro-chart-grid">
          <div class="repro-chart-panel">
            <div class="repro-chart-title">操作者均值对比</div>
            <div ref="operatorChartRef" class="repro-chart"></div>
          </div>
          <div class="repro-chart-panel">
            <div class="repro-chart-title">部件 × 操作者交互图</div>
            <div ref="interactionChartRef" class="repro-chart"></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, inject, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import * as echarts from 'echarts'
import { analysisApi } from '../../api/index.js'

const showToast = inject('showToast', () => {})

const form = reactive({
  appraiserCount: '3',
  partCount: '10',
  trialCount: '3',
  tolerance: ''
})

const measurements = ref([])
const result = ref(null)
const calculating = ref(false)
const exportingReport = ref(false)
const calculatedSignature = ref('')

const operatorChartRef = ref(null)
const interactionChartRef = ref(null)
let operatorChart = null
let interactionChart = null

const appraiserCountInt = computed(() => clampInt(form.appraiserCount, 2, 10, 3))
const partCountInt = computed(() => clampInt(form.partCount, 2, 30, 10))
const trialCountInt = computed(() => clampInt(form.trialCount, 2, 10, 3))
const requiredCount = computed(() => appraiserCountInt.value * partCountInt.value * trialCountInt.value)

watch([appraiserCountInt, partCountInt, trialCountInt], ([a, p, t]) => {
  measurements.value = resizeCube(measurements.value, a, t, p)
}, { immediate: true })

const sampleCount = computed(() => measurements.value.flat(2).filter(v => toFiniteNumber(v) != null).length)
const isResultStale = computed(() =>
  !!result.value
  && !!calculatedSignature.value
  && currentSignature.value !== calculatedSignature.value
)

const displayRows = computed(() => {
  const rows = []
  let serial = 1
  for (let o = 0; o < appraiserCountInt.value; o += 1) {
    for (let t = 0; t < trialCountInt.value; t += 1) {
      rows.push({
        key: `row-${o}-${t}`,
        operatorIndex: o,
        trialIndex: t,
        serialLabel: t === 0 ? `${serial}. ${toOperatorLabel(o)}` : `${serial}.`,
        markerLabel: String(t + 1)
      })
      serial += 1
    }
  }
  return rows
})

const currentSignature = computed(() => {
  const tol = toFiniteNumber(form.tolerance)
  return [
    appraiserCountInt.value,
    partCountInt.value,
    trialCountInt.value,
    tol == null ? '' : tol,
    measurements.value.flat(2).join('|')
  ].join('#')
})

watch(currentSignature, sig => {
  if (result.value && calculatedSignature.value && sig !== calculatedSignature.value) {
    result.value = null
    renderCharts()
  }
})

watch([measurements, result, appraiserCountInt, partCountInt, trialCountInt], async () => {
  await nextTick()
  ensureCharts()
  renderCharts()
}, { deep: true })

onMounted(async () => {
  await nextTick()
  ensureCharts()
  renderCharts()
  window.addEventListener('resize', resizeCharts)
})

onUnmounted(() => {
  window.removeEventListener('resize', resizeCharts)
  operatorChart?.dispose()
  interactionChart?.dispose()
  operatorChart = null
  interactionChart = null
})

function clampInt(value, min, max, fallback) {
  const n = Number(value)
  if (!Number.isFinite(n)) return fallback
  return Math.min(max, Math.max(min, Math.trunc(n)))
}

function resizeCube(oldData, appraisers, trials, parts) {
  return Array.from({ length: appraisers }, (_, o) =>
    Array.from({ length: trials }, (_, t) =>
      Array.from({ length: parts }, (_, p) => oldData?.[o]?.[t]?.[p] ?? '')
    )
  )
}

function toFiniteNumber(value) {
  const txt = String(value ?? '').trim()
  if (!txt) return null
  const n = Number(txt)
  return Number.isFinite(n) ? n : null
}

function toOperatorLabel(index) {
  let n = index + 1
  let label = ''
  while (n > 0) {
    const mod = (n - 1) % 26
    label = String.fromCharCode(65 + mod) + label
    n = Math.floor((n - 1) / 26)
  }
  return label
}

function mean(values) {
  const valid = values.filter(v => v != null)
  if (!valid.length) return null
  return valid.reduce((s, v) => s + v, 0) / valid.length
}

function valueAt(o, t, p) {
  return toFiniteNumber(measurements.value?.[o]?.[t]?.[p])
}

function buildOrderedValues() {
  const values = []
  for (let o = 0; o < appraiserCountInt.value; o += 1) {
    for (let p = 0; p < partCountInt.value; p += 1) {
      for (let t = 0; t < trialCountInt.value; t += 1) {
        const v = valueAt(o, t, p)
        if (v != null) values.push(v)
      }
    }
  }
  return values
}

function buildOperatorMeans() {
  return Array.from({ length: appraiserCountInt.value }, (_, o) => {
    const values = []
    for (let p = 0; p < partCountInt.value; p += 1) {
      for (let t = 0; t < trialCountInt.value; t += 1) {
        values.push(valueAt(o, t, p))
      }
    }
    return mean(values)
  })
}

function buildInteractionMeans() {
  return Array.from({ length: appraiserCountInt.value }, (_, o) =>
    Array.from({ length: partCountInt.value }, (_, p) => {
      const values = Array.from({ length: trialCountInt.value }, (_, t) => valueAt(o, t, p))
      return mean(values)
    })
  )
}

function summaryByStudyVar(pct) {
  if (!Number.isFinite(pct)) return '已完成再现性分析'
  if (pct <= 10) return '再现性优秀（≤10%）'
  if (pct <= 30) return '再现性可接受（10%~30%）'
  return '再现性偏高（>30%），建议统一方法与操作'
}

async function calculate() {
  const values = buildOrderedValues()
  if (values.length < requiredCount.value) {
    showToast(`样本不足：${values.length}/${requiredCount.value}`, 'error')
    return
  }

  calculating.value = true
  try {
    const response = await analysisApi.grr({
      appraiserCount: appraiserCountInt.value,
      partCount: partCountInt.value,
      trialCount: trialCountInt.value,
      tolerance: toFiniteNumber(form.tolerance),
      rawValues: values.join(',')
    })

    const operatorMeans = buildOperatorMeans()
    const interactionMeans = buildInteractionMeans()
    const validMeans = operatorMeans.filter(v => v != null)
    const operatorMeanDiff = validMeans.length ? Math.max(...validMeans) - Math.min(...validMeans) : null

    result.value = {
      ...response.data,
      operatorMeans,
      interactionMeans,
      operatorMeanDiff,
      summaryLocal: summaryByStudyVar(Number(response.data?.pctStudyVarReproducibility))
    }
    calculatedSignature.value = currentSignature.value
    showToast('再现性计算完成')
  } catch (error) {
    const message = error?.response?.data?.message || '再现性计算失败，请检查输入数据'
    showToast(message, 'error')
  } finally {
    calculating.value = false
  }
}

function buildReportPayload() {
  const values = buildOrderedValues()
  if (values.length < requiredCount.value) {
    showToast(`样本不足：${values.length}/${requiredCount.value}`, 'error')
    return null
  }
  return {
    appraiserCount: appraiserCountInt.value,
    partCount: partCountInt.value,
    trialCount: trialCountInt.value,
    tolerance: toFiniteNumber(form.tolerance),
    rawValues: values.join(',')
  }
}

function parseFilenameFromDisposition(disposition) {
  if (!disposition) return null
  const utf8Match = disposition.match(/filename\*=UTF-8''([^;]+)/i)
  if (utf8Match?.[1]) {
    try {
      return decodeURIComponent(utf8Match[1])
    } catch {
      return utf8Match[1]
    }
  }
  const basicMatch = disposition.match(/filename=\"?([^\";]+)\"?/i)
  return basicMatch?.[1] || null
}

function triggerBlobDownload(blob, filename) {
  const link = document.createElement('a')
  const url = URL.createObjectURL(blob)
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
  URL.revokeObjectURL(url)
}

async function exportProfessionalReport() {
  const payload = buildReportPayload()
  if (!payload) return
  if (!result.value || isResultStale.value) {
    showToast('当前结果与输入不一致，请先重新计算后再导出专业报告', 'error')
    return
  }

  exportingReport.value = true
  try {
    const response = await analysisApi.reproducibilityReport(payload)
    const filename = parseFilenameFromDisposition(response?.headers?.['content-disposition'])
      || `再现性_专业报告-${new Date().toISOString().slice(0, 10)}.xls`
    triggerBlobDownload(response.data, filename)
    showToast('再现性专业报告导出成功')
  } catch (error) {
    const message = error?.response?.data?.message || '再现性专业报告导出失败，请稍后重试'
    showToast(message, 'error')
  } finally {
    exportingReport.value = false
  }
}

function clearData() {
  measurements.value = resizeCube([], appraiserCountInt.value, trialCountInt.value, partCountInt.value)
  result.value = null
  calculatedSignature.value = ''
  renderCharts()
}

function linearIndex(o, t) {
  return o * trialCountInt.value + t
}

function coordsFromLinear(index) {
  return { o: Math.floor(index / trialCountInt.value), t: index % trialCountInt.value }
}

function focusNextRow(o, t, p) {
  const next = linearIndex(o, t) + 1
  const max = appraiserCountInt.value * trialCountInt.value
  if (next >= max) return
  const c = coordsFromLinear(next)
  const el = document.querySelector(`[data-cell="${c.o}-${c.t}-${p}"]`)
  if (el) el.focus()
}

function handlePaste(event, startO, startT, startP) {
  const text = event.clipboardData?.getData('text')
  if (!text) return
  event.preventDefault()
  const rows = text.replace(/\r/g, '').split('\n').filter(Boolean)
  const startLinear = linearIndex(startO, startT)
  const maxLinear = appraiserCountInt.value * trialCountInt.value

  rows.forEach((row, rowOffset) => {
    const linear = startLinear + rowOffset
    if (linear >= maxLinear) return
    const target = coordsFromLinear(linear)
    row.split('\t').forEach((cell, colOffset) => {
      const part = startP + colOffset
      if (part >= partCountInt.value) return
      measurements.value[target.o][target.t][part] = cell.trim()
    })
  })
}

function fmt(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return '-'
  return Number(value).toFixed(digits)
}

function toneClass(value) {
  const n = Number(value)
  if (!Number.isFinite(n)) return ''
  if (n <= 10) return 'tone-good'
  if (n <= 30) return 'tone-warning'
  return 'tone-danger'
}

function setNoData(chart, text) {
  if (!chart) return
  chart.setOption({
    title: { text, left: 'center', top: '45%', textStyle: { color: '#94a3b8', fontSize: 14 } },
    xAxis: { show: false },
    yAxis: { show: false },
    series: []
  }, true)
}

function renderCharts() {
  if (!result.value) {
    setNoData(operatorChart, '暂无数据')
    setNoData(interactionChart, '暂无数据')
    return
  }

  const operatorLabels = Array.from({ length: appraiserCountInt.value }, (_, i) => toOperatorLabel(i))
  const partLabels = Array.from({ length: partCountInt.value }, (_, i) => `C${i + 1}`)
  const overallMean = mean(result.value.operatorMeans)

  operatorChart?.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 52, right: 14, top: 24, bottom: 42, containLabel: true },
    xAxis: { type: 'category', data: operatorLabels, name: '操作者', nameGap: 24 },
    yAxis: { type: 'value', scale: true, name: '均值' },
    series: [
      { name: '操作者均值', type: 'bar', data: result.value.operatorMeans, itemStyle: { color: '#93c5fd' } },
      { name: '总体均值', type: 'line', data: operatorLabels.map(() => overallMean), symbol: 'none', lineStyle: { color: '#16a34a', type: 'dashed' } }
    ]
  }, true)

  interactionChart?.setOption({
    tooltip: { trigger: 'axis' },
    legend: { top: 4, type: 'scroll' },
    grid: { left: 54, right: 14, top: 44, bottom: 42, containLabel: true },
    xAxis: { type: 'category', data: partLabels, name: '部件', nameGap: 22 },
    yAxis: { type: 'value', scale: true, name: '均值' },
    series: result.value.interactionMeans.map((row, idx) => ({
      name: operatorLabels[idx],
      type: 'line',
      data: row,
      symbolSize: 7
    }))
  }, true)
}

function ensureCharts() {
  if (operatorChartRef.value && !operatorChart) operatorChart = echarts.init(operatorChartRef.value)
  if (interactionChartRef.value && !interactionChart) interactionChart = echarts.init(interactionChartRef.value)
}

function resizeCharts() {
  operatorChart?.resize()
  interactionChart?.resize()
}
</script>

<style scoped>
.repro-shell {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.repro-main-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.repro-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: var(--shadow-xs);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.repro-card-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
  padding: 12px 14px 0;
}

.repro-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 8px 12px 0;
}

.repro-title-row .repro-card-title { padding: 0; }

.repro-title-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.repro-form-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  padding: 10px 12px 0;
}

.repro-input-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.repro-input-group label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 700;
}

.repro-input-group input {
  width: 100%;
  min-height: 36px;
}

.repro-hint {
  color: #64748b;
  font-size: 12px;
  line-height: 1.35;
  padding: 10px 12px 0;
}

.repro-stale-banner {
  margin: 10px 12px 0;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid #fed7aa;
  background: #fff7ed;
  color: #c2410c;
  font-size: 13px;
  font-weight: 600;
}

.repro-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 12px 12px;
}

.repro-stats-grid {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 10px 12px 12px;
}

.repro-stat-row {
  display: grid;
  grid-template-columns: minmax(96px, 1fr) minmax(88px, 1fr) minmax(96px, 1fr) minmax(88px, 1fr);
  align-items: center;
  min-height: 38px;
  border-bottom: 1px solid #e9eef5;
  font-size: 13px;
  column-gap: 8px;
}

.repro-stat-row span { color: #64748b; }
.repro-stat-row b { color: #0f172a; font-weight: 700; }

.repro-empty-tip {
  color: #94a3b8;
  font-size: 13px;
  padding: 8px 2px 6px;
}

.tone-good { color: #059669 !important; }
.tone-warning { color: #d97706 !important; }
.tone-danger { color: #dc2626 !important; }

.repro-sheet-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 12px 14px 8px;
}

.repro-sheet-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
}

.repro-sheet-meta {
  font-size: 12px;
  color: #64748b;
}

.repro-sheet-wrap {
  overflow: auto;
  padding: 0 10px 10px;
}

.repro-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.repro-table th,
.repro-table td {
  border: 1px solid #2f2f2f;
  height: 40px;
  background: #f6f7f9;
}

.repro-table thead th {
  background: #f1f3f6;
  color: #111827;
  font-size: 13px;
  font-weight: 700;
  text-align: center;
}

.td-serial,
.td-marker {
  background: #f1f3f6;
  color: #111827;
  font-weight: 600;
  text-align: center;
}

.repro-cell-input {
  width: 100%;
  height: 32px;
  border: none;
  text-align: center;
  font-size: 13px;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
  color: #1d4ed8;
  background: transparent;
}

.repro-cell-input:focus {
  outline: 2px solid rgba(37, 99, 235, 0.3);
  outline-offset: -2px;
}

.repro-charts-card {
  padding-bottom: 10px;
}

.repro-chart-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  padding: 10px 12px 2px;
}

.repro-chart-panel {
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 8px 8px 6px;
}

.repro-chart-title {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 4px;
}

.repro-chart {
  width: 100%;
  height: 300px;
}

@media (max-width: 1200px) {
  .repro-form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .repro-chart-grid { grid-template-columns: 1fr; }
  .repro-table {
    table-layout: auto;
    width: max-content;
    min-width: 100%;
  }
  .repro-table thead th { min-width: 72px; }
  .repro-cell-input { width: 92px; min-width: 92px; }
}

@media (max-width: 768px) {
  .repro-stat-row {
    grid-template-columns: 1fr 1fr;
    row-gap: 2px;
    padding: 6px 0;
  }
  .repro-chart { height: 280px; }
}
</style>
