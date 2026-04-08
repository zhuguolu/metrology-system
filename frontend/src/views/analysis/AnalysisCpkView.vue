<template>
  <div class="analysis-shell">
    <div class="analysis-card">
      <div class="analysis-card-title">CPK/PPK 参数</div>
      <div class="analysis-form-grid">
        <div class="analysis-input-group">
          <label>LSL</label>
          <input v-model="form.lsl" type="number" step="0.001" />
        </div>
        <div class="analysis-input-group">
          <label>USL</label>
          <input v-model="form.usl" type="number" step="0.001" />
        </div>
        <div class="analysis-input-group">
          <label>目标值</label>
          <input v-model="form.target" type="number" step="0.001" />
        </div>
        <div class="analysis-input-group">
          <label>子组大小</label>
          <input v-model="form.subgroupSize" type="number" min="2" max="25" step="1" />
        </div>
        <div class="analysis-input-group">
          <label>分箱数</label>
          <input v-model="form.bins" type="number" min="5" max="30" step="1" />
        </div>
      </div>
      <div class="analysis-hint">
        支持按表格整块复制粘贴样本数据，当前已识别 {{ sampleCount }} 个数值。
      </div>
    </div>

    <div class="analysis-main-grid">
      <div class="analysis-left">
        <div class="analysis-card">
          <div class="analysis-title-row">
            <div class="analysis-card-title">能力指标</div>
            <el-button :loading="calculating" type="primary" @click="calculate">计算 CPK/PPK</el-button>
          </div>
          <div class="analysis-stats-grid">
            <template v-if="result">
              <div class="analysis-stat-row">
                <span>总样本数</span>
                <b>{{ result.sampleCount }}</b>
                <span>子组大小</span>
                <b>{{ result.subgroupSize }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>图表类型</span>
                <b>{{ result.chartType }}</b>
                <span>组数</span>
                <b>{{ result.groupCount }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>平均值</span>
                <b>{{ fmt(result.mean, 6) }}</b>
                <span>目标值</span>
                <b>{{ fmt(result.target, 3) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>最小值</span>
                <b>{{ fmt(result.min, 3) }}</b>
                <span>最大值</span>
                <b>{{ fmt(result.max, 3) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>组内标准差</span>
                <b>{{ fmt(result.sigmaWithin, 6) }}</b>
                <span>整体标准差</span>
                <b>{{ fmt(result.sigmaOverall, 6) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>CPK</span>
                <b :class="toneClass(result.cpk)">{{ fmt(result.cpk, 4) }}</b>
                <span>CP</span>
                <b :class="toneClass(result.cp)">{{ fmt(result.cp, 4) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>CPL</span>
                <b>{{ fmt(result.cpl, 4) }}</b>
                <span>CPU</span>
                <b>{{ fmt(result.cpu, 4) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>PPK</span>
                <b :class="toneClass(result.ppk)">{{ fmt(result.ppk, 4) }}</b>
                <span>PP</span>
                <b :class="toneClass(result.pp)">{{ fmt(result.pp, 4) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>PPL</span>
                <b>{{ fmt(result.ppl, 4) }}</b>
                <span>PPU</span>
                <b>{{ fmt(result.ppu, 4) }}</b>
              </div>
              <div class="analysis-stat-row">
                <span>能力评级</span>
                <b :class="toneClass(result.cpk)">{{ result.summary || '-' }}</b>
                <span>PPM Total</span>
                <b>{{ fmt(result.observedPpmTotal, 2) }}</b>
              </div>
            </template>
            <div v-else class="analysis-empty-tip">点击“计算 CPK/PPK”后显示结果</div>
          </div>
          <div class="analysis-inline-actions">
            <el-button :loading="calculating" type="primary" @click="calculate">计算 CPK/PPK</el-button>
            <el-button :loading="exportingReport" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
            <el-button @click="clearData">清空数据</el-button>
            <el-button @click="exportCharts">导出图表</el-button>
          </div>
        </div>
      </div>

      <div class="analysis-right">
        <div class="analysis-card">
          <div class="analysis-sheet-toolbar">
            <span class="analysis-sheet-title">样本录入表</span>
            <span class="analysis-sheet-meta">已识别 {{ sampleCount }} 个数值</span>
          </div>
          <div class="analysis-sheet-wrap">
            <table class="analysis-sheet-table">
              <thead>
                <tr>
                  <th class="analysis-sheet-corner"></th>
                  <th v-for="(_, cIndex) in cols" :key="'head-' + cIndex">
                    {{ columnLabel(cIndex) }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(_, rIndex) in rows" :key="'row-' + rIndex">
                  <th>{{ rIndex + 1 }}</th>
                  <td v-for="(_, cIndex) in cols" :key="'cell-' + rIndex + '-' + cIndex">
                    <input
                      :data-cell="`${rIndex}-${cIndex}`"
                      v-model="grid[rIndex][cIndex]"
                      class="analysis-cell-input"
                      type="text"
                      @keydown.enter.prevent="focusNextRow(rIndex, cIndex)"
                      @paste="handlePaste($event, rIndex, cIndex)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="analysis-card analysis-charts-card">
          <div class="analysis-card-title">图表分析</div>
          <div class="analysis-chart-grid">
            <div class="analysis-chart-panel">
              <div class="analysis-chart-title">运行图</div>
              <div ref="runChartRef" class="analysis-chart"></div>
            </div>
            <div class="analysis-chart-panel">
              <div class="analysis-chart-title">直方图</div>
              <div ref="histogramRef" class="analysis-chart"></div>
            </div>
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
const histogramRef = ref(null)
const runChartRef = ref(null)
let histogramChart = null
let runChart = null

const rows = 15
const cols = 22
const grid = ref(createEmptyGrid(rows, cols))
const calculating = ref(false)
const exportingReport = ref(false)
const result = ref(null)
const calculatedSignature = ref('')

const form = reactive({
  lsl: '38',
  usl: '58',
  target: '48',
  subgroupSize: '3',
  bins: '8'
})

const sampleCount = computed(() =>
  grid.value.reduce(
    (acc, row) => acc + row.reduce((inner, cell) => inner + (toFiniteNumber(cell) != null ? 1 : 0), 0),
    0
  )
)

const currentDataSignature = computed(() => {
  const values = buildGridPayload().flat().map(v => (v == null ? '' : v))
  return [
    toFiniteNumber(form.lsl) ?? '',
    toFiniteNumber(form.usl) ?? '',
    toFiniteNumber(form.target) ?? '',
    toIntOrNull(form.subgroupSize) ?? '',
    toIntOrNull(form.bins) ?? '',
    values.join(',')
  ].join('|')
})

watch(currentDataSignature, (signature) => {
  if (result.value && calculatedSignature.value && signature !== calculatedSignature.value) {
    result.value = null
    renderCharts()
  }
})

function createEmptyGrid(rowCount, colCount) {
  return Array.from({ length: rowCount }, () => Array.from({ length: colCount }, () => ''))
}

function columnLabel(index) {
  let n = index + 1
  let label = ''
  while (n > 0) {
    const mod = (n - 1) % 26
    label = String.fromCharCode(65 + mod) + label
    n = Math.floor((n - 1) / 26)
  }
  return label
}

function toFiniteNumber(value) {
  const normalized = String(value ?? '').trim()
  if (!normalized) return null
  const parsed = Number(normalized)
  return Number.isFinite(parsed) ? parsed : null
}

function toIntOrNull(value) {
  const numeric = toFiniteNumber(value)
  if (numeric == null) return null
  return Math.trunc(numeric)
}

function buildGridPayload() {
  return grid.value.map(row => row.map(cell => toFiniteNumber(cell)))
}

function focusNextRow(rowIndex, colIndex) {
  const nextRow = rowIndex + 1
  if (nextRow >= rows) return
  const el = document.querySelector(`[data-cell="${nextRow}-${colIndex}"]`)
  if (el) el.focus()
}

function handlePaste(event, startRow, startCol) {
  const text = event.clipboardData?.getData('text')
  if (!text) return
  event.preventDefault()
  const lines = text.replace(/\r/g, '').split('\n').filter(line => line.length > 0)
  lines.forEach((line, lineIndex) => {
    const targetRow = startRow + lineIndex
    if (targetRow >= rows) return
    const cells = line.split('\t')
    cells.forEach((cell, cellIndex) => {
      const targetCol = startCol + cellIndex
      if (targetCol >= cols) return
      grid.value[targetRow][targetCol] = cell.trim()
    })
  })
}

function clearData() {
  grid.value = createEmptyGrid(rows, cols)
  result.value = null
  calculatedSignature.value = ''
  renderCharts()
}

function fmt(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return '-'
  return Number(value).toFixed(digits)
}

function toneClass(value) {
  const numeric = Number(value)
  if (!Number.isFinite(numeric)) return ''
  if (numeric >= 1.33) return 'tone-good'
  if (numeric >= 1.0) return 'tone-warning'
  return 'tone-danger'
}

function normalPdf(x, mean, sigma) {
  if (!Number.isFinite(sigma) || sigma <= 0) return 0
  const a = 1 / (sigma * Math.sqrt(2 * Math.PI))
  const z = (x - mean) / sigma
  return a * Math.exp(-0.5 * z * z)
}

function chartPalette(index, total) {
  const ratio = total <= 1 ? 0.5 : index / (total - 1)
  if (ratio <= 0.15) return '#c62828'
  if (ratio <= 0.35) return '#ef6c00'
  if (ratio <= 0.6) return '#9cae2f'
  if (ratio <= 0.82) return '#f5d009'
  return '#2a6f7a'
}

function buildHistogramOption(data) {
  if (!data?.histogram?.length) {
    return {
      title: {
        text: '暂无数据',
        left: 'center',
        top: 'middle',
        textStyle: { color: '#94a3b8', fontSize: 14, fontWeight: 500 }
      }
    }
  }

  const histogram = data.histogram
  const binWidth = Math.max((histogram[0]?.upper ?? 0) - (histogram[0]?.lower ?? 0), 0.0001)
  const maxCount = Math.max(...histogram.map(item => item.count))
  const xMin = Math.min(data.lsl, data.min, data.minus3Sigma) - binWidth
  const xMax = Math.max(data.usl, data.max, data.plus3Sigma) + binWidth
  const pointCount = 80
  const overallCurve = []
  const withinCurve = []

  for (let i = 0; i <= pointCount; i += 1) {
    const x = xMin + ((xMax - xMin) * i) / pointCount
    overallCurve.push([x, normalPdf(x, data.mean, data.sigmaOverall) * data.sampleCount * binWidth])
    withinCurve.push([x, normalPdf(x, data.mean, data.sigmaWithin) * data.sampleCount * binWidth])
  }

  return {
    grid: { top: 30, right: 16, left: 46, bottom: 42, containLabel: true },
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'cross' }
    },
    legend: {
      bottom: 0,
      icon: 'circle',
      textStyle: { color: '#64748b', fontSize: 12 },
      data: ['整体', '组内']
    },
    xAxis: {
      type: 'value',
      min: xMin,
      max: xMax,
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisLabel: { color: '#64748b', formatter: value => Number(value).toFixed(2), margin: 10 },
      splitLine: { lineStyle: { color: '#e2e8f0', type: 'dashed' } }
    },
    yAxis: {
      type: 'value',
      max: value => Math.max(maxCount + 4, value.max + 1),
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisLabel: { color: '#64748b', margin: 10 },
      splitLine: { lineStyle: { color: '#eef2f7', type: 'dashed' } }
    },
    series: [
      {
        name: '直方图',
        type: 'bar',
        barWidth: 18,
        data: histogram.map((item, index) => ({
          value: [item.center, item.count],
          count: item.count,
          range: `${item.lower.toFixed(2)} ~ ${item.upper.toFixed(2)}`,
          itemStyle: { color: chartPalette(index, histogram.length) }
        })),
        markLine: {
          symbol: 'none',
          lineStyle: { type: 'dashed', width: 1.2 },
          label: { fontSize: 11, color: '#334155' },
          data: [
            { xAxis: data.lsl, name: `LSL=${data.lsl}` },
            { xAxis: data.usl, name: `USL=${data.usl}` },
            { xAxis: data.mean, name: data.mean.toFixed(2), lineStyle: { color: '#ef4444', type: 'solid' } }
          ]
        }
      },
      {
        name: '整体',
        type: 'line',
        showSymbol: false,
        smooth: true,
        lineStyle: { color: '#111827', width: 1.6 },
        data: overallCurve
      },
      {
        name: '组内',
        type: 'line',
        showSymbol: false,
        smooth: true,
        lineStyle: { color: '#ef4444', width: 1.4 },
        data: withinCurve
      }
    ]
  }
}

function buildRunChartOption(data) {
  if (!data?.values?.length) {
    return {
      title: {
        text: '暂无数据',
        left: 'center',
        top: 'middle',
        textStyle: { color: '#94a3b8', fontSize: 14, fontWeight: 500 }
      }
    }
  }

  const xData = data.values.map((_, index) => index + 1)
  return {
    grid: { top: 26, right: 16, left: 46, bottom: 38, containLabel: true },
    tooltip: { trigger: 'axis', axisPointer: { type: 'line' } },
    xAxis: {
      type: 'category',
      data: xData,
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisTick: { show: false },
      axisLabel: { color: '#64748b', margin: 10 }
    },
    yAxis: {
      type: 'value',
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisLabel: { color: '#64748b', margin: 10 },
      splitLine: { lineStyle: { color: '#eef2f7', type: 'dashed' } }
    },
    series: [
      {
        type: 'line',
        data: data.values,
        smooth: false,
        symbol: 'circle',
        symbolSize: 5,
        lineStyle: { color: '#3b82f6', width: 1.5 },
        itemStyle: { color: '#2563eb' },
        markLine: {
          symbol: 'none',
          label: { position: 'end', fontSize: 11 },
          lineStyle: { type: 'solid', width: 1.2 },
          data: [
            { yAxis: data.usl, name: `USL=${data.usl}`, lineStyle: { color: '#ef4444' }, label: { color: '#ef4444' } },
            { yAxis: data.target, name: `Target=${data.target}`, lineStyle: { color: '#16a34a', type: 'dashed' }, label: { color: '#16a34a' } },
            { yAxis: data.lsl, name: `LSL=${data.lsl}`, lineStyle: { color: '#ef4444' }, label: { color: '#ef4444' } }
          ]
        }
      }
    ]
  }
}

function renderCharts() {
  if (histogramChart) histogramChart.setOption(buildHistogramOption(result.value), true)
  if (runChart) runChart.setOption(buildRunChartOption(result.value), true)
}

function resizeCharts() {
  histogramChart?.resize()
  runChart?.resize()
}

async function calculate() {
  const payload = buildCapabilityPayload()
  if (!payload) return

  calculating.value = true
  try {
    const response = await analysisApi.capability(payload)
    calculatedSignature.value = currentDataSignature.value
    result.value = response.data
    await nextTick()
    renderCharts()
    showToast(`计算完成：CPK ${fmt(result.value.cpk, 4)}，PPK ${fmt(result.value.ppk, 4)}`)
  } catch (error) {
    const message = error?.response?.data?.message || '计算失败，请检查输入数据'
    showToast(message, 'error')
  } finally {
    calculating.value = false
  }
}

function buildCapabilityPayload() {
  const lsl = toFiniteNumber(form.lsl)
  const usl = toFiniteNumber(form.usl)
  if (lsl == null || usl == null) {
    showToast('请先输入有效的 LSL / USL', 'error')
    return null
  }
  return {
    lsl,
    usl,
    target: toFiniteNumber(form.target),
    subgroupSize: toIntOrNull(form.subgroupSize),
    bins: toIntOrNull(form.bins),
    gridValues: buildGridPayload()
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
  const payload = buildCapabilityPayload()
  if (!payload) return

  exportingReport.value = true
  try {
    const response = await analysisApi.capabilityReport(payload)
    const filename = parseFilenameFromDisposition(response?.headers?.['content-disposition'])
      || `CPK_PPK_专业报告-${new Date().toISOString().slice(0, 10)}.xls`
    triggerBlobDownload(response.data, filename)
    showToast('专业报告导出成功')
  } catch (error) {
    const message = error?.response?.data?.message || '专业报告导出失败，请稍后重试'
    showToast(message, 'error')
  } finally {
    exportingReport.value = false
  }
}

function downloadDataUrl(filename, dataUrl) {
  const a = document.createElement('a')
  a.href = dataUrl
  a.download = filename
  a.click()
}

function exportCharts() {
  if (!histogramChart || !runChart) {
    showToast('图表尚未初始化', 'error')
    return
  }
  if (!result.value) {
    showToast('请先计算 CPK/PPK 后再导出', 'error')
    return
  }

  const runPng = runChart.getDataURL({ type: 'png', pixelRatio: 2, backgroundColor: '#ffffff' })
  const histPng = histogramChart.getDataURL({ type: 'png', pixelRatio: 2, backgroundColor: '#ffffff' })
  downloadDataUrl('数据分析-运行图.png', runPng)
  downloadDataUrl('数据分析-直方图.png', histPng)
  showToast('图表导出成功')
}

onMounted(() => {
  histogramChart = echarts.init(histogramRef.value)
  runChart = echarts.init(runChartRef.value)
  renderCharts()
  window.addEventListener('resize', resizeCharts)
})

onUnmounted(() => {
  window.removeEventListener('resize', resizeCharts)
  histogramChart?.dispose()
  runChart?.dispose()
  histogramChart = null
  runChart = null
})
</script>

<style scoped>
.analysis-shell {
  display: flex;
  flex-direction: column;
  gap: 12px;
  height: auto;
  min-height: auto;
  overflow: visible;
}

.analysis-main-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: auto;
  align-items: stretch;
  overflow: visible;
}

.analysis-left,
.analysis-right {
  display: block;
  width: 100%;
  min-width: 0;
  min-height: auto;
  overflow: visible;
}

.analysis-right {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.analysis-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: var(--shadow-xs);
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.analysis-card-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
  padding: 12px 14px 0;
}

.analysis-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 12px 0;
}

.analysis-title-row .analysis-card-title {
  padding: 0;
}

.analysis-form-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
  padding: 10px 12px 0;
}

.analysis-input-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.analysis-input-group label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.analysis-input-group input {
  width: 100%;
  min-height: 36px;
}

.analysis-hint {
  color: #64748b;
  font-size: 12px;
  line-height: 1.35;
  padding: 10px 12px 0;
}

.analysis-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 12px 12px;
}

.analysis-inline-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 8px 12px 12px;
  border-top: 1px solid #e9eef5;
}

.analysis-stats-grid {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 10px 12px 12px;
  flex: 1;
  min-height: 0;
  overflow: auto;
}

.analysis-stat-row {
  display: grid;
  grid-template-columns: minmax(96px, 1fr) minmax(88px, 1fr) minmax(96px, 1fr) minmax(88px, 1fr);
  align-items: center;
  border-bottom: 1px solid #e9eef5;
  min-height: 38px;
  font-size: 13px;
  column-gap: 8px;
}

.analysis-stat-row span {
  color: #64748b;
  line-height: 1.35;
  white-space: normal;
  word-break: break-word;
}

.analysis-stat-row b {
  color: #0f172a;
  font-weight: 700;
  line-height: 1.35;
  white-space: normal;
  word-break: break-word;
}

.analysis-empty-tip {
  color: #94a3b8;
  font-size: 13px;
  padding: 8px 2px 6px;
}

.analysis-stat-row .tone-good {
  color: #059669;
}

.analysis-stat-row .tone-warning {
  color: #d97706;
}

.analysis-stat-row .tone-danger {
  color: #dc2626;
}

.analysis-sheet-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 10px;
  padding: 12px 14px 8px;
}

.analysis-sheet-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
}

.analysis-sheet-meta {
  font-size: 12px;
  color: #64748b;
  line-height: 1.35;
  white-space: normal;
  text-align: right;
}

.analysis-sheet-wrap {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 0 10px 10px;
}

.analysis-sheet-table {
  border-collapse: collapse;
  width: 100%;
  min-width: 0;
  table-layout: fixed;
}

.analysis-sheet-table th,
.analysis-sheet-table td {
  border: 1px solid #dbe3ef;
}

.analysis-sheet-table thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background: #f8fafc;
  color: #475569;
  font-size: 11px;
  font-weight: 700;
  min-width: 0;
  text-align: center;
  height: 30px;
}

.analysis-sheet-table tbody th {
  position: sticky;
  left: 0;
  z-index: 1;
  background: #f8fafc;
  color: #475569;
  font-size: 12px;
  font-weight: 700;
  width: 34px;
  min-width: 34px;
  text-align: center;
}

.analysis-sheet-corner {
  left: 0;
  z-index: 3 !important;
  width: 34px !important;
  min-width: 34px !important;
}

.analysis-cell-input {
  width: 100%;
  min-width: 0;
  height: 28px;
  border: none;
  border-radius: 0;
  text-align: center;
  font-size: 12px;
  background: #fff;
  padding: 0 2px;
}

.analysis-cell-input:focus {
  outline: 2px solid rgba(37, 99, 235, 0.3);
  outline-offset: -2px;
  z-index: 2;
}

.analysis-charts-card {
  padding-bottom: 10px;
}

.analysis-chart-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  padding: 10px 12px 2px;
}

.analysis-chart-panel {
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 8px 8px 6px;
}

.analysis-chart-title {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 4px;
  line-height: 1.3;
  white-space: normal;
  word-break: break-word;
}

.analysis-chart {
  width: 100%;
  height: 300px;
}

@media (max-width: 1200px) {
  .analysis-form-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .analysis-chart-grid {
    grid-template-columns: 1fr;
  }

  .analysis-sheet-table {
    table-layout: auto;
    width: max-content;
    min-width: 100%;
  }

  .analysis-sheet-table thead th {
    min-width: 48px;
    font-size: 12px;
  }

  .analysis-cell-input {
    width: 48px;
    min-width: 48px;
    font-size: 13px;
    padding: 0 4px;
  }
}

@media (max-width: 768px) {
  .analysis-form-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
  }

  .analysis-stat-row {
    grid-template-columns: 1fr 1fr;
    row-gap: 2px;
    padding: 6px 0;
  }

  .analysis-stat-row span:nth-child(3),
  .analysis-stat-row b:nth-child(4) {
    margin-top: 4px;
  }

  .analysis-chart {
    height: 280px;
  }

  .analysis-cell-input {
    width: 52px;
  }
}
</style>
