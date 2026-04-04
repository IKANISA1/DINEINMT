const { test } = require('playwright/test');

async function capturePageState(page, tag) {
  const consoleMessages = [];
  const pageErrors = [];
  const requestFailures = [];
  const responses = [];
  page.on('console', (msg) => {
    consoleMessages.push({ type: msg.type(), text: msg.text() });
  });
  page.on('pageerror', (error) => {
    pageErrors.push(String(error));
  });
  page.on('requestfailed', (request) => {
    requestFailures.push({
      url: request.url(),
      method: request.method(),
      failure: request.failure(),
    });
  });
  page.on('response', async (response) => {
    const url = response.url();
    if (url.includes('supabase.co') || url.includes('flutter') || url.includes('main.dart.js')) {
      responses.push({
        url,
        status: response.status(),
      });
    }
  });

  await page.waitForLoadState('networkidle', { timeout: 120000 });
  await page.waitForTimeout(15000);
  await page.screenshot({
    path: `output/playwright/${tag}.png`,
    fullPage: true,
  });

  const title = await page.title();
  const url = page.url();
  const bodyText = await page.locator('body').innerText();
  const accessibility = await page.accessibility.snapshot({ interestingOnly: false });
  const inputs = await page.locator('input').evaluateAll((nodes) =>
    nodes.map((node, index) => ({
      index,
      type: node.getAttribute('type'),
      placeholder: node.getAttribute('placeholder'),
      inputmode: node.getAttribute('inputmode'),
      ariaLabel: node.getAttribute('aria-label'),
    }))
  );
  const buttons = await page.locator('button').evaluateAll((nodes) =>
    nodes.map((node, index) => ({
      index,
      text: (node.textContent || '').trim(),
      ariaLabel: node.getAttribute('aria-label'),
    }))
  );

  console.log(JSON.stringify({
    tag,
    title,
    url,
    bodyText,
    accessibility,
    inputs,
    buttons,
    consoleMessages,
    pageErrors,
    requestFailures,
    responses,
  }, null, 2));
}

test('inspect Malta admin login page', async ({ page }) => {
  await page.goto('https://dineinmta.ikanisa.com/#/admin/login');
  await capturePageState(page, 'admin-mt-login');
});

test('inspect Rwanda admin login page', async ({ page }) => {
  await page.goto('https://dineinrwa.ikanisa.com/#/admin/login');
  await capturePageState(page, 'admin-rw-login');
});

test('request Malta admin OTP through live PWA', async ({ page }) => {
  const otpResponses = [];
  page.on('response', async (response) => {
    const url = response.url();
    if (!url.includes('/functions/v1/whatsapp-otp')) return;
    let body = null;
    try {
      body = await response.json();
    } catch {
      body = await response.text();
    }
    otpResponses.push({
      url,
      status: response.status(),
      body,
    });
  });

  await page.goto('https://dineinmta.ikanisa.com/#/admin/login');
  await page.waitForLoadState('networkidle', { timeout: 120000 });
  await page.waitForTimeout(5000);

  await page.mouse.click(280, 325);
  await page.keyboard.insertText('771861993');
  await page.screenshot({ path: 'output/playwright/admin-mt-filled.png', fullPage: true });
  for (const [x, y] of [[640, 430], [640, 500], [640, 560]]) {
    if (otpResponses.length) break;
    await page.mouse.click(x, y);
    await page.waitForTimeout(3000);
  }
  await page.waitForTimeout(8000);
  await page.screenshot({ path: 'output/playwright/admin-mt-after-submit.png', fullPage: true });

  console.log(JSON.stringify({ tag: 'admin-mt-send', otpResponses }, null, 2));
});
