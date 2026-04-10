<template>
  <div class="grr-shell">
    <section class="analysis-report-hero analysis-report-hero-grr">
      <div>
        <div class="analysis-report-kicker">Gauge Study</div>
        <h1 class="analysis-report-title">GRR 量测系统结果总览</h1>
        <p class="analysis-report-desc">把样本覆盖、EV、AV、GRR 与 NDC 集中到首屏，先看结论，再展开均值极差法的明细与图表。</p>
      </div>
      <div class="analysis-report-badges">
        <span class="analysis-report-badge strong">样本 {{ sampleCount }} / {{ requiredSampleCount }}</span>
        <span class="analysis-report-badge" :class="isResultStale ? 'warn' : 'success'">{{ isResultStale ? '结果待刷新' : '结果已同步' }}</span>
        <span class="analysis-report-badge primary">{{ grrResult?.summary || '等待计算' }}</span>
      </div>
    </section>
    <div class="grr-card">
      <div class="grr-card-title">GRR 参数</div>
      <div class="grr-form-grid">
        <div class="grr-input-group">
          <label>操作者数</label>
          <input v-model="form.appraiserCount" type="number" min="2" step="1" />
        </div>
        <div class="grr-input-group">
          <label>零件数</label>
          <input v-model="form.partCount" type="number" min="2" step="1" />
        </div>
        <div class="grr-input-group">
          <label>重复次数</label>
          <input v-model="form.trialCount" type="number" min="2" step="1" />
        </div>
        <div class="grr-input-group">
          <label>公差（可选）</label>
          <input v-model="form.tolerance" type="number" step="0.001" />
        </div>
      </div>
      <div class="grr-hint">
        按模板可直接粘贴 Excel 数据。最少需要 {{ requiredSampleCount }} 个样本值，当前已识别 {{ sampleCount }} 个。
      </div>
      <div v-if="isResultStale" class="grr-stale-banner">
        当前 GRR 结果已与输入数据不一致，请重新计算后再导出完整报告。
      </div>
      <div class="grr-actions">
        <el-button :loading="calculating" type="success" @click="calculateGrr">计算 GRR</el-button>
        <el-button :disabled="!grrResult || isResultStale" @click="exportFullReport">导出完整报告(.xls)</el-button>
        <el-button @click="copyTrialData">复制试验数据</el-button>
        <el-button @click="clearData">清空数据</el-button>
      </div>
    </div>

    <div class="grr-main-grid">
      <div class="grr-left">
        <div class="grr-card">
          <div class="grr-title-row">
            <div class="grr-card-title">GRR 结果（均值极差法）</div>
            <el-button :loading="calculating" type="success" @click="calculateGrr">计算 GRR</el-button>
          </div>
          <div class="grr-stats-grid">
            <template v-if="grrResult">
              <div class="grr-stat-row">
                <span>样本点数</span>
                <b>{{ grrResult.sampleCount }}</b>
                <span>总体均值</span>
                <b>{{ fmt(grrResult.grandMean, 6) }}</b>
              </div>
              <div class="grr-stat-row">
                <span>操作者 / 零件</span>
                <b>{{ grrResult.appraiserCount }} / {{ grrResult.partCount }}</b>
                <span>重复次数</span>
                <b>{{ grrResult.trialCount }}</b>
              </div>
              <div class="grr-stat-row">
                <span>EV (6σ)</span>
                <b>{{ fmt(grrResult.svRepeatability, 4) }}</b>
                <span>AV (6σ)</span>
                <b>{{ fmt(grrResult.svReproducibility, 4) }}</b>
              </div>
              <div class="grr-stat-row">
                <span>GRR (6σ)</span>
                <b :class="grrToneClass(grrResult.pctStudyVarGrr)">{{ fmt(grrResult.svGrr, 4) }}</b>
                <span>PV (6σ)</span>
                <b>{{ fmt(grrResult.svPartToPart, 4) }}</b>
              </div>
              <div class="grr-stat-row">
                <span>%StudyVar EV</span>
                <b>{{ fmt(grrResult.pctStudyVarRepeatability, 2) }}%</b>
                <span>%StudyVar AV</span>
                <b>{{ fmt(grrResult.pctStudyVarReproducibility, 2) }}%</b>
              </div>
              <div class="grr-stat-row">
                <span>%StudyVar GRR</span>
                <b :class="grrToneClass(grrResult.pctStudyVarGrr)">{{ fmt(grrResult.pctStudyVarGrr, 2) }}%</b>
                <span>%StudyVar PV</span>
                <b>{{ fmt(grrResult.pctStudyVarPartToPart, 2) }}%</b>
              </div>
              <div class="grr-stat-row">
                <span>NDC</span>
                <b>{{ fmt(grrResult.ndc, 2) }}</b>
                <span>评价</span>
                <b :class="grrToneClass(grrResult.pctStudyVarGrr)">{{ grrResult.summary || '-' }}</b>
              </div>
            </template>
            <div v-else class="grr-empty-tip">点击“计算 GRR”后显示结果</div>
          </div>
          <div class="grr-inline-actions">
            <el-button :loading="calculating" type="success" @click="calculateGrr">计算 GRR</el-button>
            <el-button :disabled="!grrResult || isResultStale" @click="exportFullReport">导出完整报告(.xls)</el-button>
            <el-button @click="copyTrialData">复制试验数据</el-button>
            <el-button @click="clearData">清空数据</el-button>
          </div>
        </div>
      </div>

      <div class="grr-right">
        <div class="grr-card grr-input-card">
          <div class="grr-sheet-toolbar">
            <span class="grr-sheet-title">GRR 录入模板</span>
            <span class="grr-sheet-meta">支持按模板整块复制粘贴（自动识别试验行）</span>
          </div>
          <div class="grr-sheet-wrap">
            <table class="grr-template-table">
              <thead>
                <tr>
                  <th colspan="2" rowspan="2" class="th-tester">测试人</th>
                  <th :colspan="partCountInt">零件编号及测试记录</th>
                  <th rowspan="2" class="th-mean">均值</th>
                </tr>
                <tr>
                  <th v-for="part in partCountInt" :key="'head-part-' + part">{{ part }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in displayRows" :key="row.key" :class="['row-' + row.type]">
                  <td class="td-serial">{{ row.serialLabel }}</td>
                  <td class="td-marker">{{ row.markerLabel }}</td>
                  <td v-for="partIndex in partCountInt" :key="row.key + '-part-' + partIndex">
                    <input
                      v-if="row.type === 'trial'"
                      :data-cell="`${row.operatorIndex}-${row.trialIndex}-${partIndex - 1}`"
                      v-model="measurements[row.operatorIndex][row.trialIndex][partIndex - 1]"
                      class="grr-cell-input"
                      type="text"
                      @keydown.enter.prevent="focusNextRow(row.operatorIndex, row.trialIndex, partIndex - 1)"
                      @paste="handlePaste($event, row.operatorIndex, row.trialIndex, partIndex - 1)"
                    />
                    <span v-else class="grr-cell-display">{{ fmtCell(rowPartValue(row, partIndex - 1), 3) }}</span>
                  </td>
                  <td :class="['td-mean', row.meanCellClass]">{{ fmtCell(rowMeanValue(row), 4) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="grr-card grr-charts-card">
          <div class="grr-card-title">图表分析（Xbar/R）</div>
          <div class="grr-chart-grid">
            <div class="grr-chart-panel">
              <div class="grr-chart-title">变异分量</div>
              <div ref="variationChartRef" class="grr-chart"></div>
            </div>
            <div class="grr-chart-panel">
              <div class="grr-chart-title">测量数据 × 部件</div>
              <div ref="partChartRef" class="grr-chart"></div>
            </div>
            <div class="grr-chart-panel">
              <div class="grr-chart-title">R 控制图（按操作者）</div>
              <div ref="rControlChartRef" class="grr-chart"></div>
            </div>
            <div class="grr-chart-panel">
              <div class="grr-chart-title">测量数据 × 操作者</div>
              <div ref="operatorChartRef" class="grr-chart"></div>
            </div>
            <div class="grr-chart-panel">
              <div class="grr-chart-title">Xbar 控制图（按操作者）</div>
              <div ref="xbarControlChartRef" class="grr-chart"></div>
            </div>
            <div class="grr-chart-panel">
              <div class="grr-chart-title">部件 × 操作者 交互作用</div>
              <div ref="interactionChartRef" class="grr-chart"></div>
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

const calculating = ref(false)
const grrResult = ref(null)
const measurements = ref([])
const calculatedSignature = ref('')

const variationChartRef = ref(null)
const partChartRef = ref(null)
const rControlChartRef = ref(null)
const operatorChartRef = ref(null)
const xbarControlChartRef = ref(null)
const interactionChartRef = ref(null)

let variationChart = null
let partChart = null
let rControlChart = null
let operatorChart = null
let xbarControlChart = null
let interactionChart = null

const A2_BY_TRIAL = {
  2: 1.88, 3: 1.023, 4: 0.729, 5: 0.577, 6: 0.483, 7: 0.419, 8: 0.373, 9: 0.337, 10: 0.308
}
const D3_BY_TRIAL = {
  2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0.076, 8: 0.136, 9: 0.184, 10: 0.223
}
const D4_BY_TRIAL = {
  2: 3.267, 3: 2.574, 4: 2.282, 5: 2.114, 6: 2.004, 7: 1.924, 8: 1.864, 9: 1.816, 10: 1.777
}

const form = reactive({
  appraiserCount: '3',
  partCount: '10',
  trialCount: '3',
  tolerance: ''
})

const appraiserCountInt = computed(() => parsePositiveInt(form.appraiserCount, 2, 3))
const partCountInt = computed(() => parsePositiveInt(form.partCount, 2, 10))
const trialCountInt = computed(() => parsePositiveInt(form.trialCount, 2, 3))

watch(
  [appraiserCountInt, trialCountInt, partCountInt],
  ([appraiserCount, trialCount, partCount]) => {
    measurements.value = resizeMeasurements(measurements.value, appraiserCount, trialCount, partCount)
  },
  { immediate: true }
)

watch(
  [measurements, grrResult, appraiserCountInt, trialCountInt, partCountInt],
  async () => {
    await nextTick()
    ensureChartsReady()
    renderCharts()
  },
  { deep: true }
)

onMounted(async () => {
  await nextTick()
  ensureChartsReady()
  renderCharts()
  window.addEventListener('resize', resizeCharts)
})

onUnmounted(() => {
  window.removeEventListener('resize', resizeCharts)
  disposeCharts()
})

const requiredSampleCount = computed(() =>
  appraiserCountInt.value * partCountInt.value * trialCountInt.value
)

const sampleCount = computed(() => {
  let count = 0
  measurements.value.forEach(operatorRows => {
    operatorRows.forEach(trialRow => {
      trialRow.forEach(cell => {
        if (toFiniteNumber(cell) != null) count += 1
      })
    })
  })
  return count
})
const isResultStale = computed(() =>
  !!grrResult.value
  && !!calculatedSignature.value
  && currentDataSignature.value !== calculatedSignature.value
)

const currentDataSignature = computed(() => {
  const tolerance = toFiniteNumber(form.tolerance)
  const values = buildOrderedValuesForApi()
  return [
    appraiserCountInt.value,
    partCountInt.value,
    trialCountInt.value,
    tolerance == null ? '' : tolerance,
    values.join(',')
  ].join('|')
})

watch(currentDataSignature, (signature) => {
  if (grrResult.value && calculatedSignature.value && signature !== calculatedSignature.value) {
    grrResult.value = null
  }
})

const displayRows = computed(() => {
  const rows = []
  let serial = 1
  for (let operatorIndex = 0; operatorIndex < appraiserCountInt.value; operatorIndex += 1) {
    for (let trialIndex = 0; trialIndex < trialCountInt.value; trialIndex += 1) {
      rows.push({
        key: `trial-${operatorIndex}-${trialIndex}`,
        type: 'trial',
        operatorIndex,
        trialIndex,
        serialLabel: trialIndex === 0
          ? `${serial}. ${toOperatorLabel(operatorIndex)}`
          : `${serial}.`,
        markerLabel: String(trialIndex + 1),
        meanCellClass: ''
      })
      serial += 1
    }

    rows.push({
      key: `mean-${operatorIndex}`,
      type: 'mean',
      operatorIndex,
      trialIndex: -1,
      serialLabel: `${serial}.`,
      markerLabel: '均值',
      meanCellClass: 'mean-green'
    })
    serial += 1

    rows.push({
      key: `range-${operatorIndex}`,
      type: 'range',
      operatorIndex,
      trialIndex: -1,
      serialLabel: `${serial}.`,
      markerLabel: '极差',
      meanCellClass: 'mean-green'
    })
    serial += 1
  }

  rows.push({
    key: 'part-mean',
    type: 'partMean',
    operatorIndex: -1,
    trialIndex: -1,
    serialLabel: `${serial}.`,
    markerLabel: '零件平均值',
    meanCellClass: 'mean-yellow'
  })
  serial += 1

  rows.push({
    key: 'part-range',
    type: 'partRange',
    operatorIndex: -1,
    trialIndex: -1,
    serialLabel: `${serial}.`,
    markerLabel: '零件极差',
    meanCellClass: 'mean-yellow'
  })

  return rows
})

function parsePositiveInt(value, min = 1, fallback = min) {
  const numeric = Number(value)
  if (!Number.isFinite(numeric)) return fallback
  return Math.max(min, Math.trunc(numeric))
}

function resizeMeasurements(oldData, appraiserCount, trialCount, partCount) {
  return Array.from({ length: appraiserCount }, (_, operatorIndex) =>
    Array.from({ length: trialCount }, (_, trialIndex) =>
      Array.from({ length: partCount }, (_, partIndex) =>
        oldData?.[operatorIndex]?.[trialIndex]?.[partIndex] ?? ''
      )
    )
  )
}

function toFiniteNumber(value) {
  const normalized = String(value ?? '').trim()
  if (!normalized) return null
  const parsed = Number(normalized)
  return Number.isFinite(parsed) ? parsed : null
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

function meanFromNumbers(values) {
  const valid = values.filter(v => v != null)
  if (!valid.length) return null
  return valid.reduce((sum, value) => sum + value, 0) / valid.length
}

function rangeFromNumbers(values) {
  const valid = values.filter(v => v != null)
  if (!valid.length) return null
  return Math.max(...valid) - Math.min(...valid)
}

function getTrialValue(operatorIndex, trialIndex, partIndex) {
  return toFiniteNumber(measurements.value?.[operatorIndex]?.[trialIndex]?.[partIndex])
}

function rowPartValue(row, partIndex) {
  if (row.type === 'trial') {
    return getTrialValue(row.operatorIndex, row.trialIndex, partIndex)
  }
  if (row.type === 'mean') {
    const values = Array.from({ length: trialCountInt.value }, (_, trialIndex) =>
      getTrialValue(row.operatorIndex, trialIndex, partIndex)
    )
    return meanFromNumbers(values)
  }
  if (row.type === 'range') {
    const values = Array.from({ length: trialCountInt.value }, (_, trialIndex) =>
      getTrialValue(row.operatorIndex, trialIndex, partIndex)
    )
    return rangeFromNumbers(values)
  }
  if (row.type === 'partMean') {
    const values = []
    for (let operatorIndex = 0; operatorIndex < appraiserCountInt.value; operatorIndex += 1) {
      for (let trialIndex = 0; trialIndex < trialCountInt.value; trialIndex += 1) {
        values.push(getTrialValue(operatorIndex, trialIndex, partIndex))
      }
    }
    return meanFromNumbers(values)
  }
  if (row.type === 'partRange') {
    const operatorMeans = Array.from({ length: appraiserCountInt.value }, (_, operatorIndex) => {
      const values = Array.from({ length: trialCountInt.value }, (_, trialIndex) =>
        getTrialValue(operatorIndex, trialIndex, partIndex)
      )
      return meanFromNumbers(values)
    })
    return rangeFromNumbers(operatorMeans)
  }
  return null
}

function rowMeanValue(row) {
  if (row.type === 'partRange') {
    const partMeans = Array.from({ length: partCountInt.value }, (_, partIndex) =>
      rowPartValue({ type: 'partMean' }, partIndex)
    )
    return rangeFromNumbers(partMeans)
  }
  const rowValues = Array.from({ length: partCountInt.value }, (_, partIndex) =>
    rowPartValue(row, partIndex)
  )
  return meanFromNumbers(rowValues)
}

function fmt(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return '-'
  return Number(value).toFixed(digits)
}

function fmtCell(value, digits = 3) {
  if (value == null || !Number.isFinite(Number(value))) return ''
  return Number(value).toFixed(digits)
}

function grrToneClass(percentValue) {
  const numeric = Number(percentValue)
  if (!Number.isFinite(numeric)) return ''
  if (numeric <= 10) return 'tone-good'
  if (numeric <= 30) return 'tone-warning'
  return 'tone-danger'
}

function nearestConstant(map, key, fallback = 0) {
  if (map[key] != null) return map[key]
  const keys = Object.keys(map).map(Number).sort((a, b) => a - b)
  if (!keys.length) return fallback
  let nearest = keys[0]
  for (const candidate of keys) {
    if (Math.abs(candidate - key) < Math.abs(nearest - key)) nearest = candidate
  }
  return map[nearest]
}

function roundOrNull(value, digits = 6) {
  if (value == null || !Number.isFinite(value)) return null
  const factor = 10 ** digits
  return Math.round(value * factor) / factor
}

function quantile(sortedValues, q) {
  if (!sortedValues.length) return null
  if (sortedValues.length === 1) return sortedValues[0]
  const pos = (sortedValues.length - 1) * q
  const lower = Math.floor(pos)
  const upper = Math.ceil(pos)
  if (lower === upper) return sortedValues[lower]
  const ratio = pos - lower
  return sortedValues[lower] + (sortedValues[upper] - sortedValues[lower]) * ratio
}

function calculateBox(values) {
  const valid = values
    .map(v => Number(v))
    .filter(v => Number.isFinite(v))
    .sort((a, b) => a - b)
  if (!valid.length) return null
  return [
    valid[0],
    quantile(valid, 0.25),
    quantile(valid, 0.5),
    quantile(valid, 0.75),
    valid[valid.length - 1]
  ]
}

function buildChartDataset() {
  const operatorCount = appraiserCountInt.value
  const partCount = partCountInt.value
  const trialCount = trialCountInt.value

  const operatorLabels = Array.from({ length: operatorCount }, (_, idx) => toOperatorLabel(idx))
  const partLabels = Array.from({ length: partCount }, (_, idx) => `C${idx + 1}`)
  const scatterByPart = Array.from({ length: partCount }, () => [])
  const operatorMeans = Array.from({ length: operatorCount }, () => Array(partCount).fill(null))
  const ranges = []
  const xbars = []
  const allValuesByOperator = Array.from({ length: operatorCount }, () => [])

  for (let operatorIndex = 0; operatorIndex < operatorCount; operatorIndex += 1) {
    for (let partIndex = 0; partIndex < partCount; partIndex += 1) {
      const trialValues = []
      for (let trialIndex = 0; trialIndex < trialCount; trialIndex += 1) {
        const value = getTrialValue(operatorIndex, trialIndex, partIndex)
        if (value != null) {
          trialValues.push(value)
          scatterByPart[partIndex].push(value)
          allValuesByOperator[operatorIndex].push(value)
        }
      }
      const meanValue = meanFromNumbers(trialValues)
      const rangeValue = rangeFromNumbers(trialValues)
      operatorMeans[operatorIndex][partIndex] = meanValue
      if (meanValue != null) {
        xbars.push({
          label: `${operatorLabels[operatorIndex]}-${partLabels[partIndex]}`,
          value: meanValue
        })
      }
      if (rangeValue != null) {
        ranges.push({
          label: `${operatorLabels[operatorIndex]}-${partLabels[partIndex]}`,
          value: rangeValue
        })
      }
    }
  }

  const partMeans = partLabels.map((_, idx) => meanFromNumbers(scatterByPart[idx]))
  const rbarFromData = meanFromNumbers(ranges.map(item => item.value))
  const xbarbar = meanFromNumbers(xbars.map(item => item.value))

  const a2 = nearestConstant(A2_BY_TRIAL, trialCount, 1.023)
  const d3 = nearestConstant(D3_BY_TRIAL, trialCount, 0)
  const d4 = nearestConstant(D4_BY_TRIAL, trialCount, 2.574)

  const rbar = rbarFromData ?? 0

  const rUcl = rbar * d4
  const rLcl = Math.max(rbar * d3, 0)
  const xUcl = (xbarbar ?? 0) + a2 * rbar
  const xLcl = (xbarbar ?? 0) - a2 * rbar

  const variationRows = [
    {
      name: '量具 R&R',
      contribution: grrResult.value?.pctContributionGrr ?? null,
      studyVar: grrResult.value?.pctStudyVarGrr ?? null
    },
    {
      name: '重复性',
      contribution: grrResult.value?.pctContributionRepeatability ?? null,
      studyVar: grrResult.value?.pctStudyVarRepeatability ?? null
    },
    {
      name: '再现性',
      contribution: grrResult.value?.pctContributionReproducibility ?? null,
      studyVar: grrResult.value?.pctStudyVarReproducibility ?? null
    },
    {
      name: '部件间',
      contribution: grrResult.value?.pctContributionPartToPart ?? null,
      studyVar: grrResult.value?.pctStudyVarPartToPart ?? null
    }
  ]

  return {
    operatorLabels,
    partLabels,
    partMeans,
    scatterByPart,
    operatorMeans,
    ranges,
    xbars,
    allValuesByOperator,
    variationRows,
    limits: {
      rbar: roundOrNull(rbar, 6),
      rUcl: roundOrNull(rUcl, 6),
      rLcl: roundOrNull(rLcl, 6),
      xbarbar: roundOrNull(xbarbar, 6),
      xUcl: roundOrNull(xUcl, 6),
      xLcl: roundOrNull(xLcl, 6)
    }
  }
}

function setNoDataOption(chart, title) {
  if (!chart) return
  chart.setOption({
    animation: false,
    title: {
      text: title,
      left: 'center',
      top: '45%',
      textStyle: { color: '#94a3b8', fontSize: 14, fontWeight: 500 }
    },
    xAxis: { show: false },
    yAxis: { show: false },
    series: []
  }, true)
}

function renderVariationChart(dataset) {
  if (!variationChart) return
  const categories = dataset.variationRows.map(row => row.name)
  const contribution = dataset.variationRows.map(row => row.contribution)
  const studyVar = dataset.variationRows.map(row => row.studyVar)
  const hasData = contribution.some(v => v != null) || studyVar.some(v => v != null)
  if (!hasData) {
    setNoDataOption(variationChart, '暂无结果')
    return
  }
  variationChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['%贡献', '%研究变异'], top: 4 },
    grid: { left: 52, right: 16, top: 42, bottom: 40, containLabel: true },
    xAxis: {
      type: 'category',
      data: categories,
      axisLabel: { color: '#334155' }
    },
    yAxis: {
      type: 'value',
      name: '百分比',
      min: 0,
      max: 100,
      axisLabel: { formatter: '{value}%', color: '#334155' }
    },
    series: [
      {
        name: '%贡献',
        type: 'bar',
        data: contribution,
        itemStyle: { color: '#3b82f6', borderRadius: [6, 6, 0, 0] }
      },
      {
        name: '%研究变异',
        type: 'bar',
        data: studyVar,
        itemStyle: { color: '#ef4444', borderRadius: [6, 6, 0, 0] }
      }
    ]
  }, true)
}

function renderPartChart(dataset) {
  if (!partChart) return
  const scatterData = []
  dataset.scatterByPart.forEach((values, idx) => {
    values.forEach(value => {
      scatterData.push([idx, value])
    })
  })
  const hasData = scatterData.length > 0
  if (!hasData) {
    setNoDataOption(partChart, '暂无数据')
    return
  }
  const partLabelRotate = dataset.partLabels.length > 12 ? 40 : 0
  partChart.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 52, right: 14, top: 24, bottom: partLabelRotate ? 54 : 42, containLabel: true },
    xAxis: {
      type: 'category',
      data: dataset.partLabels,
      name: '部件',
      nameGap: 24,
      axisLabel: {
        rotate: partLabelRotate,
        margin: 10,
        hideOverlap: false
      }
    },
    yAxis: { type: 'value', scale: true, axisLabel: { margin: 10 } },
    series: [
      {
        name: '测量点',
        type: 'scatter',
        symbolSize: 8,
        itemStyle: { color: '#94a3b8' },
        data: scatterData
      },
      {
        name: '部件均值',
        type: 'line',
        smooth: false,
        symbolSize: 7,
        itemStyle: { color: '#2563eb' },
        lineStyle: { width: 2, color: '#2563eb' },
        data: dataset.partMeans
      }
    ]
  }, true)
}

