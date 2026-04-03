<template>
  <div class="login-page">
    <div class="login-stage">
      <section class="login-hero">
        <div class="hero-grid"></div>
        <div class="hero-rings hero-rings-main"></div>
        <div class="hero-rings hero-rings-sub"></div>
        <div class="hero-axis hero-axis-x"></div>
        <div class="hero-axis hero-axis-y"></div>
        <div class="hero-glow hero-glow-a"></div>
        <div class="hero-glow hero-glow-b"></div>

        <div class="hero-content">
          <div class="hero-badge">Precision · Traceability · Calibration</div>
          <div class="hero-kicker">Metrology Workflow Hub</div>
          <h1 class="hero-title">计量管理系统</h1>
          <p class="hero-desc">设备、校准、审核与资料统一归集。</p>
        </div>
      </section>

      <section class="login-panel">
        <div class="login-panel-shell">
          <div class="login-brand">
            <div class="brand-icon">
              <span class="brand-icon-core"></span>
            </div>
            <div class="brand-text">
              <div class="brand-name">计量管理系统</div>
              <div class="brand-sub">Calibration Management System</div>
            </div>
          </div>

          <div class="login-copy">
            <div class="login-copy-title">欢迎回来</div>
            <div class="login-copy-desc">登录后继续处理设备校准与数据资料。</div>
          </div>

          <form @submit.prevent="submit" class="login-form">
            <div class="field">
              <label class="field-label">用户名</label>
              <div class="field-wrap">
                <svg class="field-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                <input
                  v-model="form.username"
                  type="text"
                  placeholder="请输入用户名"
                  required
                  autocomplete="username"
                  class="field-input"
                />
              </div>
            </div>

            <div class="field">
              <label class="field-label">密码</label>
              <div class="field-wrap">
                <svg class="field-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                <input
                  v-model="form.password"
                  :type="showPw ? 'text' : 'password'"
                  placeholder="请输入密码"
                  required
                  autocomplete="current-password"
                  class="field-input"
                />
                <button type="button" class="pw-toggle" @click="showPw = !showPw" tabindex="-1">
                  <svg v-if="!showPw" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                  <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
                </button>
              </div>
            </div>

            <div v-if="error" class="error-msg">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
              {{ error }}
            </div>

            <button type="submit" class="submit-btn" :disabled="loading">
              <span v-if="loading" class="spinner"></span>
              {{ loading ? '登录中...' : '登 录' }}
            </button>
          </form>

          <div class="login-footer-hint">如需注册账号，请联系管理员</div>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const error = ref('')
const showPw = ref(false)
const form = reactive({ username: '', password: '' })

async function submit() {
  error.value = ''
  if (!form.username.trim()) {
    error.value = '请输入用户名'
    return
  }
  if (!form.password) {
    error.value = '请输入密码'
    return
  }
  loading.value = true
  try {
    await authStore.login({ username: form.username, password: form.password })
    router.push('/dashboard')
  } catch (e) {
    error.value = e.response?.data?.message || '用户名或密码错误'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  width: 100%;
  flex: 1 1 auto;
  min-height: 100vh;
  min-height: 100dvh;
  padding: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background:
    radial-gradient(circle at 16% 18%, rgba(93, 173, 255, 0.22), transparent 22%),
    radial-gradient(circle at 84% 16%, rgba(45, 212, 191, 0.16), transparent 18%),
    radial-gradient(circle at 50% 100%, rgba(37, 99, 235, 0.18), transparent 28%),
    linear-gradient(135deg, #08111f 0%, #0d1f38 38%, #0b2d55 68%, #061426 100%);
}

.login-stage {
  position: relative;
  width: min(980px, 100%);
  min-height: min(680px, calc(100vh - 48px));
  min-height: min(680px, calc(100dvh - 48px));
  margin: 0 auto;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(360px, 408px);
  border-radius: 32px;
  overflow: hidden;
  border: 1px solid rgba(148, 163, 184, 0.22);
  background: rgba(7, 18, 34, 0.34);
  box-shadow:
    0 36px 90px rgba(2, 8, 23, 0.5),
    inset 0 1px 0 rgba(255, 255, 255, 0.08);
  backdrop-filter: blur(16px);
}

.login-hero {
  position: relative;
  overflow: hidden;
  padding: 44px;
  background:
    linear-gradient(160deg, rgba(7, 23, 45, 0.82), rgba(10, 35, 66, 0.58)),
    radial-gradient(circle at top right, rgba(59, 130, 246, 0.22), transparent 32%);
  display: flex;
  align-items: center;
}

.hero-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(148, 163, 184, 0.08) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 163, 184, 0.08) 1px, transparent 1px);
  background-size: 28px 28px;
  mask-image: linear-gradient(180deg, rgba(0, 0, 0, 0.95), rgba(0, 0, 0, 0.35));
}

