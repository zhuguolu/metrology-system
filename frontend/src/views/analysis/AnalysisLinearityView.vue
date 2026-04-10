<template>
  <div class="linearity-shell">
    <section class="analysis-report-hero analysis-report-hero-linearity">
      <div>
        <div class="analysis-report-kicker">Linearity</div>
        <h1 class="analysis-report-title">线性结果报告页</h1>
        <p class="analysis-report-desc">把点位覆盖、偏倚、斜率与 R 方提前到头部，先看线性结论，再进入表格与回归图细节。</p>
      </div>
      <div class="analysis-report-badges">
        <span class="analysis-report-badge strong">点位 {{ result?.sampleCount ?? 0 }} / {{ pointCountInt }}</span>
        <span class="analysis-report-badge" :class="isResultStale ? 'warn' : 'success'">{{ isResultStale ? '结果待刷新' : '结果已同步' }}</span>
        <span class="analysis-report-badge primary">{{ result?.summary || '等待计算' }}</span>
      </div>
    </section>
    <div class="lin-card">
      <div class="lin-card-title">线性分析参数</div>
      <div class="lin-form-grid">
        <div class="lin-input-group">
          <label>点位数</label>
          <input v-model="form.pointCount" type="number" min="3" max="50" step="1" />
        </div>
        <div class="lin-input-group">
          <label>重复次数</label>
          <input v-model="form.repeatCount" type="number" min="1" max="10" step="1" />
        </div>
        <div class="lin-input-group">
          <label>公差（可选）</label>
          <input v-model="form.tolerance" type="number" step="0.001" />
        </div>
      </div>
      <div class="lin-hint">
        每行录入一个参考点，填写参考值和重复测量值；系统自动计算平均值、偏倚与线性回归。
      </div>
      <div v-if="isResultStale" class="lin-stale-banner">
        当前线性结果已与输入数据不一致，请重新计算后再导出专业报告。
      </div>
      <div class="lin-actions">
        <el-button :loading="calculating" type="primary" @click="calculate">计算线性</el-button>
        <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
        <el-button @click="clearData">清空数据</el-button>
      </div>
    </div>

    <div class="lin-main-grid">
      <div class="lin-card">
        <div class="lin-title-row">
          <div class="lin-card-title">线性结果</div>
          <div class="lin-title-actions">
            <el-button :loading="calculating" type="primary" @click="calculate">计算线性</el-button>
            <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
          </div>
        </div>
        <div class="lin-stats-grid">
          <template v-if="result">
            <div class="lin-stat-row">
              <span>有效点位</span>
              <b>{{ result.sampleCount }}</b>
              <span>平均偏倚</span>
              <b>{{ fmt(result.meanBias, 6) }}</b>
            </div>
            <div class="lin-stat-row">
              <span>最大绝对偏倚</span>
              <b>{{ fmt(result.maxAbsBias, 6) }}</b>
              <span>%Tolerance</span>
              <b :class="toneClass(result.pctTolerance)">{{ result.pctTolerance == null ? '-' : fmt(result.pctTolerance, 2) + '%' }}</b>
            </div>
            <div class="lin-stat-row">
              <span>斜率</span>
              <b :class="toneClass(result.pctTolerance)">{{ fmt(result.slope, 8) }}</b>
              <span>截距</span>
              <b>{{ fmt(result.intercept, 6) }}</b>
            </div>
            <div class="lin-stat-row">
              <span>R²</span>
              <b>{{ fmt(result.r2, 6) }}</b>
              <span>评价</span>
              <b :class="toneClass(result.pctTolerance)">{{ result.summary }}</b>
            </div>
          </template>
          <div v-else class="lin-empty-tip">点击“计算线性”后显示结果</div>
        </div>
      </div>

      <div class="lin-card">
        <div class="lin-sheet-toolbar">
          <span class="lin-sheet-title">线性录入模板</span>
          <span class="lin-sheet-meta">可从 Excel 直接粘贴</span>
        </div>
        <div class="lin-sheet-wrap">
          <table class="lin-table">
            <thead>
              <tr>
                <th class="th-index">序号</th>
                <th class="th-ref">参考值</th>
                <th v-for="repeat in repeatCountInt" :key="'m-' + repeat">测量{{ repeat }}</th>
                <th class="th-mean">平均测量</th>
                <th class="th-bias">偏倚</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, rowIndex) in rowsData" :key="'row-' + rowIndex">
                <td class="td-index">{{ rowIndex + 1 }}</td>
                <td>
                  <input
                    :data-cell="`${rowIndex}-ref`"
                    v-model="row.reference"
                    class="lin-cell-input"
                    type="text"
                    @keydown.enter.prevent="focusNextRow(rowIndex, 'ref')"
                    @paste="handlePaste($event, rowIndex, 0)"
                  />
                </td>
                <td v-for="(m, mIndex) in row.measures" :key="'m-' + rowIndex + '-' + mIndex">
                  <input
                    :data-cell="`${rowIndex}-m-${mIndex}`"
                    v-model="row.measures[mIndex]"
                    class="lin-cell-input"
                    type="text"
                    @keydown.enter.prevent="focusNextRow(rowIndex, `m-${mIndex}`)"
                    @paste="handlePaste($event, rowIndex, mIndex + 1)"
                  />
                </td>
                <td class="td-value">{{ fmtCell(rowMean(row), 6) }}</td>
                <td class="td-value">{{ fmtCell(rowBias(row), 6) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="lin-card lin-charts-card">
        <div class="lin-card-title">图表分析</div>
        <div class="lin-chart-grid">
          <div class="lin-chart-panel">
            <div class="lin-chart-title">偏倚-参考值回归图</div>
            <div ref="regressionChartRef" class="lin-chart"></div>
          </div>
          <div class="lin-chart-panel">
            <div class="lin-chart-title">各点偏倚分布</div>
            <div ref="biasChartRef" class="lin-chart"></div>
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
  pointCount: '10',
  repeatCount: '3',
  tolerance: ''
})

