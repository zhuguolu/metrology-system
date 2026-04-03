<template>
  <div class="settings-page">
    <div class="settings-shell">
      <div class="settings-column">
        <section class="settings-panel settings-panel-account">
          <div class="panel-header">
            <div>
              <div class="panel-kicker">Account</div>
              <h3>账户安全</h3>
            </div>
          </div>

          <div class="form-stack">
            <div class="form-group">
              <label class="form-label">当前用户名</label>
              <input :value="authStore.username" class="input-readonly" readonly style="width:100%" />
            </div>

            <div class="form-group">
              <label class="form-label">修改用户名</label>
              <input v-model="newUsername" placeholder="输入新用户名，留空则不修改" style="width:100%" />
            </div>

            <div class="divider"></div>

            <div class="form-group">
              <label class="form-label">当前密码</label>
              <input v-model="oldPw" type="password" placeholder="请输入当前密码" style="width:100%" />
            </div>

            <div class="form-group">
              <label class="form-label">新密码</label>
              <input v-model="newPw" type="password" placeholder="输入新密码，留空则不修改" style="width:100%" />
            </div>

            <div class="form-group">
              <label class="form-label">确认新密码</label>
              <input v-model="confirmPw" type="password" placeholder="请再次输入新密码" style="width:100%" />
            </div>

            <div class="panel-actions">
              <button class="btn btn-primary" @click="updateAccount">保存账号信息</button>
            </div>
          </div>
        </section>

        <section v-if="authStore.isAdmin" class="settings-panel settings-panel-admin">
          <div class="panel-header">
            <div>
              <div class="panel-kicker">Admin</div>
              <h3>系统维护</h3>
            </div>
            <div class="panel-badge">管理员</div>
          </div>

          <div class="admin-grid">
            <article class="module-card module-card-accent">
              <div class="module-head">
                <div class="module-icon">校</div>
                <div>
                  <h4>校准参数</h4>
                  <p>控制设备到期预警与失效判定规则。</p>
                </div>
              </div>

              <div class="form-stack">
                <div class="form-group">
                  <label class="form-label">即将过期预警天数</label>
                  <input v-model.number="settings.warningDays" type="number" min="1" style="width:100%" />
                  <span class="form-hint">达到这个天数后，设备会显示为“即将过期”。</span>
                </div>

                <div class="form-group">
                  <label class="form-label">失效判定天数</label>
                  <input v-model.number="settings.expiredDays" type="number" min="1" style="width:100%" />
                  <span class="form-hint">超过这个天数后，设备会显示为“失效”。</span>
                </div>

                <div class="panel-actions">
                  <button class="btn btn-primary" @click="saveSettings">保存校准参数</button>
                </div>
              </div>
            </article>

            <article class="module-card module-card-soft">
              <div class="module-head">
                <div class="module-icon maintenance">维</div>
                <div>
                  <h4>系统维护</h4>
                  <p>每天 23:00 自动导出台账并备份数据库，文件落到 CMS 目录。</p>
                </div>
              </div>

              <div class="maintenance-stack">
                <div class="toggle-card">
                  <div class="toggle-main">
                    <div>
                      <div class="toggle-title">自动导出台账</div>
                      <div class="toggle-desc">每天晚上 23:00 覆盖生成最新台账文件。</div>
                    </div>
                    <label class="switch">
                      <input v-model="settings.autoLedgerExportEnabled" type="checkbox" />
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                  <div class="path-box">
                    <div class="path-label">输出文件</div>
                    <div class="path-value">{{ settings.ledgerExportPath || '未配置' }}</div>
                  </div>
                </div>

                <div class="toggle-card">
                  <div class="toggle-main">
                    <div>
                      <div class="toggle-title">自动备份数据库</div>
                      <div class="toggle-desc">每天晚上 23:00 生成可恢复的 SQL 备份。</div>
                    </div>
                    <label class="switch">
                      <input v-model="settings.databaseBackupEnabled" type="checkbox" />
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                  <div class="path-box">
                    <div class="path-label">输出文件</div>
                    <div class="path-value">{{ settings.databaseBackupPath || '未配置' }}</div>
                  </div>
                </div>

                <div class="cms-box">
                  <div class="path-label">CMS 挂载目录</div>
                  <input :value="settings.cmsRootPath" class="input-readonly" readonly style="width:100%" />
                  <span class="form-hint">自动导出和数据库备份都会写入这个容器目录对应的极空间 CMS 文件夹。</span>
                </div>

                <div class="panel-actions panel-actions-wrap">
                  <button class="btn btn-primary" @click="saveSettings">保存系统维护</button>
                  <button class="btn btn-outline" @click="runMaintenanceNow">立即执行一次</button>
                </div>
              </div>
            </article>
          </div>
        </section>

        <section class="settings-panel info-panel">
          <div class="panel-header">
            <div>
              <div class="panel-kicker">Info</div>
              <h3>系统信息</h3>
            </div>
          </div>

          <div class="info-grid">
            <div class="info-item">
              <span>当前登录</span>
              <strong>{{ authStore.username }}</strong>
            </div>
            <div class="info-item">
              <span>账号角色</span>
              <strong>{{ authStore.isAdmin ? '管理员' : '普通用户' }}</strong>
            </div>
            <div v-if="authStore.isAdmin" class="info-tip">
              自动维护会在每天 23:00 执行，导出台账和数据库备份均为固定文件名覆盖写入，便于在极空间直接取最新版本。
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { authApi, settingsApi } from '../api/index.js'
import { useAuthStore } from '../stores/auth.js'