function renderRControlChart(dataset) {
  if (!rControlChart) return
  if (!dataset.ranges.length) {
    setNoDataOption(rControlChart, '暂无数据')
    return
  }
  const labels = dataset.ranges.map(item => item.label)
  const values = dataset.ranges.map(item => item.value)
  const { rbar, rUcl, rLcl } = dataset.limits
  rControlChart.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 14, top: 24, bottom: 60, containLabel: true },
    xAxis: {
      type: 'category',
      data: labels,
      axisLabel: { rotate: 35, hideOverlap: false, margin: 10 }
    },
    yAxis: {
      type: 'value',
      min: 0,
      name: '样本极差',
      axisLabel: { margin: 10 }
    },
    series: [
      {
        name: 'R',
        type: 'line',
        data: values,
        symbolSize: 6,
        lineStyle: { color: '#2563eb', width: 2 },
        itemStyle: { color: '#2563eb' }
      },
      {
        name: 'R̄',
        type: 'line',
        data: values.map(() => rbar),
        symbol: 'none',
        lineStyle: { color: '#16a34a', type: 'dashed', width: 1.5 }
      },
      {
        name: 'UCL',
        type: 'line',
        data: values.map(() => rUcl),
        symbol: 'none',
        lineStyle: { color: '#dc2626', type: 'dashed', width: 1.5 }
      },
      {
        name: 'LCL',
        type: 'line',
        data: values.map(() => rLcl),
        symbol: 'none',
        lineStyle: { color: '#dc2626', type: 'dashed', width: 1.5 }
      }
    ]
  }, true)
}