const rowsData = ref([])
const result = ref(null)
const calculating = ref(false)
const exportingReport = ref(false)
const calculatedSignature = ref('')

const regressionChartRef = ref(null)
const biasChartRef = ref(null)
let regressionChart = null
let biasChart = null

const pointCountInt = computed(() => clampInt(form.pointCount, 3, 50, 10))
const repeatCountInt = computed(() => clampInt(form.repeatCount, 1, 10, 3))

watch([pointCountInt, repeatCountInt], ([points, repeats]) => {
  rowsData.value = resizeRows(rowsData.value, points, repeats)
}, { immediate: true })
const isResultStale = computed(() =>
  !!result.value
  && !!calculatedSignature.value
  && currentSignature.value !== calculatedSignature.value
)

const currentSignature = computed(() => {
  const tol = toFiniteNumber(form.tolerance)
  const flat = rowsData.value.flatMap(r => [r.reference, ...r.measures]).join('|')
  return [pointCountInt.value, repeatCountInt.value, tol == null ? '' : tol, flat].join('#')
})

watch(currentSignature, sig => {
  if (result.value && calculatedSignature.value && sig !== calculatedSignature.value) {
    result.value = null
    renderCharts()
  }
})

watch([rowsData, result], async () => {
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
  regressionChart?.dispose()
  biasChart?.dispose()
  regressionChart = null
  biasChart = null
})

function clampInt(value, min, max, fallback) {
  const n = Number(value)
  if (!Number.isFinite(n)) return fallback
  return Math.min(max, Math.max(min, Math.trunc(n)))
}

function resizeRows(oldRows, points, repeats) {
  return Array.from({ length: points }, (_, i) => ({
    reference: oldRows?.[i]?.reference ?? '',
    measures: Array.from({ length: repeats }, (_, j) => oldRows?.[i]?.measures?.[j] ?? '')
  }))
}

function toFiniteNumber(value) {
  const txt = String(value ?? '').trim()
  if (!txt) return null
  const n = Number(txt)
  return Number.isFinite(n) ? n : null
}

function mean(values) {
  const valid = values.filter(v => v != null)
  if (!valid.length) return null
  return valid.reduce((s, v) => s + v, 0) / valid.length
}

function rowMean(row) {
  return mean(row.measures.map(toFiniteNumber))
}

function rowBias(row) {
  const ref = toFiniteNumber(row.reference)
  const avg = rowMean(row)
  if (ref == null || avg == null) return null
  return avg - ref
}

function buildValidPoints() {
  return rowsData.value
    .map((row, idx) => {
      const ref = toFiniteNumber(row.reference)
      const avg = rowMean(row)
      if (ref == null || avg == null) return null
      return { idx, ref, avg, bias: avg - ref }
    })
    .filter(Boolean)
}

