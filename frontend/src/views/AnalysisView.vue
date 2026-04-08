<template>
  <div class="analysis-shell">
    <div class="analysis-header-card">
      <div class="analysis-header-title-wrap">
        <div class="analysis-header-title">数据分析</div>
        <div class="analysis-header-subtitle">
          已拆分为五个独立子模块：CPK/PPK 能力分析、GRR 量具分析、重复性分析、再现性分析、线性分析
        </div>
      </div>

      <div class="analysis-submodule-tabs">
        <router-link
          to="/analysis/cpk"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/cpk') ? 'active' : '']"
        >
          CPK/PPK 分析
        </router-link>
        <router-link
          to="/analysis/grr"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/grr') ? 'active' : '']"
        >
          GRR 分析
        </router-link>
        <router-link
          to="/analysis/repeatability"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/repeatability') ? 'active' : '']"
        >
          重复性分析
        </router-link>
        <router-link
          to="/analysis/reproducibility"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/reproducibility') ? 'active' : '']"
        >
          再现性分析
        </router-link>
        <router-link
          to="/analysis/linearity"
          :class="['analysis-submodule-tab', isSubmoduleActive('/analysis/linearity') ? 'active' : '']"
        >
          线性分析
        </router-link>
      </div>
    </div>

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
  gap: 12px;
  height: 100%;
  min-height: 0;
}

.analysis-header-card {
  border: 1px solid var(--border);
  border-radius: 16px;
  background: linear-gradient(180deg, #ffffff, #f8fbff);
  box-shadow: var(--shadow-xs);
  padding: 14px 16px;
}

.analysis-header-title-wrap {
  margin-bottom: 12px;
}

.analysis-header-title {
  font-size: 18px;
  font-weight: 800;
  color: #0f172a;
}

.analysis-header-subtitle {
  margin-top: 4px;
  color: #64748b;
  font-size: 12.5px;
}

.analysis-submodule-tabs {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.analysis-submodule-tab {
  text-decoration: none;
  border: 1px solid #c5d9f7;
  border-radius: 999px;
  background: #f8fbff;
  color: #1f4fd1;
  font-size: 13px;
  font-weight: 700;
  padding: 8px 14px;
  transition: all 0.2s ease;
}

.analysis-submodule-tab:hover {
  border-color: #9ec2ff;
  background: #eef5ff;
}

.analysis-submodule-tab.active {
  background: linear-gradient(180deg, #3a86ff, #2a67f5);
  border-color: #2b67f3;
  color: #ffffff;
  box-shadow: 0 8px 20px rgba(58, 134, 255, 0.26);
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
</style>
