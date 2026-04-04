const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const cases = [
  {
    name: 'rw-custom-final',
    host: 'https://dineinrwa.ikanisa.com',
    sessionPath: path.resolve(__dirname, '../playwright/rw-fixed-v2-session.json'),
  },
  {
    name: 'mt-custom-final',
    host: 'https://dineinmta.ikanisa.com',
    sessionPath: path.resolve(__dirname, '../playwright/mt-fixed-v2-session.json'),
  },
];

const outDir = path.resolve(__dirname, '../playwright');

async function injectAdminSession(page, session) {
  await page.evaluate(async (sessionValue) => {
    const storageKey = 'FlutterSecureStorage';
    const valueKey = 'FlutterSecureStorage.dinein.admin_session';
    const encoder = new TextEncoder();
    const text = JSON.stringify(sessionValue);
    let cryptoKey;
    const existing = window.localStorage.getItem(storageKey);
    if (existing) {
      const raw = Uint8Array.from(atob(existing), (char) => char.charCodeAt(0));
      cryptoKey = await window.crypto.subtle.importKey(
        'raw',
        raw,
        { name: 'AES-GCM', length: 256 },
        false,
        ['encrypt', 'decrypt'],
      );
    } else {
      cryptoKey = await window.crypto.subtle.generateKey(
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt'],
      );
      const raw = new Uint8Array(await window.crypto.subtle.exportKey('raw', cryptoKey));
      window.localStorage.setItem(storageKey, btoa(String.fromCharCode(...raw)));
    }
    const iv = window.crypto.getRandomValues(new Uint8Array(12));
    const encrypted = new Uint8Array(
      await window.crypto.subtle.encrypt(
        { name: 'AES-GCM', iv },
        cryptoKey,
        encoder.encode(text),
      ),
    );
    window.localStorage.setItem(
      valueKey,
      `${btoa(String.fromCharCode(...iv))}.${btoa(String.fromCharCode(...encrypted))}`,
    );
  }, session);
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  try {
    for (const testCase of cases) {
      const session = JSON.parse(fs.readFileSync(testCase.sessionPath, 'utf8'));
      const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
      const page = await context.newPage();
      const consoleLogs = [];
      page.on('console', (msg) => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
      page.on('pageerror', (err) => consoleLogs.push(`[pageerror] ${err.message}`));

      await page
          .goto(`${testCase.host}/#/admin/login`, {
            waitUntil: 'domcontentloaded',
            timeout: 15000,
          })
          .catch((error) => {
            consoleLogs.push(`[goto-login-error] ${error.message}`);
          });
      await page.waitForTimeout(5000);
      await injectAdminSession(page, session);
      await page
          .goto(`${testCase.host}/`, {
            waitUntil: 'domcontentloaded',
            timeout: 20000,
          })
          .catch((error) => {
            consoleLogs.push(`[goto-root-error] ${error.message}`);
          });
      await page.waitForTimeout(25000);
      await page.screenshot({
        path: path.join(outDir, `${testCase.name}-overview.png`),
        fullPage: true,
      });

      const result = {
        name: testCase.name,
        finalUrl: page.url(),
        hasTypeError: consoleLogs.some((line) => line.includes('TypeError: Instance of')),
        consoleLogTail: consoleLogs.slice(-30),
      };
      results.push(result);
      fs.writeFileSync(
        path.join(outDir, `${testCase.name}-summary.json`),
        JSON.stringify(result, null, 2),
      );
      await context.close();
    }
    fs.writeFileSync(
      path.join(outDir, 'custom-domain-admin-overview-summary.json'),
      JSON.stringify(results, null, 2),
    );
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
