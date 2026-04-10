<template>
  <div class="dashboard-shell">
    <section class="dashboard-hero">
      <div class="dashboard-hero-copy">
        <span class="dashboard-eyebrow">Overview Board</span>
        <h2 class="dashboard-headline">计量数据总览</h2>
        <p class="dashboard-subtitle">设备状态、校准趋势与部门分布集中展示，适合快速巡检和管理层查看。</p>
      </div>

      <div class="dashboard-hero-metrics">
        <div class="dashboard-hero-card dashboard-hero-card-primary">
          <span class="dashboard-hero-card-label">校准完成率</span>
          <strong>{{ completionRate }}%</strong>
          <span class="dashboard-hero-card-meta">有效设备占全部受控设备</span>
        </div>
        <div class="dashboard-hero-card dashboard-hero-card-warning">
          <span class="dashboard-hero-card-label">即将到期</span>
          <strong>{{ stats.warning || 0 }}</strong>
          <span class="dashboard-hero-card-meta">需要优先安排校准</span>
        </div>
        <div class="dashboard-hero-card dashboard-hero-card-danger">
          <span class="dashboard-hero-card-label">失效设备</span>
          <strong>{{ stats.expired || 0 }}</strong>
          <span class="dashboard-hero-card-meta">建议立即复核或停用</span>
        </div>
      </div>
    </section>

    <div class="stats-grid dashboard-stats-grid">
      <article v-for="card in summaryCards" :key="card.key" class="stat-card dashboard-stat-card">
        <div class="stat-icon" :class="card.iconClass">
          <el-icon size="22" :color="card.iconColor"><component :is="card.icon" /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">{{ card.label }}</div>
          <div class="stat-value" :class="card.valueClass">{{ card.value }}</div>
          <div class="dashboard-stat-meta">{{ card.meta }}</div>
        </div>
      </article>
    </div>

    <div class="charts-row dashboard-charts-row">
      <section class="chart-card dashboard-panel">
        <div class="chart-header dashboard-card-header">
          <div>
            <div class="chart-title">校准趋势（近 6 个月）</div>
            <div class="dashboard-panel-subtitle">按月展示完成校准数量</div>
          </div>
          <span class="tag tag-blue dashboard-chip">月度统计</span>
        </div>
        <div ref="barChartRef" class="dashboard-chart dashboard-chart-bar"></div>
      </section>

      <section class="chart-card dashboard-panel">
        <div class="chart-header dashboard-card-header">
          <div>
            <div class="chart-title">设备有效性分布</div>
            <div class="dashboard-panel-subtitle">查看有效、预警、失效占比</div>
          </div>
          <div class="dashboard-distribution-legend">
            <span class="dashboard-legend-item"><i class="dot valid"></i>有效</span>
            <span class="dashboard-legend-item"><i class="dot warning"></i>即将到期</span>
            <span class="dashboard-legend-item"><i class="dot danger"></i>失效</span>
          </div>
        </div>
        <div ref="pieChartRef" class="dashboard-chart dashboard-chart-pie"></div>
      </section>
    </div>

    <section v-if="stats.deptStats && stats.deptStats.length" class="chart-card dashboard-panel dashboard-dept-panel">
      <div class="chart-header dashboard-card-header">
        <div>
          <div class="chart-title">{{ authStore.isAdmin ? '部门设备统计' : '本部门设备统计' }}</div>
          <div class="dashboard-panel-subtitle">聚焦各部门设备总量与有效占比</div>
        </div>
        <span class="tag tag-blue dashboard-chip">按部门</span>
      </div>

      <div class="dept-mobile-list">
        <article v-for="d in stats.deptStats" :key="`${d.dept}-mobile`" class="dept-mobile-card">
          <div class="dept-mobile-head">
            <div>
              <div class="dept-mobile-name">{{ d.dept }}</div>
              <div class="dept-mobile-subtitle">有效占比 {{ deptValidPct(d) }}%</div>
            </div>
            <span class="tag tag-blue">总数 {{ d.total }}</span>
          </div>
          <div class="dept-mobile-tags">
            <span class="tag tag-valid">有效 {{ d.valid }}</span>
            <span class="tag tag-warning">预警 {{ d.warning }}</span>
            <span class="tag tag-expired">失效 {{ d.expired }}</span>
          </div>
          <div class="dept-mobile-progress">
            <div class="dept-mobile-progress-bar">
              <div class="dept-mobile-progress-fill" :style="{ width: `${deptValidPct(d)}%` }"></div>
            </div>
            <span class="dept-mobile-progress-text">{{ deptValidPct(d) }}%</span>
          </div>
        </article>
      </div>

      <div class="dept-grid">
        <article v-for="d in stats.deptStats" :key="d.dept" class="dept-card">
          <div class="dept-card-head">
            <div>
              <h3 class="dept-card-title">{{ d.dept }}</h3>
              <p class="dept-card-subtitle">有效占比 {{ deptValidPct(d) }}%</p>
            </div>
            <span class="tag tag-blue">总数 {{ d.total }}</span>
          </div>

          <div class="dept-card-tags">
            <span class="tag tag-valid">有效 {{ d.valid }}</span>
            <span class="tag tag-warning">预警 {{ d.warning }}</span>
            <span class="tag tag-expired">失效 {{ d.expired }}</span>
          </div>

          <div class="dept-card-progress">
            <div class="dept-card-progress-bar">
              <div class="dept-card-progress-fill" :style="{ width: `${deptValidPct(d)}%` }"></div>
            </div>
            <span class="dept-card-progress-value">{{ deptValidPct(d) }}%</span>
          </div>
        </article>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { Calendar, CircleCheck, Tools, Warning } from '@element-plus/icons-vue'
import { deviceApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const authStore = useAuthStore()
const stats = ref({ total: 0, dueThisMonth: 0, expired: 0, warning: 0, valid: 0, monthlyTrend: [], deptStats: [] })
const dashboardCache = useViewCache('dashboard', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('dashboard-view')

const barChartRef = ref(null)
const pieChartRef = ref(null)
let barChart = null
let pieChart = null

const completionRate = computed(() => {
  const controlledTotal = (stats.value.valid || 0) + (stats.value.warning || 0) + (stats.value.expired || 0)
  if (!controlledTotal) return 0
  return Math.round(((stats.value.valid || 0) / controlledTotal) * 100)
})

const summaryCards = computed(() => ([
  {
    key: 'total',
    label: '设备总数',
    value: stats.value.total || 0,
    meta: '当前纳入台账的全部设备',
    icon: Tools,
    iconClass: 'blue',
    iconColor: '#2563eb',
    valueClass: ''
  },
  {
    key: 'due',
    label: '本月待校准',
    value: stats.value.dueThisMonth || 0,
    meta: '建议优先安排校准计划',
    icon: Calendar,
    iconClass: 'orange',
    iconColor: '#d97706',
    valueClass: 'orange'
  },
  {
    key: 'valid',
    label: '有效设备',
    value: stats.value.valid || 0,
    meta: '状态正常，可继续使用',
    icon: CircleCheck,
    iconClass: 'green',
    iconColor: '#059669',
    valueClass: 'green'
  },
  {
    key: 'risk',
    label: '失效 / 即将到期',
    value: (stats.value.expired || 0) + (stats.value.warning || 0),
    meta: '建议及时跟进处理',
    icon: Warning,
    iconClass: 'red',
    iconColor: '#dc2626',
    valueClass: 'red'
  }
]))

function deptValidPct(dept) {
  if (!dept?.total) return 0
  return Math.round(((dept.valid || 0) / dept.total) * 100)
}

function initBarChart() {
  if (!barChartRef.value) return
  if (barChart) barChart.dispose()
  barChart = echarts.init(barChartRef.value)
  const trend = stats.value.monthlyTrend || []
  const months = trend.map(item => {
    const parts = String(item.month || '').split('-')
    return parts[1] ? `${parts[1]}月` : String(item.month || '-')
  })
  const counts = trend.map(item => item.count || 0)

  barChart.setOption({
    grid: { top: 24, right: 18, bottom: 32, left: 42 },
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: params => {
        const item = params?.[0]
        return item ? `${item.axisValue}：${item.value} 台` : ''
      }
    },
    xAxis: {
      type: 'category',
      data: months,
      axisLine: { lineStyle: { color: '#d6e0f3' } },
      axisTick: { show: false },
      axisLabel: { color: '#6b7b93', fontSize: 12, fontWeight: 600 }
    },
    yAxis: {
      type: 'value',
      splitLine: { lineStyle: { color: '#e7edf7', type: 'dashed' } },
      axisLabel: { color: '#94a3b8', fontSize: 12 },
      minInterval: 1
    },
    series: [{
      type: 'bar',
      data: counts,
      barMaxWidth: 42,
      itemStyle: {
        borderRadius: [12, 12, 6, 6],
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: '#5aa2ff' },
          { offset: 0.55, color: '#3979ff' },
          { offset: 1, color: '#1e4ed8' }
        ]),
        shadowColor: 'rgba(37, 99, 235, 0.22)',
        shadowBlur: 14,
        shadowOffsetY: 8
      },
      label: {
        show: true,
        position: 'top',
        color: '#2563eb',
        fontSize: 12,
        fontWeight: 700
      }
    }]
  })
}

