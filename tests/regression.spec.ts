import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';

const BASE_URL = 'http://127.0.0.1:15173';
const OUTPUT_DIR = path.join(process.cwd(), 'output', 'playwright');

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Tăng timeout cho kịch bản chạy tuần tự trên máy local
test.setTimeout(60000);

async function registerNewUser(page: any, prefix = 'pw') {
  await page.goto(BASE_URL);
  await page.waitForLoadState('domcontentloaded');

  const switchBtn = page.locator('.login-switch button');
  const isRegisterForm = await page.locator('input[name="confirmPassword"]').isVisible();
  if (!isRegisterForm && (await switchBtn.isVisible())) {
    await switchBtn.click();
  }

  const testUser = `${prefix}_${Date.now()}`;
  const testEmail = `${testUser}@local-test.local`;
  const testPass = 'LocalPass@123456';

  await page.fill('input[name="username"]', testUser);
  await page.fill('input[name="email"]', testEmail);
  await page.fill('input[name="password"]', testPass);
  await page.fill('input[name="confirmPassword"]', testPass);

  await Promise.all([
    page.waitForURL('**/hoc', { timeout: 15000 }),
    page.click('button.primary')
  ]);

  return { testUser, testEmail, testPass };
}

test.describe('TrafficHub UI/UX & Role Regression Suite', () => {

  test('1. Đăng ký tài khoản User mới & tự động chuyển hướng về /hoc', async ({ page }) => {
    const { testUser } = await registerNewUser(page, 'reg');
    expect(page.url()).toContain('/hoc');
    await expect(page.locator('.sidebar-bottom strong')).toContainText(testUser);
  });

  test('2. Phân quyền Role User: Ẩn menu Admin & Chặn truy cập route Admin', async ({ page }) => {
    await registerNewUser(page, 'guard');

    // User không thấy menu Admin
    const adminBox = page.locator('.nav-admin-box');
    await expect(adminBox).toHaveCount(0);

    // Chặn route /noi-dung -> redirect /hoc
    await page.goto(`${BASE_URL}/noi-dung`);
    await page.waitForURL('**/hoc');
    expect(page.url()).toMatch(/\/hoc$/);

    // Chặn route /duyet-mo-phong -> redirect /hoc
    await page.goto(`${BASE_URL}/duyet-mo-phong`);
    await page.waitForURL('**/hoc');
    expect(page.url()).toMatch(/\/hoc$/);
  });

  test('3. F5 lưu phiên đăng nhập (Session Persistence)', async ({ page }) => {
    const { testUser } = await registerNewUser(page, 'f5');

    // F5 trang
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(500);

    expect(page.url()).toContain('/hoc');
    await expect(page.locator('.sidebar-bottom strong')).toContainText(testUser);
  });

  const VIEWPORTS = [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'tablet', width: 1024, height: 768 },
    { name: 'mobile', width: 390, height: 844 },
    { name: 'landscape', width: 844, height: 390 },
  ];

  for (const vp of VIEWPORTS) {
    test(`4. Kiểm tra Không tràn ngang trên ${vp.name} (${vp.width}x${vp.height})`, async ({ page }) => {
      await page.setViewportSize({ width: vp.width, height: vp.height });
      await registerNewUser(page, `vp_${vp.name}`);

      const routes = ['/hoc', '/thi', '/tien-do', '/chat', '/van-ban', '/tai-khoan'];

      for (const r of routes) {
        await page.goto(`${BASE_URL}${r}`, { waitUntil: 'domcontentloaded' });
        await page.waitForTimeout(200);

        const hasOverflow = await page.evaluate(() => {
          return document.documentElement.scrollWidth > window.innerWidth ||
                 document.body.scrollWidth > window.innerWidth;
        });

        expect(hasOverflow, `Phát hiện tràn ngang tại route ${r} trên viewport ${vp.name}`).toBe(false);

        // Lưu ảnh baseline cho các route đại diện
        if (['/hoc', '/thi', '/chat', '/tai-khoan'].includes(r) && ['desktop', 'mobile'].includes(vp.name)) {
          const shotPath = path.join(OUTPUT_DIR, `baseline-${r.replace('/', '')}-${vp.name}.png`);
          await page.screenshot({ path: shotPath });
        }
      }
    });
  }
});