function renderOperatorChart(dataset) {
  if (!operatorChart) return
  const boxData = dataset.allValuesByOperator.map(values => calculateBox(values))
  const meanData = dataset.allValuesByOperator.map(values => meanFromNumbers(values))
  const hasBoxData = boxData.some(Boolean)
  const fallbackMeanData = dataset.operatorMeans.map(row => meanFromNumbers(row))
  const hasFallbackMean = fallbackMeanData.some(v => v != null)

  if (!hasBoxData && !hasFallbackMean) {
    setNoDataOption(operatorChart, '暂无数据')
    return
  }

  const categories = dataset.operatorLabels
  const finalMeanData = meanData.map((v, idx) => (v != null ? v : fallbackMeanData[idx]))

  if (!hasBoxData) {
    operatorChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 50, right: 14, top: 24, bottom: 42, containLabel: true },
      xAxis: {
        type: 'category',
        data: categories,
        name: '操作者',
        nameGap: 24,
        axisLabel: { hideOverlap: false, margin: 10 }
      },
      yAxis: {
        type: 'value',
        scale: true,
        axisLabel: { margin: 10 }
      },
      series: [
        {
          name: '均值',
          type: 'bar',
          data: finalMeanData,
          itemStyle: { color: '#93c5fd', borderColor: '#2563eb' }
        }
      ]
    }, true)
    return
  }

  const normalizedBoxData = boxData.map((box, idx) => {
    if (box) return box
    const m = finalMeanData[idx]
    if (m == null) return [0, 0, 0, 0, 0]
    return [m, m, m, m, m]
  })

  operatorChart.setOption({
    tooltip: { trigger: 'item' },
    grid: { left: 50, right: 14, top: 24, bottom: 42, containLabel: true },
    xAxis: {
      type: 'category',
      data: categories,
      name: '操作者',
      nameGap: 24,
      axisLabel: {
        hideOverlap: false,
        margin: 10
      }
    },
    yAxis: {
      type: 'value',
      scale: true,
      axisLabel: { margin: 10 }
    },
    series: [
      {
        name: '箱线图',
        type: 'boxplot',
        data: normalizedBoxData,
        itemStyle: { color: '#93c5fd', borderColor: '#2563eb' }
      },
      {
        name: '均值',
        type: 'scatter',
        data: finalMeanData,
        symbolSize: 9,
        itemStyle: { color: '#1d4ed8' }
      }
    ]
  }, true)
}

