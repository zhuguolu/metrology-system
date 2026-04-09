<template>
  <div class="dashboard-shell">
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon blue">
          <el-icon size="22" color="#2563eb"><Tools /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">设备总数</div>
          <div class="stat-value">{{ stats.total }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange">
          <el-icon size="22" color="#d97706"><Calendar /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">本月待校准</div>
          <div class="stat-value orange">{{ stats.dueThisMonth }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon green">
          <el-icon size="22" color="#059669"><CircleCheck /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">有效设备</div>
          <div class="stat-value green">{{ stats.valid }}</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon red">
          <el-icon size="22" color="#dc2626"><Warning /></el-icon>
        </div>
        <div class="stat-body">
          <div class="stat-label">失效/即将过期</div>
          <div class="stat-value red">{{ (stats.expired||0) + (stats.warning||0) }}</div>
        </div>
      </div>
    </div>

    <div class="charts-row">
      <div class="chart-card">
        <div class="chart-header dashboard-card-header">
          <div class="chart-title">校准趋势（近6个月）</div>
          <span class="tag tag-blue" style="font-size:12px">月度统计</span>
        </div>
        <div ref="barChartRef" class="dashboard-chart dashboard-chart-bar"></div>
      </div>

      <div class="chart-card">
        <div class="chart-header dashboard-card-header">
          <div class="chart-title">设备有效性分布</div>
        </div>
        <div ref="pieChartRef" class="dashboard-chart dashboard-chart-pie"></div>
      </div>
    </div>

    <!-- 快速概览 -->
    <div class="chart-card" style="margin-bottom:20px">
      <div class="chart-header"><div class="chart-title">快速概览</div></div>
      <div class="overview-grid" style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px">
        <div style="text-align:center;padding:20px;background:linear-gradient(135deg,#eff6ff,#dbeafe);border-radius:12px;border:1px solid #bfdbfe">
          <div style="font-size:12px;color:#1e40af;font-weight:600;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.05em">校准完成率</div>
          <div style="font-size:32px;font-weight:800;color:#1d4ed8">{{ completionRate }}%</div>
        </div>
        <div style="text-align:center;padding:20px;background:linear-gradient(135deg,#fffbeb,#fef3c7);border-radius:12px;border:1px solid #fde68a">
          <div style="font-size:12px;color:#92400e;font-weight:600;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.05em">即将过期设备</div>
          <div style="font-size:32px;font-weight:800;color:#d97706">{{ stats.warning }}</div>
        </div>
        <div style="text-align:center;padding:20px;background:linear-gradient(135deg,#fff1f2,#fee2e2);border-radius:12px;border:1px solid #fecaca">
          <div style="font-size:12px;color:#991b1b;font-weight:600;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.05em">总失效设备</div>
          <div style="font-size:32px;font-weight:800;color:#dc2626">{{ stats.expired }}</div>
        </div>
      </div>
    </div>

    <!-- 部门分析 -->
    <div class="chart-card" v-if="stats.deptStats && stats.deptStats.length">
      <div class="chart-header dashboard-card-header">
        <div class="chart-title">{{ authStore.isAdmin ? '部门设备统计' : '本部门设备统计' }}</div>
        <span class="tag tag-blue" style="font-size:12px">按部门</span>
      </div>
      <div class="dept-mobile-list">
        <div v-for="d in stats.deptStats" :key="d.dept + '-mobile'" class="dept-mobile-card">
          <div class="dept-mobile-head">
            <div class="dept-mobile-name">{{ d.dept }}</div>
            <span class="tag tag-blue">总数 {{ d.total }}</span>
          </div>
          <div class="dept-mobile-tags">
            <span class="tag tag-valid">有效 {{ d.valid }}</span>
            <span class="tag tag-warning">预警 {{ d.warning }}</span>
            <span class="tag tag-expired">失效 {{ d.expired }}</span>
          </div>
          <div class="dept-mobile-progress">
            <div class="dept-mobile-progress-bar">
              <div class="dept-mobile-progress-fill" :style="{ width: deptValidPct(d) + '%' }"></div>
            </div>
            <span class="dept-mobile-progress-text">有效占比 {{ deptValidPct(d) }}%</span>
          </div>
        </div>
      </div>
      <div class="dept-table-wrap">
        <table style="width:100%;border-collapse:collapse;min-width:480px">
          <thead>
            <tr style="background:#f8fafc">
              <th style="padding:10px 14px;text-align:left;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">部门</th>
              <th style="padding:10px 14px;text-align:center;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">总数</th>
              <th style="padding:10px 14px;text-align:center;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">有效</th>
              <th style="padding:10px 14px;text-align:center;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">即将过期</th>
              <th style="padding:10px 14px;text-align:center;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">失效</th>
              <th style="padding:10px 14px;text-align:left;font-size:12px;color:#64748b;font-weight:700;border-bottom:1px solid #e2e8f0;text-transform:uppercase;letter-spacing:0.04em">有效占比</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in stats.deptStats" :key="d.dept" style="border-bottom:1px solid #f1f5f9" class="hover-row">
              <td style="padding:12px 14px;font-weight:600;font-size:13.5px">{{ d.dept }}</td>
              <td style="padding:12px 14px;text-align:center;font-weight:700;color:#1e293b;font-size:16px">{{ d.total }}</td>
              <td style="padding:12px 14px;text-align:center"><span class="tag tag-valid">{{ d.valid }}</span></td>
              <td style="padding:12px 14px;text-align:center"><span class="tag tag-warning">{{ d.warning }}</span></td>
              <td style="padding:12px 14px;text-align:center"><span class="tag tag-expired">{{ d.expired }}</span></td>
              <td style="padding:12px 14px;min-width:140px">
                <div style="display:flex;align-items:center;gap:8px">
                  <div style="flex:1;height:7px;background:#f1f5f9;border-radius:4px;overflow:hidden">
                    <div style="height:100%;background:linear-gradient(90deg,#059669,#10b981);border-radius:4px;transition:width 0.6s ease" :style="{ width: deptValidPct(d) + '%' }"></div>
                  </div>
                  <span style="font-size:12px;color:#64748b;white-space:nowrap;font-weight:600;min-width:34px">{{ deptValidPct(d) }}%</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { deviceApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const authStore = useAuthStore()
const stats = ref({ total:0, dueThisMonth:0, expired:0, warning:0, valid:0, monthlyTrend:[], deptStats:[] })
const isMobile = ref(false)
const dashboardCache = useViewCache('dashboard', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('dashboard-view')

const barChartRef = ref(null)
const pieChartRef = ref(null)
let barChart = null
let pieChart = null

const completionRate = computed(() => {
  const normalTotal = (stats.value.valid || 0) + (stats.value.warning || 0) + (stats.value.expired || 0)
  if (!normalTotal) return 0
  return Math.round(((stats.value.valid || 0) / normalTotal) * 100)
})

function deptValidPct(d) {
  if (!d.total) return 0
  return Math.round((d.valid / d.total) * 100)
}

function syncViewport() {
  isMobile.value = window.innerWidth <= 768
}

function initBarChart() {
  if (!barChartRef.value) return
  if (barChart) barChart.dispose()
  barChart = echarts.init(barChartRef.value)
  const trend = stats.value.monthlyTrend || []
  const months = trend.map(m => {
    const parts = m.month.split('-')
    return parts[1] ? parts[1] + '月' : m.month
  })
  const counts = trend.map(m => m.count)
  barChart.setOption({
    grid: { top: 20, right: 16, bottom: 30, left: 40 },
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: '{b}: {c} 台'
    },
    xAxis: {
      type: 'category',
      data: months,
      axisLine: { lineStyle: { color: '#e2e8f0' } },
      axisTick: { show: false },
      axisLabel: { color: '#94a3b8', fontSize: 12, fontWeight: 600 }
    },
    yAxis: {
      type: 'value',
      splitLine: { lineStyle: { color: '#f1f5f9', type: 'dashed' } },
      axisLabel: { color: '#94a3b8', fontSize: 12 },
      minInterval: 1
    },
    series: [{
      type: 'bar',
      data: counts,
      barMaxWidth: 40,
      itemStyle: {
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: '#3b82f6' },
          { offset: 1, color: '#1d4ed8' }
        ]),
        borderRadius: [6, 6, 0, 0]
      },
      label: {
        show: true,
        position: 'top',
        color: '#2563eb',
        fontSize: 11,
        fontWeight: 600
      }
    }]
  })
}