function regress(points) {
  const n = points.length
  const xs = points.map(p => p.ref)
  const ys = points.map(p => p.bias)
  const xMean = mean(xs)
  const yMean = mean(ys)
  const sxx = xs.reduce((s, x) => s + (x - xMean) ** 2, 0)
  if (!Number.isFinite(sxx) || sxx === 0) {
    return { slope: 0, intercept: yMean ?? 0, r2: 0 }
  }
  const sxy = points.reduce((s, p) => s + (p.ref - xMean) * (p.bias - yMean), 0)
  const slope = sxy / sxx
  const intercept = yMean - slope * xMean

  const ssTot = ys.reduce((s, y) => s + (y - yMean) ** 2, 0)
  const ssRes = points.reduce((s, p) => {
    const pred = intercept + slope * p.ref
    return s + (p.bias - pred) ** 2
  }, 0)
  const r2 = ssTot === 0 ? 1 : Math.max(0, 1 - ssRes / ssTot)
  return { slope, intercept, r2 }
}

function summaryByMetrics(pctTol, slope) {
  if (pctTol != null) {
    if (pctTol <= 10 && Math.abs(slope) <= 0.1) return '线性优秀（偏倚小、斜率稳定）'
    if (pctTol <= 30) return '线性可接受（建议持续监控）'
    return '线性偏差较大，建议校准量具'
  }
  if (Math.abs(slope) <= 0.05) return '线性趋势稳定'
  if (Math.abs(slope) <= 0.15) return '线性存在轻微趋势'
  return '线性趋势明显，建议优化测量系统'
}

function calculate() {
  const points = buildValidPoints()
  if (points.length < 3) {
    showToast('至少需要 3 个有效点位（参考值 + 测量均值）', 'error')
    return
  }

  calculating.value = true
  try {
    const { slope, intercept, r2 } = regress(points)
    const biases = points.map(p => p.bias)
    const meanBias = mean(biases)
    const maxAbsBias = Math.max(...biases.map(v => Math.abs(v)))
    const tolerance = toFiniteNumber(form.tolerance)
    const pctTolerance = tolerance && tolerance > 0 ? (maxAbsBias / tolerance) * 100 : null

    result.value = {
      sampleCount: points.length,
      points,
      slope,
      intercept,
      r2,
      meanBias,
      maxAbsBias,
      pctTolerance,
      summary: summaryByMetrics(pctTolerance, slope)
    }
    calculatedSignature.value = currentSignature.value
    showToast('线性分析计算完成')
  } catch {
    showToast('线性分析计算失败，请检查输入', 'error')
  } finally {
    calculating.value = false
  }
}

function buildReportPayload() {
  const points = buildValidPoints()
  if (points.length < 3) {
    showToast('至少需要 3 个有效点位（参考值 + 测量均值）', 'error')
    return null
  }
  return {
    tolerance: toFiniteNumber(form.tolerance),
    gridValues: rowsData.value.map(row => [
      toFiniteNumber(row.reference),
      ...row.measures.map(v => toFiniteNumber(v))
    ]),
    rawValues: rowsData.value
      .map(row => [row.reference, ...row.measures].join('\t'))
      .join('\n')
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
    const response = await analysisApi.linearityReport(payload)
    const filename = parseFilenameFromDisposition(response?.headers?.['content-disposition'])
      || `线性分析_专业报告-${new Date().toISOString().slice(0, 10)}.xls`
    triggerBlobDownload(response.data, filename)
    showToast('线性专业报告导出成功')
  } catch (error) {
    const message = error?.response?.data?.message || '线性专业报告导出失败，请稍后重试'
    showToast(message, 'error')
  } finally {
    exportingReport.value = false
  }
}

function clearData() {
  rowsData.value = resizeRows([], pointCountInt.value, repeatCountInt.value)
  result.value = null
  calculatedSignature.value = ''
  renderCharts()
}

function focusNextRow(rowIndex, colKey) {
  const next = rowIndex + 1
  if (next >= pointCountInt.value) return
  const selector = colKey === 'ref' ? `${next}-ref` : `${next}-${colKey}`
  const el = document.querySelector(`[data-cell="${selector}"]`)
  if (el) el.focus()
}

function handlePaste(event, startRow, startCol) {
  const text = event.clipboardData?.getData('text')
  if (!text) return
  event.preventDefault()
  const lines = text.replace(/\r/g, '').split('\n').filter(Boolean)
  lines.forEach((line, rowOffset) => {
    const r = startRow + rowOffset
    if (r >= pointCountInt.value) return
    const cells = line.split('\t')
    cells.forEach((cell, colOffset) => {
      const c = startCol + colOffset
      if (c === 0) {
        rowsData.value[r].reference = cell.trim()
      } else {
        const mIndex = c - 1
        if (mIndex >= repeatCountInt.value) return
        rowsData.value[r].measures[mIndex] = cell.trim()
      }
    })
  })
}

function fmt(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return '-'
  return Number(value).toFixed(digits)
}

function fmtCell(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return ''
  return Number(value).toFixed(digits)
}

function toneClass(pctTol) {
  if (pctTol == null) return ''
  if (pctTol <= 10) return 'tone-good'
  if (pctTol <= 30) return 'tone-warning'
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
    setNoData(regressionChart, '暂无数据')
    setNoData(biasChart, '暂无数据')
    return
  }

  const points = result.value.points
  const refs = points.map(p => p.ref)
  const minX = Math.min(...refs)
  const maxX = Math.max(...refs)
  const fitLine = [
    [minX, result.value.intercept + result.value.slope * minX],
    [maxX, result.value.intercept + result.value.slope * maxX]
  ]

  regressionChart?.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 16, top: 24, bottom: 46, containLabel: true },
    xAxis: { type: 'value', name: '参考值', nameGap: 24 },
    yAxis: { type: 'value', name: '偏倚', nameGap: 24 },
    series: [
      {
        name: '偏倚点',
        type: 'scatter',
        symbolSize: 10,
        data: points.map(p => [p.ref, p.bias]),
        itemStyle: { color: '#2563eb' }
      },
      {
        name: '回归线',
        type: 'line',
        data: fitLine,
        symbol: 'none',
        lineStyle: { color: '#dc2626', width: 2 }
      },
      {
        name: '零偏倚',
        type: 'line',
        data: [[minX, 0], [maxX, 0]],
        symbol: 'none',
        lineStyle: { color: '#16a34a', type: 'dashed', width: 1.5 }
      }
    ]
  }, true)

  biasChart?.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 16, top: 24, bottom: 46, containLabel: true },
    xAxis: { type: 'category', data: points.map((p, i) => `P${i + 1}`), name: '点位', nameGap: 24 },
    yAxis: { type: 'value', name: '偏倚' },
    series: [
      {
        name: '偏倚',
        type: 'bar',
        data: points.map(p => p.bias),
        itemStyle: { color: '#93c5fd', borderColor: '#2563eb' }
      }
    ]
  }, true)
}

function ensureCharts() {
  if (regressionChartRef.value && !regressionChart) regressionChart = echarts.init(regressionChartRef.value)
  if (biasChartRef.value && !biasChart) biasChart = echarts.init(biasChartRef.value)
}

function resizeCharts() {
  regressionChart?.resize()
  biasChart?.resize()
}
</script>

<style scoped>
.linearity-shell {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.lin-main-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.lin-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: var(--shadow-xs);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.lin-card-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
  padding: 12px 14px 0;
}

.lin-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 8px 12px 0;
}

.lin-title-row .lin-card-title { padding: 0; }

.lin-title-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.lin-form-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  padding: 10px 12px 0;
}

.lin-input-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.lin-input-group label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 700;
}

.lin-input-group input {
  width: 100%;
  min-height: 36px;
}

.lin-hint {
  color: #64748b;
  font-size: 12px;
  line-height: 1.35;
  padding: 10px 12px 0;
}

.lin-stale-banner {
  margin: 10px 12px 0;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid #fed7aa;
  background: #fff7ed;
  color: #c2410c;
  font-size: 13px;
  font-weight: 600;
}

.lin-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 12px 12px;
}

.lin-stats-grid {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 10px 12px 12px;
}

.lin-stat-row {
  display: grid;
  grid-template-columns: minmax(96px, 1fr) minmax(88px, 1fr) minmax(96px, 1fr) minmax(88px, 1fr);
  align-items: center;
  min-height: 38px;
  border-bottom: 1px solid #e9eef5;
  font-size: 13px;
  column-gap: 8px;
}

.lin-stat-row span { color: #64748b; }
.lin-stat-row b { color: #0f172a; font-weight: 700; }

.lin-empty-tip {
  color: #94a3b8;
  font-size: 13px;
  padding: 8px 2px 6px;
}

.tone-good { color: #059669 !important; }
.tone-warning { color: #d97706 !important; }
.tone-danger { color: #dc2626 !important; }

.lin-sheet-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 12px 14px 8px;
}

.lin-sheet-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
}

.lin-sheet-meta {
  font-size: 12px;
  color: #64748b;
}

.lin-sheet-wrap {
  overflow: auto;
  padding: 0 10px 10px;
}

.lin-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.lin-table th,
.lin-table td {
  border: 1px solid #2f2f2f;
  height: 40px;
  background: #f6f7f9;
  text-align: center;
}

.lin-table thead th {
  background: #f1f3f6;
  color: #111827;
  font-size: 13px;
  font-weight: 700;
}

.td-index,
.td-value {
  background: #f1f3f6;
  color: #111827;
  font-weight: 600;
}

.lin-cell-input {
  width: 100%;
  height: 32px;
  border: none;
  text-align: center;
  font-size: 13px;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
  color: #1d4ed8;
  background: transparent;
}

.lin-cell-input:focus {
  outline: 2px solid rgba(37, 99, 235, 0.3);
  outline-offset: -2px;
}

.lin-charts-card { padding-bottom: 10px; }

.lin-chart-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  padding: 10px 12px 2px;
}

.lin-chart-panel {
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 8px 8px 6px;
}

.lin-chart-title {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 4px;
}

.lin-chart {
  width: 100%;
  height: 300px;
}

@media (max-width: 1200px) {
  .lin-form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .lin-chart-grid { grid-template-columns: 1fr; }
  .lin-table {
    table-layout: auto;
    width: max-content;
    min-width: 100%;
  }
  .lin-table thead th { min-width: 88px; }
  .lin-cell-input { width: 92px; min-width: 92px; }
}

@media (max-width: 768px) {
  .lin-stat-row {
    grid-template-columns: 1fr 1fr;
    row-gap: 2px;
    padding: 6px 0;
  }
  .lin-chart { height: 280px; }
}
.lin-card { border-radius: 22px; border: 1px solid rgba(226,232,240,.94); box-shadow: 0 16px 34px rgba(15,23,42,.06); }
.lin-chart-panel { border-radius: 18px; box-shadow: inset 0 1px 0 rgba(255,255,255,.72); }
.analysis-report-hero {
  display:flex; align-items:flex-start; justify-content:space-between; gap:18px; padding:24px 26px; margin-bottom:18px;
  border-radius:28px; border:1px solid rgba(191,219,254,.82);
  background:radial-gradient(circle at top right, rgba(224,231,255,.86), transparent 28%), linear-gradient(180deg, rgba(255,255,255,.98), rgba(248,250,252,.96));
  box-shadow:0 24px 60px rgba(15,23,42,.08);
}
.analysis-report-kicker { display:inline-flex; align-items:center; min-height:28px; padding:0 12px; border-radius:999px; background:rgba(37,99,235,.1); color:#2563eb; font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase; }
.analysis-report-title { margin:14px 0 8px; font-size:30px; line-height:1.12; color:#0f172a; }
.analysis-report-desc { margin:0; max-width:760px; color:#64748b; line-height:1.7; }
.analysis-report-badges { display:flex; flex-wrap:wrap; justify-content:flex-end; gap:10px; min-width:240px; }
.analysis-report-badge { display:inline-flex; align-items:center; min-height:38px; padding:0 16px; border-radius:999px; font-size:13px; font-weight:700; border:1px solid rgba(226,232,240,.94); background:rgba(241,245,249,.96); color:#475569; }
.analysis-report-badge.strong { color:#2563eb; background:rgba(219,234,254,.78); border-color:rgba(147,197,253,.9); }
.analysis-report-badge.success { color:#047857; background:rgba(209,250,229,.92); border-color:rgba(110,231,183,.9); }
.analysis-report-badge.warn { color:#b45309; background:rgba(254,243,199,.95); border-color:rgba(252,211,77,.9); }
.analysis-report-badge.primary { color:#4338ca; background:rgba(224,231,255,.92); border-color:rgba(165,180,252,.9); }
@media (max-width: 768px) {
  .analysis-report-hero { flex-direction:column; padding:18px; border-radius:22px; }
  .analysis-report-title { font-size:24px; }
  .analysis-report-badges { justify-content:flex-start; min-width:0; }
}
</style>