function renderXbarControlChart(dataset) {
  if (!xbarControlChart) return
  if (!dataset.xbars.length) {
    setNoDataOption(xbarControlChart, '暂无数据')
    return
  }
  const labels = dataset.xbars.map(item => item.label)
  const values = dataset.xbars.map(item => item.value)
  const { xbarbar, xUcl, xLcl } = dataset.limits
  xbarControlChart.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 58, right: 14, top: 24, bottom: 60, containLabel: true },
    xAxis: {
      type: 'category',
      data: labels,
      axisLabel: { rotate: 35, hideOverlap: false, margin: 10 }
    },
    yAxis: {
      type: 'value',
      scale: true,
      name: '样本均值',
      axisLabel: { margin: 10 }
    },
    series: [
      {
        name: 'Xbar',
        type: 'line',
        data: values,
        symbolSize: 6,
        lineStyle: { color: '#2563eb', width: 2 },
        itemStyle: { color: '#2563eb' }
      },
      {
        name: 'X̄',
        type: 'line',
        data: values.map(() => xbarbar),
        symbol: 'none',
        lineStyle: { color: '#16a34a', type: 'dashed', width: 1.5 }
      },
      {
        name: 'UCL',
        type: 'line',
        data: values.map(() => xUcl),
        symbol: 'none',
        lineStyle: { color: '#dc2626', type: 'dashed', width: 1.5 }
      },
      {
        name: 'LCL',
        type: 'line',
        data: values.map(() => xLcl),
        symbol: 'none',
        lineStyle: { color: '#dc2626', type: 'dashed', width: 1.5 }
      }
    ]
  }, true)
}

