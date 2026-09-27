/* Run with PLAYWRIGHT_MODULE pointing to an installed @playwright/test package. */
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '@playwright/test');
const assert = require('node:assert/strict');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    headless: true,
    args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  await page.goto('http://127.0.0.1:8060', { waitUntil: 'networkidle' });
  await page.waitForSelector('#loading', { state: 'detached', timeout: 90000 });
  await page.waitForTimeout(1800);
  await page.screenshot({ path: 'builds/web-mobile-preview.png' });
  // At 390×844 the game letterboxes its base 900×1600 canvas by expanding vertically.
  // Read the generated state rather than depending on a fixed first-level fixture.
  const initialSave = await readSave();
  assert.equal(initialSave?.generator_version, 1, 'Browser starts a procedural campaign');
  assert.equal(initialSave?.legacy_level, false, 'New games use generated levels');
  const state = initialSave.board;
  let source = -1, target = -1;
  for (let a = 0; a < state.length && source < 0; a++) {
    if (new Set(state[a]).size < 2) continue;
    for (let b = 0; b < state.length; b++) {
      if (a !== b && state[b].length < 4 && (!state[b].length || state[b].at(-1) === state[a].at(-1))) {
        source = a; target = b; break;
      }
    }
  }
  assert.ok(source >= 0, 'The generated first puzzle offers a legal sorting move');
  const scale = 390 / 900;
  const virtualHeight = 844 / scale;
  const uiScale = 1.12;
  const boardScale = Math.min((900 - 24) / 941, (virtualHeight - 390 * uiScale) / 1672);
  const boardX = (900 - 941 * boardScale) / 2;
  const boardY = 194 * uiScale;
  const xs = [158, 369, 570, 782], ys = [478, 947, 1418];
  function pocketPoint(index) {
    return { x: (boardX + xs[index % 4] * boardScale) * scale,
      y: (boardY + (ys[Math.floor(index / 4)] - 1.5 * 89) * boardScale) * scale };
  }
  const before = await page.locator('canvas').screenshot();
  for (const index of [source, target]) {
    const p = pocketPoint(index);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(600);
  }
  await page.screenshot({ path: 'builds/web-mobile-after-move.png' });
  assert.notDeepEqual(await page.locator('canvas').screenshot(), before, 'Touch interaction changes the canvas');
  await page.waitForTimeout(1800);
  async function readSave() {
    return page.evaluate(async () => {
      for (const metadata of await indexedDB.databases()) {
        const db = await new Promise((resolve, reject) => {
          const request = indexedDB.open(metadata.name);
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error);
        });
        for (const store of db.objectStoreNames) {
          const entries = await new Promise((resolve, reject) => {
            const request = db.transaction(store).objectStore(store).getAll();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          });
          for (const entry of entries) {
            try {
              const data = JSON.parse(new TextDecoder().decode(entry.contents));
              if (data.version === 2 && data.board) { db.close(); return data; }
            } catch (_) { /* Other engine files are not JSON game saves. */ }
          }
        }
        db.close();
      }
      return null;
    });
  }
  assert.equal((await readSave())?.moves, 1, 'Touch move is saved to IndexedDB');
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForSelector('#loading', { state: 'detached', timeout: 90000 });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'builds/web-mobile-restored.png' });
  assert.equal((await readSave())?.moves, 1, 'Reload preserves the move');
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'builds/web-desktop-preview.png' });
  assert.equal(errors.length, 0, errors.join('\n'));
  console.log('PASS: WebGL startup, mobile touch input, persisted move, reload restoration, desktop resize; no browser runtime errors.');
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });
