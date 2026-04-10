<template>
  <div class="query-shell">
    <div class="mobile-query-head equipment-mobile-query-head">
      <div class="mobile-query-row">
        <el-input v-model="search" class="mobile-query-search" placeholder="搜索设备名称、编号、责任人" clearable @input="onFilter" @clear="onFilter">
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
      </div>
      <div class="mobile-query-actions equipment-mobile-query-actions">
        <el-button class="mobile-query-action is-compact" @click="showMobileFilters = !showMobileFilters">{{ mobileFilterCompactLabel }}</el-button>
        <el-button v-if="activeFilterCount" class="mobile-query-action is-compact" @click="resetFilter">重置</el-button>
        <el-button v-if="authStore.canCreate" type="primary" class="mobile-query-action is-compact is-primary" @click="openModal()">新增</el-button>
      </div>
    </div>

    <div class="filter-bar equipment-filter-bar" :class="{ 'mobile-filter-hidden': isMobile && !showMobileFilters }">
      <div v-if="!isMobile" class="filter-group equipment-filter-search">
        <div class="filter-label">搜索</div>
        <el-input v-model="search" placeholder="仪器名称/计量编号/责任人/资产编号/出厂编号" clearable size="default" style="width:320px" @input="onFilter" @clear="onFilter">
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>
      </div>
      <div class="filter-group">
        <div class="filter-label">部门</div>
        <el-select ref="filterDeptSelectRef" v-model="filterDept" placeholder="全部部门" clearable size="default" style="width:140px" @change="handleFilterDeptChange">
          <el-option v-for="d in DEPTS" :key="d" :value="d" :label="d" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">有效状态</div>
        <el-select v-model="filterValidity" placeholder="有效状态" clearable size="default" style="width:120px" @change="onFilter">
          <el-option value="有效" label="有效" />
          <el-option value="即将过期" label="即将过期" />
          <el-option value="失效" label="失效" />
        </el-select>
      </div>
      <div class="filter-group">
        <div class="filter-label">使用状态</div>
        <el-select v-model="filterUseStatus" placeholder="使用状态" clearable size="default" style="width:120px" @change="onFilter">
          <el-option v-for="s in deviceStatuses" :key="s.id" :value="s.name" :label="s.name" />
        </el-select>
      </div>
      <div class="filter-actions equipment-filter-actions">
        <input ref="importRef" type="file" style="display:none" accept=".xlsx,.xls" @change="handleImport" />
        <template v-if="isMobile">
          <el-button class="mobile-tools-trigger" size="default" @click="showMobileActionSheet = true">
            更多功能
          </el-button>
        </template>
        <template v-else>
          <el-button size="default" @click="resetFilter"><el-icon><RefreshLeft /></el-icon> 重置</el-button>
          <el-button size="default" @click="downloadTemplate"><el-icon><Download /></el-icon> 模板</el-button>
          <el-button v-if="authStore.canCreate" size="default" @click="triggerImport"><el-icon><Upload /></el-icon> 导入</el-button>
          <el-button size="default" @click="exportFiltered"><el-icon><Document /></el-icon> 导出当前</el-button>
          <el-button size="default" @click="exportAll"><el-icon><Document /></el-icon> 导出全部</el-button>
        </template>
        <el-button v-if="authStore.canCreate && !isMobile" type="primary" size="default" @click="openModal()"><el-icon><Plus /></el-icon> 新增设备</el-button>
      </div>
    </div>

    <div class="page-results-bar equipment-results-bar">
      <div class="page-results-meta">
        <span
          class="page-results-chip page-results-chip-strong is-clickable"
          :class="{ 'is-active': !filterUseStatus }"
          @click="applyEquipmentUseStatusFilter('')"
        >共 {{ totalElements }} 台</span>
        <span
          class="page-results-chip page-results-chip-use-normal is-clickable"
          :class="{ 'is-active': isEquipmentUseStatusActive('正常') }"
          @click="applyEquipmentUseStatusFilter('正常')"
        >正常 {{ useStatusSummary.normal }}</span>
        <span
          class="page-results-chip page-results-chip-use-fault is-clickable"
          :class="{ 'is-active': isEquipmentUseStatusActive('故障') }"
          @click="applyEquipmentUseStatusFilter('故障')"
        >故障 {{ useStatusSummary.fault }}</span>
        <span
          class="page-results-chip page-results-chip-use-scrap is-clickable"
          :class="{ 'is-active': isEquipmentUseStatusActive('报废') }"
          @click="applyEquipmentUseStatusFilter('报废')"
        >报废 {{ useStatusSummary.scrap }}</span>
        <span
          class="page-results-chip page-results-chip-use-other is-clickable"
          :class="{ 'is-active': isEquipmentUseStatusActive(OTHER_USE_STATUS_TOKEN) }"
          @click="applyEquipmentUseStatusFilter(OTHER_USE_STATUS_TOKEN)"
        >其他 {{ useStatusSummary.other }}</span>
        <span class="page-results-chip">当前第 {{ currentPage }} / {{ Math.max(totalPages || 1, 1) }} 页</span>
      </div>
    </div>

    <div class="batch-bar">
      <div class="batch-info">
        已选 <b>{{ selectedIds.length }}</b> 项      </div>
      <div class="batch-actions">
        <el-button size="small" @click="toggleSelectCurrentPage">
          {{ allCurrentPageSelected ? '取消当前页' : '全选当前页' }}
        </el-button>
        <el-button size="small" @click="clearSelection" :disabled="!selectedIds.length">清空选择</el-button>
        <el-button v-if="authStore.canUpdate" size="small" @click="openBatchEdit('dept')" :disabled="!selectedIds.length">批量改部门</el-button>
        <el-button v-if="authStore.canUpdate" size="small" @click="openBatchEdit('responsiblePerson')" :disabled="!selectedIds.length">批量改责任人</el-button>
        <el-button v-if="authStore.canUpdate" size="small" @click="openBatchEdit('location')" :disabled="!selectedIds.length">批量改位置</el-button>
        <el-button v-if="authStore.canDelete" size="small" type="danger" @click="deleteSelected" :disabled="!selectedIds.length">批量删除</el-button>
      </div>
    </div>

    <!-- 桌面表格 -->
    <div class="table-wrap">
      <div class="table-scroll">
        <table>
          <thead>
            <tr>
              <th style="width:54px">
                <input type="checkbox" :checked="allCurrentPageSelected" @change="toggleSelectCurrentPage" />
              </th>
              <th>仪器名称</th><th>计量编号</th><th>使用部门</th><th>使用责任人</th>
              <th>上次校准</th><th>下次校准</th><th>有效状态</th><th>使用状态</th>
              <th>设备图片</th><th>校准证书</th><th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="paged.length===0" class="empty-row">
              <td colspan="12">{{ loading ? '加载中...' : '暂无设备数据，点击「新增设备」开始添加' }}</td>
            </tr>
            <tr v-for="d in paged" :key="d.id">
              <td>
                <input type="checkbox" :checked="isSelected(d.id)" @change="toggleSelection(d.id)" />
              </td>
              <td><span style="font-weight:500;cursor:pointer;color:var(--primary)" @click="openPreview(d)">{{ d.name }}</span></td>
              <td><code style="font-size:12px;background:#f1f5f9;padding:2px 6px;border-radius:4px">{{ d.metricNo }}</code></td>
              <td>{{ d.dept || '-' }}</td>
              <td>{{ d.responsiblePerson || '-' }}</td>
              <td>{{ d.calDate || '-' }}</td>
              <td :style="{ color: d.validity==='失效' ? 'var(--danger)' : d.validity==='即将过期' ? 'var(--warning)' : 'inherit', fontWeight: d.validity!=='有效'?600:'normal' }">
                {{ d.nextDate || '-' }}
              </td>
              <td><span :class="['tag', validityTag(d.validity), 'tag-clickable', { 'is-active': isEquipmentValidityActive(d.validity) }]" @click.stop="applyEquipmentValidityFilter(d.validity)">{{ d.validity || '-' }}</span></td>
              <td><span :class="['tag', useStatusTag(d.useStatus), 'tag-clickable', { 'is-active': isEquipmentUseStatusActive(d.useStatus || '正常') }]" @click.stop="applyEquipmentUseStatusFilter(d.useStatus || '正常')">{{ d.useStatus || '正常' }}</span></td>
              <td>
                <img v-if="getPrimaryImage(d)" :src="getPrimaryImage(d)" class="table-img" @click="openImg(getPrimaryImage(d))" />
                <span v-else class="text-muted text-sm">-</span>
              </td>
              <td>
                <a v-if="d.certPath" :href="d.certPath" :download="d.certName||'cert'" class="table-link">下载</a>
                <span v-else class="text-muted text-sm">-</span>
              </td>
              <td>
                <div class="action-group">
                  <button class="action-btn action-btn-view" @click="openPreview(d)">预览</button>
                  <button v-if="authStore.canUpdate" class="action-btn action-btn-edit" @click="openModal(d)">编辑</button>
                  <button v-if="authStore.canDelete" class="action-btn action-btn-del" @click="confirmDelete(d)">删除</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 移动端卡片 -->
    <div class="mobile-list">
      <div v-if="paged.length===0" style="text-align:center;padding:48px 0;color:var(--text-muted)">
        {{ loading ? '加载中...' : '暂无设备数据，点击「新增设备」开始添加' }}
      </div>
      <div v-for="d in paged" :key="d.id" class="m-card equipment-mobile-card">
        <div class="m-card-row equipment-mobile-card-head">
          <div class="equipment-mobile-card-title-wrap">
            <input type="checkbox" :checked="isSelected(d.id)" @change="toggleSelection(d.id)" />
            <div class="m-card-title mobile-card-link" @click="openPreview(d)">{{ d.name }}</div>
          </div>
          <span :class="['tag', validityTag(d.validity), 'equipment-mobile-validity']">{{ d.validity || '-' }}</span>
        </div>
        <div class="m-card-meta equipment-mobile-meta">
          <div class="m-card-meta-item equipment-mobile-meta-item">
            <span class="equipment-mobile-meta-label">编号</span>
            <b>{{ d.metricNo || '-' }}</b>
          </div>
          <div class="m-card-meta-item equipment-mobile-meta-item">
            <span class="equipment-mobile-meta-label">部门</span>
            <b>{{ d.dept || '-' }}</b>
          </div>
          <div class="m-card-meta-item equipment-mobile-meta-item">
            <span class="equipment-mobile-meta-label">责任人</span>
            <b>{{ d.responsiblePerson || '-' }}</b>
          </div>
          <div v-if="d.location" class="m-card-meta-item equipment-mobile-meta-item equipment-mobile-meta-item-span">
            <span class="equipment-mobile-meta-label">位置</span>
            <b>{{ d.location }}</b>
          </div>
          <div class="m-card-meta-item equipment-mobile-meta-item">
            <span class="equipment-mobile-meta-label">上次校准</span>
            <b>{{ d.calDate || '-' }}</b>
          </div>
          <div class="m-card-meta-item equipment-mobile-meta-item">
            <span class="equipment-mobile-meta-label">下次校准</span>
            <b :class="{ 'text-danger': d.validity==='失效', 'text-warning': d.validity==='即将过期' }">{{ d.nextDate || '-' }}</b>
          </div>
        </div>
        <div class="m-card-footer equipment-mobile-card-footer">
          <div class="mobile-card-kpi equipment-mobile-card-kpi">
            <span :class="['tag', useStatusTag(d.useStatus), 'equipment-mobile-status', 'tag-clickable', { 'is-active': isEquipmentUseStatusActive(d.useStatus || '正常') }]" @click.stop="applyEquipmentUseStatusFilter(d.useStatus || '正常')">{{ d.useStatus || '正常' }}</span>
            <a v-if="d.certPath" :href="d.certPath" :download="d.certName||'cert'" class="table-link equipment-mobile-mini-link">证书</a>
            <img v-if="getPrimaryImage(d)" :src="getPrimaryImage(d)" class="equipment-mobile-thumb" @click="openImg(getPrimaryImage(d))" />
          </div>
          <div class="m-card-actions equipment-mobile-actions">
            <button v-if="authStore.canUpdate" class="action-btn action-btn-view" @click="openQuickEdit(d)">快改</button>
            <button v-if="authStore.canUpdate" class="action-btn action-btn-edit" @click="openModal(d)">编辑</button>
            <button v-if="authStore.canDelete" class="action-btn action-btn-del" @click="confirmDelete(d)">删除</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="totalElements > 0" class="page-pagination">
      <el-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :page-sizes="[10, 20, 50, 100]"
        :total="totalElements"
        :layout="paginationLayout"
        :small="isMobile"
        background
        @size-change="() => { currentPage = 1; loadDevices() }"
        @current-change="loadDevices"
      />
    </div>

    <!-- 设备表单弹窗 -->
    <div v-if="showModal" class="modal-mask" @click.self="closeModal">
      <div class="modal-box modal-lg">
        <div class="modal-header">
          <div class="modal-title">{{ editingId ? '编辑设备' : '新增设备' }}</div>
          <button class="modal-close modal-close-danger" @click="closeModal">✕</button>
        </div>
        <form @submit.prevent="saveDevice">
          <div class="modal-body" style="padding-top:0">
            <div v-if="isMobile" class="mobile-form-steps-wrap">
              <div class="mobile-form-steps">
                <button
                  v-for="item in formTabItems"
                  :key="item.name"
                  type="button"
                  :class="['mobile-form-step', { active: formTab === item.name }]"
                  @click="formTab = item.name"
                >
                  {{ item.label }}
                </button>
              </div>
              <div class="mobile-form-step-hint">
                第 {{ currentFormTabIndex + 1 }} / {{ formTabItems.length }} 步
              </div>
            </div>
            <el-tabs v-model="formTab" class="device-form-tabs">
              <!-- Tab 1: 基本信息 -->
              <el-tab-pane label="基本信息" name="basic">
                <el-form label-width="110px" label-position="right" size="default" style="margin-top:12px">
                  <el-row :gutter="20">
                    <el-col :span="12">
                      <el-form-item label="仪器名称" required>
                        <el-input v-model="form.name" placeholder="请输入设备名称" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="计量编号" required>
                        <el-input v-model="form.metricNo" placeholder="如：M2024001" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="资产编号">
                        <el-input v-model="form.assetNo" placeholder="资产编号" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="出厂编号">
                        <el-input v-model="form.serialNo" placeholder="出厂编号/序列号" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="设备型号">
                        <el-input v-model="form.model" placeholder="设备型号" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="制造厂">
                        <el-input v-model="form.manufacturer" placeholder="制造厂家名称" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="ABC分类">
                        <el-select v-model="form.abcClass" placeholder="请选择" style="width:100%">
                          <el-option value="" label="未分类" />
                          <el-option value="A类" label="A类" />
                          <el-option value="B类" label="B类" />
                          <el-option value="C类" label="C类" />
                        </el-select>
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="使用部门">
                        <el-select ref="deptSelectRef" v-model="form.dept" class="dept-select" placeholder="选择部门" clearable filterable style="width:100%" @change="handleDeptChange">
                          <el-option v-for="d in DEPTS" :key="d" :value="d" :label="d" />
                        </el-select>
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="设备位置">
                        <el-input v-model="form.location" placeholder="如：一车间" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="使用责任人">
                        <el-input v-model="form.responsiblePerson" placeholder="负责人姓名" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="使用状态">
                        <el-select v-model="form.useStatus" placeholder="选择状态" style="width:100%">
                          <el-option v-for="s in deviceStatuses" :key="s.id" :value="s.name" :label="s.name" />
                        </el-select>
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>

              <!-- Tab 2: 采购&技术 -->
              <el-tab-pane label="💰 采购&技术" name="purchase">
                <el-form label-width="130px" label-position="right" size="default" style="margin-top:12px">
                  <el-row :gutter="20">
                    <el-col :span="12">
                      <el-form-item label="采购时间">
                        <el-date-picker v-model="form.purchaseDate" type="date" value-format="YYYY-MM-DD" placeholder="选择采购日期" style="width:100%" />
                      </el-form-item>
                    </el-col>
                    <el-col v-if="canViewPurchasePrice" :span="12">
                      <el-form-item label="采购价格（元）">
                        <el-input-number v-model="form.purchasePrice" :min="0" :precision="2" :step="100" placeholder="0.00" style="width:100%" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12" v-if="form.purchaseDate">
                      <el-form-item label="使用年限（自动）">
                        <el-input :value="calcServiceLife" readonly class="input-readonly" />
                      </el-form-item>
                    </el-col>
                  </el-row>
                  <el-divider content-position="left" style="margin:8px 0 16px">技术参数</el-divider>
                  <el-row :gutter="20">
                    <el-col :span="12">
                      <el-form-item label="分度值">
                        <el-input v-model="form.graduationValue" placeholder="如：0.01mm" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="测试范围">
                        <el-input v-model="form.testRange" placeholder="如：0-200mm" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="仪器允许误差">
                        <el-input v-model="form.allowableError" placeholder="如：±0.02mm" />
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>

              <!-- Tab 3: 校准信息 -->
              <el-tab-pane label="校准信息" name="calib">
                <el-form label-width="130px" label-position="right" size="default" style="margin-top:12px">
                  <el-row :gutter="20">
                    <el-col :span="12">
                      <el-form-item label="检定周期（可选半年/一年）" required>
                        <el-select v-model="form.cycle" placeholder="请选择周期" style="width:100%">
                          <el-option :value="6" label="半年（6个月）" />
                          <el-option :value="12" label="一年（12个月）" />
                        </el-select>
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="校准时间">
                        <el-date-picker v-model="form.calDate" type="date" value-format="YYYY-MM-DD" placeholder="选择校准日期" style="width:100%" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="下次校准（自动）">
                        <el-input :value="calcNextDate || '-'" readonly class="input-readonly" />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="有效状态（自动）">
                        <el-input
                          :value="calcValidity"
                          readonly
                          :class="['input-readonly', calcValidity==='失效'?'text-danger':calcValidity==='即将过期'?'text-warning':'']"
                        />
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="校准结果判定">
                        <el-select v-model="form.calibrationResult" placeholder="请选择" style="width:100%">
                          <el-option value="" label="未判定" />
                          <el-option value="合格" label="合格" />
                          <el-option value="不合格" label="不合格" />
                          <el-option value="降级使用" label="降级使用" />
                          <el-option value="停用" label="停用" />
                        </el-select>
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>

              <!-- Tab 4: 附件&备注 -->
              <el-tab-pane label="附件&备注" name="attachment">
                <el-form label-width="110px" label-position="right" size="default" style="margin-top:12px">
                  <el-row :gutter="20">
                    <el-col :span="12">
                      <el-form-item label="设备图片">
                        <div class="device-image-section">
                          <div class="device-image-note">支持两张设备照片，选图后会自动压缩再上传。</div>
                          <div class="device-image-grid">
                            <div class="device-image-slot">
                              <div class="device-image-slot-head">
                                <span class="device-image-slot-title">图片 1</span>
                                <span class="device-image-slot-tip">自动压缩</span>
                              </div>
                              <div class="device-image-picker" :class="{ filled: imagePreview }">
                                <div class="preview-area" v-if="imagePreview">
                                  <img :src="imagePreview" class="preview-img device-preview-img" />
                                  <span class="file-chip device-remove-chip" @click="removeImage(1)">移除</span>
                                </div>
                                <div v-else class="device-image-empty">建议上传设备正面图</div>
                                <label class="upload-label device-image-button">
                                  <span>{{ imagePreview ? '重新选择' : '选择图片 1' }}</span>
                                  <input type="file" style="display:none" accept="image/*" @change="handleImageSelect(1, $event)" />
                                </label>
                              </div>
                            </div>
                            <div class="device-image-slot">
                              <div class="device-image-slot-head">
                                <span class="device-image-slot-title">图片 2</span>
                                <span class="device-image-slot-tip">自动压缩</span>
                              </div>
                              <div class="device-image-picker" :class="{ filled: imagePreview2 }">
                                <div class="preview-area" v-if="imagePreview2">
                                  <img :src="imagePreview2" class="preview-img device-preview-img" />
                                  <span class="file-chip device-remove-chip" @click="removeImage(2)">移除</span>
                                </div>
                                <div v-else class="device-image-empty">可补充铭牌或侧面图</div>
                                <label class="upload-label device-image-button">
                                  <span>{{ imagePreview2 ? '重新选择' : '选择图片 2' }}</span>
                                  <input type="file" style="display:none" accept="image/*" @change="handleImageSelect(2, $event)" />
                                </label>
                              </div>
                            </div>
                          </div>
                        </div>
                      </el-form-item>
                    </el-col>
                    <el-col :span="12">
                      <el-form-item label="校准证书">
                        <div class="upload-area">
                          <label class="upload-label">
                            <span>选择证书</span>
                            <input type="file" style="display:none" accept=".pdf,image/*" @change="handleCertSelect" />
                          </label>
                          <div class="preview-area">
                            <div v-if="certInfo" class="file-chip">
                              {{ certInfo }}
                              <span class="remove" @click="removeCert">✕</span>
                            </div>
                          </div>
                        </div>
                      </el-form-item>
                    </el-col>
                    <el-col :span="24">
                      <el-form-item label="备注">
                        <el-input v-model="form.remark" type="textarea" :rows="3" placeholder="备注信息" />
                      </el-form-item>
                    </el-col>
                  </el-row>
                </el-form>
              </el-tab-pane>
            </el-tabs>
          </div>
          <div class="modal-footer" :class="{ 'mobile-device-footer': isMobile }">
            <template v-if="isMobile">
              <button type="button" class="btn btn-danger" @click="closeModal">关闭</button>
              <button type="button" class="btn btn-outline" :disabled="isFirstFormTab" @click="goPrevFormTab">上一步</button>
              <button v-if="!isLastFormTab" type="button" class="btn btn-primary" @click="goNextFormTab">下一步</button>
              <button v-else type="submit" class="btn btn-primary" :disabled="saving">
                {{ saving ? '保存中...' : '保存设备' }}
              </button>
            </template>
            <template v-else>
              <button type="button" class="btn btn-outline" @click="closeModal">取消</button>
              <button type="submit" class="btn btn-primary" :disabled="saving">
                {{ saving ? '保存中...' : '保存设备' }}
              </button>
            </template>
          </div>
        </form>
      </div>
    </div>
    <!-- 设备预览弹窗 -->
    <div v-if="showPreview" class="modal-mask" @click.self="showPreview=false">
      <div class="modal-box">
        <div class="modal-header">
          <div class="modal-title">设备详情 -{{ previewDevice.name }}</div>
          <button class="modal-close" @click="showPreview=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="section-heading">基本信息</div>
          <div class="preview-grid">
            <div class="preview-item"><span class="preview-label">仪器名称</span><span class="preview-val">{{ previewDevice.name }}</span></div>
            <div class="preview-item"><span class="preview-label">计量编号</span><span class="preview-val"><code style="font-size:12px;background:#f1f5f9;padding:2px 6px;border-radius:4px">{{ previewDevice.metricNo }}</code></span></div>
            <div class="preview-item"><span class="preview-label">资产编号</span><span class="preview-val">{{ previewDevice.assetNo || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">出厂编号</span><span class="preview-val">{{ previewDevice.serialNo || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">ABC分类</span><span class="preview-val">{{ previewDevice.abcClass || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">设备型号</span><span class="preview-val">{{ previewDevice.model || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">制造厂</span><span class="preview-val">{{ previewDevice.manufacturer || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用部门</span><span class="preview-val">{{ previewDevice.dept || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">设备位置</span><span class="preview-val">{{ previewDevice.location || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用责任人</span><span class="preview-val">{{ previewDevice.responsiblePerson || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用状态</span><span class="preview-val"><span :class="['tag', useStatusTag(previewDevice.useStatus)]">{{ previewDevice.useStatus || '正常' }}</span></span></div>
          </div>
          <div class="section-sep section-heading">采购信息</div>
          <div class="preview-grid">
            <div class="preview-item"><span class="preview-label">采购时间</span><span class="preview-val">{{ previewDevice.purchaseDate || '-' }}</span></div>
            <div v-if="canViewPurchasePrice" class="preview-item"><span class="preview-label">采购价格</span><span class="preview-val">{{ previewDevice.purchasePrice != null ? '¥' + previewDevice.purchasePrice : '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">使用年限</span><span class="preview-val">{{ previewDevice.serviceLife != null ? previewDevice.serviceLife + ' 年' : '-' }}</span></div>
          </div>
          <div class="section-sep section-heading">📐 技术参数</div>
          <div class="preview-grid">
            <div class="preview-item"><span class="preview-label">分度值</span><span class="preview-val">{{ previewDevice.graduationValue || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">测试范围</span><span class="preview-val">{{ previewDevice.testRange || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">允许误差</span><span class="preview-val">{{ previewDevice.allowableError || '-' }}</span></div>
          </div>
          <div class="section-sep section-heading">校准信息</div>
          <div class="preview-grid">
            <div class="preview-item"><span class="preview-label">检定周期</span><span class="preview-val">{{ previewDevice.cycle ? previewDevice.cycle + ' 个月' : '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">上次校准</span><span class="preview-val">{{ previewDevice.calDate || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">下次校准</span><span class="preview-val" :style="{ color: previewDevice.validity==='失效'?'var(--danger)':previewDevice.validity==='即将过期'?'var(--warning)':'inherit', fontWeight: '600' }">{{ previewDevice.nextDate || '-' }}</span></div>
            <div class="preview-item"><span class="preview-label">有效状态</span><span class="preview-val"><span :class="['tag', validityTag(previewDevice.validity)]">{{ previewDevice.validity || '-' }}</span></span></div>
            <div class="preview-item"><span class="preview-label">校准结果</span><span class="preview-val">{{ previewDevice.calibrationResult || '-' }}</span></div>
          </div>
          <div v-if="previewDevice.remark" class="section-sep">
            <div class="section-heading">备注</div>
            <div style="padding:10px;background:#f8fafc;border-radius:8px;font-size:13px;color:#475569">{{ previewDevice.remark }}</div>
          </div>
          <div v-if="deviceImages(previewDevice).length || previewDevice.certPath" class="section-sep section-heading">附件</div>
          <div v-if="deviceImages(previewDevice).length || previewDevice.certPath" style="display:flex;gap:16px;align-items:center;margin-top:10px;flex-wrap:wrap">
            <img
              v-for="(img, index) in deviceImages(previewDevice)"
              :key="img + index"
              :src="img"
              style="width:100px;height:100px;object-fit:cover;border-radius:10px;border:1px solid var(--border);cursor:pointer"
              @click="openImg(img)"
            />
            <a v-if="previewDevice.certPath" :href="previewDevice.certPath" :download="previewDevice.certName||'cert'" class="btn btn-outline btn-sm">下载证书</a>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-outline" @click="showPreview=false">关闭</button>
          <button v-if="authStore.canUpdate && isMobile" class="btn btn-success" @click="showPreview=false; openQuickEdit(previewDevice)">快速编辑</button>
          <button v-if="authStore.canUpdate" class="btn btn-primary" @click="showPreview=false; openModal(previewDevice)">编辑</button>
        </div>
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirm" class="modal-mask" @click.self="showDeleteConfirm=false">
      <div class="modal-box modal-sm">
        <div class="modal-header">
          <div class="modal-title" style="color:var(--danger)">确认删除设备</div>
          <button class="modal-close" @click="showDeleteConfirm=false">✕</button>
        </div>
        <div class="modal-body">
          <div style="background:#fff5f5;border:1px solid #fecaca;border-radius:10px;padding:14px;margin-bottom:16px">
            <div style="font-weight:700;font-size:15px;margin-bottom:8px">{{ deleteTarget.name }}</div>
            <div class="preview-grid" style="gap:8px">
              <div class="preview-item"><span class="preview-label">计量编号</span><span class="preview-val">{{ deleteTarget.metricNo }}</span></div>
              <div class="preview-item"><span class="preview-label">使用部门</span><span class="preview-val">{{ deleteTarget.dept || '-' }}</span></div>
              <div class="preview-item"><span class="preview-label">使用责任人</span><span class="preview-val">{{ deleteTarget.responsiblePerson || '-' }}</span></div>
              <div class="preview-item"><span class="preview-label">有效状态</span><span class="preview-val"><span :class="['tag', validityTag(deleteTarget.validity)]">{{ deleteTarget.validity || '-' }}</span></span></div>
            </div>
          </div>
          <div style="color:var(--text-muted);font-size:13px">此操作不可撤销，确认要删除该设备吗？</div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-outline" @click="showDeleteConfirm=false">取消</button>
          <button class="btn btn-danger" @click="doDelete">确认删除</button>
        </div>
      </div>
    </div>

    <!-- 批量编辑弹窗 -->
    <div v-if="showBatchEdit" class="modal-mask" @click.self="showBatchEdit=false">
      <div class="modal-box modal-sm">
        <div class="modal-header">
          <div class="modal-title">批量修改 - {{ batchEditLabels[batchEditField] }} ({{ selectedIds.length }}台)</div>
          <button class="modal-close" @click="showBatchEdit=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label class="form-label">{{ batchEditLabels[batchEditField] }}</label>
            <input v-if="batchEditField==='responsiblePerson' || batchEditField==='location'" v-model="batchEditValue" :placeholder="'请输入' + batchEditLabels[batchEditField]" style="width:100%" />
            <input v-else-if="batchEditField==='dept'" v-model="batchEditValue" list="batch-dept-list" placeholder="选择或输入部门" style="width:100%" />
            <datalist id="batch-dept-list">
              <option v-for="d in DEPTS" :key="d" :value="d" />
            </datalist>
          </div>
          <div style="margin-top:12px;font-size:13px;color:var(--text-muted)">将更新已选 {{ selectedIds.length }} 台设备的「{{ batchEditLabels[batchEditField] }}」字段。</div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-outline" @click="showBatchEdit=false">取消</button>
          <button class="btn btn-primary" @click="saveBatchEdit" :disabled="batchEditSaving">{{ batchEditSaving ? '保存中...' : '批量保存' }}</button>
        </div>
      </div>
    </div>

    <div v-if="showQuickEdit" class="modal-mask" @click.self="closeQuickEdit">
      <div class="modal-box modal-sm quick-edit-modal">
        <div class="modal-header">
          <div class="modal-title">快速编辑 - {{ quickEditTarget.name || '设备' }}</div>
          <button class="modal-close" @click="closeQuickEdit">✕</button>
        </div>
        <div class="modal-body quick-edit-body">
          <div class="quick-edit-intro">
            手机端常用字段可直接在这里改，复杂信息再进完整编辑。
          </div>
          <div class="form-group">
            <label class="form-label">使用部门</label>
            <input v-model="quickEditForm.dept" list="quick-edit-dept-list" placeholder="选择或输入部门" style="width:100%" />
            <datalist id="quick-edit-dept-list">
              <option v-for="d in DEPTS" :key="d" :value="d" />
            </datalist>
          </div>
          <div class="form-grid quick-edit-grid">
            <div class="form-group">
              <label class="form-label">责任人</label>
              <input v-model="quickEditForm.responsiblePerson" placeholder="负责人姓名" />
            </div>
            <div class="form-group">
              <label class="form-label">设备位置</label>
              <input v-model="quickEditForm.location" placeholder="如：一车间" />
            </div>
            <div class="form-group">
              <label class="form-label">使用状态</label>
              <select v-model="quickEditForm.useStatus">
                <option v-for="s in deviceStatuses" :key="s.id" :value="s.name">{{ s.name }}</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">校准周期</label>
              <select v-model.number="quickEditForm.cycle">
                <option :value="6">半年（6个月）</option>
                <option :value="12">一年（12个月）</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">上次校准</label>
              <input v-model="quickEditForm.calDate" type="date" />
            </div>
            <div class="form-group">
              <label class="form-label">校准结果</label>
              <select v-model="quickEditForm.calibrationResult">
                <option value="">未判定</option>
                <option value="合格">合格</option>
                <option value="不合格">不合格</option>
                <option value="降级使用">降级使用</option>
                <option value="停用">停用</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">备注</label>
            <textarea v-model="quickEditForm.remark" rows="3" placeholder="补充说明"></textarea>
          </div>
        </div>
        <div class="modal-footer quick-edit-footer">
          <button class="btn btn-outline" @click="closeQuickEdit">取消</button>
          <button class="btn btn-ghost" @click="openFullEditFromQuick">完整编辑</button>
          <button class="btn btn-primary" @click="saveQuickEdit" :disabled="quickEditSaving">{{ quickEditSaving ? '保存中...' : '保存修改' }}</button>
        </div>
      </div>
    </div>

    <transition name="mobile-sheet-pop">
      <div v-if="showMobileActionSheet" class="modal-mask" @click.self="showMobileActionSheet = false">
        <div class="modal-box modal-sm mobile-tools-sheet">
          <div class="mobile-tools-sheet-handle"></div>
          <div class="modal-header">
            <div>
              <div class="mobile-tools-sheet-eyebrow">Quick Actions</div>
              <div class="modal-title">更多功能</div>
            </div>
            <button class="modal-close" @click="showMobileActionSheet = false">✕</button>
          </div>
          <div class="modal-body">
            <div class="mobile-tools-grid">
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(resetFilter)">
                <span class="mobile-tools-btn-title">重置筛选</span>
                <span class="mobile-tools-btn-desc">清空当前筛选条件</span>
              </button>
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(downloadTemplate)">
                <span class="mobile-tools-btn-title">下载模板</span>
                <span class="mobile-tools-btn-desc">获取导入表格模板</span>
              </button>
              <button v-if="authStore.canCreate" class="btn btn-outline mobile-tools-btn" @click="runMobileAction(triggerImport)">
                <span class="mobile-tools-btn-title">导入设备</span>
                <span class="mobile-tools-btn-desc">批量导入设备资料</span>
              </button>
              <button class="btn btn-outline mobile-tools-btn" @click="runMobileAction(exportFiltered)">
                <span class="mobile-tools-btn-title">导出当前</span>
                <span class="mobile-tools-btn-desc">导出当前筛选结果</span>
              </button>
              <button class="btn btn-outline mobile-tools-btn mobile-tools-btn-wide" @click="runMobileAction(exportAll)">
                <span class="mobile-tools-btn-title">导出全部</span>
                <span class="mobile-tools-btn-desc">导出全部设备台账</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>

  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, inject, nextTick } from 'vue'
import { deviceApi, settingsApi, deviceStatusApi, deptApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'
import { useResumeRefresh } from '../composables/useResumeRefresh.js'
import { useScrollMemory } from '../composables/useScrollMemory.js'
import { useViewCache } from '../composables/useViewCache.js'

const showToast = inject('showToast')
const authStore = useAuthStore()
const equipmentCache = useViewCache('equipment-view', { ttlMs: 30 * 60 * 1000 })
useScrollMemory('equipment-view')
const loading = ref(false)
const devices = ref([])
const deviceStatuses = ref([])
const OTHER_USE_STATUS_TOKEN = '__OTHER__'
const search = ref('')
const filterDept = ref(''), filterValidity = ref(''), filterUseStatus = ref('')
const showModal = ref(false), editingId = ref(null), saving = ref(false)
const formTab = ref('basic')
const importRef = ref(null)
const imagePreview = ref(''), imagePreview2 = ref(''), certInfo = ref('')
let pendingImage = null, pendingImage2 = null, pendingCert = null
const IMAGE_MAX_EDGE = 1600
const IMAGE_JPEG_QUALITY = 0.82
const warningDays = ref(315), expiredDays = ref(360)
const currentPage = ref(1), pageSize = ref(20), totalPages = ref(1), totalElements = ref(0)
const selectedIds = ref([])
const emptyUseStatusSummary = () => ({ normal: 0, fault: 0, scrap: 0, other: 0 })
const useStatusSummary = ref(emptyUseStatusSummary())
const deptSelectRef = ref(null)
const filterDeptSelectRef = ref(null)
const isMobile = ref(false)
const showMobileFilters = ref(true)
const showMobileActionSheet = ref(false)

// 预览弹窗
const showPreview = ref(false)
const previewDevice = ref({})

// 删除确认弹窗
const showDeleteConfirm = ref(false)
const deleteTarget = ref({})
const showQuickEdit = ref(false)
const quickEditSaving = ref(false)
const quickEditTarget = ref({})

// 批量编辑弹窗
const showBatchEdit = ref(false)
const batchEditField = ref('')
const batchEditValue = ref('')
const batchEditSaving = ref(false)
const batchEditLabels = { dept: '使用部门', responsiblePerson: '使用责任人', location: '设备位置' }

const DEPTS = ref([])
const deptTree = ref([])

function restoreEquipmentCache() {
  const cached = equipmentCache.restore()
  if (!cached) return

  devices.value = Array.isArray(cached.devices) ? cached.devices : []
  deviceStatuses.value = Array.isArray(cached.deviceStatuses) ? cached.deviceStatuses : []
  search.value = cached.search || ''
  filterDept.value = cached.filterDept || ''
  filterValidity.value = cached.filterValidity || ''
  filterUseStatus.value = cached.filterUseStatus || ''
  currentPage.value = Number(cached.currentPage) || 1
  pageSize.value = Number(cached.pageSize) || 20
  totalPages.value = Number(cached.totalPages) || 1
  totalElements.value = Number(cached.totalElements) || 0
  useStatusSummary.value = {
    ...emptyUseStatusSummary(),
    ...(cached.useStatusSummary || {})
  }
}

function saveEquipmentCache() {
  equipmentCache.save({
    devices: devices.value,
    deviceStatuses: deviceStatuses.value,
    search: search.value,
    filterDept: filterDept.value,
    filterValidity: filterValidity.value,
    filterUseStatus: filterUseStatus.value,
    currentPage: currentPage.value,
    pageSize: pageSize.value,
    totalPages: totalPages.value,
    totalElements: totalElements.value,
    useStatusSummary: useStatusSummary.value
  })
}
const formTabItems = [
  { name: 'basic', label: '基本' },
  { name: 'purchase', label: '采购' },
  { name: 'calib', label: '校准' },
  { name: 'attachment', label: '附件' }
]

const activeFilterCount = computed(() =>
  [search.value, filterDept.value, filterValidity.value, filterUseStatus.value].filter(Boolean).length
)
const mobileFilterButtonLabel = computed(() =>
  showMobileFilters.value ? '收起筛选' : '筛选' + (activeFilterCount.value ? '(' + activeFilterCount.value + ')' : '')
)
const mobileFilterCompactLabel = computed(() =>
  showMobileFilters.value ? '收起' : '筛选' + (activeFilterCount.value ? '(' + activeFilterCount.value + ')' : '')
)
const paginationLayout = computed(() =>
  isMobile.value ? 'prev, pager, next' : 'total, sizes, prev, pager, next, jumper'
)
const currentFormTabIndex = computed(() =>
  Math.max(0, formTabItems.findIndex(item => item.name === formTab.value))
)
const isFirstFormTab = computed(() => currentFormTabIndex.value === 0)
const isLastFormTab = computed(() => currentFormTabIndex.value === formTabItems.length - 1)

const form = reactive({
  name:'', metricNo:'', assetNo:'', serialNo:'', abcClass:'', dept:'', location:'',
  manufacturer:'', model:'', responsiblePerson:'', useStatus:'正常', cycle:12,
  calDate:'', calibrationResult:'', purchaseDate:'', purchasePrice:null,
  graduationValue:'', testRange:'', allowableError:'', remark:'',
  imagePath:null, imageName:null, imagePath2:null, imageName2:null, certPath:null, certName:null
})
const quickEditForm = reactive({
  dept:'',
  responsiblePerson:'',
  location:'',
  useStatus:'正常',
  cycle:12,
  calDate:'',
  calibrationResult:'',
  remark:''
})

const calcNextDate = computed(() => {
  if (!form.calDate) return ''
  const [y, m, d] = form.calDate.split('-').map(Number)
  if (!y || !m || !d) return ''
  const cycleMonths = Number(form.cycle) > 0 ? Number(form.cycle) : 12
  const localDate = new Date(y, m - 1, d)
  localDate.setMonth(localDate.getMonth() + cycleMonths)
  localDate.setDate(localDate.getDate() - 1)
  const yy = localDate.getFullYear()
  const mm = String(localDate.getMonth() + 1).padStart(2, '0')
  const dd = String(localDate.getDate()).padStart(2, '0')
  return `${yy}-${mm}-${dd}`
})
const calcValidity = computed(() => {
  if (!form.calDate) return ''
  const days = Math.floor((new Date() - new Date(form.calDate)) / 86400000)
  if (days < 0) return '有效'
  if (days >= expiredDays.value) return '失效'
  if (days >= warningDays.value) return '即将过期'
  return '有效'
})
const calcServiceLife = computed(() => {
  if (!form.purchaseDate) return ''
  const years = Math.floor((new Date() - new Date(form.purchaseDate)) / (365.25 * 86400000))
  return years + ' 年'
})
const canViewPurchasePrice = computed(() => authStore.isAdmin)

const paged = computed(() => devices.value)
const currentPageIds = computed(() => paged.value.map(d => d.id))
const allCurrentPageSelected = computed(() =>
  currentPageIds.value.length > 0 && currentPageIds.value.every(id => selectedIds.value.includes(id))
)

function onFilter() { currentPage.value = 1; clearSelection(); loadDevices() }
function resetFilter() {
  search.value=''
  filterDept.value=''; filterValidity.value=''; filterUseStatus.value=''
  currentPage.value=1; clearSelection(); loadDevices()
}

function normalizeUseStatusKey(value) {
  const text = typeof value === 'string' ? value.trim() : ''
  if (text === '正常') return 'normal'
  if (text === '故障') return 'fault'
  if (text === '报废') return 'scrap'
  return 'other'
}

function buildUseStatusSummary(devicesList) {
  const summary = emptyUseStatusSummary()
  for (const device of Array.isArray(devicesList) ? devicesList : []) {
    const key = normalizeUseStatusKey(device?.useStatus)
    summary[key] += 1
  }
  return summary
}

function validityTag(v) { return v==='有效'?'tag-valid':v==='即将过期'?'tag-warning':'tag-expired' }
function useStatusTag(s) { const map={'正常':'tag-green','故障':'tag-red','维修':'tag-yellow','报废':'tag-gray'}; return map[s]||'tag-blue' }
function openImg(url) { window.open(url) }
function getPrimaryImage(device) { return device?.imagePath || device?.imagePath2 || '' }
function deviceImages(device) {
  return [device?.imagePath, device?.imagePath2].filter(Boolean)
}
function handleDeptChange() {
  nextTick(() => {
    deptSelectRef.value?.blur?.()
  })
}
function handleFilterDeptChange() {
  onFilter()
  nextTick(() => {
    filterDeptSelectRef.value?.blur?.()
  })
}
function isSelected(id) { return selectedIds.value.includes(id) }
function toggleSelection(id) {
  selectedIds.value = isSelected(id)
    ? selectedIds.value.filter(item => item !== id)
    : [...selectedIds.value, id]
}
function clearSelection() { selectedIds.value = [] }
function toggleSelectCurrentPage() {
  if (allCurrentPageSelected.value) {
    selectedIds.value = selectedIds.value.filter(id => !currentPageIds.value.includes(id))
    return
  }
  selectedIds.value = Array.from(new Set([...selectedIds.value, ...currentPageIds.value]))
}

function syncViewport() {
  const mobile = window.innerWidth <= 768
  if (mobile !== isMobile.value) {
    isMobile.value = mobile
    showMobileFilters.value = !mobile
    return
  }
  isMobile.value = mobile
}
function goPrevFormTab() {
  if (isFirstFormTab.value) return
  formTab.value = formTabItems[currentFormTabIndex.value - 1].name
}
function goNextFormTab() {
  if (isLastFormTab.value) return
  formTab.value = formTabItems[currentFormTabIndex.value + 1].name
}
function isEquipmentUseStatusActive(status) {
  return (filterUseStatus.value || '') === (status || '')
}
function isEquipmentValidityActive(validity) {
  return !!validity && filterValidity.value === validity
}
function applyEquipmentValidityFilter(validity) {
  const nextValue = filterValidity.value === validity ? '' : (validity || '')
  if (filterValidity.value === nextValue) return
  filterValidity.value = nextValue
  onFilter()
}
function applyEquipmentUseStatusFilter(status) {
  const nextValue = filterUseStatus.value === status ? '' : (status || '')
  if (filterUseStatus.value === nextValue) return
  filterUseStatus.value = nextValue
  onFilter()
}

async function loadDevices() {
  loading.value = true
  try {
    const isOtherUseStatusFilter = filterUseStatus.value === OTHER_USE_STATUS_TOKEN
    const listParams = {
      search: search.value||undefined,
      dept: filterDept.value||undefined,
      validity: filterValidity.value||undefined,
      useStatus: isOtherUseStatusFilter ? undefined : (filterUseStatus.value||undefined)
    }
    if (isOtherUseStatusFilter) {
      const summaryRes = await deviceApi.list(listParams)
      const allMatched = Array.isArray(summaryRes.data) ? summaryRes.data : []
      const otherMatched = allMatched.filter(device => normalizeUseStatusKey(device?.useStatus) === 'other')
      totalElements.value = otherMatched.length
      totalPages.value = Math.max(1, Math.ceil(otherMatched.length / pageSize.value))
      if (currentPage.value > totalPages.value) currentPage.value = 1
      const start = Math.max(0, (currentPage.value - 1) * pageSize.value)
      devices.value = otherMatched.slice(start, start + pageSize.value)
      useStatusSummary.value = buildUseStatusSummary(allMatched)
    } else {
      const res = await deviceApi.listPaged({
        ...listParams,
        page: currentPage.value, size: pageSize.value
      })
      devices.value = res.data.content
      totalPages.value = res.data.totalPages
      totalElements.value = res.data.totalElements
      currentPage.value = res.data.page
      try {
        const summaryRes = await deviceApi.list(listParams)
        useStatusSummary.value = buildUseStatusSummary(summaryRes.data)
      } catch (summaryError) {
        console.error(summaryError)
        useStatusSummary.value = buildUseStatusSummary(devices.value)
      }
    }
    selectedIds.value = selectedIds.value.filter(id => devices.value.some(d => d.id === id))
    saveEquipmentCache()
  } catch(e) { console.error(e) }
  finally { loading.value = false }
}
async function loadStatuses() {
  try {
    deviceStatuses.value = (await deviceStatusApi.list()).data
    saveEquipmentCache()
  } catch(e) {}
}

function normalizeDepartmentName(name) {
  return typeof name === 'string' ? name.trim() : ''
}

function normalizeUserDepartments() {
  if (Array.isArray(authStore.departments) && authStore.departments.length) {
    return authStore.departments.map(normalizeDepartmentName).filter(Boolean)
  }
  if (typeof authStore.department === 'string' && authStore.department.trim()) {
    return authStore.department
      .replaceAll('，', ',')
      .split(',')
      .map(s => s.trim())
      .filter(Boolean)
  }
  return []
}

function collectAllDeptNames(nodes, set) {
  for (const node of nodes || []) {
    const name = normalizeDepartmentName(node?.name)
    if (name) set.add(name)
    collectAllDeptNames(node?.children || [], set)
  }
}

function collectNodeAndChildren(node, set) {
  if (!node) return
  const name = normalizeDepartmentName(node.name)
  if (name) set.add(name)
  for (const child of node.children || []) {
    collectNodeAndChildren(child, set)
  }
}

function appendDeptScopeByRoot(nodes, rootName, set) {
  for (const node of nodes || []) {
    if (normalizeDepartmentName(node?.name) === rootName) {
      collectNodeAndChildren(node, set)
      return true
    }
    if (appendDeptScopeByRoot(node?.children || [], rootName, set)) return true
  }
  return false
}

function buildAllowedDepartments(tree, fallbackNames = []) {
  const allSet = new Set()
  collectAllDeptNames(tree, allSet)

  if (authStore.isAdmin) return Array.from(allSet)

  const userRoots = normalizeUserDepartments()
  if (!userRoots.length) {
    return allSet.size ? Array.from(allSet) : fallbackNames
  }

  const scopeSet = new Set()
  for (const root of userRoots) {
    const found = appendDeptScopeByRoot(tree, root, scopeSet)
    if (!found) scopeSet.add(root)
  }
  return Array.from(scopeSet)
}

function openModal(device=null) {
  pendingImage=null; pendingImage2=null; pendingCert=null; imagePreview.value=''; imagePreview2.value=''; certInfo.value=''
  formTab.value = 'basic'
  editingId.value = null
  Object.assign(form, {
    name:'', metricNo:'', assetNo:'', serialNo:'', abcClass:'', dept:'', location:'',
    manufacturer:'', model:'', responsiblePerson:'', useStatus:'正常', cycle:12,
    calDate:'', calibrationResult:'', purchaseDate:'', purchasePrice:null,
    graduationValue:'', testRange:'', allowableError:'', remark:'',
    imagePath:null, imageName:null, imagePath2:null, imageName2:null, certPath:null, certName:null
  })
  if (device) {
    editingId.value = device.id
    Object.assign(form, {
      name:device.name||'', metricNo:device.metricNo||'', assetNo:device.assetNo||'',
      serialNo:device.serialNo||'', abcClass:device.abcClass||'', dept:device.dept||'',
      location:device.location||'', manufacturer:device.manufacturer||'', model:device.model||'',
      responsiblePerson:device.responsiblePerson||'', useStatus:device.useStatus||'正常',
      cycle:device.cycle||12, calDate:device.calDate||'', calibrationResult:device.calibrationResult||'',
      purchaseDate:device.purchaseDate||'', purchasePrice:device.purchasePrice||null,
      graduationValue:device.graduationValue||'', testRange:device.testRange||'',
      allowableError:device.allowableError||'', remark:device.remark||'',
      imagePath:device.imagePath||null, imageName:device.imageName||null,
      imagePath2:device.imagePath2||null, imageName2:device.imageName2||null,
      certPath:device.certPath||null, certName:device.certName||null
    })
    if (device.imagePath) imagePreview.value = device.imagePath
    if (device.imagePath2) imagePreview2.value = device.imagePath2
    if (device.certName) certInfo.value = device.certName
  }
  showModal.value = true
}
function closeModal() { showModal.value = false }
function openQuickEdit(device) {
  if (!device) return
  quickEditTarget.value = device
  Object.assign(quickEditForm, {
    dept: device.dept || '',
    responsiblePerson: device.responsiblePerson || '',
    location: device.location || '',
    useStatus: device.useStatus || '正常',
    cycle: device.cycle || 12,
    calDate: device.calDate || '',
    calibrationResult: device.calibrationResult || '',
    remark: device.remark || ''
  })
  showQuickEdit.value = true
}
function closeQuickEdit() {
  showQuickEdit.value = false
  quickEditTarget.value = {}
}
function openFullEditFromQuick() {
  const target = quickEditTarget.value
  closeQuickEdit()
  openModal(target)
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = () => reject(new Error('read failed'))
    reader.readAsDataURL(file)
  })
}
function loadImageElement(src) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error('image load failed'))
    img.src = src
  })
}
function toJpegName(name) {
  if (!name) return 'device-photo.jpg'
  const dotIndex = name.lastIndexOf('.')
  const baseName = dotIndex > 0 ? name.slice(0, dotIndex) : name
  return `${baseName}.jpg`
}
async function compressImageFile(file) {
  if (!file?.type?.startsWith('image/')) return file
  try {
    const src = await readFileAsDataUrl(file)
    const img = await loadImageElement(src)
    const maxSide = Math.max(img.width, img.height)
    const scale = maxSide > IMAGE_MAX_EDGE ? IMAGE_MAX_EDGE / maxSide : 1
    const targetWidth = Math.max(1, Math.round(img.width * scale))
    const targetHeight = Math.max(1, Math.round(img.height * scale))
    const canvas = document.createElement('canvas')
    canvas.width = targetWidth
    canvas.height = targetHeight
    const ctx = canvas.getContext('2d')
    if (!ctx) return file
    ctx.fillStyle = '#ffffff'
    ctx.fillRect(0, 0, targetWidth, targetHeight)
    ctx.drawImage(img, 0, 0, targetWidth, targetHeight)
    const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', IMAGE_JPEG_QUALITY))
    if (!blob || blob.size >= file.size) return file
    return new File([blob], toJpegName(file.name), { type: 'image/jpeg' })
  } catch {
    return file
  }
}
async function handleImageSelect(slot, e) {
  const input = e.target
  const selectedFile = input?.files?.[0]
  if (!selectedFile) return
  const uploadFile = await compressImageFile(selectedFile)
  const preview = await readFileAsDataUrl(uploadFile)
  if (slot === 2) {
    pendingImage2 = uploadFile
    imagePreview2.value = preview
  } else {
    pendingImage = uploadFile
    imagePreview.value = preview
  }
  if (input) input.value = ''
}
function removeImage(slot) {
  if (slot === 2) {
    imagePreview2.value=''
    pendingImage2=null
    form.imagePath2=''
    form.imageName2=''
    return
  }
  imagePreview.value=''
  pendingImage=null
  form.imagePath=''
  form.imageName=''
}
function handleCertSelect(e) { const f = e.target.files[0]; if (!f) return; pendingCert=f; certInfo.value=f.name }
function removeCert() { certInfo.value=''; pendingCert=null; form.certPath=''; form.certName='' }

async function saveDevice() {
  saving.value = true
  try {
    if (pendingImage) { const r = await deviceApi.uploadFile(pendingImage); form.imagePath=r.data.path; form.imageName=r.data.name }
    if (pendingImage2) { const r = await deviceApi.uploadFile(pendingImage2); form.imagePath2=r.data.path; form.imageName2=r.data.name }
    if (pendingCert)  { const r = await deviceApi.uploadFile(pendingCert);  form.certPath=r.data.path;  form.certName=r.data.name  }
    const payload = { ...form }
    const res = editingId.value ? await deviceApi.update(editingId.value, payload) : await deviceApi.create(payload)
    closeModal()
    if (res.status === 202) {
      showToast(res.data?.message || '申请已提交，等待管理员审核', 'info')
    } else {
      showToast('保存成功')
    }
    loadDevices()
  } catch(e) { showToast(e.response?.data?.message||'保存失败','error') }
  finally { saving.value=false }
}
async function saveQuickEdit() {
  if (!quickEditTarget.value?.id) return
  quickEditSaving.value = true
  try {
    const targetId = quickEditTarget.value.id
    const payload = {
      dept: quickEditForm.dept.trim(),
      responsiblePerson: quickEditForm.responsiblePerson.trim(),
      location: quickEditForm.location.trim(),
      useStatus: quickEditForm.useStatus || '正常',
      cycle: Number(quickEditForm.cycle) || 12,
      calDate: quickEditForm.calDate || '',
      calibrationResult: quickEditForm.calibrationResult || '',
      remark: quickEditForm.remark.trim()
    }
    const res = await deviceApi.update(targetId, payload)
    if (showPreview.value && previewDevice.value?.id === targetId) {
      showPreview.value = false
    }
    closeQuickEdit()
    if (res.status === 202) {
      showToast(res.data?.message || '申请已提交，等待管理员审核', 'info')
    } else {
      showToast('快速修改已保存')
    }
    loadDevices()
  } catch(e) {
    showToast(e.response?.data?.message || '快速修改失败', 'error')
  } finally {
    quickEditSaving.value = false
  }
}
function openPreview(d) { previewDevice.value = d; showPreview.value = true }
function confirmDelete(d) { deleteTarget.value = d; showDeleteConfirm.value = true }
async function doDelete() {
  try {
    const res = await deviceApi.remove(deleteTarget.value.id)
    showDeleteConfirm.value = false
    if (res.status === 202) {
      showToast(res.data?.message || '删除申请已提交，等待管理员审核', 'info')
    } else {
      showToast('已删除')
    }
    loadDevices()
  } catch(e) { showToast(e.response?.data?.message||'删除失败','error') }
}
async function deleteDevice(id) {
  if (!confirm('确定要删除该设备吗？')) return
  try { await deviceApi.remove(id); showToast('已删除'); loadDevices() }
  catch(e) { showToast(e.response?.data?.message||'删除失败','error') }
}
function openBatchEdit(field) {
  batchEditField.value = field
  batchEditValue.value = ''
  showBatchEdit.value = true
}
async function saveBatchEdit() {
  if (!batchEditValue.value.trim()) { showToast('请输入内容', 'error'); return }
  batchEditSaving.value = true
  try {
    const payload = { [batchEditField.value]: batchEditValue.value.trim() }
    await Promise.all(selectedIds.value.map(id => deviceApi.update(id, payload)))
    showToast('已批量更新 ' + selectedIds.value.length + ' 台设备的「' + batchEditLabels[batchEditField.value] + '」')
    showBatchEdit.value = false
    loadDevices()
  } catch(e) { showToast('批量更新失败', 'error') }
  finally { batchEditSaving.value = false }
}
async function deleteSelected() {
  if (!selectedIds.value.length) return
  if (!confirm('确定删除已选中的 ' + selectedIds.value.length + ' 台设备吗？')) return
  try {
    await Promise.all(selectedIds.value.map(id => deviceApi.remove(id)))
    showToast('已删除 ' + selectedIds.value.length + ' 台设备')
    clearSelection()
    loadDevices()
  } catch(e) {
    showToast(e.response?.data?.message || '批量删除失败', 'error')
  }
}
function triggerImport() {
  if (!authStore.canCreate) {
    showToast('无导入权限，请联系管理员开通设备新增权限', 'error')
    return
  }
  importRef.value.click()
}
function runMobileAction(action) {
  showMobileActionSheet.value = false
  action()
}
async function handleImport(e) {
  const f = e.target.files[0]; if (!f) return
  if (!authStore.canCreate) {
    showToast('无导入权限，请联系管理员开通设备新增权限', 'error')
    e.target.value=''
    return
  }
  try { const r = await deviceApi.import(f); showToast(r.data.message||'导入成功'); loadDevices() }
  catch(e) {
    if (e?.response?.status === 403) {
      showToast('无导入权限，请联系管理员开通设备新增权限', 'error')
    } else {
      showToast('导入失败：' + (e.response?.data?.message || e.message), 'error')
    }
  }
  finally { e.target.value='' }
}
async function exportFiltered() {
  try {
    const r = await deviceApi.export({
      search: search.value||undefined,
      dept: filterDept.value||undefined,
      validity: filterValidity.value||undefined,
      useStatus: filterUseStatus.value||undefined
    })
    const url = URL.createObjectURL(r.data)
    Object.assign(document.createElement('a'), { href:url, download:'设备台账.xlsx' }).click()
    URL.revokeObjectURL(url)
  } catch(e) { showToast('导出失败','error') }
}
async function exportAll() {
  try {
    const r = await deviceApi.export({})
    const url = URL.createObjectURL(r.data)
    Object.assign(document.createElement('a'), { href:url, download:'设备台账-全部.xlsx' }).click()
    URL.revokeObjectURL(url)
  } catch(e) { showToast('导出失败','error') }
}
async function downloadTemplate() {
  try {
    const r = await deviceApi.template()
    const url = URL.createObjectURL(r.data)
    Object.assign(document.createElement('a'), { href:url, download:'导入模板.xlsx' }).click()
    URL.revokeObjectURL(url)
  } catch(e) { showToast('下载失败','error') }
}

async function refreshEquipmentPage() {
  await Promise.all([loadDevices(), loadStatuses()])
}

useResumeRefresh(refreshEquipmentPage)

onMounted(async () => {
  restoreEquipmentCache()
  syncViewport()
  window.addEventListener('resize', syncViewport)
  loadDevices(); loadStatuses()
  try { const r = await settingsApi.get(); warningDays.value=r.data.warningDays||315; expiredDays.value=r.data.expiredDays||360 } catch(e) {}
  try {
    const [treeRes, listRes] = await Promise.all([deptApi.tree(), deptApi.list()])
    deptTree.value = Array.isArray(treeRes.data) ? treeRes.data : []
    const fallbackNames = Array.from(
      new Set(
        (Array.isArray(listRes.data) ? listRes.data : [])
          .map(d => (d?.name ?? '').trim())
          .filter(Boolean)
      )
    )
    DEPTS.value = buildAllowedDepartments(deptTree.value, fallbackNames)
    if (filterDept.value && !DEPTS.value.includes(filterDept.value)) {
      filterDept.value = ''
      currentPage.value = 1
      loadDevices()
    }
  } catch(e) {}
})

onUnmounted(() => {
  window.removeEventListener('resize', syncViewport)
})
</script>

<style scoped>
.text-danger { color: var(--danger) !important; }
.text-warning { color: var(--warning) !important; }
.preview-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 10px 20px; margin-top: 8px;
}
.preview-item { display: flex; flex-direction: column; gap: 2px; }
.preview-label { font-size: 11.5px; color: var(--text-muted); }
.preview-val { font-size: 13.5px; color: var(--text); }
.equipment-filter-bar { margin-bottom: 0; }
.equipment-results-bar { margin-top: -2px; }
.page-results-chip-use-normal {
  background: #ecfdf3;
  color: #059669;
  border-color: #a7f3d0;
}
.page-results-chip-use-fault {
  background: #fffbeb;
  color: #b45309;
  border-color: #fcd34d;
}
.page-results-chip-use-scrap {
  background: #fef2f2;
  color: #dc2626;
  border-color: #fca5a5;
}
.page-results-chip-use-other {
  background: #f8fafc;
  color: #64748b;
  border-color: #cbd5e1;
}
.equipment-mobile-query-head { gap: 8px; }
.equipment-mobile-query-actions {
  justify-content: flex-end;
  gap: 6px;
}
.equipment-mobile-query-actions > * {
  flex: 0 0 auto !important;
}
.equipment-mobile-query-actions :deep(.el-button) {
  min-height: 32px;
  padding: 0 12px;
  border-radius: 10px;
  font-size: 12.5px;
  margin-left: 0;
}
.equipment-mobile-query-actions :deep(.el-button.is-primary) {
  box-shadow: 0 8px 18px rgba(37, 99, 235, 0.18);
}
.mobile-tools-trigger {
  width: 100%;
  border-radius: 12px;
  background: linear-gradient(135deg, #ffffff, #f8fbff);
  border-color: #dbeafe;
}
.mobile-tools-sheet {
  max-width: min(420px, 96vw);
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.72), transparent 28%),
    linear-gradient(180deg, #ffffff, #f8fbff);
  border: 1px solid rgba(191, 219, 254, 0.9);
}
.mobile-tools-sheet-handle {
  width: 48px;
  height: 5px;
  border-radius: 999px;
  background: rgba(148, 163, 184, 0.4);
  margin: 10px auto 2px;
}
.mobile-tools-sheet-eyebrow {
  display: inline-flex;
  align-items: center;
  margin-bottom: 8px;
  padding: 4px 9px;
  border-radius: 999px;
  background: rgba(37, 99, 235, 0.1);
  color: #1d4ed8;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.mobile-tools-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
.mobile-tools-btn {
  width: 100%;
  min-height: 72px;
  justify-content: flex-start;
  align-items: flex-start;
  flex-direction: column;
  gap: 6px;
  padding: 12px 13px;
  border-radius: 16px;
  background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(248,250,252,0.98));
  border-color: #dbe3ef;
  transition: transform 0.18s, box-shadow 0.18s, border-color 0.18s;
}
.mobile-tools-btn:hover {
  transform: translateY(-1px);
  border-color: #bfdbfe;
  box-shadow: 0 12px 24px rgba(37, 99, 235, 0.12);
}
.mobile-tools-btn:active {
  transform: scale(0.985);
  box-shadow: 0 6px 14px rgba(37, 99, 235, 0.10);
}
.mobile-tools-btn-title {
  font-size: 13px;
  font-weight: 800;
  color: #0f172a;
}
.mobile-tools-btn-desc {
  font-size: 11.5px;
  line-height: 1.45;
  color: #64748b;
  text-align: left;
}
.mobile-tools-btn-wide {
  grid-column: 1 / -1;
}

.mobile-sheet-pop-enter-active,
.mobile-sheet-pop-leave-active {
  transition: opacity 0.22s ease;
}

.mobile-sheet-pop-enter-active .mobile-tools-sheet,
.mobile-sheet-pop-leave-active .mobile-tools-sheet {
  transition: transform 0.28s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.22s ease;
}

.mobile-sheet-pop-enter-from,
.mobile-sheet-pop-leave-to {
  opacity: 0;
}

.mobile-sheet-pop-enter-from .mobile-tools-sheet,
.mobile-sheet-pop-leave-to .mobile-tools-sheet {
  transform: translateY(24px) scale(0.985);
  opacity: 0.9;
}
.equipment-mobile-card {
  padding: 10px 12px;
  margin-bottom: 10px;
  border-radius: 14px;
}
.equipment-mobile-card-head {
  margin-bottom: 6px;
  align-items: center;
  gap: 8px;
}
.equipment-mobile-card-title-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1;
}
.equipment-mobile-card .m-card-title {
  font-size: 14px;
  line-height: 1.3;
  -webkit-line-clamp: 1;
}
.equipment-mobile-validity,
.equipment-mobile-status {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 999px;
}
.equipment-mobile-meta {
  gap: 5px 10px;
  margin-bottom: 8px;
}
.equipment-mobile-meta-item {
  gap: 3px;
  font-size: 11.5px;
  line-height: 1.3;
}
.equipment-mobile-meta-item-span {
  grid-column: 1 / -1;
}
.equipment-mobile-meta-label {
  color: var(--text-muted);
  flex-shrink: 0;
}
.equipment-mobile-meta-item b {
  font-size: 12px;
  font-weight: 700;
  color: var(--text);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.equipment-mobile-card-footer {
  padding-top: 8px;
  gap: 8px;
  align-items: center;
}
.equipment-mobile-card-kpi {
  gap: 6px;
}
.equipment-mobile-mini-link {
  font-size: 12px !important;
}
.equipment-mobile-thumb {
  width: 26px;
  height: 26px;
  object-fit: cover;
  border-radius: 6px;
  border: 1px solid var(--border);
  cursor: pointer;
}
.equipment-mobile-actions {
  width: auto;
  margin-left: auto;
  gap: 6px;
}
.equipment-mobile-actions .action-btn {
  min-height: 28px;
  padding: 5px 10px;
  font-size: 12px;
  border-radius: 10px;
}
.quick-edit-modal {
  max-width: min(520px, 96vw);
}
.quick-edit-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.quick-edit-intro {
  padding: 10px 12px;
  border-radius: 10px;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 13px;
  line-height: 1.6;
}
.device-image-section {
  width: 100%;
}
.device-image-note {
  margin-bottom: 10px;
  color: var(--text-muted);
  font-size: 12px;
  line-height: 1.5;
}
.device-image-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}
.device-image-slot {
  border: 1.5px dashed #cbd5e1;
  border-radius: 14px;
  background: linear-gradient(180deg, #fbfdff 0%, #f8fafc 100%);
  padding: 10px;
}
.device-image-slot-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 10px;
}
.device-image-slot-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--text);
}
.device-image-slot-tip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  background: #eff6ff;
  color: #2563eb;
  font-size: 11px;
}
.device-image-picker {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  gap: 10px;
  min-height: 150px;
  padding: 12px;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  background: #fff;
}
.device-image-picker.filled {
  justify-content: flex-start;
}
.device-image-picker .preview-area {
  width: 100%;
  margin-top: 0;
  justify-content: center;
}
.device-preview-img {
  width: 100%;
  max-width: 126px;
  aspect-ratio: 1 / 1;
  height: auto;
  object-fit: cover;
}
.device-remove-chip {
  cursor: pointer;
  color: var(--danger);
}
.device-image-empty {
  font-size: 12px;
  color: var(--text-muted);
  text-align: center;
  line-height: 1.5;
}
.device-image-button {
  width: 100%;
  justify-content: center;
  margin: 0;
}
.device-image-button span {
  white-space: nowrap;
}
.quick-edit-grid {
  grid-template-columns: 1fr 1fr;
}
.quick-edit-footer .btn-ghost {
  border-color: var(--border);
  background: white;
}
.mobile-form-steps-wrap {
  position: sticky;
  top: -2px;
  z-index: 2;
  padding: 10px 0 8px;
  background: linear-gradient(180deg, #fff, rgba(255,255,255,0.92));
}
.mobile-form-steps {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
}
.mobile-form-step {
  border: 1px solid var(--border);
  border-radius: 10px;
  background: #fff;
  color: var(--text-muted);
  font-size: 12px;
  font-weight: 700;
  padding: 8px 0;
}
.mobile-form-step.active {
  color: var(--primary);
  border-color: #bfdbfe;
  background: #eff6ff;
}
.mobile-form-step-hint {
  margin-top: 8px;
  font-size: 12px;
  color: var(--text-muted);
  text-align: center;
}
.batch-bar {
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:12px;
  padding:10px 14px;
  margin-bottom:12px;
  background:#fff;
  border:1px solid var(--border);
  border-radius:12px;
}
.batch-info { color:var(--text-muted); font-size:13px; }
.batch-actions { display:flex; gap:8px; flex-wrap:wrap; }
.device-form-tabs :deep(.el-tabs__header) { padding: 0 24px; margin-bottom: 0; }
.device-form-tabs :deep(.el-tabs__content) { padding: 0 24px 8px; }
.dept-select :deep(.el-select__selected-item),
.dept-select :deep(.el-input__inner) {
  color: var(--text) !important;
  -webkit-text-fill-color: var(--text) !important;
}
.modal-close-danger {
  background: #fff1f2;
  color: var(--danger);
  border: 1px solid #fecdd3;
}
.modal-close-danger:hover {
  background: #fee2e2;
  border-color: #fca5a5;
  color: #b91c1c;
}

@media (max-width: 768px) {
  .mobile-filter-hidden { display: none; }
  .equipment-filter-bar.mobile-filter-hidden { display: none !important; }

  .equipment-filter-bar {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 8px;
    padding: 8px 10px;
    align-items: end;
  }

  .equipment-filter-bar .filter-group {
    min-width: 0;
    width: auto;
    gap: 4px;
  }

  .equipment-filter-bar .filter-label {
    font-size: 11.5px;
    margin-bottom: 0;
  }

  .equipment-filter-bar :deep(.el-select),
  .equipment-filter-bar :deep(.el-input) {
    width: 100% !important;
  }

  .equipment-filter-bar :deep(.el-input__wrapper) {
    min-height: 34px;
    padding: 0 10px;
  }

  .batch-bar {
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
  }

  .equipment-filter-actions {
    width: 100%;
    grid-column: 1 / -1;
    padding-top: 4px;
    margin-top: 2px;
  }

  .equipment-filter-actions :deep(.el-button) {
    flex: 1 1 calc(33.333% - 4px);
    margin-left: 0;
    min-height: 32px;
    font-size: 12px;
    padding-left: 10px;
    padding-right: 10px;
  }

  .equipment-results-bar {
    margin-top: -4px;
  }

  .equipment-mobile-card {
    padding: 9px 11px;
    border-radius: 13px;
  }

  .equipment-mobile-meta {
    grid-template-columns: 1fr 1fr;
  }

  .mobile-tools-grid {
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }

  .batch-actions :deep(.el-button) {
    flex: 1 1 calc(50% - 4px);
    margin-left: 0;
  }

  .device-form-tabs :deep(.el-tabs__header) {
    display: none;
  }

  .device-form-tabs :deep(.el-tabs__nav-wrap) {
    overflow-x: auto;
    scrollbar-width: none;
  }

  .device-form-tabs :deep(.el-tabs__nav-wrap::-webkit-scrollbar) {
    display: none;
  }

  .device-form-tabs :deep(.el-tabs__item) {
    padding: 0 12px;
    font-size: 14px;
    white-space: nowrap;
  }

  .device-form-tabs :deep(.el-tabs__content) {
    padding: 0 12px 8px;
  }

  .quick-edit-grid {
    grid-template-columns: 1fr;
  }

  .device-image-grid {
    gap: 10px;
  }

  .device-image-slot {
    padding: 8px;
    border-radius: 12px;
  }

  .device-image-picker {
    min-height: 136px;
    padding: 10px;
  }

  .device-preview-img {
    max-width: 100px;
  }

  .quick-edit-footer {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .quick-edit-footer .btn:last-child {
    grid-column: span 2;
  }

  .modal-footer.mobile-device-footer {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
  }

  .modal-footer.mobile-device-footer .btn {
    width: 100%;
    justify-content: center;
  }

  .device-form-tabs :deep(.el-row) {
    margin-left: 0 !important;
    margin-right: 0 !important;
  }

  .device-form-tabs :deep(.el-row > .el-col) {
    padding-left: 0 !important;
    padding-right: 0 !important;
  }

  .device-form-tabs :deep(.el-col-12) {
    max-width: 100%;
    flex: 0 0 100%;
  }

  .device-form-tabs :deep(.el-form-item) {
    display: block;
    margin-bottom: 14px;
  }

  .device-form-tabs :deep(.el-form-item__label) {
    display: block;
    width: 100% !important;
    height: auto;
    line-height: 1.4;
    text-align: left;
    padding: 0 0 6px;
  }

  .device-form-tabs :deep(.el-form-item__content) {
    margin-left: 0 !important;
    width: 100%;
    min-height: 0;
  }

  .device-form-tabs :deep(.el-input-number),
  .device-form-tabs :deep(.el-date-editor.el-input),
  .device-form-tabs :deep(.el-select),
  .device-form-tabs :deep(.el-input) {
    width: 100% !important;
  }

  .modal-footer {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .modal-footer .btn {
    width: 100%;
    justify-content: center;
  }
}

@media (max-width: 480px) {
  .equipment-filter-bar {
    gap: 7px;
    padding: 8px;
  }

  .equipment-mobile-card {
    padding: 8px 10px;
  }

  .equipment-mobile-meta {
    gap: 4px 8px;
  }

  .equipment-mobile-actions .action-btn {
    padding: 5px 8px;
    min-height: 27px;
    font-size: 11.5px;
  }

  .mobile-tools-grid {
    grid-template-columns: 1fr;
  }

  .mobile-tools-btn-wide {
    grid-column: auto;
  }

  .equipment-filter-actions :deep(.el-button) {
    flex: 1 1 calc(50% - 4px);
  }

  .mobile-form-steps {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .modal-footer.mobile-device-footer {
    grid-template-columns: 1fr 1fr;
  }

  .modal-footer.mobile-device-footer .btn:last-child {
    grid-column: span 2;
  }

  .device-form-tabs :deep(.el-tabs__item) {
    padding: 0 10px;
    font-size: 13px;
  }
}

.equipment-filter-bar {
  border-radius: 22px;
  border: 1px solid rgba(191, 219, 254, 0.88);
  background:
    radial-gradient(circle at top right, rgba(219, 234, 254, 0.72), transparent 28%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
}

.equipment-results-bar {
  padding-block: 14px;
}

.batch-bar {
  border-radius: 18px;
  border: 1px solid rgba(226, 232, 240, 0.92);
  background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.95));
  box-shadow: 0 14px 30px rgba(15, 23, 42, 0.05);
}

.batch-info b {
  color: #0f172a;
}

.equipment-mobile-card {
  border-radius: 20px;
  border: 1px solid rgba(226, 232, 240, 0.92);
  background:
    radial-gradient(circle at top right, rgba(239, 246, 255, 0.62), transparent 24%),
    linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  box-shadow: 0 14px 32px rgba(15, 23, 42, 0.06);
}

.equipment-mobile-card .m-card-title {
  font-size: 15px;
  font-weight: 800;
  color: #0f172a;
}

.equipment-mobile-meta-item {
  padding: 8px 10px;
  border-radius: 12px;
  background: rgba(248, 250, 252, 0.88);
}

.equipment-mobile-actions .action-btn {
  min-height: 32px;
  border-radius: 12px;
}

.quick-edit-modal {
  border-radius: 24px;
}

.quick-edit-body .form-group {
  gap: 6px;
}

@media (max-width: 768px) {
  .equipment-filter-bar {
    border-radius: 18px;
  }
}

.equipment-results-bar .page-results-chip {
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.72), 0 10px 18px rgba(15, 23, 42, 0.04);
}

.equipment-results-bar .page-results-chip-strong {
  background: linear-gradient(135deg, rgba(37,99,235,0.16), rgba(219,234,254,0.92));
}

.table-wrap .table-scroll table tbody tr:hover {
  background: rgba(239, 246, 255, 0.62);
}

.action-group .action-btn,
.equipment-mobile-actions .action-btn {
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.72), 0 8px 18px rgba(15, 23, 42, 0.06);
}

.page-pagination {
  margin-top: 18px;
  padding: 14px 18px;
  border-radius: 20px;
  border: 1px solid rgba(226, 232, 240, 0.94);
  background: linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.95));
  box-shadow: 0 14px 30px rgba(15, 23, 42, 0.05);
}

.modal-box.modal-lg {
  box-shadow: 0 28px 70px rgba(15, 23, 42, 0.18);
}


.module-hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  margin-bottom: 16px;
  padding: 22px 24px;
  border-radius: 28px;
  border: 1px solid rgba(191, 219, 254, 0.82);
  background: radial-gradient(circle at top right, rgba(219, 234, 254, 0.82), transparent 28%), linear-gradient(180deg, rgba(255,255,255,0.98), rgba(248,250,252,0.96));
  box-shadow: 0 24px 60px rgba(15, 23, 42, 0.08);
}
.module-hero-eyebrow { display:inline-flex; align-items:center; min-height:28px; padding:0 12px; border-radius:999px; background:rgba(37,99,235,0.1); color:#2563eb; font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase; }
.module-hero-title { margin:14px 0 8px; font-size:30px; line-height:1.12; color:#0f172a; }
.module-hero-desc { margin:0; max-width:760px; color:#64748b; line-height:1.7; }
.module-hero-pills { display:flex; flex-wrap:wrap; justify-content:flex-end; gap:10px; min-width:240px; }
.module-hero-pill { display:inline-flex; align-items:center; min-height:38px; padding:0 16px; border-radius:999px; font-size:13px; font-weight:700; border:1px solid transparent; }
.module-hero-pill.strong { color:#2563eb; background:rgba(219,234,254,0.78); border-color:rgba(147,197,253,0.9); }
.module-hero-pill.success { color:#047857; background:rgba(209,250,229,0.92); border-color:rgba(110,231,183,0.9); }
.module-hero-pill.warning { color:#b45309; background:rgba(254,243,199,0.95); border-color:rgba(252,211,77,0.9); }
.module-hero-pill.danger { color:#b91c1c; background:rgba(254,226,226,0.95); border-color:rgba(252,165,165,0.9); }
.module-hero-pill.neutral { color:#475569; background:rgba(241,245,249,0.96); border-color:rgba(226,232,240,0.96); }
@media (max-width: 768px) {
  .module-hero { flex-direction:column; padding:18px; border-radius:22px; }
  .module-hero-title { font-size:24px; }
  .module-hero-pills { justify-content:flex-start; min-width:0; }
}
</style>