function renderInteractionChart(dataset) {
  if (!interactionChart) return
  const hasData = dataset.operatorMeans.some(row => row.some(v => v != null))
  if (!hasData) {
    setNoDataOption(interactionChart, '暂无数据')
    return
  }
  interactionChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: {
      top: 4,
      right: 8,
      type: 'scroll'
    },
    grid: { left: 54, right: 16, top: 44, bottom: 42, containLabel: true },
    xAxis: {
      type: 'category',
      data: dataset.partLabels,
      name: '部件',
      nameGap: 22,
      axisLabel: {
        hideOverlap: false,
        margin: 10
      }
    },
    yAxis: {
      type: 'value',
      scale: true,
      name: '平均',
      axisLabel: { margin: 10 }
    },
    series: dataset.operatorMeans.map((means, idx) => ({
      name: dataset.operatorLabels[idx],
      type: 'line',
      data: means,
      smooth: false,
      symbolSize: 7
    }))
  }, true)
}

function renderCharts() {
  const dataset = buildChartDataset()
  renderVariationChart(dataset)
  renderPartChart(dataset)
  renderRControlChart(dataset)
  renderOperatorChart(dataset)
  renderXbarControlChart(dataset)
  renderInteractionChart(dataset)
}

function ensureChartsReady() {
  if (variationChartRef.value && !variationChart) variationChart = echarts.init(variationChartRef.value)
  if (partChartRef.value && !partChart) partChart = echarts.init(partChartRef.value)
  if (rControlChartRef.value && !rControlChart) rControlChart = echarts.init(rControlChartRef.value)
  if (operatorChartRef.value && !operatorChart) operatorChart = echarts.init(operatorChartRef.value)
  if (xbarControlChartRef.value && !xbarControlChart) xbarControlChart = echarts.init(xbarControlChartRef.value)
  if (interactionChartRef.value && !interactionChart) interactionChart = echarts.init(interactionChartRef.value)
}

