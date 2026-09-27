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
  assert.equal(initialSave?.layout?.version, 3, 'Browser uses procedural board geometry');
  assert.equal(initialSave.layout.wells.length, 12, 'Generated layout includes every touch target');
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
  function pocketPoint(index, layout = initialSave.layout) {
    const center = layout.wells[index].center;
    return { x: (boardX + center[0] * boardScale) * scale,
      y: (boardY + center[1] * boardScale) * scale };
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
  assert.deepEqual((await readSave()).layout, initialSave.layout, 'Reload preserves exact pocket geometry');
  // Finish the introductory puzzle, then interact with the next physical layout.
  function sortingMove(board) {
    for (const allowEmpty of [false, true]) {
      for (let a = 0; a < board.length; a++) {
        if (!board[a].length || (board[a].length === 4 && new Set(board[a]).size === 1)) continue;
        for (let b = 0; b < board.length; b++) {
          if (a === b || board[b].length >= 4) continue;
          if (board[b].length && board[b].at(-1) === board[a].at(-1)) return [a, b];
          if (allowEmpty && !board[b].length && new Set(board[a]).size > 1) return [a, b];
        }
      }
    }
    return null;
  }
  async function touchMove(move, layout) {
    assert.ok(move, 'A sorting move exists');
    for (const index of move) {
      const point = pocketPoint(index, layout);
      await page.touchscreen.tap(point.x, point.y);
      await page.waitForTimeout(650);
    }
    await page.waitForTimeout(1200);
  }
  let progress = await readSave();
  for (let step = 0; step < 12 && progress.unlocked < 2; step++) {
    await touchMove(sortingMove(progress.board), progress.layout);
    progress = await readSave();
  }
  assert.equal(progress.unlocked, 2, 'Tutorial completion unlocks the next generated board');
  const modalTop = (virtualHeight - 510 * uiScale) / 2;
  await page.touchscreen.tap(195, (modalTop + 363.5 * uiScale) * scale);
  await page.waitForTimeout(1800);
  const secondLevel = await readSave();
  assert.equal(secondLevel.level, 1, 'Next puzzle opens');
  assert.notDeepEqual(secondLevel.layout.wells, initialSave.layout.wells, 'Next puzzle changes actual pocket placement');
  assert.notDeepEqual(secondLevel.layout.corridors, initialSave.layout.corridors, 'Next puzzle changes maze connections');
  await touchMove(sortingMove(secondLevel.board), secondLevel.layout);
  assert.equal((await readSave()).moves, 1, 'Touch input works on the second generated layout');
  await page.screenshot({ path: 'builds/web-mobile-layout-02.png' });
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'builds/web-desktop-preview.png' });
  assert.equal(errors.length, 0, errors.join('\n'));
  console.log('PASS: WebGL startup, touch input on two generated layouts, persisted geometry, reload, win/advance, desktop resize; no browser runtime errors.');
  await browser.close();
})().catch(error => { console.error(error); process.exit(1); });
