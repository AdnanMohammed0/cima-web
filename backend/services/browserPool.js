const { chromium } = require('playwright');

let browser;
let browserPromise = null;

async function launchBrowser() {
  const launchTimeout = 45000;
  const launchPromise = chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process'],
  });
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('Browser launch timed out')), launchTimeout)
  );
  return Promise.race([launchPromise, timeoutPromise]);
}

async function getBrowser() {
  if (browser && browser.isConnected()) return browser;
  if (browserPromise) return browserPromise;
  browserPromise = (async () => {
    try {
      if (browser) await browser.close().catch(() => {});
      browser = await launchBrowser();
      return browser;
    } finally {
      browserPromise = null;
    }
  })();
  return browserPromise;
}

async function warmup() {
  try {
    const b = await getBrowser();
    const ctx = await b.newContext();
    const page = await ctx.newPage();
    await page.goto('about:blank');
    await page.close();
    await ctx.close();
    console.log('[browser] Warmed up');
  } catch (err) {
    console.error('[browser] Warmup failed:', err.message);
  }
}

async function shutdown() {
  if (browser) { await browser.close().catch(() => {}); browser = null; }
}

module.exports = { getBrowser, warmup, shutdown };