function resizeCharts() {
  variationChart?.resize()
  partChart?.resize()
  rControlChart?.resize()
  operatorChart?.resize()
  xbarControlChart?.resize()
  interactionChart?.resize()
}

function disposeCharts() {
  variationChart?.dispose()
  partChart?.dispose()
  rControlChart?.dispose()
  operatorChart?.dispose()
  xbarControlChart?.dispose()
  interactionChart?.dispose()
  variationChart = null
  partChart = null
  rControlChart = null
  operatorChart = null
  xbarControlChart = null
  interactionChart = null
}

function linearTrialRowIndex(operatorIndex, trialIndex) {
  return operatorIndex * trialCountInt.value + trialIndex
}

function trialCoordinatesByLinearIndex(index) {
  const operatorIndex = Math.floor(index / trialCountInt.value)
  const trialIndex = index % trialCountInt.value
  return { operatorIndex, trialIndex }
}

function focusNextRow(operatorIndex, trialIndex, partIndex) {
  const nextLinear = linearTrialRowIndex(operatorIndex, trialIndex) + 1
  const maxLinear = appraiserCountInt.value * trialCountInt.value
  if (nextLinear >= maxLinear) return
  const next = trialCoordinatesByLinearIndex(nextLinear)
  const el = document.querySelector(`[data-cell="${next.operatorIndex}-${next.trialIndex}-${partIndex}"]`)
  if (el) el.focus()
}

function isTrialMarker(token) {
  const n = Number(String(token ?? '').trim())
  return Number.isInteger(n) && n >= 1 && n <= trialCountInt.value
}

function extractNumbersFromCells(cells) {
  const joined = cells.map(cell => String(cell ?? '')).join('\t')
  const matches = joined.match(/[-+]?(?:\d*\.?\d+|\d+)(?:[eE][-+]?\d+)?/g)
  return matches ?? []
}

function extractTemplateTrialValues(cells) {
  const numericTokens = extractNumbersFromCells(cells)
  if (numericTokens.length < partCountInt.value + 3) return null

  const trialMarker = Number(numericTokens[1])
  if (!isTrialMarker(trialMarker)) return null

  return numericTokens.slice(2, 2 + partCountInt.value)
}

function looksLikeTemplateSummaryRow(cells) {
  const joined = cells.map(cell => String(cell ?? '').trim()).join('|')
  return joined.includes('均值') || joined.includes('极差')
}

function extractMeasurementCells(cells) {
  const templateValues = extractTemplateTrialValues(cells)
  if (templateValues) {
    return templateValues
  }

  const values = cells.map(cell => String(cell ?? '').trim())
  return values.slice(0, partCountInt.value)
}

function normalizePasteLines(lines) {
  const parsed = lines
    .map(line => line.split('\t'))
    .filter(cells => cells.some(cell => String(cell ?? '').trim().length > 0))

  const templateRows = parsed
    .map(cells => extractTemplateTrialValues(cells))
    .filter(values => Array.isArray(values) && values.length > 0)

  if (templateRows.length > 0) {
    return templateRows
  }

  return parsed
    .filter(cells => !looksLikeTemplateSummaryRow(cells))
    .map(cells => extractMeasurementCells(cells))
}