.hero-rings {
  position: absolute;
  border-radius: 50%;
  border: 1px solid rgba(191, 219, 254, 0.24);
}

.hero-rings-main {
  width: 520px;
  height: 520px;
  right: -140px;
  top: -40px;
  box-shadow:
    0 0 0 38px rgba(96, 165, 250, 0.06),
    0 0 0 76px rgba(191, 219, 254, 0.04),
    0 0 0 116px rgba(45, 212, 191, 0.04);
}

.hero-rings-sub {
  width: 240px;
  height: 240px;
  left: -58px;
  bottom: -48px;
  box-shadow:
    0 0 0 24px rgba(59, 130, 246, 0.06),
    0 0 0 48px rgba(96, 165, 250, 0.04);
}

.hero-axis {
  position: absolute;
  background: linear-gradient(90deg, transparent, rgba(186, 230, 253, 0.45), transparent);
}

.hero-axis-x {
  left: 0;
  right: 0;
  top: 50%;
  height: 1px;
}

.hero-axis-y {
  top: 0;
  bottom: 0;
  right: 28%;
  width: 1px;
  background: linear-gradient(180deg, transparent, rgba(186, 230, 253, 0.4), transparent);
}

.hero-glow {
  position: absolute;
  border-radius: 999px;
  filter: blur(36px);
}

.hero-glow-a {
  width: 220px;
  height: 220px;
  top: 18%;
  right: 16%;
  background: rgba(37, 99, 235, 0.2);
}

.hero-glow-b {
  width: 180px;
  height: 180px;
  left: 10%;
  bottom: 12%;
  background: rgba(20, 184, 166, 0.14);
}

.hero-content {
  position: relative;
  z-index: 1;
  max-width: 420px;
}

