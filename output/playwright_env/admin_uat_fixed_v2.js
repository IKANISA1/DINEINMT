const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const rwEnv = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../dinein_app/env/release.rw.json'),
    'utf8',
  ),
);
const mtEnv = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, '../../dinein_app/env/release.mt.json'),
    'utf8',
  ),
);

const cases = [
  {
    name: 'rw-fixed-v2',
    host: 'https://ad4f3bdf.dinein-rw-pwa.pages.dev',
    functionBase: 'https://kczghhipbyykluuiiunp.supabase.co/functions/v1/whatsapp-otp',
    anonKey: rwEnv.SUPABASE_ANON_KEY,
    phone: '+250788767816',
  },
  {
    name: 'mt-fixed-v2',
    host: 'https://4f36e4a4.dinein-mt-pwa.pages.dev',
    functionBase: 'https://uskfnszcdqpcfrhjxitl.supabase.co/functions/v1/whatsapp-otp',
    anonKey: mtEnv.SUPABASE_ANON_KEY,
    phone: '+356771861993',
  },
];

const outDir = '../playwright';
fs.mkdirSync(outDir, { recursive: true });

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

async function runCase(browser, testCase) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
  const page = await context.newPage();
  const consoleLogs = [];
  page.on('console', (msg) => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', (err) => consoleLogs.push(`[pageerror] ${err.message}`));

  await page.goto(`${testCase.host}/#/admin/login`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(16000);
  await page.screenshot({ path: `${outDir}/${testCase.name}-login.png`, fullPage: true });

  const sendRes = await fetch(testCase.functionBase, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      apikey: testCase.anonKey,
      authorization: `Bearer ${testCase.anonKey}`,
    },
    body: JSON.stringify({
      action: 'send',
      appScope: 'admin',
      phone: testCase.phone,
    }),
  });
  const sendJson = await sendRes.json();
  if (!sendRes.ok || !sendJson.success) {
    throw new Error(`${testCase.name} send failed: ${JSON.stringify(sendJson)}`);
  }

  const verifyRes = await fetch(testCase.functionBase, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      apikey: testCase.anonKey,
      authorization: `Bearer ${testCase.anonKey}`,
    },
    body: JSON.stringify({
      action: 'verify',
      appScope: 'admin',
      phone: testCase.phone,
      verificationId: sendJson.verificationId,
      code: '123456',
    }),
  });
  const verifyJson = await verifyRes.json();
  if (!verifyRes.ok || !verifyJson.success || !verifyJson.verified || !verifyJson.adminSession) {
    throw new Error(`${testCase.name} verify failed: ${JSON.stringify(verifyJson)}`);
  }

  fs.writeFileSync(
    `${outDir}/${testCase.name}-session.json`,
    JSON.stringify(verifyJson.adminSession, null, 2),
  );

  await injectAdminSession(page, verifyJson.adminSession);

  await page.goto(`${testCase.host}/`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(18000);
  await page.screenshot({ path: `${outDir}/${testCase.name}-overview.png`, fullPage: true });

  const bodyText = await page.evaluate(() => document.body.innerText);
  const summary = {
    name: testCase.name,
    finalUrl: page.url(),
    send: {
      verificationId: sendJson.verificationId,
      deliveryMethod: sendJson.deliveryMethod,
    },
    verify: {
      verified: verifyJson.verified,
      verifiedAt: verifyJson.verifiedAt,
    },
    consoleLogTail: consoleLogs.slice(-30),
    hasTypeError: consoleLogs.some((line) => line.includes('TypeError: Instance of')),
    hasKpiText: bodyText.includes('TOTAL VENUES'),
    bodyTextSample: bodyText.slice(0, 400),
  };

  fs.writeFileSync(
    `${outDir}/${testCase.name}-uat.json`,
    JSON.stringify(summary, null, 2),
  );
  await context.close();
  return summary;
}

async function main() {
  const browser = await chromium.launch({ headless: true });
  try {
    const results = [];
    for (const testCase of cases) {
      results.push(await runCase(browser, testCase));
    }
    fs.writeFileSync(
      `${outDir}/admin-uat-fixed-v2-summary.json`,
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
