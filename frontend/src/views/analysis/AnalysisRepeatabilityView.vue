<template>
  <div class="repeatability-shell">
    <section class="analysis-report-hero analysis-report-hero-repeat">
      <div>
        <div class="analysis-report-kicker">Repeatability</div>
        <h1 class="analysis-report-title">重复性结果报告页</h1>
        <p class="analysis-report-desc">把样本覆盖、EV、Rbar 与控制图放到统一首屏，让重复性结论更像正式量测分析摘要。</p>
      </div>
      <div class="analysis-report-badges">
        <span class="analysis-report-badge strong">样本 {{ sampleCount }} / {{ requiredCount }}</span>
        <span class="analysis-report-badge" :class="isResultStale ? 'warn' : 'success'">{{ isResultStale ? '结果待刷新' : '结果已同步' }}</span>
        <span class="analysis-report-badge primary">{{ result?.summary || '等待计算' }}</span>
      </div>
    </section>
    <div class="rp-card">
      <div class="rp-card-title">重复性参数</div>
      <div class="rp-form-grid">
        <div class="rp-input-group">
          <label>零件数</label>
          <input v-model="form.partCount" type="number" min="2" max="30" step="1" />
        </div>
        <div class="rp-input-group">
          <label>重复次数</label>
          <input v-model="form.trialCount" type="number" min="2" max="25" step="1" />
        </div>
        <div class="rp-input-group">
          <label>公差（可选）</label>
          <input v-model="form.tolerance" type="number" step="0.001" />
        </div>
      </div>
      <div class="rp-hint">
        每行一个零件，每列一个重复测量值；支持从 Excel 整块粘贴。当前已识别 {{ sampleCount }} / {{ requiredCount }}。
      </div>
      <div v-if="isResultStale" class="rp-stale-banner">
        当前重复性结果已与输入数据不一致，请重新计算后再导出专业报告。
      </div>
      <div class="rp-actions">
        <el-button :loading="calculating" type="primary" @click="calculate">计算重复性</el-button>
        <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
        <el-button @click="clearData">清空数据</el-button>
      </div>
    </div>

    <div class="rp-main-grid">
      <div class="rp-card">
        <div class="rp-title-row">
          <div class="rp-card-title">重复性结果</div>
          <div class="rp-title-actions">
            <el-button :loading="calculating" type="primary" @click="calculate">计算重复性</el-button>
            <el-button :loading="exportingReport" :disabled="!result || isResultStale" @click="exportProfessionalReport">导出专业报告(.xls)</el-button>
          </div>
        </div>
        <div class="rp-stats-grid">
          <template v-if="result">
            <div class="rp-stat-row">
              <span>样本点数</span>
              <b>{{ result.sampleCount }}</b>
              <span>零件/重复</span>
              <b>{{ result.partCount }} / {{ result.trialCount }}</b>
            </div>
            <div class="rp-stat-row">
              <span>R̄</span>
              <b>{{ fmt(result.rbar, 6) }}</b>
              <span>σ(重复性)</span>
              <b>{{ fmt(result.sigmaRepeatability, 6) }}</b>
            </div>
            <div class="rp-stat-row">
              <span>EV (6σ)</span>
              <b :class="toneClass(result.pctTolerance)">{{ fmt(result.ev, 4) }}</b>
              <span>%Tolerance</span>
              <b :class="toneClass(result.pctTolerance)">{{ result.pctTolerance == null ? '-' : fmt(result.pctTolerance, 2) + '%' }}</b>
            </div>
            <div class="rp-stat-row">
              <span>R-UCL/LCL</span>
              <b>{{ fmt(result.rUcl, 4) }} / {{ fmt(result.rLcl, 4) }}</b>
              <span>Xbar-UCL/LCL</span>
              <b>{{ fmt(result.xUcl, 4) }} / {{ fmt(result.xLcl, 4) }}</b>
            </div>
            <div class="rp-stat-row">
              <span>评价</span>
              <b :class="toneClass(result.pctTolerance)">{{ result.summary }}</b>
              <span></span>
              <b></b>
            </div>
          </template>
          <div v-else class="rp-empty-tip">点击“计算重复性”后显示结果</div>
        </div>
      </div>

      <div class="rp-card">
        <div class="rp-sheet-toolbar">
          <span class="rp-sheet-title">重复性录入模板</span>
          <span class="rp-sheet-meta">自动计算均值和极差</span>
        </div>
        <div class="rp-sheet-wrap">
          <table class="rp-table">
            <thead>
              <tr>
                <th class="th-part">零件</th>
                <th v-for="trial in trialCountInt" :key="'trial-' + trial">第{{ trial }}次</th>
                <th class="th-mean">均值</th>
                <th class="th-range">极差</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="partIndex in partCountInt" :key="'part-' + partIndex">
                <td class="td-part">C{{ partIndex }}</td>
                <td v-for="trialIndex in trialCountInt" :key="'cell-' + partIndex + '-' + trialIndex">
                  <input
                    :data-cell="`${partIndex - 1}-${trialIndex - 1}`"
                    v-model="measurements[partIndex - 1][trialIndex - 1]"
                    class="rp-cell-input"
                    type="text"
                    @keydown.enter.prevent="focusNextRow(partIndex - 1, trialIndex - 1)"
                    @paste="handlePaste($event, partIndex - 1, trialIndex - 1)"
                  />
                </td>
                <td class="td-value">{{ fmtCell(partMean(partIndex - 1), 4) }}</td>
                <td class="td-value">{{ fmtCell(partRange(partIndex - 1), 4) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="rp-card rp-charts-card">
        <div class="rp-card-title">图表分析</div>
        <div class="rp-chart-grid">
          <div class="rp-chart-panel">
            <div class="rp-chart-title">R 控制图</div>
            <div ref="rChartRef" class="rp-chart"></div>
          </div>
          <div class="rp-chart-panel">
            <div class="rp-chart-title">Xbar 控制图</div>
            <div ref="xbarChartRef" class="rp-chart"></div>
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

const D2 = { 2: 1.128, 3: 1.693, 4: 2.059, 5: 2.326, 6: 2.534, 7: 2.704, 8: 2.847, 9: 2.97, 10: 3.078, 11: 3.173, 12: 3.258, 13: 3.336, 14: 3.407, 15: 3.472, 16: 3.532, 17: 3.588, 18: 3.64, 19: 3.689, 20: 3.735, 21: 3.778, 22: 3.819, 23: 3.858, 24: 3.895, 25: 3.931 }
const D3 = { 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0.076, 8: 0.136, 9: 0.184, 10: 0.223, 11: 0.256, 12: 0.283, 13: 0.307, 14: 0.328, 15: 0.347, 16: 0.363, 17: 0.378, 18: 0.391, 19: 0.403, 20: 0.415, 21: 0.425, 22: 0.434, 23: 0.443, 24: 0.451, 25: 0.459 }
const D4 = { 2: 3.267, 3: 2.574, 4: 2.282, 5: 2.114, 6: 2.004, 7: 1.924, 8: 1.864, 9: 1.816, 10: 1.777, 11: 1.744, 12: 1.717, 13: 1.693, 14: 1.672, 15: 1.653, 16: 1.637, 17: 1.622, 18: 1.608, 19: 1.597, 20: 1.585, 21: 1.575, 22: 1.566, 23: 1.557, 24: 1.548, 25: 1.541 }
const A2 = { 2: 1.88, 3: 1.023, 4: 0.729, 5: 0.577, 6: 0.483, 7: 0.419, 8: 0.373, 9: 0.337, 10: 0.308, 11: 0.285, 12: 0.266, 13: 0.249, 14: 0.235, 15: 0.223, 16: 0.212, 17: 0.203, 18: 0.194, 19: 0.187, 20: 0.18, 21: 0.173, 22: 0.167, 23: 0.162, 24: 0.157, 25: 0.153 }

const form = reactive({
  partCount: '10',
  trialCount: '3',
  tolerance: ''
})

const measurements = ref([])
const result = ref(null)
const calculating = ref(false)
const exportingReport = ref(false)
const calculatedSignature = ref('')

const rChartRef = ref(null)
const xbarChartRef = ref(null)
let rChart = null
let xbarChart = null

const partCountInt = computed(() => clampInt(form.partCount, 2, 30, 10))
const trialCountInt = computed(() => clampInt(form.trialCount, 2, 25, 3))
const requiredCount = computed(() => partCountInt.value * trialCountInt.value)

watch([partCountInt, trialCountInt], ([parts, trials]) => {
  measurements.value = resizeMatrix(measurements.value, parts, trials)
}, { immediate: true })

const sampleCount = computed(() => measurements.value.flat().filter(v => toFiniteNumber(v) != null).length)
const isResultStale = computed(() =>
  !!result.value
  && !!calculatedSignature.value
  && currentSignature.value !== calculatedSignature.value
)

const currentSignature = computed(() => {
  const tol = toFiniteNumber(form.tolerance)
  return [partCountInt.value, trialCountInt.value, tol == null ? '' : tol, measurements.value.flat().join('|')].join('#')
})

watch(currentSignature, sig => {
  if (result.value && calculatedSignature.value && sig !== calculatedSignature.value) {
    result.value = null
    renderCharts()
  }
})

watch([measurements, result, partCountInt, trialCountInt], async () => {
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
  rChart?.dispose()
  xbarChart?.dispose()
  rChart = null
  xbarChart = null
})

function clampInt(value, min, max, fallback) {
  const n = Number(value)
  if (!Number.isFinite(n)) return fallback
  return Math.min(max, Math.max(min, Math.trunc(n)))
}

function resizeMatrix(oldData, parts, trials) {
  return Array.from({ length: parts }, (_, p) =>
    Array.from({ length: trials }, (_, t) => oldData?.[p]?.[t] ?? '')
  )
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

function range(values) {
  const valid = values.filter(v => v != null)
  if (!valid.length) return null
  return Math.max(...valid) - Math.min(...valid)
}

function partValues(partIndex) {
  return Array.from({ length: trialCountInt.value }, (_, t) => toFiniteNumber(measurements.value?.[partIndex]?.[t]))
}

function partMean(partIndex) {
  return mean(partValues(partIndex))
}

function partRange(partIndex) {
  return range(partValues(partIndex))
}

function nearest(map, key, fallback = 1) {
  if (map[key] != null) return map[key]
  const keys = Object.keys(map).map(Number).sort((a, b) => a - b)
  let best = keys[0]
  for (const k of keys) {
    if (Math.abs(k - key) < Math.abs(best - key)) best = k
  }
  return map[best] ?? fallback
}

function summaryByTolerance(pctTol) {
  if (pctTol == null) return '已完成重复性分析'
  if (pctTol <= 10) return '重复性优秀（≤10%）'
  if (pctTol <= 30) return '重复性可接受（10%~30%）'
  return '重复性偏高（>30%），建议优化量具或方法'
}

function calculate() {
  if (sampleCount.value < requiredCount.value) {
    showToast(`样本不足：${sampleCount.value}/${requiredCount.value}`, 'error')
    return
  }

  calculating.value = true
  try {
    const ranges = []
    const means = []
    for (let p = 0; p < partCountInt.value; p += 1) {
      ranges.push(partRange(p))
      means.push(partMean(p))
    }

    const rbar = mean(ranges)
    const xbarbar = mean(means)
    const d2 = nearest(D2, trialCountInt.value, 1.693)
    const d3 = nearest(D3, trialCountInt.value, 0)
    const d4 = nearest(D4, trialCountInt.value, 2.574)
    const a2 = nearest(A2, trialCountInt.value, 1.023)

    const sigmaRepeatability = (rbar ?? 0) / d2
    const ev = 6 * sigmaRepeatability
    const tolerance = toFiniteNumber(form.tolerance)
    const pctTolerance = tolerance && tolerance > 0 ? (ev / tolerance) * 100 : null

    result.value = {
      sampleCount: requiredCount.value,
      partCount: partCountInt.value,
      trialCount: trialCountInt.value,
      partRanges: ranges,
      partMeans: means,
      rbar,
      sigmaRepeatability,
      ev,
      pctTolerance,
      rUcl: (rbar ?? 0) * d4,
      rLcl: Math.max((rbar ?? 0) * d3, 0),
      xbarbar,
      xUcl: (xbarbar ?? 0) + a2 * (rbar ?? 0),
      xLcl: (xbarbar ?? 0) - a2 * (rbar ?? 0),
      summary: summaryByTolerance(pctTolerance)
    }
    calculatedSignature.value = currentSignature.value
    showToast('重复性计算完成')
  } catch {
    showToast('重复性计算失败，请检查输入', 'error')
  } finally {
    calculating.value = false
  }
}

function buildReportPayload() {
  if (sampleCount.value < requiredCount.value) {
    showToast(`样本不足：${sampleCount.value}/${requiredCount.value}`, 'error')
    return null
  }
  return {
    partCount: partCountInt.value,
    trialCount: trialCountInt.value,
    tolerance: toFiniteNumber(form.tolerance),
    gridValues: measurements.value.map(row => row.map(cell => toFiniteNumber(cell))),
    rawValues: measurements.value.flat().join(',')
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
    const response = await analysisApi.repeatabilityReport(payload)
    const filename = parseFilenameFromDisposition(response?.headers?.['content-disposition'])
      || `重复性_专业报告-${new Date().toISOString().slice(0, 10)}.xls`
    triggerBlobDownload(response.data, filename)
    showToast('重复性专业报告导出成功')
  } catch (error) {
    const message = error?.response?.data?.message || '重复性专业报告导出失败，请稍后重试'
    showToast(message, 'error')
  } finally {
    exportingReport.value = false
  }
}

function clearData() {
  measurements.value = resizeMatrix([], partCountInt.value, trialCountInt.value)
  result.value = null
  calculatedSignature.value = ''
  renderCharts()
}

function focusNextRow(partIndex, trialIndex) {
  const nextPart = partIndex + 1
  if (nextPart >= partCountInt.value) return
  const el = document.querySelector(`[data-cell="${nextPart}-${trialIndex}"]`)
  if (el) el.focus()
}

function handlePaste(event, startPart, startTrial) {
  const text = event.clipboardData?.getData('text')
  if (!text) return
  event.preventDefault()
  const lines = text.replace(/\r/g, '').split('\n').filter(Boolean)
  lines.forEach((line, i) => {
    const p = startPart + i
    if (p >= partCountInt.value) return
    const cells = line.split('\t')
    cells.forEach((cell, j) => {
      const t = startTrial + j
      if (t >= trialCountInt.value) return
      measurements.value[p][t] = cell.trim()
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
  const labels = Array.from({ length: partCountInt.value }, (_, i) => `C${i + 1}`)

  if (!result.value) {
    setNoData(rChart, '暂无数据')
    setNoData(xbarChart, '暂无数据')
    return
  }

  rChart?.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 16, top: 22, bottom: 52, containLabel: true },
    xAxis: { type: 'category', data: labels },
    yAxis: { type: 'value', min: 0, name: '极差' },
    series: [
      { name: 'R', type: 'line', data: result.value.partRanges, symbolSize: 7, lineStyle: { color: '#2563eb', width: 2 } },
      { name: 'R̄', type: 'line', data: labels.map(() => result.value.rbar), symbol: 'none', lineStyle: { color: '#16a34a', type: 'dashed' } },
      { name: 'UCL', type: 'line', data: labels.map(() => result.value.rUcl), symbol: 'none', lineStyle: { color: '#dc2626', type: 'dashed' } },
      { name: 'LCL', type: 'line', data: labels.map(() => result.value.rLcl), symbol: 'none', lineStyle: { color: '#dc2626', type: 'dashed' } }
    ]
  }, true)

  xbarChart?.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 16, top: 22, bottom: 52, containLabel: true },
    xAxis: { type: 'category', data: labels },
    yAxis: { type: 'value', scale: true, name: '均值' },
    series: [
      { name: 'Xbar', type: 'line', data: result.value.partMeans, symbolSize: 7, lineStyle: { color: '#2563eb', width: 2 } },
      { name: 'X̄', type: 'line', data: labels.map(() => result.value.xbarbar), symbol: 'none', lineStyle: { color: '#16a34a', type: 'dashed' } },
      { name: 'UCL', type: 'line', data: labels.map(() => result.value.xUcl), symbol: 'none', lineStyle: { color: '#dc2626', type: 'dashed' } },
      { name: 'LCL', type: 'line', data: labels.map(() => result.value.xLcl), symbol: 'none', lineStyle: { color: '#dc2626', type: 'dashed' } }
    ]
  }, true)
}

function ensureCharts() {
  if (rChartRef.value && !rChart) rChart = echarts.init(rChartRef.value)
  if (xbarChartRef.value && !xbarChart) xbarChart = echarts.init(xbarChartRef.value)
}

function resizeCharts() {
  rChart?.resize()
  xbarChart?.resize()
}
</script>

<style scoped>
.repeatability-shell {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.rp-main-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.rp-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: var(--shadow-xs);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.rp-card-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
  padding: 12px 14px 0;
}

.rp-title-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 8px 12px 0;
}