const showToast = inject('showToast')
const router = useRouter()
const authStore = useAuthStore()

const newUsername = ref('')
const oldPw = ref('')
const newPw = ref('')
const confirmPw = ref('')

const settings = reactive({
  warningDays: 315,
  expiredDays: 360,
  autoLedgerExportEnabled: false,
  databaseBackupEnabled: false,
  cmsRootPath: '',
  ledgerExportPath: '',
  databaseBackupPath: '',
})

async function updateAccount() {
  const nextUsername = newUsername.value.trim()
  if (!oldPw.value) {
    showToast('请输入当前密码', 'error')
    return
  }
  if (newPw.value && newPw.value !== confirmPw.value) {
    showToast('两次输入的新密码不一致', 'error')
    return
  }

  try {
    if (newPw.value) {
      await authApi.changePassword({ oldPassword: oldPw.value, newPassword: newPw.value })
      showToast('密码修改成功')
    }

    if (nextUsername && nextUsername !== authStore.username) {
      const response = await authApi.changeUsername({ newUsername: nextUsername })
      authStore.updateFromResponse(response.data)
      showToast('用户名已修改，请重新登录')
      setTimeout(() => {
        authStore.logout()
        router.push('/login')
      }, 1800)
      return
    }

    oldPw.value = ''
    newPw.value = ''
    confirmPw.value = ''
    newUsername.value = ''
  } catch (error) {
    showToast(error.response?.data?.message || '操作失败', 'error')
  }
}

async function saveSettings() {
  try {
    const response = await settingsApi.save({
      warningDays: settings.warningDays,
      expiredDays: settings.expiredDays,
      autoLedgerExportEnabled: settings.autoLedgerExportEnabled,
      databaseBackupEnabled: settings.databaseBackupEnabled,
    })
    applySettings(response.data)
    showToast('系统设置已保存')
  } catch (error) {
    showToast(error.response?.data?.message || '保存失败', 'error')
  }
}

async function runMaintenanceNow() {
  try {
    const response = await settingsApi.runMaintenance()
    const data = response.data || {}
    const messages = []
    if (data.ledgerExported) messages.push('台账导出完成')
    if (data.databaseBackedUp) messages.push('数据库备份完成')
    showToast(messages.length ? messages.join('，') : (data.message || '执行完成'))
  } catch (error) {
    showToast(error.response?.data?.message || '执行失败', 'error')
  }
}

