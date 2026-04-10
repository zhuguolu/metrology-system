<template>
  <div class="analysis-shell">
    <section class="analysis-header-card analysis-hero-card">
      <div class="analysis-header-title-wrap">
        <span class="analysis-eyebrow">Analysis Center</span>
        <div class="analysis-header-title">数据分析工作台</div>
        <div class="analysis-header-subtitle">
          将能力分析、GRR、重复性、再现性与线性分析统一收纳，适合做正式结果查看与报告输出。
        </div>
      </div>

      <div class="analysis-submodule-tabs">
        <router-link
          to="/analysis/cpk"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/cpk') ? 'active' : '']"
        >
          <span class="analysis-tab-main">CPK / PPK</span>
          <span class="analysis-tab-sub">过程能力</span>
        </router-link>
        <router-link
          to="/analysis/grr"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/grr') ? 'active' : '']"
        >
          <span class="analysis-tab-main">GRR</span>
          <span class="analysis-tab-sub">量具分析</span>
        </router-link>
        <router-link
          to="/analysis/repeatability"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/repeatability') ? 'active' : '']"
        >
          <span class="analysis-tab-main">重复性</span>
          <span class="analysis-tab-sub">设备内波动</span>
        </router-link>
        <router-link
          to="/analysis/reproducibility"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/reproducibility') ? 'active' : '']"
        >
          <span class="analysis-tab-main">再现性</span>
          <span class="analysis-tab-sub">人员间波动</span>
        </router-link>
        <router-link
          to="/analysis/linearity"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/linearity') ? 'active' : '']"
        >
          <span class="analysis-tab-main">线性分析</span>
          <span class="analysis-tab-sub">量程一致性</span>
        </router-link>
      </div>
    </section>

    <div class="analysis-body">
      <router-view />
    </div>
  </div>
</template>

<script setup>
import { useRoute } from 'vue-router'

const route = useRoute()

function isSubmoduleActive(path) {
  return route.path === path
}
</script>

<style scoped>
.analysis-shell {
  display: flex;
  flex-direction: column;
  gap: 14px;
  height: 100%;
  min-height: 0;
}

.analysis-hero-card {
  position: relative;
  overflow: hidden;
  border-radius: 26px;
  padding: 22px 22px 20px;
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.72), transparent 28%),
    radial-gradient(circle at top left, rgba(224, 231, 255, 0.6), transparent 30%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
}

.analysis-hero-card::after {
  content: '';
  position: absolute;
  inset: auto 20px 0;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(59,130,246,0.28), transparent);
}

.analysis-header-title-wrap {
  margin-bottom: 16px;
}

.analysis-eyebrow {
  display: inline-flex;
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

.analysis-header-title {
  margin-top: 12px;
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.03em;
  color: #0f172a;
}

.analysis-header-subtitle {
  margin-top: 8px;
  max-width: 780px;
  color: #64748b;
  font-size: 13px;
  line-height: 1.7;
}

.analysis-submodule-tabs {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
}

.analysis-submodule-tab {
  text-decoration: none;
  border: 1px solid rgba(191, 219, 254, 0.96);
  border-radius: 20px;
  background: rgba(255,255,255,0.92);
  color: #1f4fd1;
  padding: 14px 14px 12px;
  transition: all 0.2s ease;
  display: flex;
  flex-direction: column;
  gap: 4px;
  box-shadow: 0 10px 24px rgba(59, 130, 246, 0.06);
}

.analysis-submodule-tab:hover {
  border-color: #93c5fd;
  background: linear-gradient(180deg, #ffffff, #f4f9ff);
  transform: translateY(-2px);
  box-shadow: 0 14px 30px rgba(59, 130, 246, 0.12);
}

.analysis-submodule-tab.active {
  background: linear-gradient(135deg, #3a86ff, #2a67f5);
  border-color: #2b67f3;
  color: #ffffff;
  box-shadow: 0 14px 28px rgba(58, 134, 255, 0.26);
}

.analysis-tab-main {
  font-size: 14px;
  font-weight: 800;
}

.analysis-tab-sub {
  font-size: 12px;
  color: inherit;
  opacity: 0.72;
}

.analysis-body {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.analysis-body :deep(.analysis-main-grid),
.analysis-body :deep(.grr-shell),
.analysis-body :deep(.repeatability-shell),
.analysis-body :deep(.repro-shell),
.analysis-body :deep(.linearity-shell) {
  flex: 1;
  min-height: 0;
}

@media (max-width: 1120px) {
  .analysis-submodule-tabs {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 768px) {
  .analysis-hero-card {
    border-radius: 22px;
    padding: 18px;
  }

  .analysis-header-title {
    font-size: 20px;
  }

  .analysis-submodule-tabs {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .analysis-submodule-tabs {
    grid-template-columns: 1fr;
  }
}
</style>