function handlePaste(event, operatorIndex, trialIndex, startCol) {
  const text = event.clipboardData?.getData('text')
  if (!text) return
  event.preventDefault()

  const rawLines = text
    .replace(/\r/g, '')
    .split('\n')
    .filter(line => line.trim().length > 0)
  const lines = normalizePasteLines(rawLines)
  const startLinear = linearTrialRowIndex(operatorIndex, trialIndex)
  const maxLinear = appraiserCountInt.value * trialCountInt.value

  lines.forEach((lineCells, lineOffset) => {
    const targetLinear = startLinear + lineOffset
    if (targetLinear >= maxLinear) return
    const target = trialCoordinatesByLinearIndex(targetLinear)
    lineCells.forEach((cell, cellOffset) => {
      const targetCol = startCol + cellOffset
      if (targetCol >= partCountInt.value) return
      measurements.value[target.operatorIndex][target.trialIndex][targetCol] = cell.trim()
    })
  })
}

function buildOrderedValuesForApi() {
  const values = []
  for (let operatorIndex = 0; operatorIndex < appraiserCountInt.value; operatorIndex += 1) {
    for (let partIndex = 0; partIndex < partCountInt.value; partIndex += 1) {
      for (let trialIndex = 0; trialIndex < trialCountInt.value; trialIndex += 1) {
        const value = getTrialValue(operatorIndex, trialIndex, partIndex)
        if (value != null) values.push(value)
      }
    }
  }
  return values
}

function buildGrrPayload() {
  const values = buildOrderedValuesForApi()
  return {
    values,
    payload: {
      appraiserCount: appraiserCountInt.value,
      partCount: partCountInt.value,
      trialCount: trialCountInt.value,
      tolerance: toFiniteNumber(form.tolerance),
      rawValues: values.join(',')
    }
  }
}

async function copyText(text) {
  if (navigator?.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }
  const el = document.createElement('textarea')
  el.value = text
  document.body.appendChild(el)
  el.select()
  document.execCommand('copy')
  document.body.removeChild(el)
}

async function copyTrialData() {
  const lines = []
  for (let operatorIndex = 0; operatorIndex < appraiserCountInt.value; operatorIndex += 1) {
    for (let trialIndex = 0; trialIndex < trialCountInt.value; trialIndex += 1) {
      const line = Array.from({ length: partCountInt.value }, (_, partIndex) =>
        measurements.value?.[operatorIndex]?.[trialIndex]?.[partIndex] ?? ''
      ).join('\t')
      lines.push(line)
    }
  }
  try {
    await copyText(lines.join('\n'))
    showToast('试验数据已复制，可直接粘贴到 Excel')
  } catch {
    showToast('复制失败，请检查浏览器权限', 'error')
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

function downloadBlob(blob, filename) {
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  window.URL.revokeObjectURL(url)
}

async function parseBlobError(error) {
  const payload = error?.response?.data
  if (!(payload instanceof Blob)) return null
  try {
    const text = await payload.text()
    if (!text) return null
    const json = JSON.parse(text)
    return json?.message || null
  } catch {
    return null
  }
}

async function exportFullReport() {
  const { values, payload } = buildGrrPayload()
  if (values.length < requiredSampleCount.value) {
    showToast(`样本值不足，当前 ${values.length} / 需要 ${requiredSampleCount.value}`, 'error')
    return
  }
  if (!grrResult.value || isResultStale.value) {
    showToast('当前结果与输入不一致，请先重新计算后再导出完整报告', 'error')
    return
  }
  try {
    const response = await analysisApi.grrReport(payload)
    const filename = parseFilenameFromDisposition(response?.headers?.['content-disposition'])
      || `GRR完整报告-${new Date().toISOString().slice(0, 10)}.xls`
    downloadBlob(response.data, filename)
    showToast('完整报告导出成功')
  } catch (error) {
    const message = (await parseBlobError(error))
      || error?.response?.data?.message
      || '完整报告导出失败，请稍后重试'
    showToast(message, 'error')
  }
}

function clearData() {
  measurements.value = resizeMeasurements(
    [],
    appraiserCountInt.value,
    trialCountInt.value,
    partCountInt.value
  )
  grrResult.value = null
  calculatedSignature.value = ''
}

async function calculateGrr() {
  const { values, payload } = buildGrrPayload()
  if (values.length < requiredSampleCount.value) {
    showToast(`样本值不足，当前 ${values.length} / 需要 ${requiredSampleCount.value}`, 'error')
    return
  }

  calculating.value = true
  try {
    const response = await analysisApi.grr(payload)
    calculatedSignature.value = currentDataSignature.value
    grrResult.value = response.data
    showToast(`GRR 计算完成：%StudyVar(GRR) ${fmt(grrResult.value.pctStudyVarGrr, 2)}%，NDC ${fmt(grrResult.value.ndc, 2)}`)
  } catch (error) {
    const message = error?.response?.data?.message || 'GRR 计算失败，请检查输入数据'
    showToast(message, 'error')
  } finally {
    calculating.value = false
  }
}
</script>

<style scoped>
.grr-shell {
  display: flex;
  flex-direction: column;
  gap: 12px;
  height: auto;
  min-height: auto;
  overflow: visible;
}

.grr-main-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 0 0 auto;
  min-height: auto;
  align-items: stretch;
  overflow: visible;
}

.grr-left,
.grr-right {
  display: block;
  width: 100%;
  min-width: 0;
  min-height: auto;
  overflow: visible;
}

.grr-right {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.grr-left .grr-card {
  max-height: none;
}

.grr-right .grr-card {
  min-height: 0;
}

.grr-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
  box-shadow: var(--shadow-xs);
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.grr-charts-card {
  margin-top: 0;
  padding-bottom: 10px;
}

.grr-chart-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  padding: 10px 12px 2px;
}

.grr-chart-panel {
  border: 1px solid #dbe5f2;
  border-radius: 12px;
  background: #f8fbff;
  padding: 8px 8px 6px;
}

.grr-chart-title {
  font-size: 13px;
  font-weight: 700;
  color: #334155;
  margin-bottom: 4px;
  line-height: 1.3;
  white-space: normal;
  word-break: break-word;
}

.grr-chart {
  width: 100%;
  height: 300px;
}

.grr-card-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
  padding: 12px 14px 0;
}

