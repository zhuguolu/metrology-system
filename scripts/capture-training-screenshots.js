const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE_URL = process.env.BASE_URL || 'http://host.docker.internal';
const USERNAME = process.env.APP_USERNAME || 'admin';
const PASSWORD = process.env.APP_PASSWORD || 'admin123';
const OUT_DIR = path.resolve(process.cwd(), 'docs', 'training-screenshots');

fs.mkdirSync(OUT_DIR, { recursive: true });

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function safeDismissDialogs(page) {
  const closeTexts = ['取消', '关闭', '知道了', '确定'];
  for (const text of closeTexts) {
    const btn = page.getByRole('button', { name: text }).first();
    if (await btn.isVisible().catch(() => false)) {
      await btn.click().catch(() => {});
      await wait(300);
    }
  }
}

async function capture(page, filename, opts = {}) {
  if (opts.route) {
    await page.goto(`${BASE_URL}${opts.route}`, { waitUntil: 'networkidle' });
  }
  if (opts.waitForText) {
    await page.getByText(opts.waitForText, { exact: false }).first().waitFor({ timeout: 15000 });
  }
  if (opts.waitForSelector) {
    await page.locator(opts.waitForSelector).first().waitFor({ timeout: 15000 });
  }
  await wait(opts.delay || 1200);
  await safeDismissDialogs(page);
  await page.screenshot({
    path: path.join(OUT_DIR, filename),
    fullPage: !!opts.fullPage,
  });
  console.log(`captured ${filename}`);
}

async function login(page) {
  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle' });
  await wait(1200);
  await page.screenshot({ path: path.join(OUT_DIR, '01-login.png'), fullPage: true });
  await page.locator('input[autocomplete="username"]').fill(USERNAME);
  await page.locator('input[autocomplete="current-password"]').fill(PASSWORD);
  await page.getByRole('button', { name: /登录|鐧/ }).click();
  await page.waitForURL(/dashboard/, { timeout: 20000 });
  await wait(1800);
}

async function captureEquipment(page) {
  await page.goto(`${BASE_URL}/equipment`, { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: /新增设备|新增/ }).click();
  await page.getByText(/基本信息|仪器名称/, { exact: false }).first().waitFor({ timeout: 15000 });
  await wait(900);
  await page.screenshot({ path: path.join(OUT_DIR, '03-equipment.png'), fullPage: true });
}

async function captureFileShare(page) {
  await page.goto(`${BASE_URL}/files`, { waitUntil: 'networkidle' });
  await page.getByText(/全部文件/, { exact: false }).first().waitFor({ timeout: 15000 });
  await wait(1500);

  const items = page.locator('.file-item');
  const count = await items.count();
  let opened = false;

  for (let i = 0; i < Math.min(count, 12); i += 1) {
    const item = items.nth(i);
    await item.click({ button: 'right' }).catch(() => {});
    await wait(500);
    const shareBtn = page.getByRole('button', { name: '外链分享' }).first();
    if (await shareBtn.isVisible().catch(() => false)) {
      await shareBtn.click();
      opened = true;
      break;
    }
    await page.mouse.click(10, 10);
    await wait(200);
  }

  if (!opened) {
    throw new Error('No shareable folder was found in files page.');
  }

  await page.getByText(/文件夹外链分享/, { exact: false }).first().waitFor({ timeout: 15000 });
  await wait(900);
  await page.screenshot({ path: path.join(OUT_DIR, '07-share-dialog.png'), fullPage: true });

  const saveBtn = page.getByRole('button', { name: '保存分享' }).first();
  if (await saveBtn.isVisible().catch(() => false)) {
    await saveBtn.click();
    await wait(1600);
  }

  const shareInput = page.locator('.share-link-row input').first();
  const shareLink = await shareInput.inputValue().catch(() => '');
  if (!shareLink) {
    throw new Error('Share link was not generated.');
  }

  return shareLink;
}

async function capturePublicShare(browser, shareLink) {
  const page = await browser.newPage({ viewport: { width: 1440, height: 920 } });
  await page.goto(shareLink, { waitUntil: 'networkidle' });
  await wait(1800);
  await page.screenshot({ path: path.join(OUT_DIR, '08-public-share.png'), fullPage: true });
  await page.close();
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 920 },
    locale: 'zh-CN',
  });
  const page = await context.newPage();

  try {
    await login(page);

    await capture(page, '02-dashboard.png', { route: '/dashboard', waitForText: '总览看板' });
    await captureEquipment(page);
    await capture(page, '04-calibration.png', { route: '/calibration', waitForText: '校准管理' });
    await capture(page, '05-todo.png', { route: '/todo', waitForText: '我的待办' });
    await capture(page, '06-files.png', { route: '/files', waitForText: '全部文件' });

    const shareLink = await captureFileShare(page);
    await capturePublicShare(browser, shareLink);

    await capture(page, '09-audit.png', { route: '/audit', waitForText: '数据审核' });
    await capture(page, '10-change-records.png', { route: '/change-records', waitForText: '变更记录' });
    await capture(page, '11-users.png', { route: '/users', waitForText: '用户管理' });
    await capture(page, '12-departments.png', { route: '/departments', waitForText: '部门管理' });
    await capture(page, '13-device-status.png', { route: '/device-status', waitForText: '使用状态' });
    await capture(page, '14-settings.png', { route: '/settings', waitForText: '系统设置' });
    await capture(page, '15-webdav.png', { route: '/webdav', waitForText: '网络挂载' });
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