.hero-badge {
  display: inline-flex;
  align-items: center;
  width: fit-content;
  padding: 7px 12px;
  border: 1px solid rgba(191, 219, 254, 0.22);
  border-radius: 999px;
  background: rgba(7, 23, 45, 0.38);
  color: #c6dbff;
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.hero-kicker {
  margin-top: 18px;
  color: #7dd3fc;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.hero-title {
  margin-top: 14px;
  color: #f8fbff;
  font-size: clamp(34px, 4vw, 52px);
  line-height: 1.05;
  font-weight: 800;
  letter-spacing: -0.04em;
}

.hero-desc {
  margin-top: 16px;
  color: rgba(226, 232, 240, 0.84);
  font-size: 15px;
  line-height: 1.8;
}

.login-panel {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 28px;
  background: linear-gradient(180deg, rgba(255,255,255,0.07), rgba(255,255,255,0.02));
}

.login-panel-shell {
  width: 100%;
  max-width: 408px;
  padding: 32px 28px 26px;
  border-radius: 28px;
  background:
    radial-gradient(circle at top right, rgba(219, 234, 254, 0.95), transparent 34%),
    linear-gradient(180deg, rgba(255,255,255,0.96), rgba(248,250,252,0.98));
  border: 1px solid rgba(226, 232, 240, 0.96);
  box-shadow:
    0 22px 52px rgba(15, 23, 42, 0.22),
    inset 0 1px 0 rgba(255,255,255,0.72);
}

.login-brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.brand-icon {
  width: 54px;
  height: 54px;
  border-radius: 18px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  background:
    radial-gradient(circle at 32% 28%, rgba(255,255,255,0.42), transparent 26%),
    linear-gradient(135deg, #1d4ed8, #0ea5e9 56%, #14b8a6);
  box-shadow: 0 16px 28px rgba(37, 99, 235, 0.28);
}

.brand-icon::before,
.brand-icon::after {
  content: '';
  position: absolute;
  border-radius: 999px;
  background: rgba(255,255,255,0.88);
}

.brand-icon::before {
  width: 24px;
  height: 2px;
  transform: rotate(45deg);
}

.brand-icon::after {
  width: 2px;
  height: 24px;
  opacity: 0.7;
}

.brand-icon-core {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 0 0 4px rgba(255,255,255,0.18);
}

.brand-name {
  color: #0f172a;
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.03em;
}

.brand-sub {
  margin-top: 4px;
  color: #64748b;
  font-size: 12px;
  letter-spacing: 0.04em;
}

.login-copy {
  margin-top: 20px;
}

.login-copy-title {
  color: #0f172a;
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.03em;
}

.login-copy-desc {
  margin-top: 8px;
  color: #64748b;
  font-size: 13px;
  line-height: 1.7;
}

.login-form {
  margin-top: 22px;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.field-label {
  color: #1e293b;
  font-size: 13px;
  font-weight: 700;
}

.field-wrap {
  position: relative;
}

.field-icon {
  position: absolute;
  left: 14px;
  top: 50%;
  transform: translateY(-50%);
  color: #94a3b8;
  pointer-events: none;
}

.field-input {
  width: 100%;
  height: 52px;
  padding: 0 44px 0 42px;
  border: 1.5px solid #dbe3ef;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  color: #0f172a;
  font-size: 15px;
  outline: none;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.04);
}

.field-input:focus {
  border-color: #3b82f6;
  background: #fff;
  box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.12);
}

.field-input::placeholder {
  color: #9aa9bf;
}

.pw-toggle {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: 0;
  background: transparent;
  color: #94a3b8;
  cursor: pointer;
}

.pw-toggle:hover {
  color: #475569;
}

.error-msg {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 14px;
  border-radius: 16px;
  border: 1px solid #fecaca;
  background: #fff1f2;
  color: #b91c1c;
  font-size: 13px;
}

.submit-btn {
  height: 54px;
  margin-top: 4px;
  border: 0;
  border-radius: 18px;
  background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 58%, #0f5bd9 100%);
  color: #fff;
  font-size: 16px;
  font-weight: 800;
  letter-spacing: 0.18em;
  cursor: pointer;
  transition: transform 0.18s ease, box-shadow 0.18s ease, opacity 0.18s ease;
  box-shadow: 0 18px 28px rgba(37, 99, 235, 0.28);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 22px 34px rgba(37, 99, 235, 0.34);
}

.submit-btn:disabled {
  opacity: 0.68;
  cursor: not-allowed;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255,255,255,0.32);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.login-footer-hint {
  margin-top: 18px;
  text-align: center;
  color: #94a3b8;
  font-size: 12px;
}

@media (max-width: 900px) {
  .login-page {
    padding: 18px;
  }

  .login-stage {
    width: min(560px, 100%);
    min-height: calc(100dvh - 36px);
    display: block;
  }

  .login-hero {
    position: absolute;
    inset: 0;
    padding: 26px 22px;
    align-items: flex-start;
  }

  .hero-content {
    max-width: none;
    width: 100%;
    text-align: center;
  }

  .hero-badge {
    margin: 0 auto;
    font-size: 10px;
    letter-spacing: 0.1em;
  }

  .hero-kicker {
    margin-top: 12px;
    font-size: 10px;
    letter-spacing: 0.12em;
  }

  .hero-title {
    margin-top: 10px;
    font-size: 30px;
  }

  .hero-desc {
    margin-top: 12px;
    font-size: 12.5px;
    line-height: 1.7;
  }

  .hero-rings-main {
    width: 340px;
    height: 340px;
    right: -110px;
    top: -48px;
  }

  .hero-rings-sub {
    width: 190px;
    height: 190px;
    left: -60px;
    bottom: -40px;
  }

  .login-panel {
    position: relative;
    z-index: 1;
    min-height: calc(100dvh - 36px);
    padding: 24px 18px;
    background: transparent;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .login-panel-shell {
    margin: 0;
    padding: 26px 22px 22px;
    border-radius: 26px;
  }

  .login-copy {
    margin-top: 18px;
  }

  .login-copy-title {
    font-size: 22px;
  }

  .login-copy-desc {
    font-size: 12px;
    line-height: 1.6;
  }
}

@media (max-width: 480px) {
  .login-page {
    padding: 12px;
  }

  .login-stage {
    width: 100%;
    min-height: calc(100dvh - 24px);
    border-radius: 28px;
  }

  .login-hero {
    padding: 24px 18px;
  }

  .hero-badge {
    display: none;
  }

  .hero-kicker {
    display: none;
  }

  .hero-title {
    font-size: 28px;
  }

  .hero-desc {
    font-size: 12px;
  }

  .login-panel {
    min-height: calc(100dvh - 24px);
    padding: 16px;
  }

  .login-panel-shell {
    padding: 24px 18px 20px;
    border-radius: 24px;
  }

  .brand-icon {
    width: 50px;
    height: 50px;
    border-radius: 16px;
  }

  .brand-name {
    font-size: 18px;
  }

  .brand-sub {
    font-size: 11px;
  }

  .login-copy-title {
    font-size: 20px;
  }

  .login-copy-desc {
    display: none;
  }

  .field-input {
    height: 50px;
    border-radius: 15px;
  }

  .submit-btn {
    height: 52px;
    border-radius: 16px;
  }
}
</style>