function initPieChart() {
  if (!pieChartRef.value) return
  if (pieChart) pieChart.dispose()
  pieChart = echarts.init(pieChartRef.value)

  pieChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}：{c} 台（{d}%）'
    },
    legend: {
      show: false
    },
    series: [{
      type: 'pie',
      radius: ['54%', '74%'],
      center: ['50%', '54%'],
      padAngle: 2,
      itemStyle: {
        borderColor: '#ffffff',
        borderWidth: 6
      },
      label: {
        show: true,
        position: 'center',
        formatter: [`{count|${stats.value.total || 0}}`, '{label|设备总数}'].join('\n'),
        rich: {
          count: {
            fontSize: 28,
            fontWeight: 800,
            color: '#0f172a',
            lineHeight: 34
          },
          label: {
            fontSize: 12,
            color: '#64748b',
            fontWeight: 600,
            lineHeight: 18
          }
        }
      },
      emphasis: {
        scale: true,
        scaleSize: 6
      },
      data: [
        { value: stats.value.valid || 0, name: '有效', itemStyle: { color: '#12b981' } },
        { value: stats.value.warning || 0, name: '即将到期', itemStyle: { color: '#f59e0b' } },
        { value: stats.value.expired || 0, name: '失效', itemStyle: { color: '#ef4444' } }
      ]
    }]
  })
}

function handleResize() {
  barChart?.resize()
  pieChart?.resize()
}

async function loadDashboard() {
  try {
    const response = await deviceApi.dashboard()
    stats.value = response.data || stats.value
    dashboardCache.save({ stats: stats.value })
    await nextTick()
    initBarChart()
    initPieChart()
  } catch (error) {
    console.error('Failed to load dashboard:', error)
  }
}

useResumeRefresh(loadDashboard)

onMounted(async () => {
  const cached = dashboardCache.restore()
  if (cached?.stats) {
    stats.value = cached.stats
    await nextTick()
    initBarChart()
    initPieChart()
  }
  await loadDashboard()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  barChart?.dispose()
  pieChart?.dispose()
})
</script>

<style scoped>
.dashboard-shell {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.dashboard-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr);
  gap: 18px;
  padding: 24px;
  border-radius: 28px;
  border: 1px solid rgba(191, 219, 254, 0.9);
  background:
    radial-gradient(circle at top left, rgba(186, 230, 253, 0.7), transparent 34%),
    radial-gradient(circle at top right, rgba(196, 181, 253, 0.28), transparent 26%),
    linear-gradient(135deg, rgba(255,255,255,0.98), rgba(248,250,252,0.94));
  box-shadow: 0 22px 52px rgba(15, 23, 42, 0.08);
}

.dashboard-hero-copy {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.dashboard-eyebrow {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  padding: 6px 12px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.08);
  color: #1d4ed8;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.dashboard-headline {
  margin-top: 14px;
  font-size: 32px;
  line-height: 1.1;
  letter-spacing: -0.04em;
  color: #0f172a;
}

.dashboard-subtitle {
  margin-top: 10px;
  max-width: 560px;
  font-size: 14px;
  line-height: 1.75;
  color: #5b6b83;
}

.dashboard-hero-metrics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.dashboard-hero-card {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 16px;
  min-height: 148px;
  padding: 16px;
  border-radius: 22px;
  border: 1px solid rgba(255,255,255,0.65);
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.45);
}

.dashboard-hero-card strong {
  font-size: 34px;
  line-height: 1;
  font-weight: 800;
  letter-spacing: -0.04em;
}

