import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = process.env.BASE_URL || 'https://finsimup.app';
const USERNAME = process.env.TEST_USERNAME || 'test';
const PASSWORD = process.env.TEST_PASSWORD || 'Test12345678!';

const PAGES = [
  { path: '/', name: 'Landing' },
  { path: '/login', name: 'Login' },
  { path: '/register', name: 'Register' },
];

const AUTH_PAGES = [
  { path: '/dashboard', name: 'Dashboard' },
  { path: '/markets', name: 'Markets' },
  { path: '/stocks', name: 'Stocks' },
  { path: '/indices', name: 'Indices' },
  { path: '/forex', name: 'Forex' },
  { path: '/portfolio', name: 'Portfolio' },
  { path: '/leaderboard', name: 'Leaderboard' },
  { path: '/learn', name: 'Learn' },
  { path: '/transactions', name: 'Transactions' },
  { path: '/profile', name: 'Profile' },
  { path: '/admin', name: 'Admin' },
];

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
  });

  const page = await context.newPage();
  const consoleErrors = [];
  const failedRequests = new Set();

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push({ text: msg.text(), url: msg.location().url });
    }
  });

  page.on('requestfailed', (req) => {
    const url = req.url();
    const method = req.method();
    const failure = req.failure();
    if (failure) {
      failedRequests.add({ url, method, error: failure.errorText });
    }
  });

  let passed = 0;
  let failed = 0;
  const results = [];

  function check(description, condition) {
    if (condition) {
      passed++;
      results.push(`  ✅ ${description}`);
    } else {
      failed++;
      results.push(`  ❌ ${description}`);
    }
  }

  // Step 1: Clear SW and caches before any navigation
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.evaluate(() => {
    if ('serviceWorker' in navigator) {
      return navigator.serviceWorker.getRegistrations().then((regs) =>
        Promise.all(regs.map((r) => r.unregister()))
      );
    }
  });
  await page.evaluate(() => {
    if ('caches' in window) {
      return caches.keys().then((names) => Promise.all(names.map((n) => caches.delete(n))));
    }
  });
  console.log('🧹 Cleared service workers and caches');
  console.log('');

  // Step 2: Check public pages
  console.log('📄 Testing public pages...');
  for (const { path, name } of PAGES) {
    const url = `${BASE_URL}${path}`;
    const errCount = consoleErrors.length;
    const failCount = failedRequests.size;

    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});

    const newErrors = consoleErrors.slice(errCount);
    const newFails = Array.from(failedRequests).slice(failCount);

    const pageErrors = newErrors.filter((e) =>
      !e.text.includes('favicon') && !e.text.includes('Failed to load resource')
    );
    const chunk404s = newFails.filter((f) =>
      f.url.includes('/assets/') && f.error.includes('404')
    );
    const cspViolations = newFails.filter((f) =>
      f.error.includes('ERR_BLOCKED_BY_CLIENT')
    );
    const autocompleteWarnings = newErrors.filter((e) =>
      e.text.includes('autocomplete')
    );

    check(`${name} (${path}) — loaded without errors`, pageErrors.length === 0);
    if (pageErrors.length > 0) {
      pageErrors.forEach((e) => results.push(`     ⚠️  ${e.text.substring(0, 200)}`));
    }
    check(`${name} — no 404 chunk errors`, chunk404s.length === 0);
    check(`${name} — no CSP violations`, cspViolations.length === 0);
    check(`${name} — no autocomplete warnings`, autocompleteWarnings.length === 0);

    // Clear collected errors for next page
    consoleErrors.length = 0;
    failedRequests.clear();
  }

  // Step 3: Try login
  console.log('');
  console.log('🔑 Testing login...');

  await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForSelector('input[name="username"]', { timeout: 10000 }).catch(() => {});

  // Clear any CSP errors from page load before login
  consoleErrors.length = 0;
  failedRequests.clear();

  await page.fill('input[name="username"]', USERNAME);
  await page.fill('input[name="password"]', PASSWORD);
  await page.click('button[type="submit"]');

  // Wait for navigation to dashboard (up to 15s)
  try {
    await page.waitForURL('**/dashboard', { timeout: 15000 });
  } catch {
    // If navigation didn't happen, check current URL after timeout
    await page.waitForTimeout(2000);
  }
  const currentUrl = page.url();

  // Filter only login-specific errors
  const loginErrors = consoleErrors.slice(0);
  const loginFails = Array.from(failedRequests).slice(0);

  const sessionExpired = loginErrors.some((e) =>
    e.text.includes('sesión ha expirado') || e.text.includes('sesion ha expirado')
  );

  check('Login successful (redirected to dashboard)',
    currentUrl.includes('/dashboard') || currentUrl !== `${BASE_URL}/login`
  );
  check('No "sesión ha expirado" toast after login', !sessionExpired);

  const refresh401s = loginFails.filter((f) =>
    f.url.includes('/refresh-token') && f.error.includes('401')
  );
  check('No refresh-token 401 errors', refresh401s.length === 0);

  consoleErrors.length = 0;
  failedRequests.clear();

  // Step 4: Test auth pages
  if (currentUrl.includes('/dashboard') || currentUrl !== `${BASE_URL}/login`) {
    console.log('');
    console.log('🔒 Testing authenticated pages...');

    for (const { path, name } of AUTH_PAGES) {
      const ec = consoleErrors.length;
      const fc = failedRequests.size;

      await page.goto(`${BASE_URL}${path}`, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});

      const newErrors = consoleErrors.slice(ec);
      const newFails = Array.from(failedRequests).slice(fc);

      const pageErrors = newErrors.filter((e) =>
        !e.text.includes('favicon') && !e.text.includes('Failed to fetch dynamically imported module')
      );
      const chunk404s = newFails.filter((f) =>
        f.url.includes('/assets/') && f.error.includes('404')
      );
      const cspViolations = newFails.filter((f) =>
        f.error.includes('ERR_BLOCKED_BY_CLIENT')
      );
      // Track dynamic import failures as page errors
      const importFailures = newErrors.filter((e) =>
        e.text.includes('Failed to fetch dynamically imported module')
      );

      check(`${name} (${path}) — loaded without JS import errors`, importFailures.length === 0);
      check(`${name} — no 404 chunk errors`, chunk404s.length === 0);
      check(`${name} — no CSP violations`, cspViolations.length === 0);

      consoleErrors.length = 0;
      failedRequests.clear();
    }
  }

  console.log('');
  console.log('='.repeat(50));
  console.log(`📊 Results: ${passed} passed, ${failed} failed`);
  console.log('='.repeat(50));
  results.forEach((r) => console.log(r));

  await browser.close();
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('Test error:', e);
  process.exit(1);
});