.rp-title-row .rp-card-title { padding: 0; }

.rp-title-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.rp-form-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  padding: 10px 12px 0;
}

.rp-input-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.rp-input-group label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 700;
}

.rp-input-group input {
  width: 100%;
  min-height: 36px;
}

.rp-hint {
  color: #64748b;
  font-size: 12px;
  line-height: 1.35;
  padding: 10px 12px 0;
}

.rp-stale-banner {
  margin: 10px 12px 0;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid #fed7aa;
  background: #fff7ed;
  color: #c2410c;
  font-size: 13px;
  font-weight: 600;
}

.rp-actions,
.rp-inline-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 12px 12px;
}

.rp-stats-grid {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 10px 12px 12px;
}

.rp-stat-row {
  display: grid;
  grid-template-columns: minmax(96px, 1fr) minmax(88px, 1fr) minmax(96px, 1fr) minmax(88px, 1fr);
  align-items: center;
  min-height: 38px;
  border-bottom: 1px solid #e9eef5;
  font-size: 13px;
  column-gap: 8px;
}

.rp-stat-row span { color: #64748b; }
.rp-stat-row b { color: #0f172a; font-weight: 700; }

.rp-empty-tip {
  color: #94a3b8;
  font-size: 13px;
  padding: 8px 2px 6px;
}

.tone-good { color: #059669 !important; }
.tone-warning { color: #d97706 !important; }
.tone-danger { color: #dc2626 !important; }

.rp-sheet-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 12px 14px 8px;
}

.rp-sheet-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
}

.rp-sheet-meta {
  font-size: 12px;
  color: #64748b;
}

.rp-sheet-wrap {
  overflow: auto;
  padding: 0 10px 10px;
}

.rp-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.rp-table th,
.rp-table td {
  border: 1px solid #2f2f2f;
  height: 38px;
  background: #f6f7f9;
  text-align: center;
}

.rp-table thead th {
  background: #f1f3f6;
  color: #111827;
  font-size: 13px;
  font-weight: 700;
}

.td-part,
.td-value {
  background: #f1f3f6;
  font-weight: 600;
  color: #111827;
}

.rp-cell-input {
  width: 100%;
  height: 30px;
  border: none;
  text-align: center;
  font-size: 13px;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
  color: #1d4ed8;
  background: transparent;
}

.rp-cell-input:focus {
  outline: 2px solid rgba(37, 99, 235, 0.3);
  outline-offset: -2px;
}

.rp-charts-card {
  padding-bottom: 10px;
}

.rp-chart-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  padding: 10px 12px 2px;
}

.rp-chart-panel {
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 8px 8px 6px;
}

.rp-chart-title {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 4px;
}

.rp-chart {
  width: 100%;
  height: 300px;
}

@media (max-width: 1200px) {
  .rp-form-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .rp-chart-grid { grid-template-columns: 1fr; }
  .rp-table {
    table-layout: auto;
    width: max-content;
    min-width: 100%;
  }
  .rp-table thead th { min-width: 72px; }
  .rp-cell-input { width: 92px; min-width: 92px; }
}

@media (max-width: 768px) {
  .rp-stat-row {
    grid-template-columns: 1fr 1fr;
    row-gap: 2px;
    padding: 6px 0;
  }
  .rp-chart { height: 280px; }
}
.rp-card { border-radius: 22px; border: 1px solid rgba(226,232,240,.94); box-shadow: 0 16px 34px rgba(15,23,42,.06); }
.rp-chart-panel { border-radius: 18px; box-shadow: inset 0 1px 0 rgba(255,255,255,.72); }
.analysis-report-hero {
  display:flex; align-items:flex-start; justify-content:space-between; gap:18px; padding:24px 26px; margin-bottom:18px;
  border-radius:28px; border:1px solid rgba(187,247,208,.82);
  background:radial-gradient(circle at top right, rgba(220,252,231,.8), transparent 28%), linear-gradient(180deg, rgba(255,255,255,.98), rgba(248,250,252,.96));
  box-shadow:0 24px 60px rgba(15,23,42,.08);
}
.analysis-report-kicker { display:inline-flex; align-items:center; min-height:28px; padding:0 12px; border-radius:999px; background:rgba(16,185,129,.1); color:#059669; font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase; }
.analysis-report-title { margin:14px 0 8px; font-size:30px; line-height:1.12; color:#0f172a; }
.analysis-report-desc { margin:0; max-width:760px; color:#64748b; line-height:1.7; }
.analysis-report-badges { display:flex; flex-wrap:wrap; justify-content:flex-end; gap:10px; min-width:240px; }
.analysis-report-badge { display:inline-flex; align-items:center; min-height:38px; padding:0 16px; border-radius:999px; font-size:13px; font-weight:700; border:1px solid rgba(226,232,240,.94); background:rgba(241,245,249,.96); color:#475569; }
.analysis-report-badge.strong { color:#2563eb; background:rgba(219,234,254,.78); border-color:rgba(147,197,253,.9); }
.analysis-report-badge.success { color:#047857; background:rgba(209,250,229,.92); border-color:rgba(110,231,183,.9); }
.analysis-report-badge.warn { color:#b45309; background:rgba(254,243,199,.95); border-color:rgba(252,211,77,.9); }
.analysis-report-badge.primary { color:#047857; background:rgba(209,250,229,.92); border-color:rgba(110,231,183,.9); }
@media (max-width: 768px) {
  .analysis-report-hero { flex-direction:column; padding:18px; border-radius:22px; }
  .analysis-report-title { font-size:24px; }
  .analysis-report-badges { justify-content:flex-start; min-width:0; }
}
</style>
