const { test, expect, devices } = require('@playwright/test');

const PLAYTEST_URL = process.env.PLAYTEST_URL || 'https://jvmisxn.github.io/jmo-pixel-dungeon/';
const BLOCKED_CONSOLE_PATTERNS = [
  /SCRIPT ERROR/i,
  /Parse Error/i,
  /Failed to load script/i,
  /Parameter "p_child" is null/i,
  /Loaded 0 sound effects/i,
  /Loaded 0 music tracks/i,
  /Unknown music track/i,
];

test.use({
  browserName: 'chromium',
  ...devices['Pixel 7'],
});

test('mobile web start flow has no critical console regressions', async ({ page }) => {
  const messages = [];
  page.on('console', (msg) => {
    messages.push(`${msg.type()}: ${msg.text()}`);
  });
  page.on('pageerror', (err) => {
    messages.push(`pageerror: ${err.message}`);
  });

  await page.goto(PLAYTEST_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(12000);

  await expectCanvas(page);
  await page.touchscreen.tap(206, 258); // default profile name Continue
  await page.waitForTimeout(2500);
  await page.touchscreen.tap(206, 238); // New Game
  await page.waitForTimeout(2500);
  await page.touchscreen.tap(206, 780); // Start hero
  await page.waitForTimeout(6000);
  await expectCanvas(page);

  const blocked = messages.filter((line) => BLOCKED_CONSOLE_PATTERNS.some((pattern) => pattern.test(line)));
  expect(blocked, `Critical console output:\n${blocked.join('\n')}`).toEqual([]);
});

async function expectCanvas(page) {
  const canvas = page.locator('canvas').first();
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  expect(box).not.toBeNull();
  expect(box.width).toBeGreaterThan(300);
  expect(box.height).toBeGreaterThan(600);
}