function initPieChart() {
  if (!pieChartRef.value) return
  if (pieChart) pieChart.dispose()
  pieChart = echarts.init(pieChartRef.value)
  const total = stats.value.total || 1
  pieChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} 台 ({d}%)'
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'middle',
      itemWidth: 10,
      itemHeight: 10,
      borderRadius: 5,
      textStyle: { color: '#64748b', fontSize: 12 }
    },
    series: [{
      type: 'pie',
      radius: ['45%', '70%'],
      center: ['38%', '50%'],
      avoidLabelOverlap: false,
      label: { show: false },
      emphasis: {
        label: { show: true, fontSize: 14, fontWeight: 700 }
      },
      data: [
        { value: stats.value.valid || 0, name: '有效', itemStyle: { color: '#059669' } },
        { value: stats.value.warning || 0, name: '即将过期', itemStyle: { color: '#d97706' } },
        { value: stats.value.expired || 0, name: '失效', itemStyle: { color: '#dc2626' } }
      ]
    }]
  })
}

function handleResize() {
  syncViewport()
  barChart?.resize()
  pieChart?.resize()
}

async function loadDashboard() {
  try {
    const res = await deviceApi.dashboard()
    stats.value = res.data
    dashboardCache.save({ stats: stats.value })
    await nextTick()
    initBarChart()
    initPieChart()
  } catch(e) { console.error(e) }
}

useResumeRefresh(loadDashboard)

onMounted(async () => {
  syncViewport()
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

.dashboard-card-header {
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.dashboard-chart {
  width: 100%;
  height: 220px;
}

.dept-table-wrap {
  overflow-x: auto;
}

.dept-mobile-list {
  display: none;
}

.dept-mobile-card {
  background: linear-gradient(180deg, #ffffff, #f8fbff);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 14px;
  box-shadow: var(--shadow-xs);
}

.dept-mobile-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
}

.dept-mobile-name {
  font-size: 15px;
  font-weight: 700;
  color: var(--text);
}

.dept-mobile-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
}

.dept-mobile-progress {
  display: flex;
  align-items: center;
  gap: 10px;
}

.dept-mobile-progress-bar {
  flex: 1;
  height: 8px;
  background: #e2e8f0;
  border-radius: 999px;
  overflow: hidden;
}

.dept-mobile-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #059669, #10b981);
  border-radius: 999px;
}

.dept-mobile-progress-text {
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
  font-weight: 600;
}

.hover-row:hover td { background: #f8fbff; transition: background 0.15s; }

@media (max-width: 768px) {
  .dashboard-shell {
    gap: 14px;
  }

  .dashboard-chart {
    height: 210px;
  }

  .dashboard-card-header {
    align-items: flex-start;
  }

  .dept-table-wrap {
    display: none;
  }

  .dept-mobile-list {
    display: grid;
    gap: 10px;
  }
}
</style>