function applySettings(data = {}) {
  settings.warningDays = data.warningDays ?? 315
  settings.expiredDays = data.expiredDays ?? 360
  settings.autoLedgerExportEnabled = !!data.autoLedgerExportEnabled
  settings.databaseBackupEnabled = !!data.databaseBackupEnabled
  settings.cmsRootPath = data.cmsRootPath || ''
  settings.ledgerExportPath = data.ledgerExportPath || ''
  settings.databaseBackupPath = data.databaseBackupPath || ''
}

onMounted(async () => {
  try {
    const response = await settingsApi.get()
    applySettings(response.data)
  } catch (error) {
    // noop
  }
})
</script>

<style scoped>
.settings-page {
  width: 100%;
  display: flex;
  justify-content: flex-start;
  padding: 6px 0 32px;
  box-sizing: border-box;
}

.settings-shell {
  width: 100%;
  max-width: 1280px;
  display: flex;
  justify-content: flex-start;
  margin: 0 auto 0 0;
  padding: 0 18px;
  box-sizing: border-box;
}

.settings-column {
  width: 100%;
  max-width: 980px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  margin: 0;
  align-items: stretch;
}

.settings-panel {
  width: 100%;
  margin: 0;
  background:
    radial-gradient(circle at top right, rgba(96, 165, 250, 0.1), transparent 28%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(248, 250, 252, 0.96));
  border: 1px solid rgba(226, 232, 240, 0.92);
  border-radius: 24px;
  padding: 24px;
  box-shadow: 0 18px 40px rgba(148, 163, 184, 0.12);
}

.settings-column > .settings-panel:first-child,
.settings-column > .info-panel {
  max-width: 100%;
  margin-left: 0;
}

.settings-panel-admin {
  background:
    radial-gradient(circle at top right, rgba(56, 189, 248, 0.14), transparent 24%),
    radial-gradient(circle at bottom left, rgba(34, 197, 94, 0.09), transparent 26%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(248, 250, 252, 0.98));
}

.settings-panel-account {
  background:
    radial-gradient(circle at top right, rgba(59, 130, 246, 0.14), transparent 24%),
    radial-gradient(circle at bottom left, rgba(45, 212, 191, 0.1), transparent 28%),
    linear-gradient(180deg, rgba(239, 246, 255, 0.96), rgba(255, 255, 255, 0.98));
  border-color: rgba(191, 219, 254, 0.95);
}

.settings-panel-account .panel-kicker {
  color: #4f46e5;
}

.settings-panel-account .form-stack {
  gap: 18px;
}

.settings-panel-account .form-group {
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.72);
  border: 1px solid rgba(219, 234, 254, 0.95);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.75);
}

.settings-panel-account .divider {
  height: 1px;
  margin: 2px 6px;
  background: linear-gradient(90deg, transparent, rgba(125, 211, 252, 0.95), rgba(167, 243, 208, 0.95), transparent);
}

.settings-panel-account .panel-actions {
  margin-top: 4px;
}

.settings-panel-account .btn-primary {
  background: linear-gradient(135deg, #2563eb, #14b8a6);
  box-shadow: 0 14px 30px rgba(37, 99, 235, 0.2);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

.panel-header h3 {
  margin: 4px 0 0;
  font-size: 24px;
  line-height: 1.2;
  color: #0f172a;
}

.panel-kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #64748b;
}

.panel-badge {
  padding: 8px 14px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  color: #0f766e;
  background: rgba(204, 251, 241, 0.9);
  border: 1px solid rgba(153, 246, 228, 0.9);
}

.form-stack,
.maintenance-stack {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.divider {
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(203, 213, 225, 0.9), transparent);
}

.admin-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 18px;
  justify-content: stretch;
}

.module-card {
  border-radius: 22px;
  padding: 20px;
  border: 1px solid rgba(226, 232, 240, 0.92);
}

