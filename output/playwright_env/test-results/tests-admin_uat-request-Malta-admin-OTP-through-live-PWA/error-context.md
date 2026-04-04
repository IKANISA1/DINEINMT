# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: tests/admin_uat.spec.js >> request Malta admin OTP through live PWA
- Location: tests/admin_uat.spec.js:84:1

# Error details

```
Test timeout of 30000ms exceeded.
```

```
Error: page.waitForTimeout: Test timeout of 30000ms exceeded.
```

# Page snapshot

```yaml
- button "Enable accessibility" [ref=e2]
```

# Test source

```ts
  14  |   page.on('requestfailed', (request) => {
  15  |     requestFailures.push({
  16  |       url: request.url(),
  17  |       method: request.method(),
  18  |       failure: request.failure(),
  19  |     });
  20  |   });
  21  |   page.on('response', async (response) => {
  22  |     const url = response.url();
  23  |     if (url.includes('supabase.co') || url.includes('flutter') || url.includes('main.dart.js')) {
  24  |       responses.push({
  25  |         url,
  26  |         status: response.status(),
  27  |       });
  28  |     }
  29  |   });
  30  | 
  31  |   await page.waitForLoadState('networkidle', { timeout: 120000 });
  32  |   await page.waitForTimeout(15000);
  33  |   await page.screenshot({
  34  |     path: `output/playwright/${tag}.png`,
  35  |     fullPage: true,
  36  |   });
  37  | 
  38  |   const title = await page.title();
  39  |   const url = page.url();
  40  |   const bodyText = await page.locator('body').innerText();
  41  |   const accessibility = await page.accessibility.snapshot({ interestingOnly: false });
  42  |   const inputs = await page.locator('input').evaluateAll((nodes) =>
  43  |     nodes.map((node, index) => ({
  44  |       index,
  45  |       type: node.getAttribute('type'),
  46  |       placeholder: node.getAttribute('placeholder'),
  47  |       inputmode: node.getAttribute('inputmode'),
  48  |       ariaLabel: node.getAttribute('aria-label'),
  49  |     }))
  50  |   );
  51  |   const buttons = await page.locator('button').evaluateAll((nodes) =>
  52  |     nodes.map((node, index) => ({
  53  |       index,
  54  |       text: (node.textContent || '').trim(),
  55  |       ariaLabel: node.getAttribute('aria-label'),
  56  |     }))
  57  |   );
  58  | 
  59  |   console.log(JSON.stringify({
  60  |     tag,
  61  |     title,
  62  |     url,
  63  |     bodyText,
  64  |     accessibility,
  65  |     inputs,
  66  |     buttons,
  67  |     consoleMessages,
  68  |     pageErrors,
  69  |     requestFailures,
  70  |     responses,
  71  |   }, null, 2));
  72  | }
  73  | 
  74  | test('inspect Malta admin login page', async ({ page }) => {
  75  |   await page.goto('https://dineinmta.ikanisa.com/#/admin/login');
  76  |   await capturePageState(page, 'admin-mt-login');
  77  | });
  78  | 
  79  | test('inspect Rwanda admin login page', async ({ page }) => {
  80  |   await page.goto('https://dineinrwa.ikanisa.com/#/admin/login');
  81  |   await capturePageState(page, 'admin-rw-login');
  82  | });
  83  | 
  84  | test('request Malta admin OTP through live PWA', async ({ page }) => {
  85  |   const otpResponses = [];
  86  |   page.on('response', async (response) => {
  87  |     const url = response.url();
  88  |     if (!url.includes('/functions/v1/whatsapp-otp')) return;
  89  |     let body = null;
  90  |     try {
  91  |       body = await response.json();
  92  |     } catch {
  93  |       body = await response.text();
  94  |     }
  95  |     otpResponses.push({
  96  |       url,
  97  |       status: response.status(),
  98  |       body,
  99  |     });
  100 |   });
  101 | 
  102 |   await page.goto('https://dineinmta.ikanisa.com/#/admin/login');
  103 |   await page.waitForLoadState('networkidle', { timeout: 120000 });
  104 |   await page.waitForTimeout(5000);
  105 | 
  106 |   await page.mouse.click(280, 325);
  107 |   await page.keyboard.insertText('771861993');
  108 |   await page.screenshot({ path: 'output/playwright/admin-mt-filled.png', fullPage: true });
  109 |   for (const [x, y] of [[640, 430], [640, 500], [640, 560]]) {
  110 |     if (otpResponses.length) break;
  111 |     await page.mouse.click(x, y);
  112 |     await page.waitForTimeout(3000);
  113 |   }
> 114 |   await page.waitForTimeout(8000);
      |              ^ Error: page.waitForTimeout: Test timeout of 30000ms exceeded.
  115 |   await page.screenshot({ path: 'output/playwright/admin-mt-after-submit.png', fullPage: true });
  116 | 
  117 |   console.log(JSON.stringify({ tag: 'admin-mt-send', otpResponses }, null, 2));
  118 | });
  119 | 
```