.dashboard-hero-card-label {
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.dashboard-hero-card-meta {
  font-size: 12px;
  line-height: 1.5;
  color: #64748b;
}

.dashboard-hero-card-primary {
  background: linear-gradient(180deg, rgba(239, 246, 255, 0.96), rgba(219, 234, 254, 0.8));
}
.dashboard-hero-card-primary strong,
.dashboard-hero-card-primary .dashboard-hero-card-label { color: #1d4ed8; }

.dashboard-hero-card-warning {
  background: linear-gradient(180deg, rgba(255, 251, 235, 0.96), rgba(254, 240, 138, 0.46));
}
.dashboard-hero-card-warning strong,
.dashboard-hero-card-warning .dashboard-hero-card-label { color: #b45309; }

.dashboard-hero-card-danger {
  background: linear-gradient(180deg, rgba(255, 241, 242, 0.96), rgba(254, 202, 202, 0.52));
}
.dashboard-hero-card-danger strong,
.dashboard-hero-card-danger .dashboard-hero-card-label { color: #dc2626; }

.dashboard-stats-grid {
  margin-bottom: 0;
}

.dashboard-stat-card {
  min-height: 154px;
  border-radius: 22px;
  padding: 20px 22px;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  box-shadow: 0 16px 36px rgba(15, 23, 42, 0.06);
}

.dashboard-stat-meta {
  margin-top: 12px;
  font-size: 12px;
  color: #64748b;
}

.dashboard-charts-row {
  grid-template-columns: minmax(0, 1.25fr) minmax(340px, 0.95fr);
}

.dashboard-panel {
  border-radius: 24px;
  padding: 22px;
  border: 1px solid rgba(226, 232, 240, 0.92);
  background:
    radial-gradient(circle at top right, rgba(239, 246, 255, 0.72), transparent 28%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  box-shadow: 0 18px 38px rgba(15, 23, 42, 0.06);
}

.dashboard-card-header {
  align-items: flex-start;
  gap: 14px;
  flex-wrap: wrap;
}

.dashboard-panel-subtitle {
  margin-top: 4px;
  font-size: 12.5px;
  color: #64748b;
}

.dashboard-chip {
  font-size: 12px;
  padding-inline: 12px;
}

.dashboard-chart {
  width: 100%;
  height: 260px;
}

.dashboard-distribution-legend {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px 10px;
}

.dashboard-legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(248, 250, 252, 0.96);
  border: 1px solid #e2e8f0;
  color: #475569;
  font-size: 12px;
  font-weight: 700;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
}

.dot.valid { background: #12b981; }
.dot.warning { background: #f59e0b; }
.dot.danger { background: #ef4444; }

.dashboard-dept-panel {
  padding-bottom: 24px;
}

.dept-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.dept-card,
.dept-mobile-card {
  border-radius: 20px;
  border: 1px solid rgba(226, 232, 240, 0.92);
  background: linear-gradient(180deg, #ffffff, #f8fbff);
  box-shadow: 0 14px 30px rgba(15, 23, 42, 0.05);
}

.dept-card {
  padding: 18px;
}

.dept-card-head,
.dept-mobile-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.dept-card-title,
.dept-mobile-name {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
}

.dept-card-subtitle,
.dept-mobile-subtitle {
  margin-top: 6px;
  font-size: 12px;
  color: #64748b;
}

.dept-card-tags,
.dept-mobile-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 16px;
}

.dept-card-progress,
.dept-mobile-progress {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 18px;
}

.dept-card-progress-bar,
.dept-mobile-progress-bar {
  flex: 1;
  height: 10px;
  background: #e2e8f0;
  border-radius: 999px;
  overflow: hidden;
}

.dept-card-progress-fill,
.dept-mobile-progress-fill {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #12b981, #10b981);
}

.dept-card-progress-value,
.dept-mobile-progress-text {
  min-width: 42px;
  text-align: right;
  font-size: 12px;
  color: #64748b;
  font-weight: 700;
}

.dept-mobile-list {
  display: none;
}

@media (max-width: 1180px) {
  .dashboard-hero {
    grid-template-columns: 1fr;
  }

  .dashboard-hero-metrics {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .dashboard-charts-row {
    grid-template-columns: 1fr;
  }

  .dept-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .dashboard-shell {
    gap: 14px;
  }

  .dashboard-hero {
    padding: 18px;
    border-radius: 24px;
  }

  .dashboard-headline {
    font-size: 26px;
  }

  .dashboard-subtitle {
    font-size: 13px;
  }

  .dashboard-hero-metrics {
    grid-template-columns: 1fr;
  }

  .dashboard-hero-card {
    min-height: auto;
  }

  .dashboard-stat-card {
    min-height: 138px;
    padding: 16px 18px;
  }

  .dashboard-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .dashboard-chart {
    height: 224px;
  }

  .dashboard-distribution-legend {
    justify-content: flex-start;
  }

  .dept-grid {
    display: none;
  }

  .dept-mobile-list {
    display: grid;
    gap: 12px;
  }
}
</style>