.module-card-accent {
  background: linear-gradient(180deg, rgba(239, 246, 255, 0.98), rgba(255, 255, 255, 0.96));
}

.module-card-soft {
  background: linear-gradient(180deg, rgba(240, 253, 244, 0.78), rgba(255, 255, 255, 0.98));
}

.module-head {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  margin-bottom: 18px;
}

.module-head h4 {
  margin: 0;
  font-size: 20px;
  color: #0f172a;
}

.module-head p {
  margin: 6px 0 0;
  color: #64748b;
  line-height: 1.6;
  font-size: 14px;
}

.module-icon {
  width: 44px;
  height: 44px;
  border-radius: 14px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  color: #1d4ed8;
  background: linear-gradient(135deg, rgba(191, 219, 254, 0.95), rgba(219, 234, 254, 0.98));
  box-shadow: 0 10px 22px rgba(59, 130, 246, 0.16);
}

.module-icon.maintenance {
  color: #047857;
  background: linear-gradient(135deg, rgba(187, 247, 208, 0.95), rgba(220, 252, 231, 0.98));
  box-shadow: 0 10px 22px rgba(34, 197, 94, 0.15);
}

.toggle-card,
.cms-box {
  background: rgba(255, 255, 255, 0.78);
  border: 1px solid rgba(226, 232, 240, 0.9);
  border-radius: 18px;
  padding: 16px;
}

.toggle-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
}

.toggle-title {
  font-size: 16px;
  font-weight: 700;
  color: #0f172a;
}

.toggle-desc {
  margin-top: 4px;
  color: #64748b;
  line-height: 1.6;
  font-size: 14px;
}

.path-box {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px dashed rgba(203, 213, 225, 0.9);
}

.path-label {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #64748b;
  margin-bottom: 6px;
}

.path-value {
  font-size: 14px;
  line-height: 1.6;
  color: #0f172a;
  word-break: break-all;
}

.switch {
  position: relative;
  display: inline-flex;
  width: 58px;
  height: 32px;
  flex-shrink: 0;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.switch-slider {
  position: absolute;
  inset: 0;
  cursor: pointer;
  border-radius: 999px;
  background: #cbd5e1;
  transition: all 0.22s ease;
}

.switch-slider::before {
  content: '';
  position: absolute;
  left: 4px;
  top: 4px;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 6px 16px rgba(15, 23, 42, 0.18);
  transition: all 0.22s ease;
}

.switch input:checked + .switch-slider {
  background: linear-gradient(135deg, #2563eb, #22c55e);
}

.switch input:checked + .switch-slider::before {
  transform: translateX(26px);
}

.panel-actions {
  display: flex;
  gap: 12px;
  align-items: center;
}

.panel-actions-wrap {
  flex-wrap: wrap;
}

.info-panel {
  background:
    radial-gradient(circle at top right, rgba(191, 219, 254, 0.22), transparent 22%),
    linear-gradient(135deg, rgba(239, 246, 255, 0.94), rgba(240, 253, 244, 0.9));
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 16px 18px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.66);
  border: 1px solid rgba(226, 232, 240, 0.85);
}

.info-item span {
  font-size: 13px;
  color: #64748b;
}

.info-item strong {
  font-size: 18px;
  color: #0f172a;
}

.info-tip {
  grid-column: 1 / -1;
  padding: 16px 18px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.66);
  border: 1px solid rgba(226, 232, 240, 0.85);
  color: #334155;
  line-height: 1.7;
}

@media (max-width: 960px) {
  .admin-grid,
  .info-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .settings-page {
    padding: 0 0 22px;
  }

  .settings-shell {
    padding: 0 8px;
  }

  .settings-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .panel-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .toggle-main {
    align-items: flex-start;
  }

  .module-card {
    padding: 16px;
  }

  .panel-actions {
    width: 100%;
    flex-direction: column;
  }

  .panel-actions .btn {
    width: 100%;
  }
}
</style>