.grr-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 12px 0;
}

.grr-title-row .grr-card-title {
  padding: 0;
}

.grr-form-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  padding: 10px 12px 0;
}

.grr-input-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.grr-input-group label {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 700;
}

.grr-input-group input {
  width: 100%;
  min-height: 36px;
}

.grr-hint {
  color: #64748b;
  font-size: 12px;
  padding: 10px 12px 0;
}

.grr-stale-banner {
  margin: 10px 12px 0;
  padding: 10px 12px;
  border-radius: 12px;
  border: 1px solid #fecaca;
  background: #fff1f2;
  color: #be123c;
  font-size: 13px;
  font-weight: 600;
}

.grr-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 12px 12px;
}

.grr-inline-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 8px 12px 12px;
  border-top: 1px solid #e9eef5;
}

.grr-stats-grid {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 10px 12px 12px;
  flex: 1;
  min-height: 0;
  overflow: auto;
}

.grr-stat-row {
  display: grid;
  grid-template-columns: minmax(96px, 1fr) minmax(88px, 1fr) minmax(96px, 1fr) minmax(88px, 1fr);
  align-items: center;
  border-bottom: 1px solid #e9eef5;
  min-height: 38px;
  font-size: 13px;
  column-gap: 8px;
}

.grr-stat-row span {
  color: #64748b;
  line-height: 1.35;
  white-space: normal;
  word-break: break-word;
}

.grr-stat-row b {
  color: #0f172a;
  font-weight: 700;
  line-height: 1.35;
  white-space: normal;
  word-break: break-word;
}

.grr-empty-tip {
  color: #94a3b8;
  font-size: 13px;
  padding: 8px 2px 6px;
}

.tone-good {
  color: #059669 !important;
}

.tone-warning {
  color: #d97706 !important;
}

.tone-danger {
  color: #dc2626 !important;
}

.grr-sheet-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 10px;
  padding: 12px 14px 8px;
}

.grr-sheet-title {
  font-size: 14px;
  font-weight: 800;
  color: #334155;
}

.grr-sheet-meta {
  font-size: 12px;
  color: #64748b;
  line-height: 1.35;
  white-space: normal;
  text-align: right;
}

.grr-sheet-wrap {
  flex: initial;
  min-height: auto;
  overflow: visible;
  padding: 0 10px 10px;
}

.grr-template-table {
  width: 100%;
  min-width: 0;
  border-collapse: collapse;
  table-layout: fixed;
}

.grr-template-table th,
.grr-template-table td {
  border: 1px solid #2f2f2f;
  height: 40px;
  background: #f6f7f9;
}

.grr-template-table thead th {
  background: #f1f3f6;
  color: #111827;
  font-size: 13px;
  font-weight: 700;
  text-align: center;
}

.th-tester {
  width: 170px;
}

.th-mean {
  width: 84px;
}

.td-serial {
  width: 96px;
  text-align: left;
  padding-left: 8px;
  color: #111827;
  font-weight: 600;
  background: #f1f3f6;
  white-space: nowrap;
}

.td-marker {
  width: 74px;
  text-align: center;
  color: #111827;
  font-weight: 600;
  background: #f1f3f6;
  white-space: nowrap;
}

.grr-cell-input {
  width: 100%;
  min-width: 0;
  height: 32px;
  border: none;
  border-radius: 0;
  text-align: center;
  font-size: 13px;
  line-height: 1;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
  color: #1d4ed8;
  background: transparent;
  padding: 0 2px;
}

.grr-cell-input:focus {
  outline: 2px solid rgba(37, 99, 235, 0.3);
  outline-offset: -2px;
  z-index: 2;
}

.grr-cell-display {
  display: inline-flex;
  width: 100%;
  height: 32px;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  color: #111827;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
}

.td-mean {
  text-align: center;
  color: #111827;
  font-weight: 600;
  background: #f1f3f6;
  font-family: 'Consolas', 'SFMono-Regular', Menlo, monospace;
}

.mean-green {
  background: #d7f5d8;
}

.mean-yellow {
  background: #f5f0ab;
}

@media (max-width: 1200px) {
  .grr-form-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .grr-main-grid {
    display: flex;
    flex-direction: column;
  }

  .grr-chart-grid {
    grid-template-columns: 1fr;
  }

  .grr-right .grr-card,
  .grr-left .grr-card {
    min-height: 0;
    max-height: none;
  }

  .grr-template-table {
    table-layout: auto;
    width: max-content;
    min-width: 100%;
  }

  .grr-template-table thead th {
    min-width: 72px;
  }

  .grr-cell-input {
    width: 92px;
    min-width: 92px;
    font-size: 12px;
  }
}

@media (max-width: 768px) {
  .grr-chart {
    height: 280px;
  }

  .grr-stat-row {
    grid-template-columns: 1fr 1fr;
    row-gap: 2px;
    padding: 6px 0;
  }

  .grr-stat-row span:nth-child(3),
  .grr-stat-row b:nth-child(4) {
    margin-top: 4px;
  }
}
.grr-card { border-radius: 22px; border: 1px solid rgba(226,232,240,.94); box-shadow: 0 16px 34px rgba(15,23,42,.06); }
.grr-chart-panel { border-radius: 18px; box-shadow: inset 0 1px 0 rgba(255,255,255,.72); }
.analysis-report-hero {
  display:flex;
  align-items:flex-start;
  justify-content:space-between;
  gap:18px;
  padding:24px 26px;
  border-radius:28px;
  border:1px solid rgba(191,219,254,.82);
  background:radial-gradient(circle at top right, rgba(219,234,254,.82), transparent 28%), linear-gradient(180deg, rgba(255,255,255,.98), rgba(248,250,252,.96));
  box-shadow:0 24px 60px rgba(15,23,42,.08);
}
.analysis-report-hero-grr { margin-bottom: 18px; }
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
