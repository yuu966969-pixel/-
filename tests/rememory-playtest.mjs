import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const browser = await chromium.launch({
  headless: true,
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist']
});
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const pageErrors = [];
const dataFailures = [];
page.on('pageerror', error => pageErrors.push(error.message));
page.on('response', response => {
  if (/\/data\/(companions|weapons)\.json/.test(response.url()) && !response.ok()) {
    dataFailures.push(response.url() + ' -> ' + response.status());
  }
});
try {
  await page.goto('http://127.0.0.1:4173/?test=1', { waitUntil: 'networkidle', timeout: 60000 });
  await page.locator('#game canvas').waitFor({ timeout: 20000 });
  await page.waitForFunction(() => window.__REMEMORY_TEST__?.weaponCount === 100, null, { timeout: 20000 });
  const webgl = await page.locator('#game canvas').evaluate(canvas => Boolean(canvas.getContext('webgl2')));
  assert.equal(webgl, true, 'WebGL2 renderer should initialize');
  await page.waitForTimeout(800);
  assert.ok((await page.evaluate(() => window.__REMEMORY_TEST__.renderCalls)) > 0, '3D scene should render');

  await page.locator('#choosePC').click();
  assert.equal(await page.evaluate(() => window.__REMEMORY_TEST__.platform), 'pc');
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => window.__REMEMORY_TEST__.started);
  assert.ok(await page.evaluate(() => window.__REMEMORY_TEST__.hunger) > 99.9, 'Hunger should start full');
  await page.waitForFunction(() => document.querySelector('#prompt')?.textContent.includes('灰雪マッシュルーム'));
  await page.keyboard.press('e');
  await page.waitForFunction(() => window.__REMEMORY_TEST__.foodInventory.wildMushroom === 1);
  await page.waitForFunction(() => document.querySelector('#prompt')?.textContent.includes('穢れの肉片'));
  await page.keyboard.press('e');
  await page.waitForFunction(() => window.__REMEMORY_TEST__.foodInventory.kegareMeat === 1);
  await page.keyboard.press('Tab');
  await page.locator('#mFood').click();
  await page.locator('#cookMushroom').click();
  assert.equal(await page.evaluate(() => window.__REMEMORY_TEST__.foodInventory.cookedMeal), 1, 'Mushroom should cook into a meal');
  assert.ok(await page.locator('#cook_root').count() === 1, 'Root vegetable recipe should be available');
  assert.ok(await page.locator('#cook_berry').count() === 1, 'Berry recipe should be available');
  assert.ok(await page.locator('#cook_broth').count() === 1, 'Nutrient broth recipe should be available');
  assert.ok(await page.locator('#cook_corn').count() === 1, 'Charred corn recipe should be available');
  assert.ok(await page.locator('#cook_tea').count() === 1, 'Herbal tea recipe should be available');
  assert.ok(await page.locator('#cook_porridge').count() === 1, 'Nut porridge recipe should be available');
  assert.ok(await page.locator('#cook_preserve').count() === 1, 'Peach preserve recipe should be available');
  
  const hungerBeforeMeal = await page.evaluate(() => window.__REMEMORY_TEST__.hunger);
  await page.locator('#eatMeal').click();
  assert.ok(await page.evaluate(() => window.__REMEMORY_TEST__.hunger) > hungerBeforeMeal, 'Eating should restore hunger');
  await page.keyboard.press('Escape');
  
  await page.keyboard.press('Tab');
  await page.waitForFunction(() => window.__REMEMORY_TEST__.menu);
  await page.locator('#mMap').focus();
  await page.keyboard.press('Enter');
  await page.getByText('APURF789 探索マップ', { exact: true }).waitFor();
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => !window.__REMEMORY_TEST__.menu);

  await page.keyboard.press('Tab');
  await page.locator('#mArmory').focus();
  await page.keyboard.press('Enter');
  await page.getByText('武器工房・防具研究', { exact: true }).waitFor();
  await page.keyboard.press('Escape');

  await page.keyboard.press('Tab');
  await page.locator('#saveButton').focus();
  await page.keyboard.press('Enter');
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('rememory-apurf789-autosave-v2')));
  assert.equal(saved.version, 16, 'Save data should use schema v16');
  assert.ok(saved.player && Number.isFinite(saved.player.x), 'Save should include player position');

  const mobilePage = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const mobileErrors = [];
  mobilePage.on('pageerror', error => mobileErrors.push(error.message));
  await mobilePage.goto('http://127.0.0.1:4173/?test=1', { waitUntil: 'networkidle', timeout: 60000 });
  await mobilePage.locator('#game canvas').waitFor({ timeout: 20000 });
  await mobilePage.locator('#chooseMobile').click();
  assert.equal(await mobilePage.evaluate(() => window.__REMEMORY_TEST__.platform), 'mobile');
  await mobilePage.locator('#start').click();
  await mobilePage.waitForFunction(() => window.__REMEMORY_TEST__.started);
  assert.equal(await mobilePage.locator('#mobileControls').isVisible(), true, 'Touch controls should be visible on mobile');
  assert.equal(await mobilePage.locator('[data-hold="w"]').count(), 1, 'Mobile movement pad should be present');
  assert.equal(await mobilePage.locator('[data-tap="e"]').count(), 1, 'Mobile interaction button should be present');
  assert.deepEqual(mobileErrors, [], 'Mobile mode should have no uncaught browser exceptions');
  await mobilePage.close();

  assert.deepEqual(dataFailures, [], 'Companion and weapon data should load successfully');
  assert.deepEqual(pageErrors, [], 'No uncaught browser exceptions should occur');
  console.log(JSON.stringify({
    status: 'PASS',
    checks: ['WebGL2 boot', '3D render loop', '100-weapon catalog load', 'PC platform selection', 'Enter start', 'forage and cooking survival loop', 'keyboard map navigation', 'keyboard armory navigation', 'v16 save', 'hunger HUD', 'forage mushrooms and Kegare meat', 'cook and eat food', 'mobile platform selection', 'touch control layout'],
    pageErrors
  }, null, 2));
} catch (error) {
  await page.screenshot({ path: '/tmp/rememory-playtest-failure.png', fullPage: true }).catch(() => {});
  console.error('PLAYTEST FAILED:', error);
  console.error('PAGE ERRORS:', pageErrors);
  console.error('DATA FAILURES:', dataFailures);
  process.exitCode = 1;
} finally {
  await browser.close();
}
