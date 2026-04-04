const { test } = require('playwright/test');

async function capturePageState(page, tag) {
  await page.waitForLoadState('networkidle', { timeout: 120000 });
  await page.screenshot({
    path: `output/playwright/${tag}.png`,
    fullPage: true,
  });

  const title = await page.title();
  const url = page.url();
  const bodyText = await page.locator('body').innerText();
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

  console.log(JSON.stringify({ tag, title, url, bodyText, inputs, buttons }, null, 2));
}

test('inspect Malta admin login page', async ({ page }) => {
  await page.goto('https://dineinmta.ikanisa.com/#/admin/login');
  await capturePageState(page, 'admin-mt-login');
});

test('inspect Rwanda admin login page', async ({ page }) => {
  await page.goto('https://dineinrwa.ikanisa.com/#/admin/login');
  await capturePageState(page, 'admin-rw-login');
});
